#ifndef STATES_h
#define STATES_h

#include "fsm.h"
#include <stdint.h>


//State handlers
void handleIdle(FSM* nFsm);
void handleCupPlaced(FSM* nFsm);
void handleDispense(FSM* nFsm);
void handleDeliver(FSM* nFsm);
void handleMaintenance(FSM* nFsm);
void handleCalibrate(FSM* nFsm);
void handleError(FSM* nFsm);
void handleCleaning(FSM* nFsm);
void handleRefill(FSM* nFsm);

//Helper functions
char classifyCup(float weight);
uint8_t calculateMl(FSM* nFsm, uint8_t pump);
uint16_t getCupSize(FSM* nFsm);
void dynamicDelay (FSM* nFsm, uint8_t pump);
void rstAction(FSM* nFsm);
void potClassify();
#endif // !DEBUG
