/* 
 * File:   adc.h
 * Author: ricardo
 *
 * Created on May 4, 2015, 3:03 PM
 */

#ifndef ADC_H
#define	ADC_H

#define NSAMPLES 128
#define VOLTAGE 0
#define CURRENT 1

void initADC1(void);
void initTimer3(void);
void initDma0(void);
void aquireADC(int);

#endif	/* ADC_H */

