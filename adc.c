#include <p33FJ64GP802.h>
#include "common.h"
#include <stdio.h>

#define NSAMPLES 100

int sampleVArray[NSAMPLES] __attribute__((space(dma)));
int sampleCArray[NSAMPLES] __attribute__((space(dma)));
int sampleReady = 0;

void initADC1( void )
{
    int i;
    for(i=0; i < NSAMPLES; i++) {
        sampleVArray[i] = 0;
    }
    for(i=0; i < NSAMPLES; i++) {
        sampleCArray[i] = 0;
    }
    /* turn off ADC module */
    AD1CON1bits.ADON = 0;
    AD1CON1bits.FORM = 3; // Signed Fractional Format
    AD1CON1bits.SSRC = 2; // Sample Clock - Timer3 = 2
    AD1CON1bits.ASAM = 1; // Sample Auto-Start
    AD1CON1bits.AD12B = 0; // Operational Mode 10-bit, 4-channel
    AD1CON1bits.SIMSAM = 1; // Simultaneous / sequential
    AD1CON2bits.CHPS = 1;  // Channel - dual channel
    AD1CON3bits.ADRC = 0;  // ADC Conversion Clock Source bit
    AD1CON3bits.SAMC = 0;  // Voltage Reference - Vdd
    // AD1CON3bits.ADCS = 1; // only used when the SSRC = 7

    TRISAbits.TRISA0 = 1;
    TRISAbits.TRISA1 = 1;

    AD1CON1bits.ADDMABM = 1; // DMA Buffer Build Mode bit
    AD1CON2bits.SMPI = 1; //  Increments the DMA address after completion of every 2nd sample/conversion

    // Initialize MUXA Input Selection
    AD1CHS0bits.CH0SA = 0; // Select AN0 for CH0 +ve input
    AD1CHS0bits.CH0NA = 0; // Select VREF- for CH0 -ve input
    AD1CHS123bits.CH123SA=0; // AN1 for CH1 +ve input
    AD1CHS123bits.CH123NA=0;

    AD1PCFGL = 0xFFFF;
    AD1PCFGLbits.PCFG0 = 0; // AN0 as Analog Input
    AD1PCFGLbits.PCFG1 = 1; // AN1 as Analog Input
    IFS0bits.AD1IF = 0;
    IEC0bits.AD1IE = 0;
    AD1CON1bits.ADON = 1;
}

void __attribute__((__interrupt__,no_auto_psv)) _T3Interrupt(void)
{
    LATBbits.LATB15 ^= 1;
    IFS0bits.T3IF = 0;
}

void initTimer3(void)
{
    TRISBbits.TRISB15 = 0;
    TMR3 = 0x0000;
    PR3 = 300; // Trigger ADC1 every 125usec
    T3CONbits.TCKPS = 3;
    IFS0bits.T3IF = 0; // Clear Timer 3 interrupt
    IEC0bits.T3IE = 1; // Disable Timer 3 interrupt
    T3CONbits.TON = 1; //Start Timer 3
}

void initDma0(void)
{
    DMA0CONbits.AMODE = 0;
    DMA0CONbits.MODE = 2;

    DMA0PAD = (int)&ADC1BUF0;
    DMA0CNT = ((NSAMPLES-1));

    DMA0REQ = 13;

    DMA0STA = __builtin_dmaoffset(sampleVArray);
    DMA0STB = __builtin_dmaoffset(sampleCArray);

    IFS0bits.DMA0IF = 0;
    IEC0bits.DMA0IE = 1;

    DMA0CONbits.CHEN = 1;
}

void printArray()
{
    int i;
    char str[15];
    Debug("ADC voltage values:\n\r");
    for(i=0; i < NSAMPLES; i++) {
        sprintf(str, "%d\n\r", sampleVArray[i]);
        Debug(str);
    }
    Debug("\n\r");
    Debug("ADC current values:\n\r");
    for(i=0; i < NSAMPLES; i++) {
        sprintf(str, "%d ", sampleCArray[i]);
        Debug(str);
    }
    Debug("\n\r");
}

void aquireADC(int channel)
{
    sampleReady = 0;
    AD1CON1bits.ADON = 1;
    while(sampleReady == 0)
        Debug("Wait for sampling.\n\r");
    printArray();
}

void __attribute__((__interrupt__,no_auto_psv)) _DMA0Interrupt(void)
{
    IFS0bits.DMA0IF = 0;
    AD1CON1bits.ADON = 0;
    sampleReady = 1;
}