#ifndef TIMERS_H
#define TIMERS_H

#include <stdint.h>

uint16_t calculateTime(uint8_t volume);
uint16_t calculateOCR1(uint16_t time);
void dynamicTimer(uint16_t ocr);
void delay5s();

#endif // !TIMERS
