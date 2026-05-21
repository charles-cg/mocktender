#ifndef USART_h
#define USART_h

#include <stdint.h>

void USART_init(unsigned int ubrr);
void USART_send_char(char ch);
void USART_send_string(char *str);
void USART_send_uint8(uint8_t val);
void sendScaleReading(double weight);
#endif // !DEBUG
