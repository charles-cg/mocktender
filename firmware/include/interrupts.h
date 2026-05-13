#ifndef INTERRUPTS_h
#define INTERRUPTS_h

#include <avr/interrupt.h>
#include <avr/io.h>
#include <stdint.h>

extern volatile char packet;
extern volatile uint8_t dataReady;
extern volatile uint8_t pump;

ISR(USART_RXC_vect);
ISR(TIMER1_COMPA_vect);

#endif // !INTERRUPTS_h

