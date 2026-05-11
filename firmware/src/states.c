#include "states.h"
#include "USART.h"
#include "fsm.h"
#include "interrupts.h"
#include "HX711.h"
#include "config.h"
#include <stdint.h>
#include <util/delay.h>
#include "ADC.h"

void handleIdle(FSM *nFsm) {
    USART_send_string("IDLE");
    _delay_ms(1000);
    checkLid(nFsm); //check if Lid is open, if it is change to MAINTENANCE
    double weight = HX711_get_mean_value(3);
    sendScaleReading(weight);
    _delay_ms(1000);
    if (weight > CUP_PRESENT) {
        transition(nFsm, CUP_PLACED);
    }
}

void handleCupPlaced(FSM *nFsm) {
    USART_send_string("CUP_PLACED");
    checkLid(nFsm); //check if Lid is open

    double weight = HX711_get_mean_value(3);

    if (weight < CUP_PRESENT) {
        nFsm->cupClass = 0x00;
        transition(nFsm, IDLE);
    }

    nFsm->cupClass = classifyCup(weight);

    USART_send_char(nFsm->cupClass);

    if (dataReady) {
        switch (packet) {
            case 1:
                nFsm->recipeId = 0;
                break;
            case 2:
                nFsm->recipeId = 1;
                break;
            case 3:
                nFsm->recipeId = 2;
                break;
            case 4:
                nFsm->recipeId = 3;
                break;
            case 5:
                nFsm->recipeId = 4;
                break;
            case 6:
                nFsm->recipeId = 5;
                break;
            default: {
                nFsm->errorCode = 1;
                transition(nFsm, ERROR);
                break;
            }
        }

        transition(nFsm, DISPENSE);
    }
}

uint8_t classifyCup(double weight) {
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

void checkLid(FSM *nFsm) {
    uint16_t ldr = adcRead(0);
    if (ldr > LIGHT_THRESHOLD) {
        transition(nFsm, MAINTENANCE);
    }
}
