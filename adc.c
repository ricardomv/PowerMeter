#include <p33FJ64GP802.h>
#include "common.h"

#define NSAMPLES 64

unsigned char sampleCount = 0;
int sampleVArray[NSAMPLES];
int sampleCArray[NSAMPLES];
int sampleIdx = 0;
int sampleReady = 0;

void initADC( void )
{
    /* enable ADC interrupts, disable this interrupt if the DMA is enabled */
    IEC0bits.AD1IE = 1;

    /* turn on ADC module 
    AD1CON1bits.ADON = 0;
    AD1CON1bits.AD12B = 0; // Operational Mode 10-bit, 4-channel
    AD1CON2bits.CHPS = 1;  // Channel - dual channel
    AD1CON2bits.VCFG = 0;  // Voltage Reference - Vdd
    AD1CON3bits.ADRC = 0;  // Clock TCY * (ADCS + 1)
    AD1CON1bits.FORM = 0b11; // Signed Fractional Format

    IFS0bits.AD1IF = 0; //clear ADC interrupt flag
    IEC0bits.AD1IE = 1; //enable ADC interrupt
    AD1CON1bits.ADON = 1; //turn on the ADC



    // Initialize MUXA Input Selection
    AD1CHS0bits.CH0SA = 3;
    // Select AN3 for CH0 +ve input
    AD1CHS0bits.CH0NA = 0; // Select VREF- for CH0 -ve input
    // Select VREF- for CH0 -ve input
    AD1CHS123bits.CH123SA=0; // AN0 for CH1 +ve input
                             // AN1 for CH2 +ve input
    AD1CHS123bits.CH123NA=0;
    */

    TRISAbits.TRISA0 = 1;   // Set AN0 as input
    TRISAbits.TRISA1 = 1;   // Set AN1 as input

    AD1CON1bits.AD12B=0;    // Select 10-bit mode
    AD1CON2bits.CHPS=1;     // Select 2-channel mode
    AD1CON2bits.SMPI = 3;   // Select 4 conversion between interrupt
    AD1CON1bits.ASAM = 1;   // Enable Automatic Sampling
    AD1CON2bits.ALTS = 1;   // Enable Alternate Input Selection
    AD1CON1bits.SIMSAM = 0; // Enable Sequential Sampling
    AD1CON1bits.SSRC = 2;   // Timer3 generates SOC trigger

    // Initialize MUXA Input Selection
    AD1CHS0bits.CH0SA = 0; // Select AN0 for CH0 +ve input
    AD1CHS0bits.CH0NA = 0; // Select V REF - for CH0 -ve input
    AD1CHS123bits.CH123SA = 1;// Select AN1 for CH1 +ve input
    AD1CHS123bits.CH123NA = 0;// Select Vref- for CH1 -ve inputs

    // Initialize MUXB Input Selection
    //AD1CHS0bits.CH0SB = 7; // Select AN7 for CH0 +ve input
    //AD1CHS0bits.CH0NB = 0; // Select V REF - for CH0 -ve input
    //AD1CHS123bits.CH123SB=1;// Select AN3 for CH1 +ve input
    //AD1CHS123bits.CH123NB=0;// Select V REF - for CH1-ve inputs

    /* reset ADC interrupt flag */
    IFS0bits.AD1IF = 0;
    /*set AD1 interrupt level =7;*/

    IPC3bits.AD1IP=2;
    /* enable ADC interrupts, disable this interrupt if the DMA is enabled */
    IEC0bits.AD1IE = 1;

    /* turn on ADC module */
    AD1CON1bits.ADON = 1;
}

void printArray()
{
    int i;
    Debug("ADC voltage values: ");
    for(i=0; i < NSAMPLES; i++) {
        Debug(sampleVArray[i]);
        Debug(" ");
    }
    Debug("\n\r");
}

void aquireADC(int channel)
{
    IEC0bits.AD1IE = 1;
}

void __attribute__((__interrupt__)) _ADC1Interrupt(void)
{
    IFS0bits.AD1IF = 0;
    sampleVArray[sampleIdx++] = ADC1BUF0;

    if (sampleIdx == NSAMPLES) {
        sampleIdx = 0;
        printArray();
        AD1CON1bits.ADON = 0;
        IEC0bits.AD1IE = 0;
    }
}