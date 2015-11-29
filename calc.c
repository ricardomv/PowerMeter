#include <stdio.h>
#include <math.h>

#include "common.h"
#include "adc.h"
#include "fft.h"
#include <p33FJ32GP302.h>

#define TRANSF_RATIO 25.4663

extern int sampleArray[NSAMPLES][2] __attribute__((space(dma),aligned(32)));
extern int sampleVArray [NSAMPLES];
extern int sampleCArray [NSAMPLES];
int sampleVArrayImag [NSAMPLES];
int sampleCArrayImag [NSAMPLES];

typedef struct _COMPLEX
{
    int real;
    int imag;
}COMPLEX;

COMPLEX DFTOut_V[32] __attribute__((space(xmemory), far));
COMPLEX DFTOut_I[32] __attribute__((space(ymemory), far));

extern void copy_data(int length, int* data_out, int* data_in, int offset, int* end_data_in);
extern void DFT(int length, int* data_in, int* data_out, int* table, int page);
extern void DFT_Fundamental(int length, int* data_in, int* data_out, int* table, int page, int cycles);
extern float calculate_freq(int data1, int data2, int data3, int data4, unsigned char smp_pnt);
extern void qusi_syn_wnd(int smp_pnt, int* input_data, int offset, int* end_input_data, int* table, int page, int* output_data);
extern void ComputeMagnitude(int* input, unsigned long* output, int len, unsigned long* total_magnitude);
extern void ComputePower(int* voltage_buffer, int* current_buffer, int* output, int len);
extern long ComputeNeutralAmplitude(int*, int);

unsigned long DFTMagnitude[33] = {0};
int harmonicMag[33] = {0};

void computeSample (void)
{
    long power[4] = {0};
    char str[50];
    unsigned long amplitude = 0;

    int i;


    fix_fft((short *)sampleVArray, (short *)sampleVArrayImag, 6);
    fix_fft((short *)sampleCArray, (short *)sampleCArrayImag, 6);

    amplitude = ComputeNeutralAmplitude(sampleVArray, NSAMPLES);
    sprintf(str, "Voltage RMS: %f\n\r", sqrt((float)amplitude/NSAMPLES));
    Debug(str);

    Debug("FFT Re\n\r");
    for(i=0; i < 32; i++) {
        DFTOut_V[i].real = sampleVArray[i];
        DFTOut_I[i].real = sampleCArray[i];
        DFTOut_V[i].imag = sampleVArrayImag[i];
        DFTOut_I[i].imag = sampleCArrayImag[i];
        sprintf(str, "%d\n\r", DFTOut_V[i].real);
        Debug(str);
    }

    Debug("FFT Im\n\r");
    for(i=0; i < 32; i++) {
        sprintf(str, "%d\n\r", DFTOut_V[i].imag);
        Debug(str);
    }
    //calculate the amplitude of every order, store into DFTMagnitude[i]
    //

    ComputeMagnitude((int*)&DFTOut_V[0].real, (long*)&DFTMagnitude[0], 32, &amplitude);
    // as the result was divide by 1024 in computeMagnitude(),
    // so here we multiply with sqrt(1024)=32 for compensation
    sprintf(str, "Voltage amplitude: %f\n\r", sqrt((float)amplitude)/1024*3.1);
    Debug(str);
    ComputeMagnitude((int*)&DFTOut_I[0].real, (long*)&DFTMagnitude[0], 32, &amplitude);
    sprintf(str, "Current amplitude: %f\n\r", sqrt((float)amplitude)/1024*3.1);
    Debug(str);

    //------------ harmonic ------------------
    //Calculate harmonic, the 1st value (harmonicMag[x][0])is base value
    ComputeHarmonic(&DFTMagnitude[0], &harmonicMag[0], 32+1);

    Debug("Magnitude:\n\r");
    for(i=0; i < 32; i++) {
        sprintf(str, "%ld\n\r", DFTMagnitude[i]);
        Debug(str);
    }
    Debug("Harmonic Magnitude:\n\r");
    for(i=0; i < 32; i++) {
        sprintf(str, "%d\n\r", harmonicMag[i]);
        Debug(str);
    }
    // now calculate the active power, re-active power, apparent power and the power factor
    ComputePower((int*)DFTOut_V, (int*)DFTOut_I, (int*)&power, 31);
    sprintf(str, "Active power: %f\n\r", power[0]/32768/3.2);
    Debug(str);
    sprintf(str, "Re-active power: %f\n\r", power[1]/32768/3.2);
    Debug(str);
    sprintf(str, "Apparent power: %f\n\r", power[2]/32768/3.2);
    Debug(str);
    sprintf(str, "Power factor: %f\n\r", power[3]/32768/3.2);
    Debug(str);
}
