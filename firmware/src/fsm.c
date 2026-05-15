#include "fsm.h"

void transition(FSM *fsm, State newState) {
    fsm->prevState = fsm->state;
    fsm->state = newState;
}
