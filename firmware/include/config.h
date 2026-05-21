#define BAUD 9600 //Set Baud Rate
#define MYUBRR F_CPU/16/BAUD-1 //UBRR formula

// Cup weight threshold (placeholder values)
#define CUP_PRESENT 20
#define SMALL_CUP 100
#define MED_CUP 300
#define BIG_CUP 500

// Idle deadband (grams, integer): |reading| < SCALE_DEADBAND is reported as 0.
#define SCALE_DEADBAND 1

//pump constants
#define FLOWRATE_X100 2667UL  // 26.67 mL/s * 100, avoids float
#define TIMER_TICK_US 128UL   // tick period in µs (8MHz, prescaler 1024)

// Pot thresholds
#define PUMP1_2 146
#define PUMP2_3 292
#define PUMP3_4 438
#define PUMP4_5 584
#define PUMP5_6 730
#define PUMP6_ALL 876
#define PUMP_END 1023

