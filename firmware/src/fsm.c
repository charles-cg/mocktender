#include "fsm.h"
#include "USART.h"

void transition(FSM *fsm, State newState) {
    fsm->prevState = fsm->state;
    fsm->state = newState;
    sendPacket(fsm->cupClass, fsm->state, fsm->errorCode);
}
