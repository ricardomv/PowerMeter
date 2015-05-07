#include <p33FJ64GP802.h>
#include "common.h"
#include <stdio.h>
#include <math.h>

#define NSAMPLES 64
#define VOLTAGE 0
#define CURRENT 1


extern void copy_data(int length, int* data_out, int* data_in, int offset, int* end_data_in);
extern void DFT(int length, int* data_in, int* data_out, int* table, int page);
extern void DFT_Fundamental(int length, int* data_in, int* data_out, int* table, int page, int cycles);
extern float calculate_freq(int data1, int data2, int data3, int data4, unsigned char smp_pnt);
extern void qusi_syn_wnd(int smp_pnt, int* input_data, int offset, int* end_input_data, int* table, int page, int* output_data);
extern void ComputeMagnitude(int* input, unsigned long* output, int len, unsigned long* total_magnitude);
extern void ComputePower(int* voltage_buffer, int* current_buffer, int* output, int len);

extern long ComputeNeutralAmplitude(int*, int);

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

    TRISAbits.TRISA0 = 1;
    TRISAbits.TRISA1 = 1;

    AD1CON1bits.ADDMABM = 1; // DMA Buffer Build Mode bit
    AD1CON2bits.SMPI = 2; // Increments the DMA address after completion of every 2nd sample/conversion
    //AD1CON4bits.DMABL = 7;

    // Initialize MUXA Input Selection
    AD1CHS0bits.CH0SA = 1; // Select AN1 for CH0 +ve input
    AD1CHS0bits.CH0NA = 0; // Select VREF- for CH0 -ve input
    AD1CHS123bits.CH123SA = 0; // AN0 for CH1 +ve input
    AD1CHS123bits.CH123NA = 0;

    AD1PCFGL = 0xFFFF;
    AD1PCFGLbits.PCFG0 = 0; // AN0 as Analog Input
    AD1PCFGLbits.PCFG1 = 0; // AN1 as Analog Input
    IFS0bits.AD1IF = 0;  // Clear interrupt flag
    IEC0bits.AD1IE = 0;  // Disable ADC interrupt
    AD1CON1bits.ADON = 1; // Enable ADC
}

void initTimer3(void)
{
    TRISBbits.TRISB15 = 0;
    TMR3 = 0x0000;
    PR3 = 150; // Trigger ADC1 every 125usec
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
    long neutrAmp;
    char str[50];
    Debug("ADC voltage values:\n\r");
    for(i=0; i < NSAMPLES; i++) {
        sampleVArray[i] = sampleArray[i][VOLTAGE];
        sprintf(str, "%d ", sampleVArray[i]);
        Debug(str);
    }
    Debug("\n\rADC current values:\n\r");
    for(i=0; i < NSAMPLES; i++) {
        sampleCArray[i] = sampleArray[i][CURRENT];
        sprintf(str, "%d\n\r", sampleCArray[i]);
        Debug(str);
    }
    Debug("\n\r");
/*
    CORCON = 0x00F1;        // signed computing, saturation for both Acc, integer computing

    asm volatile(
        "mov    #_sampleCArray, W8 \n"   //  W8 = @arr1, point to a first element of array
        "mov    #_sampleCArray, W10 \n"   //  W8 = @arr1, point to a first element of array

        "mov    #0, W4\n"         // clear W4
        "mov    #0, W6\n"         // clear W6

        "clr    A\n"
        "repeat #10\n"
        "mac    W4*W6, A, [W8]+=2, W4, [W10]+=2, W6\n"     // AccA = sum(arr1*arr2)

        "sftac  A, #-16\n"        // shift the result in high word of AccA
        "sac    A, #0, %0" : "=r"(neutrAmp)      // W1 = sum(arr1*arr2)
    );*/
    neutrAmp = -ComputeNeutralAmplitude(sampleCArray, NSAMPLES);

    sprintf(str, "Calculated RMS value: %d\n\r", neutrAmp/NSAMPLES);
    Debug(str);
}

void aquireADC(int channel)
{
    sampleReady = 0;
    AD1CON1bits.ADON = 1; // Enable ADC
    while(sampleReady == 0)
        Debug("Wait for sampling.\n\r");
    printArray();
}

void __attribute__((__interrupt__,no_auto_psv)) _DMA0Interrupt(void)
{
    IFS0bits.DMA0IF = 0;
    AD1CON1bits.ADON = 0; // Disable ADC
    sampleReady = 1;
}