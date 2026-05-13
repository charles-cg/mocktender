#include "interrupts.h"
#include <avr/io.h>

volatile char packet = 0;
volatile uint8_t dataReady = 0;

ISR(USART_RXC_vect) {
    packet = UDR;
    dataReady = 1;
}

ISR(TIMER1_COMPA_vect) {

}
