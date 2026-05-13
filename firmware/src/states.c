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

void handleIdle(FSM *nFsm) {
    USART_send_string("IDLE");
    _delay_ms(1000);
    checkLid(nFsm); //check if Lid is open, if it is change to MAINTENANCE
    double weight = HX711_get_mean_value(1);
    sendScaleReading(weight);
    _delay_ms(1000);
    if (weight > CUP_PRESENT) {
        transition(nFsm, CUP_PLACED);
    }
}

void handleCupPlaced(FSM *nFsm) {
    checkLid(nFsm); //check if Lid is open

    double weight = HX711_get_mean_value(1);
    sendScaleReading(weight);

    if (weight < CUP_PRESENT) {
        nFsm->cupClass = 0x00;
        transition(nFsm, IDLE);
    }

    nFsm->cupClass = classifyCup(weight);

    //debug
    USART_send_char(nFsm->cupClass);
    _delay_ms(1000);
    USART_send_char(packet);

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
            default:
                break;
        }
    }
}

void handleDispense(FSM* nFsm) {

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

void dynamicTimer(uint16_t ocr) {
    OCR1AH = (ocr >> 8);
    OCR1AL = ocr;

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

void checkLid(FSM *nFsm) {
    uint16_t ldr = adcRead(0);
    if (ldr > LIGHT_THRESHOLD) {
        transition(nFsm, MAINTENANCE);
    }
}
