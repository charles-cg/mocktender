#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#include "USART.h"
#include "HX711.h"
#include "config.h"
#include "fsm.h"
#include "states.h"

int main (void) {
    USART_init(MYUBRR);
    HX711_init(128);
    sei();

    FSM fsm = {IDLE, IDLE, 0, 0, 0};
    while (1) {
        switch (fsm.state) {
            case IDLE: {
                handleIdle(fsm);
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
