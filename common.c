#include "uart.h"

extern int debug;

void Debug(const char * s) {
    if (debug)
        writeStringUART1(s);
}
