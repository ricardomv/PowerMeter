
;**********************************************************************
; *    Project:       Front-end of tri-phase power meter                *
; *    Author: 	   	  CADC  										 	*
; *    Date:          10/16/2006                                           *
; *    File Version:  ver1.0											*
; *    Tools used:    MPLAB C30 Compiler v 1.32                         *
; *    Linker File:   p33FJ128GP206.gld   								*
; *                                                                     *
; *		File name:	  DFT.s												*
; * 	File description: asm code for harmonic's magnitude calculation *
; *					  after FFT conversion
; *					  and some other ASM codes						 	*
; **********************************************************************/



	.include	"dspcommon.inc"		; fractsetup,CORCON

    /* global symbols */
	.global _Delay
	.global _Multiply16x16
    .global _ComputeHarmonic
    .global _Sqrt32
    .global _DFT
	.global _DFT_Fundamental
	.global _qusi_syn_wnd
	.global _ComputeMagnitude
	.global _ComputeSmallMagnitude
	.global _ComputePower
	.global _Data_Preprocessing
	.global _copy_data
	.global _ComputeNeutralAmplitude


    /* code */
    .section .text


/************************************************************************
* Delay()
* delay time = (w0)*2 + 4
***********************************************************************/
_Delay:
	dec w0, w0
	bra nz, _Delay
	return

/*************************************************************************
*
* Multiply16x16
* input:
*		w0 = multiplier 1
*		w1 = multiplier 2
* output:
*		(long)
*************************************************************************/
_Multiply16x16:
 mul.ss w0, w1, w0

 return


/***********************************************************************
* _copy_data: copy data from buffer to another buffer
*
* Data_Output[i] = Data_In[i]
* as Data_In[] is a cycle buffer, so we need to consider the boundary of the array and loop back
* input:
*		w0 = number of source data
*		w1 = ptr to the destination data buffer
*		w2 = ptr to the source data buffer
*		w3 = offset of begining address of source data buffer
*		w4 = ptr to the end of source data buffer
* return:
*		null (after calculation, the data store back to the input buffer)
* instruction cycle:
*		w0 * 2 + 11
* execution time under 30MIPS:
*		around 9~10us
*	Design By:					 Jemmey Huang  CADC
*	Last modification:			 Oct 18 / 2006
***********************************************************************/
_copy_data:
	add w3, w3, w3			;offset size in byte
	add w2, w3, w5			;find the begining of source data in cycle buffer
	cpsgt w5, w4
	goto _copy_data_skip1
	sub w5, w4, w5
	add w2, w5, w5			;adjust the pointer if exceed the boundary
_copy_data_skip1:
	dec w0, w0
	do w0, _copy_data_lp1
	mov [w5++], w6
	cpsgt w4, w5
	mov w2, w5				;adjust the pointer if exceed the boundary
_copy_data_lp1:
	mov w6, [w1++]
	return


/**********************************************************************
*
*   Function:    Data_Preprocessing()
*	this routine pre_processing the original data, enlarge the data to make sure
*   that the maximum data fit into range 0.5 ~ 1.0, so the calculation could get a better precision
*	firstly, find the absolute maximum data in the array, then detect how many bits should shift
*	finally, shift all data in the array
*
*   Arguments:   int,  length of the data to processing (stored in W0)
*                int*, pointer to the buffer stored the original data (stored in W1)
*   Returns:     left shift bits
*				 Note - the data after processing still store back into its original buffer
*
*	Design By:					 Jemmey Huang  CADC
*	Last modification:			 Oct 8 / 2006
***********************************************************************/
_Data_Preprocessing:
	push.d	w8				; {w8,w9} to TOS
	push.d	w10				; {w10,w11} to TOS
	; Prepare CORCON for fractional computation.
	push CORCON

	; w0 data length
	; w1 pointer to buffer(original)
	; w2 loop counter
	; w3 maximum value
	; w4 minimum value
	; w5 pointer to data buffer
	; w6 present data

	mov w0, w2
	dec w2, w2			; loop counter
	mov w1, w5			; pointer
	mov [w5++], w3		; maximum = buffer[0]
	mov w3, w4			; minimum = buffer[0]
	mov [w5++], w6		; read out buffer[1]

	;find the maximum and minimum value
	do w2, _cmp_end
	cpsgt w3, w6
	mov w6, w3
	cpslt w4, w6
	mov w6, w4
_cmp_end:
	mov [w5++], w6		; read out buffer[i]

	; if |minimum value| > maximum value, then maximum value = |minimum value|
	neg w4, w4
	cpsgt w3, w4
	mov w4, w3

	mov #0, w2
	mov #256, w4
	cpsgt w3, w4			;if maximum data less than 512, skip the pre-processing operation
	bra _shift_all_end

	mov #16384, w4
	mov #2, w6
	mov #1, w5
_shift_lp:
	cpslt w3, w4
	bra _shift_end
	sl	w3, w3
	inc w2, w2				; w2 now store the shift value
	mul.ss w5, w6, w8
	mov w8, w5
	bra _shift_lp

_shift_end:
	mov #0, w3
	cpsgt w2, w3
	bra _shift_all_end

	; now shift all data
	dec w0, w0
	do w0, _shift_all_data
	mul.ss w5, [w1], w6
