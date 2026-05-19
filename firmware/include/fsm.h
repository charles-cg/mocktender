#ifndef FSM_h
#define FSM_h
#include <stdint.h>

typedef enum {
    CALIBRATE, IDLE, CUP_PLACED, DISPENSE, DELIVER, MAINTENANCE, CLEANING, REFILL, ERROR
} State; //FSM states

typedef struct {
    State state;
    State prevState;
    char cupClass;
    uint8_t errorCode;
    char recipeId;
} FSM;

void transition(FSM *fsm, State newState);

#endif // !DEBUG
