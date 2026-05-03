#ifndef FSM_h
#define FSM_h

typedef enum {
    IDLE, CUP_PLACED, DISPENSE, DELIVER, MAINTENANCE, CLEANING, ERROR
} State; //FSM states

typedef struct {
    State state;
    State prevState;
    char cupClass;
    char errorCode;
} FSM;

//initial fsm state
FSM fsm = {IDLE, IDLE, 0x00, 0x00}; 

void transition(FSM *fsm, State newState);

#endif // !DEBUG
