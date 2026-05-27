#include "USART.h"
#include "eeprom.h"
#include <avr/io.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

void USART_init (unsigned int ubrr) {
    UBRRH = (unsigned char)(ubrr>>8);
    UBRRL = (unsigned char)ubrr;
    UCSRB = (1<<RXEN) | (1<<TXEN) | (1 << RXCIE);
    UCSRC = (1<<URSEL) | (1<<UCSZ0) | (1<<UCSZ1);
}

void USART_send_char(char ch) {
    while (! (UCSRA & (1<<UDRE)));  //Wait for empty transmit buffer
	UDR = ch ;
}

void USART_send_string(char *str) {
    unsigned char j = 0;

    while (str[j] != 0) {
        USART_send_char(str[j]);
        j++;
    }
}

void sendScaleReading(float weight) {
    char buffer[16];
    dtostrf(weight, 8, 3, buffer);  // e.g. "  123.456"
    strcat(buffer, "\r\n");         // packet terminator
    USART_send_string(buffer);
}

static void send_u16_le(uint16_t v) {
    USART_send_char((char)(v & 0xFF));
    USART_send_char((char)((v >> 8) & 0xFF));
}

void sendPacket(char cup, State state, uint8_t error) {
    USART_send_string("State:");
    USART_send_char((char)state);
    USART_send_string(",Cup:");
    USART_send_char(cup);
    USART_send_string(",Error:");
    USART_send_char((char)error);
    USART_send_string(",OJ:");
    send_u16_le(usedMl[0]);
    USART_send_string(",PJ:");
    send_u16_le(usedMl[1]);
    USART_send_string(",CJ:");
    send_u16_le(usedMl[2]);
    USART_send_string(",LJ:");
    send_u16_le(usedMl[3]);
    USART_send_string(",GR:");
    send_u16_le(usedMl[4]);
    USART_send_string(",GS:");
    send_u16_le(usedMl[5]);
    USART_send_string("\r\n");
}
