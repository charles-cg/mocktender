#include "states.h"
#include "interrupts.h"
#include "HX711.h"
#include "config.h"
#include "fsm.h"


void handleIdle(void) {
    checkLid(); //check if Lid is open, if it is change to MAINTENANCE
    double weight = HX711_get_mean_value(3);
    if (weight > CUP_PRESENT) {
        transition(&fsm, CUP_PLACED);
    }
}

void handleCupPlaced(void) {
    checkLid(); //check if Lid is open

    double weight = HX711_get_mean_value(3);

    if (weight < CUP_PRESENT) {
        fsm.cupClass = 0x00;
        transition(&fsm, IDLE);
    }

    fsm.cupClass = classifyCup(weight);

    if (dataReady) {
        
    }

    
}

char classifyCup(double weight) {
    if (weight >= CUP_PRESENT && weight < SMALL_CUP) {
        return 0x01;
    } else if (weight >= SMALL_CUP && weight < MED_CUP) {
        return 0x02;
    } else if (weight >= MED_CUP && weight < BIG_CUP) {
        return 0x03;
    } else {
        return 0x00;
    }
}