_shift_all_data:
	mov w6, [w1++]


_shift_all_end:
	mov w2, w0
	; Restore PSVPAG and CORCON.
	pop	CORCON
	pop.d	w10				; {w10,w11} to TOS
	pop.d	w8				; {w8,w9} to TOS

	return



/***********************************************************************
* _qusi_syn_wnd: adding the qusi_synchronous window to the data buffer for pre-processing
*
* Data_Output[i] = Data_In[i] * Table[i]
* size of Data_In[] is larger than number of source data that will be calculated every time
* so we will only truncate part of the data
* and Data_In[] is a cycle buffer, that means we should consider the suffix of array loop back to
* the begining
* input:
*		w0 = number of source data
*		w1 = ptr to the source data
*		w2 = offset of the begining data
*		w3 = ptr to the end of source data
*		w4 = table address of qusi_syn window
*		w5 = page address of the qusi_syn window
*		w6 = ptr to the destination data buffer - to store the data after processing back
*
* return:
*		null (after calculation, the data store back to the input buffer)
*
* instruction cycle:
*		w0/2 * 5 +
* execution time under 30MIPS:
*
*	Design By:					 Jemmey Huang  CADC
*	Last modification:			 Oct 18 / 2006
***********************************************************************/
_qusi_syn_wnd:
	push.d	w8				; {w8,w9} to TOS
	push.d	w10				; {w10,w11} to TOS
	push.d	w12				; {w12,w13} to TOS
	; Prepare CORCON for fractional computation.
	push CORCON
	bset CORCON, #4					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #6					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #7					;ACCSAT = 1, Set 9.31 mode

;............................................................................

	; Prepare CORCON and PSVPAG for possible access of data
	; located in program memory, using the PSV.
	push	PSVPAG;

	mov	#COEFFS_IN_DATA,w10			; w10 = COEFFS_IN_DATA
	psvaccess	w10					; enable PSV bit in CORCON
	mov	w5,PSVPAG					; load PSVPAG with program
									; space page offset
									; from here w5 can be used for other job
	mov w4, w8
	mov w6, w10						; w10 point to the begining of output buffer
	add w2, w2, w2					; w2 is the offset of begining address in byte count
									; w1 always point to begining of input buffer(f(i))
									; w3 always point to the end of f(i)
	mov w0, w5
	inc w5, w5						; N = N + 1
	asr w5, #1, w7					; N/2
	dec w7, w7						; N/2 - 1, w7 for loop count

	mov w0, w9
	add w0, w9, w9					; 2*N for the total data lengh in bytes
	add w10, w9, w11				; w11 point to end of output buffer

	add w1, w9, w9					; find the last data in f(i)
	add w2, w9, w9					;
	cpsgt w9, w3					; consider the cycle buffer
	goto qusi_skp1
	sub w9, w3, w5
	sub w5, #2, w5					; w5 = w9 - w3 - 2
	add w1, w5, w9					; now w9 point to the last data in f(i)

qusi_skp1:							; first data address = offset + array begining address
	add w1, w2, w12					; find the first data in f(i)
;	cpsgt w12, w3					; consider the cycle buffer
;	goto qusi_skp2					; if address small than the address of end of f(i), skip adjust
;	sub w12, w3, w12
;	add w1, w12, w12				; now w12 point to the first data in f(i)
;qusi_skp2:

	inc w3, w13
	dec w1, w4

	mov [w12++], w5					;prefetch data in the begining of f(i) array
	mov [w8++], w6					;prefetch data in quasi-synchronous window
									;as the window is symmetrical, so we only store half size of the table
	do 	  w7, qusi_lp1
	cpsgt w13, w12					;consider the cycle buffer
	mov w1, w12						;if w12 great than the end address of f(i) array, then loop back to the begining
	mpy w5*w6, a, [w9]-=2, w5		;pre-fetch data from the tail of f(i)
	sac.r a, [w10++] 				;store result back to output buffer
	cpsgt w9, w4					;consider the cycle buffer
	mov w3, w9						;if w9 small than the begining of f(i), then loop back to the end of f(i)
	mpy w5*w6, a, [w8]+=2, w6
	sac.r a, [w11--]				;store back to output buffer, divide by power(2,15)
qusi_lp1:
	mov [w12++], w5					;pre-fetch data from the head of f(i) array

	btsc w0, #0						;should detection odd or even to process the center point in the array
	bra _skip_process_center
	mpy w5*w6, a
	sac.r a, [w10]					;store back to input buffer, divide by power(2,15)

_skip_process_center:

	pop	PSVPAG
	pop	CORCON
	pop.d	w12				; {w12,w13} to TOS
	pop.d	w10				; {w10,w11} to TOS
	pop.d	w8				; {w8,w9} to TOS

	return



