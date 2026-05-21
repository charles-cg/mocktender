#ifndef FLASH_h
#define FLASH_h

#include <stdint.h>
#define NUM_RECIPES 10
#define NUM_PUMPS 6

typedef struct {
    char name[22];
    uint8_t ratio[NUM_PUMPS];
} Recipe;

uint8_t getRecipeRatio(uint8_t recipe, uint8_t pump);
void getRecipeName(uint8_t recipe, char *buf);

#endif // !DEBUG
