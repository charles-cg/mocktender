#ifndef STATES_h
#define STATES_h

//State handlers
void handleIdle(void);
void handleCupPlaced(void);

//Helper functions
void checkLid(void);
char classifyCup(double weight);
#endif // !DEBUG