/***********************************************************************
* _DFT_Fundamental:
*				  calculate DFT transform for the fundamental waveform
* 		 		  this routine could be use to calculate the phase of fundamental waveform
*				  which equals to atan(A(1)/B(1))
*
* Operation:
* F(1) = (1/N)* sum_n (f(n)*WN(n)), WN(n) = exp[-(j*2*pi*n)/N],
*	 n in {0, 1,... , N-1},
* F(2) = (1/N)* sum_n (f(n)*WN(n)), WN(n) = exp[-(j*2*pi*n)/N],
*	 n in {N, 1,... , 2*N-1},
*
* calculate:
*			cycle 1 's DFT transform
*    and    cycle 2 's DFT transform
* Input:
*   w0 = number of source data per cycle
*	w1 = ptr to source vector (srcCV)		----- data should be stored in Y-DATA memory
*   w2 = ptr to output value
*	w3 = ptr to cos_sin table
*	w4 = COEFFS_IN_DATA, or memory program page with cos_sin table
*   w5 = calculate cycle number
* Return:
*	 null
* result store in (w2) array, where
* (w2  ) = F(1).real
* (w2+1) = F(1).imag
* (w2+2) = F(2).real
* (w2+3) = F(2).imag
*
* System resources usage:
*	{w0..w7}	used, not restored
*	{w8..w13}	saved, used, restored
*	 AccuA		used, not restored
*	 AccuB		used, not restored
*	 CORCON		saved, used, restored
*	 PSVPAG		saved, used, restored (if factors in P memory)
*
* one loop stage usage.
* instruction cycle:
*		w0 * 4 +
* execution time under 30MIPS:
*	Design By:					 Jemmey Huang  CADC
*	Last modification:			 Oct 8 / 2006
***********************************************************************/
_DFT_Fundamental:

	push.d	w8				; {w8,w9} to TOS
	push.d	w10				; {w10,w11} to TOS
	push.d	w12				; {w12,w13} to TOS

;............................................................................

	; Prepare CORCON for fractional computation.
	push CORCON
	bset CORCON, #4					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #6					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #7					;ACCSAT = 1, Set 9.31 mode

;............................................................................

	; Prepare CORCON and PSVPAG for possible access of data
	; located in program memory, using the PSV.
	push	PSVPAG;


	mov	#COEFFS_IN_DATA,w7			; w7 = COEFFS_IN_DATA
	psvaccess	w7					; enable PSV bit in CORCON
	mov	w4,PSVPAG					; load PSVPAG with program
									; space page offset
									; from here w4 can be used for other job

	mov w5, w9						; cycle number store to w9

	mov w0, w7						; data length = N
	dec w7, w7						; N-1

	; from here,
	; w0 data length N
	; w1 source data start address
	; w2 return data start address
	; w3 table start address for cosx
	; w4 not use
	; w5, w6 use by MAC
	; w7 loop counter = N-1
	; w8 X data pointer to the sin_cos table
	; w9 cycle number
	; w10 Y data pointer to the f(i)
	; w11 not use
	; w12 not use
	; w13 not use

	mov w1, w11
_loop_cycls:
	mov w11, w10					; source data begining address
	mov w3, w8						; cos table begining address
	clr A
	mov [w10++], w6					; pre-fetch source data
	mov [w8++], w5					; pre-fetch cos table
	repeat  w7
	mac w5*w6, a, [w8]+=2, w5, [w10]+=2, w6
	sac.r a, #5, [w2++]				; stored real value of cycle 1

	mov w11, w10					; retrive source data begining address
	mov [w10++], w6					; pre-fetch data f(1)
	clr A
	repeat w7						; repeat N time
	mac w5*w6, a, [w8]+=2, w5, [w10]+=2, w6
	sac.r a, #5, [w2++]				; stored image value of cycle 1  >>20

	add w11, w0, w11
	add w11, w0, w11
	dec	w9, w9						; w9--
	bra	gt,_loop_cycls				; if w0 > 0, do next stage


	; Restore PSVPAG and CORCON.
	pop	PSVPAG
	pop	CORCON

	pop.d	w12				; {w12,w13} to TOS
	pop.d	w10				; {w10,w11} to TOS
	pop.d	w8				; {w8,w9} to TOS
	return





/***********************************************************************
* _DFT:  calculate N point DFT transform
* 		 the source data contain 3 cycles data, so the data length = N*3
*
* Operation:
*	F(k) = sum_n (f(n)*WN(kn)), WN(kn) = exp[-(j*2*pi*k*n)/N],
*
* n in {0, 1,... , 3*N-1}, and
* k in {0, 1,... , N/2-1}
*
* calculate:  A(k) = (F(k).real * F(k).real + F(k).imag * F(k).imag)
*
* Input:
*   w0 = number of source data per cycle
*	w1 = ptr to source vector (srcCV)		-- store in y-memory
*   w2 = ptr to the return buffer of amplitude for each order harmonic -- store in x-memory
*	w3 = ptr to cos_sin table
*	w4 = COEFFS_IN_DATA, or memory program page with cos_sin table
* Return:
*	 null
*
* System resources usage:
*	{w0..w7}	used, not restored
*	{w8..w13}	saved, used, restored
*	 AccuA		used, not restored
*	 AccuB		used, not restored
*	 CORCON		saved, used, restored
*	 PSVPAG		saved, used, restored (if factors in P memory)
*
* two loop stage usage.
*
* total cycles: about (w0*3*6*+13)*32 + 35
*
*	Design By:					 Jemmey Huang  CADC
*	Last modification:			 Oct 8 / 2006
***********************************************************************/
_DFT:
	push.d	w8				; {w8,w9} to TOS
	push.d	w10				; {w10,w11} to TOS
	push.d	w12				; {w12,w13} to TOS

