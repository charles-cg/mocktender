#include "ADC.h"
#include <avr/io.h>

void adc_init(void) {
    ADMUX = (1 << REFS1) | (1 << REFS0);

    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1);
}

uint16_t adc_read(uint8_t channel) {
    // Select channel, preserve reference bits
    ADMUX = (ADMUX & 0xF0) | (channel & 0x0F);

    // Small delay for mux to settle before conversion
    __asm__ __volatile__("nop\nnop\nnop\nnop");

    // Start conversion
    ADCSRA |= (1 << ADSC);

    // Wait for conversion to complete
    while (ADCSRA & (1 << ADSC));

    return ADC;  // 10-bit result, 0–1023
}
