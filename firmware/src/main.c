#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#include "config.h"
#include "fsm.h"

int main (void) {

    while (1) {
        switch (fsm.state) {
            case IDLE: {
                break;
            }
            case CUP_PLACED: {
                break;
            }
            case DISPENSE: {
                break;
            }
            case DELIVER: {
                break;
            }
            case MAINTENANCE: {
                break;
            }
            case CLEANING: {
                break;
            }
            case ERROR: {
                break;
            }
        }
    }

    return 0;
}