;............................................................................

	; Prepare CORCON for fractional computation.
	push CORCON
	bset CORCON, #4					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #6					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #7					;ACCSAT = 1, Set 9.31 mode

;............................................................................

	; Prepare CORCON and PSVPAG for possible access of data
	; located in program memory, using the PSV.
	push	PSVPAG;

	mov	#COEFFS_IN_DATA,w7			; w7 = COEFFS_IN_DATA
	psvaccess	w7					; enable PSV bit in CORCON
	mov	w4,PSVPAG					; load PSVPAG with program
									; space page offset
									; from here w4 can be used for other job

	add w3,  w0, w12				; sin table address = cos table start address + 2*N
	add w12, w0, w12				; w12 point to the sin table start address
									; and w3 point to the cos table start address

	; calculate the external loop times = N/2, use w8
	;ASR w0, #1, w8					; order = N/2
	mov #31, w8						; only calculate 31 order harmonic

	mov #31, w4
	add w4, w4, w4
	add w4, w4, w4					; the output data is complex, so length = (2*31)*2
	add w2, w4, w2					; w2 pointer to the last data of output arrary
	add w2, #2, w2					; output buffer size = (2*31)*2+2


	; calculate the inner loop times = N*3, use w7
	add w0, w0, w7					;Get the inner loop time and store in w7
	mov w7, w4						;W4 = 2N
	add w7,w0, w7					;total data number = 3N  (3 cycles)
	dec w7, w7						;w7 = 3*N - 1

	; from here,
	; w0 is free
	; w1 source data start address
	; w2 return data start address
	; w3 table start address for cosx
	; w4 = 2*N
	; w5, w6 use by MAC
	; w7 inner loop counter
	; w8 external loop counter
	; w9 relative adress of cosx/sinx to the begining address
	; w10 pointer of f(i)
	; w11 2*(external loop counter) - for address count
	; w12 table start address for sinx

	mov 0, w13
_lp1:
	clr A
	clr B
	ADD w8, w8, w11					;order*2 for adress loop up(in byte)
	mov w1, w10						;point to Y data address (input data)  f(i)

	mov #0, w9						;relative pointer to the table
	mov [w10++], w5					;pre-fetch the f(0)
	mov [w3+w9], w6					;pre-fetch cos(0)

_lp2: do w7, _lp2_end
	Mac W5*W6, A, [W9+w12], W6		;get sin table value
	Mac W5*W6, B, [w10]+=2, W5		;fetch next f(i)
	add w9, w11, w9					;
	cpsgt w4, w9					;w4 is the table size value * 2 (in byte)
	sub w9, w4, w9					;here detect the range of sin/cos table, if exceed, then loop back to the begining
_lp2_end:
	mov [w3+w9], w6					;get cos table value - w11 is the start address, w9 is relative pointer

	sac.r b, #5, [w2--]				; divide by power(2, 19)
	sac.r a, #5, [w2--]				; store data to the output buffer
									; now the data in the buffer multiply with (K/2) will be equal to real value

	dec	w8, w8						; w8--
	bra	gt,_lp1						; if w8 > 0, do next stage

	clr a
	mov w1, w10
	repeat w7						; sum of f(i)
	add [w10++], A

	clr B
	sac.r b, [w2--]					; [w2] = 0, clear image part of DC
	sac.r a, #3, [w2]				; store F(0) to real part of the array


_lp1_end:
	; Restore PSVPAG and CORCON.
	pop	PSVPAG
	pop	CORCON

	pop.d	w12				; {w12,w13} to TOS
	pop.d	w10				; {w10,w11} to TOS
	pop.d	w8				; {w8,w9} to TOS


    return                          ; return from function






/**********************************************************************
*
*   Function:    ComputePower()
*   Arguments:   int*, pointer to complex DFT signal data of Voltage channel (stored in W0), data should be in X memory
*                int*, pointer to complex DFT signal data of Current channel(stored in W1), data should be in Y memory
				 int*, pointer to long type array where to store the fundemental active power,harmonic active power,
				 	   fundemental re-active power and harmonic re-active power
*                int, magnitude size to compute (stored in W3)
*   Returns:     null
*
*   This assembly function computes the active power and reactive power
*   vector pointed to by W0, W1. store the result into (W2)
*   The active power is computed as:
*        sum of (Ua(k)*Ia(k) + Ub(k)*Ib(k))/2
*   The re-active power is computed as:
*        sum of (Ua(k)*Ib(k) - Ub(k)*Ia(k))/2
*   The computed magnitude is stored to the array pointed to by W1.
*
*   NOTE:  Due to the nature of the data, scaling will be required
*          when storing out the computed magnitude from the accumulator.
*
*	Design By:					 Jemmey Huang  CADC
*	Last modification:			 Oct 8 / 2006
/***********************************************************************/
_ComputePower:
	push.d	w8				; {w8,w9} to TOS
	push.d	w10				; {w10,w11} to TOS
	; Prepare CORCON for fractional computation.
	push CORCON

	bset CORCON, #4					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #6					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #7					;ACCSAT = 1, Set 9.31 mode
	BCLR CORCON, #5

