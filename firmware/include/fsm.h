#ifndef FSM_h
#define FSM_h
#include <stdint.h>

typedef enum {
    IDLE, CUP_PLACED, DISPENSE, DELIVER, MAINTENANCE, CLEANING, ERROR
} State; //FSM states

typedef struct {
    State state;
    State prevState;
    char cupClass;
    uint8_t errorCode;
    uint8_t recipeId;
} FSM;

void transition(FSM *fsm, State newState);

#endif // !DEBUG
