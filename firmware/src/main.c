#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

#define BAUD 9600 //Set Baud Rate
#define MYUBRR F_CPU/16/BAUD-1 //UBRR formula

int main (void) {
    enum {
        IDLE, CUP_PLACED, DISPENSE, MIXING, DELIVER, ERROR
    } state; //FSM states

    state = IDLE; //Initial state is IDLE
    while (1) {
        switch (state) {
            case IDLE: {
                break;
            }
            case CUP_PLACED: {
                break;
            }
            case DISPENSE: {
                break;
            }
            case MIXING: {
                break;
            }
            case DELIVER: {
                break;
            }
            case ERROR: {
                break;
            }
        }
    }

    return 0;
}
