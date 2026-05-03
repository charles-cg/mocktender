#include "fsm.h"

FSM fsm = {IDLE, IDLE, 0x00, 0x00};

void transition(FSM *fsm, State newState) {
    fsm->prevState = fsm->state;
    fsm->state = newState;
}
