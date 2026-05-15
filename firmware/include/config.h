#define BAUD 9600 //Set Baud Rate
#define MYUBRR F_CPU/16/BAUD-1 //UBRR formula

// Cup weight threshold (placeholder values)
#define CUP_PRESENT 20
#define SMALL_CUP 100
#define MED_CUP 300
#define BIG_CUP 500

// Idle deadband (grams, integer): |reading| < SCALE_DEADBAND is reported as 0.
#define SCALE_DEADBAND 1

//LDR Light Threshold
#define LIGHT_THRESHOLD 1024
#define FLOWRATE_X100 2667UL  // 26.67 mL/s * 100, avoids float
#define TIMER_TICK_US 128UL   // tick period in µs (8MHz, prescaler 1024)