;............................................................................
	; from here,
	; w0 pointer to voltage data
	; w1 pointer to current data
	; w2 return data start address
	; w3 N
	; w4 not use
	; w5, w6 use by MAC
	; w7 2N-1
	; w8 X data pointer
	; w9 not use
	; w10 Y data pointer
	; w11 not use
	; w12 not use
	; w13 not use

	mov w3, w7						; data length = N
	dec w7, w7
	dec w7, w7						; w7 = N-2
	add w7, w7, w7					; w7 = 2*(N-2)
	dec w7, w7						; 2*(N-2)- 1, for repeat count

	;calculate active power
	mov w0, w8
	mov w1, w10
	add w8, #4, w8					; move the point to the address of fundemental voltage complex array, omit DC
	add w10, #4, w10				; move the point to the address of fundemental current complex array, omit DC
	mov [w8++], w5					; pre-fetch voltage data of fundemental
	mov [w10++], w6					; pre-fetch current data of fundemental

	clr A
;	repeat #1						;calculate fundemental active power: Ua(1)*Ia(1) + Ub(1)*Ib(1)
	mpy w5*w6, a, [w8]+=2, w5, [w10]+=2, w6
	mac w5*w6, a, [w8]+=2, w5, [w10]+=2, w6
	sac a, #1, w9					; get high 16 bit
	sftac a, #-7
	sac a, #-8, [w2++]				; get low 16 bit
	mov w9,  [w2++]					; stored fundemental active power

	clr A
	repeat  w7						; calculate harmonic active power: Ua(k)*Ia(k) + Ub(k)*Ib(k), k=2...N
	mac w5*w6, a, [w8]+=2, w5, [w10]+=2, w6
	sac a, #1, w5					; get high 16 bit
	sftac a, #-7
	sac a, #-8, [w2++]				; get low 16 bit
	mov w5,  [w2++]					; stored P value

	; now calculate re-active power

	; calculate fundemental re-active power: Ua(1)*Ib(1) - Ub(1)*Ia(1)
	mov w0, w8
	mov w1, w10
	add w8, #6, w8					; move the point to the address of fundemental voltage complex array, omit DC
	add w10, #4, w10				; move the point to the address of fundemental current complex array, omit DC
	mov [w8--], w5					; pre-fetch voltage data of fundemental - Ub(1)
	mov [w10++], w6					; pre-fetch current data of fundemental - Ia(1)
	mpy w5*w6, a, [w8], w5, [w10], w6 ; calculate Ub(1)*Ia(1), prefetch Ua(1), Ib(1)
	mpy w5*w6, b					; calculate Ua(1)*Ib(1)
	sub b							; calculate Ua(1)*Ib(1) - Ub(1)*Ia(1)
	sac b, #1, w5					; get high 16 bit
	sftac b, #-7
	sac b, #-8, [W2++]				; get low 16 bit
	mov w5,  [w2++]					; stored fundemental re-active power value


	; now calculate re-active power
	; calculate sum(Ub(k)*Ia(k))
	mov w3, w7
	dec w7, w7
	dec w7, w7						; W7 = N-2, calculate the harmonic from 2~N
	dec w7, w7						; get the repeat count
	clr A
	; calculate Ub * Ia
	add w0, #10, w8					; get the Ub(2) address
	add w1, #8, w10					; get the Ia(2) address
	mov [w8], w5					; pre-fetch voltage data
	mov [w10], w6					; pre-fetch current data
	add w8, #4, w8					; adjust the pointer to Ub(3)
	add w10,#4, w10					; adjust the pointer to Ia(3)
	repeat w7						; calculate sum(Ub(k)*Ia(k))
	mac w5*w6, a, [w8]+=4, w5, [w10]+=4, w6
	; calculate Ua * Ib
	clr B
	add w0, #8, w8					; get the Ua(2) address
	add w1, #10, w10				; get the Ib(2) address
	mov [w8], w5					; pre-fetch voltage data
	mov [w10], w6					; pre-fetch current data
	add w8, #4, w8					; adjust the pointer to Ua(3)
	add w10,#4, w10					; adjust the pointer to Ib(3)
	repeat w7						; calculate sum(Ua(k)*Ib(k))
	mac w5*w6, b, [w8]+=4, w5, [w10]+=4, w6
	; calculate Ua*Ib - Ub*Ia
	sub b
	sac b, #1, w5						; get high 16 bit
	sftac b, #-7
	sac b, #-8, [W2++]					; get low 16 bit
	mov w5,  [w2++]						; stored P value

	; calculate Ua*Ib - Ub*Ia
;	sub a
;	sac a, #1, w5						; get high 16 bit
;	sftac a, #-7
;	sac a, #-8, [W2++]					; get low 16 bit
;	mov w5,  [w2++]						; stored P value


	; Restore PSVPAG and CORCON.
	pop	CORCON
	pop.d	w10				; {w10,w11} to TOS
	pop.d	w8				; {w8,w9} to TOS


    return                             ; return from function



