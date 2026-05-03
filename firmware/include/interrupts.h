#ifndef INTERRUPTS_h
#define INTERRUPTS_h

#include <avr/interrupt.h>
#include <avr/io.h>

volatile char dataReady = 0;
volatile char packet = 0;

ISR(USART_RXC_vect);

#endif // !INTERRUPTS_h

