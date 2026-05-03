#include "states.h"
#include "HX711.h"
#include "config.h"
#include "fsm.h"


void handleIdle(void) {
    checkLid(); //check if Lid is open, if it is cange to MAINTENANCE
    double weight = HX711_get_mean_value(3);
    if (weight > CUP_PRESENT) {
        transition(&fsm, CUP_PLACED);
    }
}


