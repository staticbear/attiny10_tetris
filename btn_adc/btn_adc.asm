.include "tn10def.inc"
/*
	PB3 adc input
	PB0 clk
	PB1 data
*/
.cseg
.org 	0x00
	sbi		ACSR, ACD							// disable comparator 
//-----------------init gpio-----------------------
	ldi		R16, (1 << PINB1) | (1 << PINB0)
	out		DDRB, R16
	ldi		R16, 0
	out		PORTB, R16
//-----------------init adc-----------------------
	ldi		R16, 3
	out		ADMUX, R16	// ADC3 PB3
	clr		R16
	out		ADCSRB, R16 // free run
	ldi		R16, (1 << ADEN) | (1 << ADPS2)
	out		ADCSRA, R16
	
_main:
	ldi		R16, (1 << ADEN) | (1 << ADPS2)	| (1 << ADSC)	
	out		ADCSRA, R16
_nxt:
	in		R16, ADCSRA
	andi	R16, (1 << ADSC)
	brne	_nxt

	ldi		R17, 8
	in		R16, ADCL
_nxt_bit:
	sbrc	R16, 7
	sbi		PORTB, PINB1			// set data 1
	sbrs	R16, 7
	cbi		PORTB, PINB1			// set data 0
	nop
	sbi		PORTB, PINB0			// set clk 1
	lsl		R16
	dec		R17
	cbi		PORTB, PINB0			// set clk 0		
	brne	_nxt_bit

	cbi		PORTB, PINB1			// set data 0
	ldi		R16, 32
_delay:
	dec		R16
	brne	_delay

	rjmp	_main