/**********************************************************************
*
*   Function:    ComputeMagnitude()
*   Arguments:   int*, pointer to complex DFT signal data (stored in W0)
*                int*, pointer to Magnitude (stored in W1)
*                int, magnitude size to compute (stored in W2)
*   Returns:     sum of magnitude
*
*   This assembly function computes the magnitude squared of the complex
*   vector pointed to by W0.  The magnitude squared is computed as:
*        (Real*Real + Imag*Imag)/1024  --> Long type result buffer
*   The computed magnitude is stored to the array pointed to by W1.
*	and the last unit of the array store the sum of magnitude of the harmonic (value except base wave)
*   and return value is the sum of total magnitude
*
* Input:
*   w0 = ptr to source vector (srcCV)		-- store in x-memory
*	w1 = ptr to the return buffer of amplitude for each order harmonic -- store in x-memory
*   w2 = number of source data per cycle
*   w3 = ptr to the return data buffer of total magnitude value - long type
* Return:
*	 null

*   NOTE:  Due to the nature of the data, scaling will be required
*          when storing out the computed magnitude from the accumulator.
*		   as considering the accuracy of harmonic calculation, here use 1ong value to store the result
*	 total cycles: about (w2*4*+13)*31 + 35
*
*	Design By:					 Jemmey Huang  CADC
*	Last modification:			 Oct 18 / 2006
***********************************************************************/
_ComputeMagnitude:
	push.d	w8				; {w8,w9} to TOS
;............................................................................
	; Prepare CORCON for computation.
	push CORCON
	bset CORCON, #4					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #6					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #7					;ACCSAT = 1, Set 9.31 mode
	bclr CORCON, #5

	MOV  W1, W5						;Store W1 to W5
    mov  w0, w8                    	; FFT Data stored in Y memory!

;   calculate DC order
	mov  [w8++], w4                	; fetch real value
	mpy  w4*w4, a			 	    ; compute real*real, fetch image value
	mov  [w8++], w4                	; fetch imag value
    mac  w4*w4, a			 	   	; add in imag*imag
;	add  B							; DC order didn't add to total harmonic
	sftac 	a, #4
	sac 	a, #7, w6				; get high 16 bit
	sftac 	a, #-1
	sac 	a, #-8, [w1++]			; get low 16 bit
	mov w6,  [w1++]					; stored P value

	clr  B
    dec  w2, w2                     ; decrement loop counter for DO loop
    dec  w2, w2

    do   w2, end_mag                ; use a DO loop to save time
	 mov  [w8++], w4                ; fetch real value
	 mpy  w4*w4, a			 	    ; compute real*real, fetch image value
	 mov  [w8++], w4                ; fetch imag value
     mac  w4*w4, a			 	   	; add in imag*imag
	 add  B							; add to total magnitude

; in order to easily handle the data in the harmonic percentage calculation
; here we right shift the result for 6 bit, or result = actual result/1024
	 sftac 	a, #4
	 sac 	a, #7, w6				; get high 16 bit
	 sftac 	a, #-1
	 sac 	a, #-8, [w1++]			; get low 16 bit
end_mag:
	mov w6,  [w1++]					; stored P value

	; now ACCB store the total magnitude value
	sftac 	b, #4
	sac 	b, #7, w7				; get high 16 bit
	sftac 	b, #-1
	sac 	b, #-8, w6				; get low 16 bit
	mov		w6, [w3++]				; store low 16bit into [w3] for return
	mov		w7, [w3]				; store high 16bit into [w3]

	add		#4, w5					; w5 pointer to 1st order magnitude
	mov		[w5++], w8
	mov		[w5], w9

	; (w7:w6) - (w9:w8)				; to substract the 1st order magnitude
	sub	w6, w8, w6					;
	subb w7, w9, w7

	mov w6, [w1++]					; store the total harmonic into the last unit of the magnitude array
	mov w7, [w1++]

	; Restore PSVPAG and CORCON.
	pop	CORCON

	pop.d	w8				; {w8,w9} to TOS

	return

/**********************************************************************
*
*   Function:    ComputeSmallMagnitude()
*	this function is written to handle small current signal
*   it is the same as ComputeSmallMagnitude() except the it will not right shift 10 bit before store
*   Arguments:   int*, pointer to complex DFT signal data (stored in W0)
*                int*, pointer to Magnitude (stored in W1)
*                int, magnitude size to compute (stored in W2)
*   Returns:     sum of magnitude
*
*   This assembly function computes the magnitude squared of the complex
*   vector pointed to by W0.  The magnitude squared is computed as:
*        (Real*Real + Imag*Imag) --> Long type result buffer
*   The computed magnitude is stored to the array pointed to by W1.
*	and the last unit of the array store the sum of magnitude of the harmonic (value except base wave)
*   and return value is the sum of total magnitude
*
* Input:
*   w0 = ptr to source vector (srcCV)		-- store in x-memory
*	w1 = ptr to the return buffer of amplitude for each order harmonic -- store in x-memory
*   w2 = number of source data per cycle
*   w3 = ptr to the return data buffer of total magnitude value - long type
* Return:
*	 null

*   NOTE:  Due to the nature of the data, scaling will be required
*          when storing out the computed magnitude from the accumulator.
*		   as considering the accuracy of harmonic calculation, here use 1ong value to store the result
*	 total cycles: about (w2*4*+13)*31 + 35
*
*	Design By:					 Jemmey Huang  CADC
*	Last modification:			 Oct 18 / 2006
***********************************************************************/
_ComputeSmallMagnitude:
	push.d	w8				; {w8,w9} to TOS
