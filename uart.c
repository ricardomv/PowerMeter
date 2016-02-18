#include <p33FJ32GP302.h>
#include <math.h>
#include <string.h>

#include "common.h"
#include "uart.h"

#define FCY (unsigned long)40000000
#define UART1_BAUD 9600
#define UBRG1_VALUE (FCY/UART1_BAUD)/16 - 1

int commandBufIdx = 0, commandRX = FALSE;
char commandBuf[100];
extern const char *commands[];

void initUART1(void)
{
    RPINR18bits.U1RXR = 8; // Assign RP8 as Input Pin as UART 1 input.
    RPOR4bits.RP9R = 3; // RP9 tied to UART1 Transmit
    TRISBbits.TRISB8 = 1;
    TRISBbits.TRISB9 = 0;
    U1MODEbits.STSEL = 0; // 1 Stop bit
    U1MODEbits.PDSEL = 0; // No Parity, 8 data bits
    U1MODEbits.ABAUD = 0; // Auto-Baud Disabled
    U1MODEbits.BRGH = 0; // Low Speed mode
    U1BRG = UBRG1_VALUE; // BAUD Rate Setting for 9600
    U1STAbits.URXISEL0 = 0; // Interrupt after one RX Character is recieved
    U1STAbits.URXISEL1 = 0;
    IEC0bits.U1RXIE = 1; // Enable UART RX Interrupt
    U1MODEbits.UARTEN = 1; // Enable UART
    U1STAbits.UTXEN = 1; // Enable UART TX
}

void writeUART1(unsigned int data)
{
    while (U1STAbits.TRMT==0);
    if(U1MODEbits.PDSEL == 3)
        U1TXREG = data;
    else
        U1TXREG = data & 0xFF;
}

void writeStringUART1(const char * s)
{
    while(*s)
        writeUART1(*s++);
}

void __attribute__((interrupt, no_auto_psv)) _U1RXInterrupt(void)
{
    IFS0bits.U1RXIF = 0;

    // if there is a command waiting
    if (commandRX)
        return;

    commandBuf[commandBufIdx] = U1RXREG;


    if(commandBuf[commandBufIdx] == 13) {
        commandBuf[commandBufIdx] = '\0';
        commandRX = TRUE;
        commandBufIdx = 0;
    }
    if(++commandBufIdx == 100)
        commandBufIdx = 0;
}

int getCommandUART1(void)
{
    int i;
    char buf[100] = { 0 };

    // return if no command waiting
    if(!commandRX)
        return -1;

    strcpy(buf, commandBuf);
    commandBufIdx = 0;
    commandRX = FALSE;

    // find command in array of commands
    for(i = 0; commands[i] != 0; i++) {
        if ( strcmp(buf, commands[i]) >= 0 )
            return i;
    }

    // error command not found
    return -1;
}
