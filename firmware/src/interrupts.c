#include "interrupts.h"
#include <avr/io.h>

volatile char packet = 0;
volatile uint8_t dataReady = 0;
volatile uint8_t globalPump = 0;

ISR(USART_RXC_vect) {
    char rx = UDR;
    if ((rx >= '1' && rx <= '9') || rx == 'A') {
        packet = rx;
        dataReady = 1;
    }
}

ISR(TIMER1_COMPA_vect) {
    TCCR1B = 0x00;
    PORTC |= (1 << globalPump);
}
