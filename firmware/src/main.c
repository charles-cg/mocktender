#include <avr/io.h>
#include <util/delay.h>
#include "USART.h"
#include "HX711.h"
#include "config.h"
#include "fsm.h"
#include "states.h"
#include "ADC.h"
#include "interrupts.h"

int main (void) {
    // set pull-up for external interrupts
    PORTB |= (1 << PB2);
    PORTD = (1 << PD2) | (1 << PD3);

    // INITS
    detectModeInit();
    debounceInit();
    adcInit();
    USART_init(MYUBRR);
    HX711_init(128);
    // PORTC as output
    DDRC = 0xFF;
    FSM fsm = {CALIBRATE, CALIBRATE, 0, 0, 0};

    sei();
    while (1) {
        switch (fsm.state) {
            case CALIBRATE: {
                USART_send_string("CALIBRATE");
                handleCalibrate(&fsm);
                break;
            }
            case IDLE: {
                USART_send_string("IDLE");
                _delay_ms(1000);
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
                handleDeliver(&fsm);
                break;
            }
            case MAINTENANCE: {
                USART_send_string("MAINTENANCE");
                _delay_ms(1000);
                break;
            }
            case CLEANING: {
                break;
            }
            case REFILL: {
                break;
            }
            case ERROR: {
                break;
            }
        }
    }

    return 0;
}
