#include "interrupts.h"
#include <avr/io.h>
#include <stdint.h>

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
    PORTC &= ~(1 << globalPump);
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

ISR(TIMER2_COMP_vect) {
    TCCR2 = 0;
    TIMSK &= ~(1 << OCIE2);

    if (!(PIND & (1 << PD2))) {
        maintPressed = 1;
    } else if (!(PIND & (1 << PD3))) {
        startPressed = 1;
    } else if (!(PINB & (1 << PB2))) {
        rstPressed = 1;
    }
}

ISR(INT0_vect) {
    TCNT2 = 0;
    TIMSK |= (1 << OCIE2);
    TCCR2 = (1 << CS22) | (1 << CS21) | (1 << CS20);
}

ISR(INT1_vect) {
    TCNT2 = 0;
    TIMSK |= (1 << OCIE2);
    TCCR2 = (1 << CS22) | (1 << CS21) | (1 << CS20);
}

ISR(INT2_vect) {
    TCNT2 = 0;
    TIMSK |= (1 << OCIE2);
    TCCR2 = (1 << CS22) | (1 << CS21) | (1 << CS20);
}
void detectModeInit() {
    // activates INT1 and INT0 on falling edge
    MCUCR = (1 << ISC11) | (1 << ISC01);
    // INT2 by default detects a falling-edge
}

void debounceInit() {
    TCCR2 |= (1 << WGM21); //CTC mode, timer not started yet
    OCR2 = 156; // OCR2 for 20 ms delay
}
