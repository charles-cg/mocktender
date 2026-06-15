#include "states.h"
#include "ADC.h"
#include "eeprom.h"
#include "flash.h"
#include "fsm.h"
#include "interrupts.h"
#include "HX711.h"
#include "config.h"
#include "timers.h"
#include "USART.h"
#include <avr/eeprom.h>
#include <avr/io.h>
#include <stdint.h>
#include <util/delay.h>

void handleCalibrate(FSM* nFsm) {
    // activate just INT2 (rst)
    GICR |= (1 << INT2);
    delayCheck = 0;
    delay30sDone = 0;
    delay5s();
    sendPacket(nFsm->cupClass, nFsm->state, nFsm->errorCode);
    // Let the HX711 + load cell thermally settle before taring
    uint8_t lastTick = 0;
    while (!delay30sDone) {
        if (rstPressed) {
            rstPressed = 0;
            transition(nFsm, CALIBRATE);
            return;
        }
        uint8_t tick = delayCheck;
        if (tick != lastTick) {
            lastTick = tick;
            sendPacket(nFsm->cupClass, nFsm->state, nFsm->errorCode);
        }
    }
    (void)HX711_read_average(10);   // discard first batch
    HX711_tare(20);
    HX711_set_scale(715);

    transition(nFsm, IDLE);
    return;
}

void handleIdle(FSM* nFsm) {
    GICR |= (1 << INT0);
    if (rstPressed) {
        rstAction(nFsm);
        transition(nFsm, IDLE);
        return;
    } else if (maintPressed) {
        maintPressed = 0;
        GICR |= (1 << INT1); // activate start interrupt
        transition(nFsm, MAINTENANCE);
        return;
    }

    float weight = HX711_get_mean_units(10);
    if (weight < SCALE_DEADBAND && weight > -SCALE_DEADBAND) weight = 0;
    if (weight > CUP_PRESENT) {
        dataReady = 0;
        transition(nFsm, CUP_PLACED);
        return;
    }
}

void handleCupPlaced(FSM* nFsm) {
    if (rstPressed) {
        rstAction(nFsm);
        transition(nFsm, IDLE);
        return;
    } else if (maintPressed) {
        maintPressed = 0;
        GICR |= (1 << INT1); // activate start interrupt
        transition(nFsm, MAINTENANCE);
        return;
    }

    float weight = HX711_get_mean_units(10);

    if (weight < CUP_PRESENT) {
        nFsm->cupClass = 0x00;
        transition(nFsm, IDLE);
        return;
    }

    nFsm->cupClass = classifyCup(weight);
    sendPacket(nFsm->cupClass, nFsm->state, nFsm->errorCode);

    if (dataReady) {
        dataReady = 0;
        uint8_t valid = 1;
        switch (packet) {
            case '1': nFsm->recipeId = 0; break;
            case '2': nFsm->recipeId = 1; break;
            case '3': nFsm->recipeId = 2; break;
            case '4': nFsm->recipeId = 3; break;
            case '5': nFsm->recipeId = 4; break;
            case '6': nFsm->recipeId = 5; break;
            case '7': nFsm->recipeId = 6; break;
            case '8': nFsm->recipeId = 7; break;
            case '9': nFsm->recipeId = 8; break;
            case 'A': nFsm->recipeId = 9; break;
            default:  valid = 0;          break;
        }
        if (valid) {
            transition(nFsm, DISPENSE);
        }
    }
    return;
}

