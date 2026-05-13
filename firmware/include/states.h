#ifndef STATES_h
#define STATES_h

#include "fsm.h"
#include <stdint.h>


//State handlers
void handleIdle(FSM *nFsm);
void handleCupPlaced(FSM *nFsm);
void handleDispense(FSM *nFsm);

//Helper functions
void checkLid(FSM *nFsm);
char classifyCup(double weight);
uint8_t calculateMl(FSM* nFsm, uint8_t pump);
uint16_t getCupSize(FSM* nFsm);
uint16_t calculateTime(uint8_t volume);
uint16_t calculateOCR1(uint16_t time);
void dynamicTimer(uint16_t ocr);

#endif // !DEBUG
