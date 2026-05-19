#ifndef INTERRUPTS_h
#define INTERRUPTS_h

#include <avr/interrupt.h>
#include <avr/io.h>
#include <stdint.h>

extern volatile char packet;
extern volatile uint8_t dataReady;
extern volatile uint8_t globalPump;
extern volatile uint8_t pumpBusy;
extern volatile uint8_t maintPressed;
extern volatile uint8_t rstPressed;
extern volatile uint8_t startPressed;
extern volatile uint8_t delayCheck;
extern volatile uint8_t delay30sDone;

ISR(USART_RXC_vect);
ISR(TIMER1_COMPA_vect);
ISR(TIMER1_COMPB_vect);
ISR(INT0_vect);
ISR(INT1_vect);
ISR(INT2_vect);

void detectModeInit();
void debounceInit();
#endif // !INTERRUPTS_h

