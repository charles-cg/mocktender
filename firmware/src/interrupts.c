#include "interrupts.h"

volatile uint8_t packet = 0;
volatile uint8_t dataReady = 0;

ISR(USART_RXC_vect) {
    packet = UDR;
    dataReady = 1;
}
