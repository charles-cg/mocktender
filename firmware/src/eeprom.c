#include "eeprom.h"
#include <avr/eeprom.h>

#define EEPROM_MAGIC 0xCE

// Per-pump bottle capacities in mL (P1…P6).
static const uint16_t bottleCapacityMl[6] = { 946, 960, 1000, 1000, 1000, 750 };

uint8_t EEMEM magicByte = EEPROM_MAGIC;
uint16_t EEMEM eeTotalMl[6];
uint16_t EEMEM eeUsedMl[6];

volatile uint16_t totalMl[6];
volatile uint16_t usedMl[6];

void eepromInit() {
    uint8_t needReset = (eeprom_read_byte(&magicByte) != EEPROM_MAGIC);
    if (!needReset) {
        for (int i = 0; i < 6; i++) {
            uint16_t total = eeprom_read_word(&eeTotalMl[i]);
            uint16_t used  = eeprom_read_word(&eeUsedMl[i]);
            if (total != bottleCapacityMl[i] || used > total) {
                needReset = 1;
                break;
            }
        }
    }
    if (needReset) {
        for (int i = 0; i < 6; i++) {
            eeprom_update_word(&eeTotalMl[i], bottleCapacityMl[i]);
            eeprom_update_word(&eeUsedMl[i], 0);
        }
        eeprom_update_byte(&magicByte, EEPROM_MAGIC);
    }
    eepromLoadInventory();
}

void eepromLoadInventory() {
    for (int i = 0; i < 6; i++) {
        totalMl[i] = eeprom_read_word(&eeTotalMl[i]);
        usedMl[i] = eeprom_read_word(&eeUsedMl[i]);
    }
}

void updateUsedMl() {
    for (int i = 0; i < 6; i++) {
        eeprom_update_word(&eeUsedMl[i], usedMl[i]);
    }
}

void setUsedMl() {
    for (int i = 0; i < 6; i++) {
        usedMl[i] = 0;
        eeprom_update_word(&eeUsedMl[i], 0);
    }
}
