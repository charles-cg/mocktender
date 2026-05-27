#ifndef USART_h
#define USART_h

#include "fsm.h"
#include <stdint.h>

void USART_init(unsigned int ubrr);
void USART_send_char(char ch);
void USART_send_string(char *str);
void sendScaleReading(float weight);
void sendPacket(char cup, State state, uint8_t error);
#endif // !USART
