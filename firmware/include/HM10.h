#ifndef HM10_h
#define HM10_h

void USART_init(unsigned int ubrr);
void USART_send_char(char ch);
void USART_send_string(char *str);
void sendScaleReading(double weight);
#endif // !DEBUG