;............................................................................
	; Prepare CORCON for computation.
	push CORCON
	bset CORCON, #4					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #6					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #7					;ACCSAT = 1, Set 9.31 mode
	bclr CORCON, #5

	MOV  W1, W5						;Store W1 to W5
    mov  w0, w8                    	; FFT Data stored in Y memory!


	add w8, #4, w8
	add w1, #2, w1					;adjust the pointer to skip DC order

	clr  B
    dec  w2, w2                     ; decrement loop counter for DO loop
    dec  w2, w2

    do   w2, end_mag1                ; use a DO loop to save time
	 mov  [w8++], w4                ; fetch real value
	 mpy  w4*w4, a			 	    ; compute real*real, fetch image value
	 mov  [w8++], w4                ; fetch imag value
     mac  w4*w4, a			 	   	; add in imag*imag
	 add  B							; add to total magnitude

; in order to easily handle the data in the harmonic percentage calculation
	 sac 	a, #1, w6				; get high 16 bit
	 sftac 	a, #-15
	 sac 	a, [w1++]				; get low 16 bit
end_mag1:
	mov w6,  [w1++]					; stored P value

	; now ACCB store the total magnitude value
	sac 	b, #1, w7				; get high 16 bit
	sftac 	b, #-15
	sac 	b, w6					; get low 16 bit
	mov		w6, [w3++]				; store low 16bit into [w3] for return
	mov		w7, [w3]				; store high 16bit into [w3]

	add		#4, w5					; w5 pointer to 1st order magnitude
	mov		[w5++], w8
	mov		[w5], w9

	; (w7:w6) - (w9:w8)				; to substract the 1st order magnitude
	sub	w6, w8, w6					;
	subb w7, w9, w7

	mov w6, [w1++]					; store the total harmonic into the last unit of the magnitude array
	mov w7, [w1++]

	; Restore PSVPAG and CORCON.
	pop	CORCON

	pop.d	w8				; {w8,w9} to TOS

	return



/**********************************************************************
*   Function:    ComputeHarmonic()
*	this routine calculate the each other harmonic percentage for the total N orders harmonic
*
*	input:
*			w0: pointer to the data buffer where stores the long type magnitude value of harmonic -  DFTMagnitude[]
*			w1: pointer to the data buffer where stores the calculation result in integer type - harmonicMag[]
*			w2: total order( = total orders of harmonic + 2)
*	return:
*			null
*
*	this routine execute 31 times loop to count each order harmonic percentage
*   in the input buffer, or DFTMagnitude[] long type data array, where
*	DFTMagnitude[0] - the DC value
*	DFTMagnitude[1] - the 1st order signal magnitude value
*	DFTMagnitude[2] ~ DFTMagnitude[N] is the Nth order harmonic magnitude
*	the calculation will work out the the percentage of each orders harmonic(from 2 to N)
*
*	harmonicMag[i] = Sqrt((DFTMagnitude[i]/DFTMagnitude[1]))*1000
*				   = Sqrt((DFTMagnitude[i]/DFTMagnitude[1])*1000000)
*				   = Sqrt(((DFTMagnitude[i]*15625)/(DFTMagnitude[1]/64))
*
*   Note: the input value in W0 should not exceed
*	Design By:
*				   	  CAE	Gloria Xie
* 					  CADC  Jemmey Huang
*	Date:          				6/11/06
*	Last modification:			Oct 19 / 2006
***********************************************************************/
_ComputeHarmonic:
	push.d	w8				; {w8,w9} to TOS
	push.d	w10				; {w10,w11} to TOS
	push.d	w12				; {w12,w13} to TOS

	mov w0, w8				; input buffer
	mov w1, w9				; result buffer
	mov w2, w10				; order number

	mov	#1000,w7			; store the result with 1st order = 1000
	mov w7,[w9++]			; store 1000 to array[0] is the requirement of the communication protocol

	add w8, #4, w8			; adjust the pointer to DFTMagnitude[1]
	mov [w8++], w2
	mov [w8++], w3			; read out DFTMagnitude[1]

;	refer to the ComputeMagnitude(), the magnitude value already divide by 1024 before storing
;	here we divide the result by 64 again, so we can limit the magnitude value of 1st order in 16bit lengh
;	so value in W3 should be zero after shifting
	mov #0, w7
	do #5, _divide_by_64
	inc w7, w7		; clear C
	rrc w3, w3
_divide_by_64:
	rrc w2, w2

	mov w2, w11	;store the basic order to w11

	dec w10, w10
	dec w10, w10
	dec w10, w10			; order = total order - 3, prepare for the loop count
							;
_calculate_harmonic_lp:
	do w10, _calculate_harmonic_lp_end
	mov #0, w3
	cpsne w11, w3
	bra _calculate_harmonic_lp_end	; if DFTMagnitude[1] = 0, skip the calculation and store the result with 0

;	read out the magnitude value of harmonic and store into w1:w0
	mov [w8++], w0
	mov [w8++], w1

;	comparing DFTMagnitude[i] with 0, if equal to 0, skip next calclulation
	cpseq w0, w3
	bra _mpy_with_15625
	cpsne w1, w3
	bra _calculate_harmonic_lp_end	; if DFTMagnitude[i] = 0, skip the calculation and store the result with 0

