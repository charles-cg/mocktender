#ifndef EEPROM_h
#define EEPROM_h

#include <avr/eeprom.h>
#include <stdint.h>

extern uint8_t EEMEM magicByte;
extern uint16_t EEMEM eeTotalMl[6];
extern uint16_t EEMEM eeUsedMl[6];

extern volatile uint16_t totalMl[6];
extern volatile uint16_t usedMl[6];

void eepromInit();
void eepromLoadInventory();
void updateUsedMl();
void setUsedMl();

#endif
