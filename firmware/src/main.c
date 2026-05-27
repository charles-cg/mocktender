#include <avr/io.h>
#include <util/delay.h>
#include "USART.h"
#include "HX711.h"
#include "config.h"
#include "eeprom.h"
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
    adcInit();
    USART_init(MYUBRR);
    HX711_init(128);
    eepromInit();
    // PORTC as output
    DDRC = 0xFF;
    FSM fsm = {CALIBRATE, CALIBRATE, 0, 0, 0};

    sei();
    while (1) {
        switch (fsm.state) {
            case CALIBRATE: {
                handleCalibrate(&fsm);
                break;
            }
            case IDLE: {
                _delay_ms(1000);
                sendPacket(fsm.cupClass, fsm.state, fsm.errorCode);
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
                handleMaintenance(&fsm);
                break;
            }
            case CLEANING: {
                handleCleaning(&fsm);
                break;
            }
            case REFILL: {
                handleRefill(&fsm);
                break;
            }
            case ERROR: {
                // Throttle the ERROR broadcast to ~1 Hz so the BLE bridge
                // isn't saturated while the user reads the message — same
                // pattern as IDLE.
                _delay_ms(1000);
                sendPacket(fsm.cupClass, fsm.state, fsm.errorCode);
                handleError(&fsm);
                break;
            }
        }
    }

    return 0;
}
