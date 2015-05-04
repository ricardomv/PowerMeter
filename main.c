/* 
 * File:   main.c
 * Author: Ricardo Vieira
 *
 * Created on May 2, 2015, 10:53 PM
 */

#include <p33FJ64GP802.h>
#include "common.h"
#include "uart.h"
#include "adc.h"

_FOSCSEL(FNOSC_PRI);
_FOSC(FCKSM_CSECMD & OSCIOFNC_ON  & POSCMD_NONE);
_FWDT(FWDTEN_OFF);

const char *commands[] = {"INFO", "DEBUG", "AQUIRE", 0};

int debug = 0;

int main(void)
{
    //Configure Oscillator
    PLLFBD = 41; //43 * 7.37 = x
    CLKDIVbits.PLLPOST = 0; // x = x/2
    CLKDIVbits.PLLPRE = 0; // x = x/2 ... x comes as 80MHz thus 40MIPS
    __builtin_write_OSCCONH(0x01);
    __builtin_write_OSCCONL(0x01);
    while (OSCCONbits.COSC != 1);
    while (OSCCONbits.LOCK != 1); // Wait for PLL to lock

    initUART1();

    writeStringUART1("Power Meter v0.1");
    writeStringUART1(" (compiled " __TIME__ " " __DATE__ ")\n\r");

    while(1)
    {
        switch (getCommandUART1()) {
            case 0: // INFO - print calibration data
                writeStringUART1("INFO\n\r");
                break;
            case 1: // DEBUG - enable debug
                debug ^= -1;
                if( debug ) {
                    writeStringUART1("Debug Enabled\n\r");
                }
                else {
                    writeStringUART1("Debug Disabled\n\r");
                }
                break;
            case 2: // AQUIRE - print sensor valuess
                writeStringUART1("AQUIRE\n\r");
                aquireADC(0);
                break;
            default:
                break;
        }
        Idle();
    }
}
