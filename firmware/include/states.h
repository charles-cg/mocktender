#ifndef STATES_h
#define STATES_h

#include "fsm.h"
#include <stdint.h>

//State handlers
void handleIdle(FSM nFsm);
void handleCupPlaced(FSM nFsm);

//Helper functions
void checkLid(FSM nFsm);
uint8_t classifyCup(double weight);

#endif // !DEBUG