void handleDispense(FSM* nFsm) {
    GICR &= ~(1 << INT0);
    cancelPressed = 0;   // ignore any cancel latched before the pour started

    for (uint8_t p = 0; p < 6; p++) {
        if (getRecipeRatio(nFsm->recipeId, p) == 0) continue;
        uint16_t needMl = calculateMl(nFsm, p);
        if ((uint32_t)usedMl[p] + needMl > totalMl[p]) {
            nFsm->errorCode = 0x04 + p;
            transition(nFsm, ERROR);
            return;
        }
    }

    for (globalPump = 0; globalPump < 6; globalPump++) {
        if (getRecipeRatio(nFsm->recipeId, globalPump) != 0) {
            PORTC |= (1 << globalPump);
            pumpBusy = 1;
            TCNT1 = 0;
            dynamicDelay(nFsm, globalPump);
            uint8_t absentCount = 0;   // consecutive sub-threshold reads
            while (pumpBusy) {
                // Physical reset or app "Cancel" aborts the pour back to IDLE
                if (rstPressed || cancelPressed) {
                    cancelPressed = 0;
                    rstAction(nFsm);   // clears rstPressed + cup/recipe/error
                    TCCR1B = 0x00;
                    TCNT1 = 0;
                    PORTC &= ~(1 << globalPump);
                    pumpBusy = 0;
                    globalPump = 0;
                    transition(nFsm, IDLE);
                    return;
                }
                float weight = HX711_get_mean_units(DISPENSE_POLL_SAMPLES);
                // Only fault once the cup stays absent for several reads (motor
                // noise can briefly read low)
                if (weight < CUP_PRESENT) {
                    if (++absentCount < CUP_REMOVED_CONSEC) continue;
                    TCCR1B = 0x00;
                    TCNT1 = 0;
                    PORTC &= ~(1 << globalPump);
                    pumpBusy = 0;
                    globalPump = 0;
                    nFsm->errorCode = 0x01;
                    transition(nFsm, ERROR);
                    return;
                }
                absentCount = 0;
            }
            usedMl[globalPump] += calculateMl(nFsm, globalPump);
            eeprom_update_word(&eeUsedMl[globalPump], usedMl[globalPump]);
        }
    }

    globalPump = 0;
    updateUsedMl(); // update used ML EEPROM
    transition(nFsm, DELIVER);
    return;
}

void handleDeliver(FSM* nFsm) {
    float weight = HX711_get_mean_units(10);

    if (weight < CUP_PRESENT) {
        nFsm->cupClass = 0x00;
        nFsm->recipeId = 0;
        transition(nFsm, IDLE);
        return;
    }
}

void handleError(FSM* nFsm) {
    // Periodic ERROR broadcast lives in main.c (next to IDLE's 1 Hz tick);
    // here we only watch for the reset button to release the FSM back to
    // IDLE, which the app uses as the "operator acknowledged" signal.
    if (rstPressed) {
        rstAction(nFsm);
        transition(nFsm, IDLE);
        return;
    }
}

void handleMaintenance(FSM* nFsm) {
    if (rstPressed) {
        GICR &= ~(1 << INT1);
        rstAction(nFsm);
        maintPressed = 0;
        transition(nFsm, IDLE);
        return;
    }

    if (maintPressed == 2) {
        maintPressed = 0;
    }

    // Mirror selection + pot-selected pump to the app, only on change to avoid
    // flooding the BLE bridge. Selection rides in the cup field ('0'=clean,
    // '1'=refill), pump index (0..6) in the error field.
    potClassify();
    static uint8_t lastSel = 0xFF;
    static uint8_t lastPump = 0xFF;
    if (maintPressed != lastSel || globalPump != lastPump) {
        lastSel = maintPressed;
        lastPump = globalPump;
        sendPacket('0' + maintPressed, nFsm->state, globalPump);
    }

    if (startPressed) {
        if (maintPressed == 0) {
            // ADC read with selection save by modifying globalPump
            maintPressed = 0;
            startPressed = 0;
            potClassify();
            transition(nFsm, CLEANING);
            return;
        } else if (maintPressed == 1) {
            // ADC read with selection save
            maintPressed = 0;
            startPressed = 0;
            potClassify();
            transition(nFsm, REFILL);
            return;
        }
    }
}

void handleCleaning(FSM* nFsm) {
    cancelPressed = 0;   // ignore any cancel latched before cleaning started
    if (globalPump == 6) {
        PORTC |= (0b00111111);
        dynamicTimer(65535);
        pumpBusy = 1;
    } else {
        PORTC |= (1 << globalPump);
        dynamicTimer(65535);
        pumpBusy = 1;
    }

    uint8_t absentCount = 0;   // consecutive sub-threshold reads
    while (pumpBusy) {
        // Physical reset or app "Cancel" stops cleaning; polled first so it
        // wins over the cup check during high-current inrush
        if (rstPressed || cancelPressed) {
            cancelPressed = 0;
            TCCR1B = 0x00;
            TCNT1 = 0;
            PORTC &= ~(0b00111111);
            rstAction(nFsm);
            globalPump = 0;
            GICR &= ~(1 << INT1);
            transition(nFsm, IDLE);
            return;
        }
        sendPacket(nFsm->cupClass, nFsm->state, nFsm->errorCode);

        // Ride out transient absent reads (motor inrush can brown out the
        // load cell) before faulting to "cup removed"
        float weight = HX711_get_mean_units(DISPENSE_POLL_SAMPLES);
        if (weight < CUP_PRESENT) {
            if (++absentCount < CUP_REMOVED_CONSEC) continue;
            TCCR1B = 0x00;
            TCNT1 = 0;
            PORTC &= ~(0b00111111);
            rstAction(nFsm);
            globalPump = 0;
            nFsm->errorCode = 0x03;
            GICR &= ~(1 << INT1);
            transition(nFsm, ERROR);
            return;
        }
        absentCount = 0;
    }

    globalPump = 0;
    GICR &= ~(1 << INT1);
    transition(nFsm, IDLE);
    return;
}

