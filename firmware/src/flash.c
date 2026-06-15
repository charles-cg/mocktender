#include "flash.h"
#include <avr/pgmspace.h>
#include <stdint.h>

const Recipe recipes[NUM_RECIPES] PROGMEM = {
    { "Sunrise",         {55,  0,  0, 10, 35,  0} },
    { "Tropical Breeze", { 0, 50, 35, 15,  0,  0} }, 
    { "Mocktail Mule",   { 0,  0, 42, 13,  0, 45} },
    { "Tropical Sunset", {40, 40,  0,  0, 20,  0} },
    { "Tamarind Tropic", { 0, 45,  0, 15,  0, 40} },
    { "Paradise Punch",  {30, 30, 25, 15,  0,  0} },
    { "Citrus Berry",    {40,  0, 40, 20,  0,  0} },
    { "Tamarind Berry",  { 0,  0, 48,  0, 12, 40} },
    { "Pink Lemonade",   {30,  0, 30, 20, 20,  0} },
    { "Full House",      {20, 20, 20, 10, 15, 15} },
};

uint8_t getRecipeRatio(uint8_t recipe, uint8_t pump) {
    return pgm_read_byte(&recipes[recipe].ratio[pump]);
}
