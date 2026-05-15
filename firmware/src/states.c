#include "states.h"
#include "USART.h"
#include "flash.h"
#include "fsm.h"
#include "interrupts.h"
#include "HX711.h"
#include "config.h"
#include <avr/io.h>
#include <stdint.h>
#include <util/delay.h>
#include "ADC.h"

void handleIdle(FSM* nFsm) {
    double weight = HX711_get_mean_units(10);
    if (weight < SCALE_DEADBAND && weight > -SCALE_DEADBAND) weight = 0;
    if (weight > CUP_PRESENT) {
        dataReady = 0;
        transition(nFsm, CUP_PLACED);
    }
}

void handleCupPlaced(FSM* nFsm) {
    double weight = HX711_get_mean_units(10);

    if (weight < CUP_PRESENT) {
        nFsm->cupClass = 0x00;
        transition(nFsm, IDLE);
    }

    nFsm->cupClass = classifyCup(weight);


    if (dataReady) {
        dataReady = 0;
        switch (packet) {
            case '1': {
                nFsm->recipeId = 0;
                transition(nFsm, DISPENSE);
                break;
            }
            case '2': {
                nFsm->recipeId = 1;
                transition(nFsm, DISPENSE);
                break;
            }
            case '3': {
                nFsm->recipeId = 2;
                transition(nFsm, DISPENSE);
                break;
            }
            case '4': {
                nFsm->recipeId = 3;
                transition(nFsm, DISPENSE);
                break;
            }
            case '5': {
                nFsm->recipeId = 4;
                transition(nFsm, DISPENSE);
                break;
            }
            case '6': {
                nFsm->recipeId = 5;
                transition(nFsm, DISPENSE);
                break;
            }
            case '7': {
                nFsm->recipeId = 6;
                transition(nFsm, DISPENSE);
                break;
            }
            case '8': {
                nFsm->recipeId = 7;
                transition(nFsm, DISPENSE);
                break;
            }
            case '9': {
                nFsm->recipeId = 8;
                transition(nFsm, DISPENSE);
                break;
            }
            case 'A': {
                nFsm->recipeId = 9;
                transition(nFsm, DISPENSE);
                break;
            }
            default:
                break;
        }
    }
}

void handleDispense(FSM* nFsm) {
    for (globalPump = 0; globalPump < 6; globalPump++) {
        if (getRecipeRatio(nFsm->recipeId, globalPump) != 0) {
            PORTC |= (1 << globalPump);
            pumpBusy = 1;
            TCNT1 = 0;
            dynamicDelay(nFsm, globalPump);
            while (pumpBusy);
        }
    }

    globalPump = 0;
    transition(nFsm, DELIVER);
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

void dynamicTimer(uint16_t ocr) {
    OCR1A = ocr;

    TCCR1B = (1 << WGM12) | (1 << CS12) | (1 << CS10);
    TIMSK = (1 << OCIE1A);
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

void checkLid(FSM* nFsm) {
    uint16_t ldr = adcRead(0);
    if (ldr > LIGHT_THRESHOLD) {
        transition(nFsm, MAINTENANCE);
    }
}
