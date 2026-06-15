#define BAUD 9600 //Set Baud Rate
#define MYUBRR F_CPU/16/BAUD-1 //UBRR formula

// Cup weight thresholds (grams)
#define CUP_PRESENT 20      // minimum weight to register something on the scale
#define CUP_TOLERANCE 30.0f // +/- band around each measured cup weight

// Consecutive sub-threshold reads before declaring the cup removed (rides out
// load-cell noise while a pump runs)
#define CUP_REMOVED_CONSEC 3

// HX711 reads averaged per poll in the running-pump loops (kept small so the
// loop revisits the reset/cancel checks several times a second)
#define DISPENSE_POLL_SAMPLES 2

#define SMALL_CUP 240.5f
#define MED_CUP   312.5f
#define BIG_CUP   393.8f

#define SCALE_DEADBAND 1

//pump constants
#define TIMER_TICK_US 128UL   // tick period in µs (8MHz, prescaler 1024)

// Per-pump flow rates, mL/s * 100 (avoids float)
#define FLOWRATE_PUMP1_X100 3333UL  // 2 L/min measured -> 33.33 mL/s
#define FLOWRATE_PUMP2_X100 2725UL  // 1.635 L/min measured -> 27.25 mL/s
#define FLOWRATE_PUMP3_X100 3113UL  // 1.868 L/min measured -> 31.13 mL/s
#define FLOWRATE_PUMP4_X100 2725UL  // 1.468 L/min measured -> 24.47 mL/s
#define FLOWRATE_PUMP5_X100 2270UL  // 1.362 L/min measured -> 22.70 mL/s
#define FLOWRATE_PUMP6_X100 2867UL  // 1.720 L/min measured -> 28.67 mL/s

// Pot thresholds
#define PUMP1_2 146
#define PUMP2_3 292
#define PUMP3_4 438
#define PUMP4_5 584
#define PUMP5_6 730
#define PUMP6_ALL 876
#define PUMP_END 1023

