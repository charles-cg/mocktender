#include "interrupts.h"
#include <avr/io.h>
#include <stdint.h>
#include <util/delay.h>

volatile char packet = 0;
volatile uint8_t dataReady = 0;
volatile uint8_t globalPump = 0;
volatile uint8_t pumpBusy = 0;
volatile uint8_t maintPressed = 0;
volatile uint8_t rstPressed = 0;
volatile uint8_t startPressed = 0;
volatile uint8_t delayCheck = 0;
volatile uint8_t delay30sDone = 0;

ISR(USART_RXC_vect) {
    char rx = UDR;
    if ((rx >= '1' && rx <= '9') || rx == 'A') {
        packet = rx;
        dataReady = 1;
    }
}

ISR(TIMER1_COMPA_vect) {
    TCCR1B = 0x00;
    TIMSK &= ~(1 << OCIE1A);
    if (globalPump == 6) {
        PORTC &= ~(0b00111111);
    } else {
        PORTC &= ~(1 << globalPump);
    }
    pumpBusy = 0;
}

ISR(TIMER1_COMPB_vect) {
    TCNT1 = 0;
    delayCheck += 1;
    if (delayCheck == 6) {
        TCCR1B = 0x00;
        TIMSK &= ~(1 << OCIE1B);
        delay30sDone = 1;
    }
}

ISR(INT0_vect) {
    _delay_ms(20);
    if (!(PIND & (1 << PD2))) {
        maintPressed += 1;
    }
}

ISR(INT1_vect) {
    _delay_ms(20);
    if (!(PIND & (1 << PD3))) {
        startPressed = 1;
    }
}

ISR(INT2_vect) {
    _delay_ms(20);
    if (!(PINB & (1 << PB2))) {
        rstPressed = 1;
    }
}

void detectModeInit() {
    // activates INT1 and INT0 on falling edge
    MCUCR = (1 << ISC11) | (1 << ISC01);
    // INT2 by default detects a falling-edge
}
