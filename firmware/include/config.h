#define BAUD 9600 //Set Baud Rate
#define MYUBRR F_CPU/16/BAUD-1 //UBRR formula

// Cup weight threshold (placeholder values)
#define CUP_PRESENT 20
#define SMALL_CUP 100
#define MED_CUP 300
#define BIG_CUP 500
