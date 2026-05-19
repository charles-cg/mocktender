#include "timers.h"
#include <avr/io.h>

void delay5s() {
    TCNT1 = 0;
    OCR1B = 39062;
    TCCR1B = (1 << CS12) | (1 << CS10);  // Normal mode, 1024 prescaler
    TIMSK |= (1 << OCIE1B);
}


void dynamicTimer(uint16_t ocr) {
    OCR1A = ocr;

    // CTC 1024 prescaler
    TCCR1B = (1 << WGM12) | (1 << CS12) | (1 << CS10);
    TIMSK |= (1 << OCIE1A);
}
