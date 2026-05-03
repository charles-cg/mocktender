#include "HM10.h"
#include <avr/common.h>
#include <avr/io.h>
#include <stdlib.h>
#include <string.h>

void USART_init (unsigned int ubrr) {
    UBRRH = (unsigned char)(ubrr>>8);
    UBRRL = (unsigned char)ubrr;
    UCSRB = (1<<RXEN) | (1<<TXEN) | (1 << RXCIE);
    UCSRC = (1<<URSEL) | (1<<UCSZ0) | (1<<UCSZ1);
}

void USART_send_char(char ch) {
    while (! (UCSRA & (1<<UDRE)));  /* Wait for empty transmit buffer */
	UDR = ch ;
}

void USART_send_string(char *str) {
    unsigned char j = 0;

    while (str[j] != 0) {
        USART_send_char(str[j]);
        j++;
    }
}

void sendScaleReading(double weight) {
    char buffer[16];
    dtostrf(weight, 8, 3, buffer);  // e.g. "  123.456"
    strcat(buffer, "\r\n");         // packet terminator
    USART_send_string(buffer);
}
