#include "states.h"
#include "flash.h"
#include "fsm.h"
#include "interrupts.h"
#include "HX711.h"
#include "config.h"
#include "USART.h"
#include "timers.h"
#include <stdlib.h>

void handleCalibrate(FSM* nFsm) {
    // activate just INT2 (rst)
    GICR |= (1 << INT2);
    delayCheck = 0;
    delay30sDone = 0;
    USART_send_string("Calibrating: warming up (30s)...\r\n");
    delay5s();
    // Let the HX711 + load cell thermally settle before taring,
    // otherwise warm-up drift makes the captured zero unstable.
    while (!delay30sDone) {
        if (rstPressed) {
            rstPressed = 0;
            USART_send_string("Calibration reset\r\n");
            transition(nFsm, CALIBRATE);
            return;
        }
    }
    USART_send_string("Taring...\r\n");
    (void)HX711_read_average(10);   // discard first batch
    HX711_tare(20);
    HX711_set_scale(715);

    USART_send_string("Machine is ready\r\n");
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
        transition(nFsm, MAINTENANCE);
        return;
    }

    double weight = HX711_get_mean_units(10);
    if (weight < SCALE_DEADBAND && weight > -SCALE_DEADBAND) weight = 0;
    if (weight > CUP_PRESENT) {
        USART_send_string("Cup placed: ");
        sendScaleReading(weight);
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
        transition(nFsm, MAINTENANCE);
        return;
    }

    double weight = HX711_get_mean_units(10);

    if (weight < CUP_PRESENT) {
        USART_send_string("Cup removed\r\n");
        nFsm->cupClass = 0x00;
        transition(nFsm, IDLE);
        return;
    }

    nFsm->cupClass = classifyCup(weight);

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
            char name[22];
            getRecipeName(nFsm->recipeId, name);
            USART_send_string("Recipe: ");
            USART_send_string(name);
            USART_send_string(" | Cup class: ");
            USART_send_char(nFsm->cupClass);
            USART_send_string("\r\n");
            transition(nFsm, DISPENSE);
        }
    }
    return;
}

void handleDispense(FSM* nFsm) {
    char name[22];
    getRecipeName(nFsm->recipeId, name);
    USART_send_string("Dispensing: ");
    USART_send_string(name);
    USART_send_string("\r\n");

    GICR &= ~(1 << INT0);
    for (globalPump = 0; globalPump < 6; globalPump++) {
        if (getRecipeRatio(nFsm->recipeId, globalPump) != 0) {
            uint8_t vol = calculateMl(nFsm, globalPump);
            USART_send_string("Pump ");
            USART_send_uint8(globalPump + 1);
            USART_send_string(": ");
            USART_send_uint8(vol);
            USART_send_string(" mL\r\n");
            PORTC |= (1 << globalPump);
            pumpBusy = 1;
            TCNT1 = 0;
            dynamicDelay(nFsm, globalPump);
            while (pumpBusy) {
                if (rstPressed) {
                    USART_send_string("Dispense aborted\r\n");
                    rstAction(nFsm);
                    TCCR1B = 0x00;
                    TCNT1 = 0;
                    PORTC &= ~(1 << globalPump);
                    pumpBusy = 0;
                    globalPump = 0;
                    transition(nFsm, IDLE);
                    return;
                }
                double weight = HX711_get_mean_units(10);
                if (weight < CUP_PRESENT) {
                    USART_send_string("Error: cup removed during dispense\r\n");
                    PORTC &= ~(1 << globalPump);
                    pumpBusy = 0;
                    globalPump = 0;
                    nFsm->errorCode = 0x01;
                    transition(nFsm, ERROR);
                    return;
                }
            }
            USART_send_string("Pump ");
            USART_send_uint8(globalPump + 1);
            USART_send_string(" done\r\n");
        }
    }

    USART_send_string("Dispense complete\r\n");
    globalPump = 0;
    transition(nFsm, DELIVER);
    return;
}

void handleDeliver(FSM* nFsm) {
    double weight = HX711_get_mean_units(10);

    if (weight < CUP_PRESENT) {
        USART_send_string("Order complete\r\n");
        nFsm->cupClass = 0x00;
        nFsm->recipeId = 0;
        transition(nFsm, IDLE);
        return;
    }
}

void handleError(FSM* nFsm) {
    char buf[4];
    USART_send_string("Error: 0x");
    itoa(nFsm->errorCode, buf, 16);
    USART_send_string(buf);
    USART_send_string(" - press RST to continue\r\n");

    while (!rstPressed);

    rstAction(nFsm);
    transition(nFsm, IDLE);
    return;
}

void handleMaintenance(FSM* nFsm) {
    GICR |= (1 << INT1); // activate start interrupt

    if (maintPressed == 2) {
        maintPressed = 0;
    }

    if (startPressed) {
        if (maintPressed == 0) {
            // ADC read with selection save
            transition(nFsm, CLEANING);
            return;
        } else if (maintPressed == 1) {
            // ADC read with selection save
            transition(nFsm, REFILL);
            return;
        }
    }
}

void rstAction(FSM* nFsm) {
    rstPressed = 0;
    nFsm->cupClass = 0;
    nFsm->recipeId = 0;
    nFsm->errorCode = 0;
}

char classifyCup(double weight) {
    if (weight >= CUP_PRESENT && weight < SMALL_CUP) {
        return '1';
    } else if (weight >= SMALL_CUP && weight < MED_CUP) {
        return '2';
    } else if (weight >= MED_CUP) {
        return '3';
    } else {
        return '0';
    }
}

void dynamicDelay (FSM* nFsm, uint8_t pump) {
    uint8_t volume = calculateMl(nFsm, pump);
    uint16_t time = calculateTime(volume);
    uint16_t ocr = calculateOCR1(time);
    dynamicTimer(ocr);
}

// Returns OCR1 value for a given duration in milliseconds.
// 1 ms = 1000 µs / 128 µs-per-tick = 125/16 ticks (exact).
uint16_t calculateOCR1(uint16_t time_ms) {
    return (uint32_t)time_ms * 1000UL / TIMER_TICK_US - 1;
}

// Returns dispense duration in milliseconds.
// 1000 ms/s / 26.67 mL/s = 75/2 ms per mL (exact).
uint16_t calculateTime(uint8_t volume) {
    return (uint16_t)volume * 75 / 2;
}

uint8_t calculateMl(FSM* nFsm, uint8_t pump) {
    uint8_t ratio = getRecipeRatio(nFsm->recipeId, pump);
    uint16_t cupSize = getCupSize(nFsm);
    uint8_t ml = (uint16_t)cupSize * ratio / 100;
    return ml;
}

uint16_t getCupSize(FSM* nFsm) {
    switch (nFsm->cupClass) {
        case '1':
            return 100;
        case '2':
            return 250;
        case '3':
            return 400;
        default:
            nFsm->errorCode = 0x02;
            transition(nFsm, ERROR);
            return 0;
    }
}

