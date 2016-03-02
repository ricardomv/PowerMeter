/* 
 * File:   main.c
 * Author: Ricardo Vieira
 *
 * Created on May 2, 2015, 10:53 PM
 */

#include <p33FJ32GP302.h>
#include "common.h"
#include "uart.h"
#include "adc.h"
#include "calc.h"

_FOSCSEL(FNOSC_PRI);
_FOSC(FCKSM_CSECMD & OSCIOFNC_ON  & POSCMD_NONE);
_FWDT(FWDTEN_OFF);

const char *commands[] = {"INFO\0", "DEBUG\0", "AQUIRE\0", 0};

int debug = 1;

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
    initTimer3();
    initDma0();
    initADC1();

    writeStringUART1("\nPower Meter v0.1");
    writeStringUART1(" (compiled " __TIME__ " " __DATE__ ")\r\n");

    while(1)
    {
        switch (getCommandUART1()) {
            case 0: // INFO - print calibration data
                writeStringUART1("INFO\r\n");
                break;
            case 1: // DEBUG - enable debug
                debug ^= 1;
                if( debug ) {
                    writeStringUART1("Debug Enabled\r\n");
                }
                else {
                    writeStringUART1("Debug Disabled\r\n");
                }
                break;
            case 2: // AQUIRE - print sensor valuess
                aquireADC(getChannelUART1());
                break;
            default:
                break;
        }
        Idle();
    }
}
