#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#include "USART.h"
#include "HX711.h"
#include "config.h"
#include "fsm.h"
#include "states.h"
#include "ADC.h"

int main (void) {
    USART_init(MYUBRR);
    HX711_init(128);
    HX711_tare(10);   // zero the scale with nothing on it
    adcInit();
    DDRC = 0xFF;
    sei();

    FSM fsm = {IDLE, IDLE, 0, 0, 0};
    while (1) {
        switch (fsm.state) {
            case IDLE: {
                handleIdle(&fsm);
                break;
            }
            case CUP_PLACED: {
                handleCupPlaced(&fsm);
                break;
            }
            case DISPENSE: {
                handleDispense(&fsm);
                break;
            }
            case DELIVER: {
                break;
            }
            case MAINTENANCE: {
                USART_send_string("MAINTENANCE");
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
