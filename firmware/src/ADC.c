#include "ADC.h"
#include <avr/io.h>

void adcInit(void) {
    ADMUX = (1 << REFS0);

    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1);
}

uint16_t adcRead(uint8_t channel) {
    // Select channel, preserve reference bits
    ADMUX = (ADMUX & 0xF0) | (channel & 0x0F);

    // Start conversion
    ADCSRA |= (1 << ADSC);

    // Wait for conversion to complete
    while (!(ADCSRA & (1 << ADIF)));

    ADCSRA |= (1 << ADIF);

    return ADC;  // 10-bit result, 0–1023
}
