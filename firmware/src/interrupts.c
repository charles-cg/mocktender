#include "interrupts.h"

ISR(USART_RXC_vect) {
    packet = UDR;
    dataReady = 1;
}
