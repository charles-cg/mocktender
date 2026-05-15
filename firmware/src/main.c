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

    // Let the HX711 + load cell thermally settle before taring,
    // otherwise warm-up drift makes the captured zero unstable.
    _delay_ms(30000);
    (void)HX711_read_average(10);   // discard first batch
    HX711_tare(20);
    HX711_set_scale(715);

    adcInit();
    DDRC = 0xFF;
    sei();
    USART_send_string("Machine is ready");

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
