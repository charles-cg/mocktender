#ifndef INTERRUPTS_h
#define INTERRUPTS_h

#include <avr/interrupt.h>
#include <avr/io.h>
#include <stdint.h>

extern volatile uint8_t packet;
extern volatile uint8_t dataReady;

ISR(USART_RXC_vect);

#endif // !INTERRUPTS_h