;	then it will multiply with 15625, as 1st order magnitude value already divide by 64,
;	so, relatively, the magnitude value of harmonic is enlarged by 1,000,000 times
;	ratio = [(w1:w0)*15625]/[(w3:w2)/64] = (w1:w0)*1000000/(w3:w2)
;	(w1:w0) * 15625 => (w4:w3:w2)
;	for easy handling, this algorithm requires that result of [(w1:w0) * 15625] should less than 32bit long,
;	then it requires input value (w1:w0) < 0x218DA, or retrieve to the input magnitude, the hamonic manitude should less than 0x2E57
_mpy_with_15625:
	mov #0x3D09, w2
	mul.uu w1, w2, w4   ;multiply w0 with 0xf and store to (w4:w5)
	mul.uu w0, w2, w2	;multiply w0 with 0x4240 and store to (w2:w3)
	add.w w3, w4, w3
    addc.w w5, #0, w4   ;now result store in (w4:w3:w2) - w4 value will discard in next calculation

_udivid3216:
; input:
;		w4:w3:w2    dividend 	= magnitude of harmoic * 15625
;       w11:     dividsor	= magnitude of 1st order / 64
; output:
;		w1:w0    quotient
; description:
;  				 get the unsigned divide of 48/16
;   			 (w4:w3:w2)/w11 => (w1:w0)
	mov w4, w5
	mov w3, w4
	REPEAT #17            ;Setup REPEAT loop for division
    DIV.UD W4, W11        ;Perform 32-bit by 16-bit division
	; now Store quotient to W0, remainder to W1
	mov    w1, w3
	mov    w0, w5		  ;temporary store the qotient to w5

	REPEAT #17            ;Setup REPEAT loop for division
    DIV.UD W2, W11        ;Perform 32-bit by 16-bit division
	mov	   w5, w1
	; now the queotient (32bits) in (w1:w0)

;  Sqrt32
;  input:
;         (w1:w0)   unsigned long data
;  output:
;         (w0)      unsigned int of square root
;  description:
;		  get square root of 32bit unsigned long data
;  		  (w3) Integer  number fsqrt16(x)
;	      (W4, W5 is the tmp value)
;	       W6 is count
;       Computes the square-root of unsigned long.

_Sqrt32:			; clear the count
		clr	 W2
		mov	 #0x8000,W3		; ≥ı º÷µ
		mov	 #0x8000, W6	;

loop:
		rrnc W6,W6
		btss W6,#15
		bra	 loop1
loopend:
		nop
_calculate_harmonic_lp_end:
		mov	 W3,[w9++]			;store the result


		pop.d	w12				; {w12,w13} to TOS
		pop.d	w10				; {w10,w11} to TOS
		pop.d	w8				; {w8,w9} to TOS
		return



loop1:
		mul.uu  W3,W3, W4
		sub		W1, W5,W5
		btss	SR,#1		;Z=1
		bra 	cmph		;W5!=W1
		sub		W0, W4,W4
		btss	SR,#1		;Z=1
		bra		cmpl		;W4!=W0
		bra		loopend

cmph:	btsc	SR,	#0		;W5-W1<0, C=1?
		bra		shifadd
shift:
		btsc	W2,#0
		bra		adjust
		rrnc	W3,W3
		bra		loop

adjust:
		rlnc	W6,W6
		sub		W3,W6,W3
		rrnc	W6,W6
		add		W3,W6,W3
		goto	loop

cmpl:	btss		SR,	#0		;W5-W1<0, N=1?
		bra		shift
shifadd:
		bset		W2,#0
		add 		W3,W6,W3
		bra		loop



/**********************************************************************
*
*   Function:    ComputeNeutralAmplitude()
*   Arguments:   int*, pointer to data sample
*                int, samples number
*   Returns:     amplitude of neutral line current in long type
*
*	this function calculate the neutral line current RMS value
*	w0 point to the samples buffer, w1 is sample length
*   output = sum(data1*data1 + data2*data2 + ..... dataN*dataN)
*
*	Design By:					 Jemmey Huang  CADC
*	Last modification:			 Dec 10 / 2006
***********************************************************************/
_ComputeNeutralAmplitude:
	push.d	w8				; {w8,w9} to TOS

;............................................................................
	; Prepare CORCON for computation.
	push CORCON
	bset CORCON, #4					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #6					;ACCSAT = 1, Set 9.31 mode
	bset CORCON, #7					;ACCSAT = 1, Set 9.31 mode
	bclr CORCON, #5

	mov w0, w8
	mov w1, w3
	dec w1, w5						; w5 for loop count

	clr a
	do w5, _loop_n1
	add [w0++], #7, a					;caculate average value
_loop_n1:
	nop

	sac 	a, #-7, w0				; get low 16 bit
	sftac 	a, #9
	sac 	a, w1					; get high 16 bit
	nop
	REPEAT #17            ;Setup REPEAT loop for division
	div.ud  w0, w3					;now w0 is the average value

	clr A

	do  w5, _loop_n						; calculate data(n)*data(n)
	mov [w8++], w4
	sub w4, w0, w4					;sub the average value first to remove the DC offset
	nop
	nop
_loop_n:
	mac w4*w4, a

	nop
	nop
	nop

	sac 	a, #1, w1				; get high 16 bit
	sftac 	a, #-10
	sac 	a, #-5,w0

	; Restore PSVPAG and CORCON.
	pop	CORCON
	pop.d	w8				; {w8,w9} to TOS

	return
   .end
