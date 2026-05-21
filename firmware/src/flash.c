#include "flash.h"
#include <avr/pgmspace.h>
#include <stdint.h>

const Recipe recipes[NUM_RECIPES] PROGMEM = {
    { "Sunrise",         {55,  0,  0, 10, 35,  0} },
    { "Tropical Breeze", { 0, 50, 35, 15,  0,  0} }, 
    { "Mocktail Mule",   { 0,  0, 50, 15,  0, 35} },
    { "Tropical Sunset", {40, 40,  0,  0, 20,  0} },
    { "Ginger Tropic",   { 0, 55,  0, 15,  0, 30} },
    { "Paradise Punch",  {30, 30, 25, 15,  0,  0} },
    { "Citrus Berry",    {40,  0, 40, 20,  0,  0} },
    { "Ginger Berry",    { 0,  0, 55,  0, 15, 30} },
    { "Pink Lemonade",   {30,  0, 30, 20, 20,  0} },
    { "Full House",      {20, 20, 20, 10, 20, 10} },
};

uint8_t getRecipeRatio(uint8_t recipe, uint8_t pump) {
    return pgm_read_byte(&recipes[recipe].ratio[pump]);
}
