#ifndef EEPROM_h
#define EEPROM_h

#include <avr/eeprom.h>
#include <stdint.h>

uint8_t EEMEM magicByte = 0xCD;
uint16_t EEMEM eeTotalMl[6];
uint16_t EEMEM eeUsedMl[6];

uint16_t totalMl[6];
uint16_t usedMl[6];

void eepromInit();
void eepromLoadInventory();
void updateUsedMl();

#endif
