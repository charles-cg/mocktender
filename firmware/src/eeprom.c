#include "eeprom.h"
#include <avr/eeprom.h>
void eepromInit() {
    if (eeprom_read_byte(&magicByte) != 0xCD) {
        for (int i = 0; i < 6; i++) {
            eeprom_update_word(&eeTotalMl[i], 750);
            eeprom_update_word(&eeUsedMl[i], 0);
        }
        eeprom_update_byte(&magicByte, 0xCD);
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