void handleRefill(FSM* nFsm) {
    if (globalPump == 6) {
        setUsedMl();
        globalPump = 0;
        GICR &= ~(1 << INT1);
        transition(nFsm, IDLE);
        return;
    } else {
        eeprom_update_word(&eeUsedMl[globalPump], 0);
        usedMl[globalPump] = 0;
        globalPump = 0;
        GICR &= ~(1 << INT1);
        transition(nFsm, IDLE);
        return;
    }
}

void potClassify() {
    uint16_t pot = adcRead(PA0);

    if (pot <= PUMP1_2) {
        globalPump = 0;
    } else if (pot <= PUMP2_3) {
        globalPump = 1;
    } else if (pot <= PUMP3_4) {
        globalPump = 2;
    } else if (pot <= PUMP4_5) {
        globalPump = 3;
    } else if (pot <= PUMP5_6) {
        globalPump = 4;
    } else if (pot <= PUMP6_ALL) {
        globalPump = 5;
    } else if (pot <= PUMP_END) {
        globalPump = 6; //place holder turns on all pumps
    }
}

void rstAction(FSM* nFsm) {
    rstPressed = 0;
    nFsm->cupClass = 0;
    nFsm->recipeId = 0;
    nFsm->errorCode = 0;
}

char classifyCup(float weight) {
    if (weight >= SMALL_CUP - CUP_TOLERANCE && weight <= SMALL_CUP + CUP_TOLERANCE) {
        return '1';
    } else if (weight >= MED_CUP - CUP_TOLERANCE && weight <= MED_CUP + CUP_TOLERANCE) {
        return '2';
    } else if (weight >= BIG_CUP - CUP_TOLERANCE && weight <= BIG_CUP + CUP_TOLERANCE) {
        return '3';
    } else {
        return '0';
    }
}

// Per-pump flow rates, mL/s * 100. Index matches globalPump (0-5).
static const uint16_t flowRateX100[6] = {
    FLOWRATE_PUMP1_X100,
    FLOWRATE_PUMP2_X100,
    FLOWRATE_PUMP3_X100,
    FLOWRATE_PUMP4_X100,
    FLOWRATE_PUMP5_X100,
    FLOWRATE_PUMP6_X100,
};

void dynamicDelay (FSM* nFsm, uint8_t pump) {
    uint16_t volume = calculateMl(nFsm, pump);
    uint16_t time = calculateTime(volume, pump);
    uint16_t ocr = calculateOCR1(time);
    dynamicTimer(ocr);
}

// Returns OCR1 value for a given duration in milliseconds.
// 1 ms = 1000 µs / 128 µs-per-tick = 125/16 ticks (exact).
uint16_t calculateOCR1(uint16_t time_ms) {
    return (uint32_t)time_ms * 1000UL / TIMER_TICK_US - 1;
}

// Returns dispense duration in milliseconds for a given pump.
// time_ms = volume_mL / (mL/s) * 1000 = volume * 100000 / flowRateX100.
uint16_t calculateTime(uint16_t volume, uint8_t pump) {
    return (uint32_t)volume * 100000UL / flowRateX100[pump];
}

uint16_t calculateMl(FSM* nFsm, uint8_t pump) {
    uint8_t ratio = getRecipeRatio(nFsm->recipeId, pump);
    uint16_t cupSize = getCupSize(nFsm);
    uint16_t ml = (uint16_t)cupSize * ratio / 100;
    return ml;
}

uint16_t getCupSize(FSM* nFsm) {
    switch (nFsm->cupClass) {
        case '1':
            return 120;   // small cup volume (mL)
        case '2':
            return 190;   // medium cup volume (mL)
        case '3':
            return 240;   // big cup volume (mL)
        default:
            nFsm->errorCode = 0x02;
            transition(nFsm, ERROR);
            return 0;
    }
}

