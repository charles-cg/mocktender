#ifndef ADC_H
#define ADC_H

#include <stdint.h>

void adcInit(void);
uint16_t adcRead(uint8_t channel);

#endif // ADC_H
