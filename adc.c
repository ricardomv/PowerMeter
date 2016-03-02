#include <p33FJ32GP302.h>
#include <stdio.h>
#include <math.h>

#include "common.h"
#include "adc.h"

int sampleArray[NSAMPLES][2] __attribute__((space(dma),aligned(32)));

int sampleVArray[NSAMPLES] = { 0 };
int sampleCArray[NSAMPLES] = { 0 };

int sampleReady = 0;

void initADC1( void )
{
    /* turn off ADC module */
    AD1CON1bits.ADON = 0;
    AD1CON1bits.FORM = 3;   // Signed Fractional Format
    AD1CON1bits.SSRC = 2;   // Sample Clock - Timer3 = 2
    AD1CON1bits.ASAM = 1;   // Sample Auto-Start
    AD1CON1bits.AD12B = 0;  // Operational Mode 10-bit, 4-channel
    AD1CON1bits.SIMSAM = 1; // Simultaneous / sequential
    AD1CON2bits.CHPS = 1;   // Channel - dual channel
    AD1CON3bits.ADRC = 0;   // ADC Conversion Clock Source bit

    TRISAbits.TRISA0 = 1;  // Voltage CH1
    TRISAbits.TRISA1 = 1;  // Voltage CH2
    TRISBbits.TRISB0 = 1;  // Voltage CH3
    TRISBbits.TRISB15 = 1;  // Current CH1

    AD1CON1bits.ADDMABM = 1; // DMA Buffer Build Mode bit
    AD1CON2bits.SMPI = 1; // Increments the DMA address after completion of every 2nd sample/conversion
    AD1CON2bits.VCFG = 0;
    //AD1CON4bits.DMABL = 7;

    // Initialize MUXA Input Selection
    AD1CHS0bits.CH0SA = 9; // Select AN1 for CH0 +ve input
    AD1CHS0bits.CH0NA = 0; // Select VREF- for CH0 -ve input
    AD1CHS123bits.CH123SA = 0; // AN0 for CH1 +ve input
    AD1CHS123bits.CH123NA = 0;

    AD1PCFGL = 0xFFFF;
    AD1PCFGLbits.PCFG9 = 0; // AN9 as Analog Input
    AD1PCFGLbits.PCFG0 = 0; // AN0 as Analog Input
    AD1PCFGLbits.PCFG2 = 0; // AN3 as Analog Input
    IFS0bits.AD1IF = 0;  // Clear interrupt flag
    IEC0bits.AD1IE = 0;  // Disable ADC interrupt
    AD1CON1bits.ADON = 1; // Enable ADC
}

void setChannel(int chV, int chC) {
    AD1CON1bits.ADON = 0;
}

void initTimer3(void)
{
    TRISBbits.TRISB15 = 0;
    TMR3 = 0x0000;
    PR3 = 100; // Trigger ADC1 every 125usec
    T3CONbits.TCKPS = 3;
    IFS0bits.T3IF = 0; // Clear Timer 3 interrupt
    IEC0bits.T3IE = 0; // Disable Timer 3 interrupt
    T3CONbits.TON = 1; //Start Timer 3
}

void initDma0(void)
{
    DMA0CONbits.AMODE = 0;
    DMA0CONbits.MODE = 0;

    DMA0PAD = (int)&ADC1BUF0;
    DMA0CNT = (2*NSAMPLES-1);

    DMA0REQ = 13;

    DMA0STA = __builtin_dmaoffset(sampleArray);

    IFS0bits.DMA0IF = 0;
    IEC0bits.DMA0IE = 1;

    DMA0CONbits.CHEN = 1;
}

void printArray()
{
    int i;
    char str[50];
    Debug("ADC_VOLTAGES\r\n");
    for(i=0; i < NSAMPLES; i++) {
        sampleVArray[i] = sampleArray[i][VOLTAGE];
        sprintf(str, "%d\r\n", sampleVArray[i]);
        Debug(str);
    }
    Debug("\r\nADC_CURRENTS\r\n");
    for(i=0; i < NSAMPLES; i++) {
        sampleCArray[i] = sampleArray[i][CURRENT];
        sprintf(str, "%d\r\n", sampleCArray[i]);
        Debug(str);
    }
    Debug("\r\n");
}

void computeSample (void);
void aquireADC(int channel)
{
    sampleReady = 0;
    AD1CON1bits.ADON = 1; // Enable ADC
    while(sampleReady == 0);
    printArray();
    computeSample();
}

void __attribute__((__interrupt__,no_auto_psv)) _DMA0Interrupt(void)
{
    IFS0bits.DMA0IF = 0;
    AD1CON1bits.ADON = 0; // Disable ADC
    sampleReady = 1;
}
