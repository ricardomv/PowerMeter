#include <stdio.h>
#include <math.h>

#include "common.h"
#include "adc.h"
#include "fft.h"
#include "uart.h"
#include <p33FJ32GP302.h>

#define PI 3.14159265
#define PI_3 PI/3.0

#define VRES_IN         10.0            // ohm, sample resistor on priminary of PT
#define VRES_OUT        1.0             // ohm, sample resistors on secondary of PT
#define PT_RATIO        233/9.05        // 1:1 (IN/OUT), spec of PT in this application
#define FULL_VOLT_CH    3.3             // Full scale of voltage channel input, Refer to datasheet

#define IRES_OUT        1000.0          // ohm, sample resistors on secondary of CT
#define CT_RATIO        3000.0          // 2000:1 (IN/OUT), spec of CT in this application
#define FULL_CUR_CH     3.3             // Full scale of voltage channel input, Refer to datasheet

#define sqrt_2          1.4142136       //sqrt(2)

#define VOTAGE_CH_COEF  (VRES_IN*PT_RATIO*FULL_VOLT_CH/VRES_OUT)/32768.0/sqrt_2
#define CURRENT_CH_COEF  (FULL_CUR_CH*CT_RATIO/IRES_OUT)/32768.0/sqrt_2
#define POWER_CH_COEFF  VOTAGE_CH_COEF*CURRENT_CH_COEF*2

extern int sampleArray[NSAMPLES][2] __attribute__((space(dma),aligned(32)));
extern int sampleVArray [NSAMPLES];
extern int sampleCArray [NSAMPLES];
int sampleVArrayImag [NSAMPLES];
int sampleCArrayImag [NSAMPLES];

int data_copy[NSAMPLES] __attribute__ ((space(ymemory), aligned (2)));

typedef struct _COMPLEX
{
    int real;
    int imag;
}COMPLEX;

COMPLEX DFTOut_V[64] __attribute__((space(xmemory), far));
COMPLEX DFTOut_I[64] __attribute__((space(ymemory), far));

extern void copy_data(int length, int* data_out, int* data_in, int offset, int* end_data_in);
extern void DFT_Fundamental(int length, int* data_in, int* data_out, int* table, int page, int cycles);
extern float calculate_freq(int data1, int data2, int data3, int data4, unsigned char smp_pnt);
extern void qusi_syn_wnd(int smp_pnt, int* input_data, int offset, int* end_input_data, int* table, int page, int* output_data);
extern void ComputeMagnitude(int* input, unsigned long* output, int len, unsigned long* total_magnitude);
extern void ComputePower(int* voltage_buffer, int* current_buffer, int* output, int len);
extern long ComputeNeutralAmplitude(int*, int);

unsigned long DFTMagnitude[64] __attribute__((space(xmemory), far));

void computeSample (int v_ch, int i_ch)
{
    long power[4] = {0};
    char str[50];
    unsigned long amplitude = 0;
    float vrms, irms, act_power, react_power, apar_power;
    float vcal[3] = {1.11, 1, 1}, ical[7] = {1, 1, 1, 1, 1, 1, 1};
    int i;

    fix_fft((short *)sampleVArray, (short *)sampleVArrayImag, 7);
    fix_fft((short *)sampleCArray, (short *)sampleCArrayImag, 7);

    Debug("FFT Re\r\n");
    for(i=0; i < 64; i++) {
        DFTOut_V[i].real = sampleVArray[i];
        DFTOut_I[i].real = sampleCArray[i];
        DFTOut_V[i].imag = sampleVArrayImag[i];
        DFTOut_I[i].imag = sampleCArrayImag[i];
        sprintf(str, "%d\r\n", DFTOut_V[i].real);
        Debug(str);
    }

    Debug("FFT Im\r\n");
    for(i=0; i < 64; i++) {
        sprintf(str, "%d\r\n", DFTOut_V[i].imag);
        Debug(str);
    }
    //calculate the amplitude of every order, store into DFTMagnitude[i]
    //

    DFTOut_V[0].real = 0;
    DFTOut_I[0].real = 0;
    DFTOut_V[0].imag = 0;
    DFTOut_I[0].imag = 0;

    ComputeMagnitude((int*)&DFTOut_V[0].real, DFTMagnitude, NSAMPLES/2, &amplitude);
    //neutralAmplitude = ComputeNeutralAmplitude((int*)&DFTOut_V[0].real, NSAMPLES/2);
    // as the result was divide by 1024 in computeMagnitude(),
    // so here we multiply with sqrt(1024)=32 for compensation
    // sqrt((float)amplitude)*32*ratio1*VOTAGE_CH_COEF;
    Debug("\r\nDFTMagnitude\r\n");
    for(i=0; i < 64; i++) {
        sprintf(str, "%ld\r\n", DFTMagnitude[i]);
        Debug(str);
    }

    vrms = sqrt((float)amplitude)*32*VOTAGE_CH_COEF*vcal[v_ch];

    sprintf(str, "voltage_rms=%f\r\n", vrms);
    writeStringUART1(str);
    sprintf(str, "voltage_amplitude=%ld\r\n", DFTMagnitude[0]);
    Debug(str);

    ComputeMagnitude((int*)&DFTOut_I[0].real, DFTMagnitude, NSAMPLES/2, &amplitude);

    irms = sqrt((float)amplitude)*32*CURRENT_CH_COEF*ical[i_ch];

    sprintf(str, "current_rms=%f\r\n", irms);
    writeStringUART1(str);
    sprintf(str, "current_amplitude=%f\r\n", DFTMagnitude[0] * CURRENT_CH_COEF);
    Debug(str);
    // now calculate the active power, re-active power, apparent power and the power factor
    ComputePower((int*)DFTOut_V, (int*)DFTOut_I, (int*)&power, 64 -1);
    // power[0] //fundemental active power
    // power[1] //total harmonic active power
    // power[2] //fundemental reactive power
    // power[3] //total harmonic reactive power

    act_power = (float)(power[0] + power[1]) * POWER_CH_COEFF;
    sprintf(str, "active=%f\r\n", act_power);
    writeStringUART1(str);
    sprintf(str, "reactive=%d\r\n", (power[2]+power[3]) * POWER_CH_COEFF);
    writeStringUART1(str);
    apar_power = vrms*irms;
    sprintf(str, "aparent=%f\r\n", apar_power);
    writeStringUART1(str);
    sprintf(str, "pf=%f\r\n", act_power/apar_power);
    writeStringUART1(str);
}
