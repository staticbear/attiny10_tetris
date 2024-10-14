.include "tn10def.inc"
.equ	LCD_CS		 = PINB0
.equ	LCD_SCLK	 = PINB1
.equ	LCD_SDIN	 = PINB2

.equ	TFIELD_LOW	 = 0x40
.equ	TFIELD_HIGH  = 0x00

.equ	BTN_DOWN	 = 0x00
.equ	BTN_UP		 = 0x01
.equ	BTN_LEFT	 = 0x02
.equ	BTN_RIGH	 = 0x03	

.equ	BTN_UP_CODE		 = (1 << 7) | (0 << 6) | (0 << 5) | (0 << 4) | (0 << 3)	// blue button
.equ	BTN_DOWN_CODE	 = (1 << 7) | (1 << 6) | (0 << 5) | (0 << 4) | (1 << 3)	// black button
.equ	BTN_LEFT_CODE	 = (1 << 7) | (0 << 6) | (1 << 5) | (0 << 4) | (1 << 3)	// red button
.equ	BTN_RIGH_CODE	 = (1 << 7) | (1 << 6) | (0 << 5) | (0 << 4) | (0 << 3)	// white button

.equ	DELAY_1S		 = 10
.equ	DELAY_09S		 = 9
.equ	DELAY_08S		 = 8
.equ	DELAY_07S		 = 7
.equ	DELAY_06S		 = 6
.equ	DELAY_05S		 = 5
.equ	DELAY_04S		 = 4

// common local
.def	t_field_x		= R17
.def	t_field_y		= R18

.def	t_field_byte	= R25
.def	t_field_addr_l	= R26
.def	t_field_addr_h	= R27

// CheckLine local
.def	t_line			= R16
.def	t_byte_tmp		= R17

// ShowIntro local	
.def	val_j			= R19

// SendLcd8Bit local
.def	arg0			= R16
.def	val_i			= R17

// BrickControl global
.def	brick_x			= R20
.def	brick_y			= R21
.def	brick_type		= R22
.def	brick_rot		= R23

// BrickControl local
.def	brick_pattern	= R16
.def	tmp_x			= R17
.def	tmp_y			= R18
.def	pattern_pos		= R19
.def	tmp_cmn			= R24

// LcdPrintField local
.def	lcd_addr_cnt	= R24

// main global
.def	t_result		= R28
.def	btn_wait		= R30
.def	drop_delay		= R29
.def	brick_nxt		= R31

/*
 PB1 - DISPLAY CS
 PB2 - DISPLAY SCLK
 PB3 - DISPLAY SDIN
*/
.cseg
.org 	0x00
	rjmp	_init

data_lcd_init_codes: .db 0xA8, 0x3F, 0xD3, 0x00, 0x40, 0xA0, 0xC0, 0xDA, 0x12, 0xA4, 0xA6, \
						 0xD5, 0x80, 0x8D, 0x14, 0xAF, 0x20, 0x00, 0xE3, 0x00

brick_type_0_0:	.db 0x60, 0x90, 0x50, 0xC0
brick_type_1_0:	.db 0xE0, 0x94, 0x07, 0x29
brick_type_2_0:	.db 0x38, 0xC2, 0x1C, 0x43
brick_type_3_0:	.db 0x98, 0x46, 0x19, 0x62
brick_type_4_0:	.db 0x70, 0x92, 0x70, 0x92
brick_type_5_0:	.db 0xC8, 0x2A, 0xC8, 0x2A
brick_type_6_0:	.db 0x29, 0xE0, 0x29, 0xE0

_init:
	sbi		ACSR, ACD							// disable comparator
//-----------------init timer-----------------------
	clr		R16									// TCCR0A, TCCR0C =   0
	out		TCCR0A, R16	
	out		TCCR0C, R16	
	ldi		R16, 0x27
	out		OCR0AH, R16
	ldi		R16, 0x0F
	out		OCR0AL, R16	
	ldi		R16, (1 << WGM02) | (1 << CS01);	// WG - 0100 CTC, CS - 100 clk/8 - 8000000 / 8 = 1000000
	out		TCCR0B, R16

//-----------------init lcd display-----------------
	ldi		R16, (1 << LCD_SDIN) | (1 << LCD_SCLK) | (1 << LCD_CS)
	out		DDRB, R16
	sbi		PORTB, LCD_CS						// DISPLAY CS set high
	ldi		XL,	data_lcd_init_codes * 2			// initialize X pointer
	ldi		XH,	0x40
_nxt_cfg_byte:
	ld		arg0, X+
	clc
	rcall   SendLcd8Bit
	cpi		arg0, 0xE3			
	brne	_nxt_cfg_byte

//-----------------init adc-----------------------
	ldi		R16, 3
	out		ADMUX, R16	// ADC3 PB3
	clr		R16
	out		ADCSRB, R16 // free run
	ldi		R16, (1 << ADEN) | (1 << ADPS2)
	out		ADCSRA, R16

	ldi		brick_nxt, 6
_press_wt:
	rcall	ShowIntro
	rcall	Delay100us
	rcall	PollButtons
	tst		btn_wait
	breq	_press_wt

	ldi		t_field_addr_l, TFIELD_LOW
	ldi		t_field_addr_h, TFIELD_HIGH
	ldi		R16, 0x00 
_nxt_byte_field:
	st		X+, R16
	cpi		t_field_addr_l, TFIELD_LOW + 16
	brne	_nxt_byte_field
	ldi		t_result, 0
	ldi		btn_wait, 0
	ldi		drop_delay, DELAY_07S

_new_brick:
	ldi		btn_wait, 0
	ldi		brick_x, 04
	ldi		brick_y, (1 << 0)
	ldi		brick_rot, 0
	mov		brick_type, brick_nxt
	set
	rcall	BrickControl
	brcs	_press_wt
	
_main:
	clt
	tst		btn_wait
	breq	_btn_none
	rcall	BrickControl
	set
_btn_up:
	sbrs	btn_wait, BTN_UP
	rjmp	_btn_left
	andi	btn_wait, ~(1 << BTN_UP)
	// handle button up
	cpi		brick_rot, 3
	brne	_up_rot_0
	ser		brick_rot
_up_rot_0:
	inc		brick_rot
	rcall	BrickControl
	brcc	_main
	dec		brick_rot
	sbrc	brick_rot, 7
	clr		brick_rot
	rcall	BrickControl
	rjmp	_main
_btn_left:
	sbrs	btn_wait, BTN_LEFT
	rjmp	_btn_right
	andi	btn_wait, ~(1 << BTN_LEFT)
	// handle button left
	cpi		brick_x, 7
	sbrc	brick_x, 3
	cpi		brick_x, 15
	breq	_r_l_restore
	inc		brick_x
	rcall	BrickControl
	brcc	_main
	dec		brick_x
_r_l_restore:
	rcall	BrickControl
	rjmp	_main
_btn_right:
	sbrs	btn_wait, BTN_RIGH
	rjmp	_btn_down
	andi	btn_wait, ~(1 << BTN_RIGH)
	// handle button right
	cpi		brick_x, 0
	sbrc	brick_x, 3
	cpi		brick_x, 8
	breq	_r_l_restore
	dec		brick_x
	rcall	BrickControl
	brcc	_main
	inc		brick_x
	rcall	BrickControl
	rjmp	_main
_btn_down:
	sbrs	btn_wait, BTN_DOWN
	rjmp	_btn_none
	andi	btn_wait, ~(1 << BTN_DOWN)
	// handle button down
	lsl		brick_y
	brne	_down_8_15_p
	sbrc	brick_x, 3
	breq	_x_zero
	ori		brick_x, (1 << 3)	// brick_x + 8
	ori		brick_y, 1
_down_8_15_p:
	rcall	BrickControl		// set new brick
	brcc	_btn_none
	lsr		brick_y
	brne	_down_8_15_m
	andi	brick_x, 7			// brick_x - 8
_x_zero:
	ori		brick_y, (1 << 7)
_down_8_15_m:
	rcall	BrickControl		// set last brick
_seek_full_line:
	rcall	CheckLine
	inc		t_result
	brcs	_seek_full_line
	dec		t_result
	rjmp	_new_brick

_btn_none:
	rcall	LcdPrintField

	rcall	PollButtons

	rcall	Delay100us
	dec		drop_delay
	brne	_sel_done
	ori		btn_wait, (1 << BTN_DOWN)

	ldi		drop_delay, DELAY_07S				// result from 0 to 15: delay 0.7 sec
	cpi		t_result, 16
	brlo	_sel_done
	ldi		drop_delay, DELAY_06S				// result from 16 to 31: delay 0.6 sec
	cpi		t_result, 32
	brlo	_sel_done
	ldi		drop_delay, DELAY_05S				// result from 32 to 63: delay 0.5 sec
	cpi		t_result, 64
	brlo	_sel_done
	ldi		t_result, 64
	ldi		drop_delay, DELAY_04S				// result from 64 and above: delay 0.4 sec
_sel_done:
	rjmp    _main

/*------------------------------------------------------------------------------------*/
/*
input:
		none
output:
		none
*/
ShowIntro:
	cpi		drop_delay, 7
	brlo	_si_delay

	clr		val_j
_si_nxt_bt:
	ldi		XL,	LOW(logo_arrow * 2)
	ldi		XH,	HIGH(logo_arrow * 2) | 0x40
	brtc	_si_tc
	ldi		XL,	LOW(logo_push * 2)
_si_tc:
	add		XL, val_j
	ld		arg0, X
	ldi		XL,	TFIELD_LOW
	ldi		XH,	TFIELD_HIGH
	add		XL, val_j
	st		X, arg0
	inc		val_j
	cpi		val_j, 16
	brne	_si_nxt_bt

	rcall	LcdPrintField

	//invert	SREG.T
	in		arg0, SREG
	set
	sbrc	arg0, 6
	clt
	ser		drop_delay
_si_delay:
	inc		drop_delay
	ret

logo_arrow:	.db 0x00, 0x00, 0xFC, 0xFC, 0xFC, 0xFC, 0x00, 0x00, \
			    0x04, 0x0C, 0x1F, 0x3F, 0x3F, 0x1F, 0x0C, 0x04

logo_push:  .db 0x3E, 0x20, 0x3E, 0x00, 0x00, 0x0E, 0x0A, 0x3E, \
				0x1F, 0x04, 0x1F, 0x00, 0x00, 0x1D, 0x15, 0x17
/*------------------------------------------------------------------------------------*/
/*
input:
		none
output:
		arg0 adc val
*/
GetAdcVal:
	ldi		R16, (1 << ADEN) | (1 << ADPS2)	| (1 << ADSC)	
	out		ADCSRA, R16
_gav_nxt:
	in		R16, ADCSRA
	andi	R16, (1 << ADSC)
	brne	_gav_nxt
	in		R16, ADCL
	ret

/*------------------------------------------------------------------------------------*/
/*
input:
		none
output:
		btn_wait buttons state
*/
PollButtons:
	rcall	GetAdcVal
	andi	arg0, 0xF8
_pb_btn_up:
	cpi		arg0, BTN_UP_CODE
	brne	_pb_btn_down
	ori		btn_wait, (1 << BTN_UP)
	rcall	BrickNextCounter
_pb_btn_down:
	cpi		arg0, BTN_DOWN_CODE
	brne	_pb_btn_left
	ori		btn_wait, (1 << BTN_DOWN)
	rcall	BrickNextCounter
	rcall	BrickNextCounter
_pb_btn_left:
	cpi		arg0, BTN_LEFT_CODE
	brne	_pb_btn_righ
	ori		btn_wait, (1 << BTN_LEFT)
	rcall	BrickNextCounter
	rcall	BrickNextCounter
	rcall	BrickNextCounter
_pb_btn_righ:
	cpi		arg0, BTN_RIGH_CODE
	brne	_pb_ext
	ori		btn_wait, (1 << BTN_RIGH)
	rcall	BrickNextCounter
	rcall	BrickNextCounter
	rcall	BrickNextCounter
	rcall	BrickNextCounter
_pb_ext:
	ret

/*------------------------------------------------------------------------------------*/
/*
input:
		none
output:
		none
*/
Delay100us:
	ldi		R16, 0x27
	out		OCR0AH, R16
	ldi		R16, 0x0F
	out		OCR0AL, R16				

	ldi		R16, (1 << OCF0A)
	out		TIFR0, R16

_dl:
	in		R16, TIFR0
	sbrs	R16, 1
	rjmp	_dl

	rcall	BrickNextCounter

	ret


/*------------------------------------------------------------------------------------*/
/*
input:
		none
output:
		none
*/
BrickNextCounter:
	dec		brick_nxt
	sbrc	brick_nxt, 7
	ldi		brick_nxt, 6
	ret

/*------------------------------------------------------------------------------------*/
/*
input:
		none
output:
		SREG.C - 1 full line found and removed, 0 no full lines
*/
CheckLine:
	clt											// T = 0 - from 0 to 7, 1 from 8 to 15
	ldi		t_field_addr_l, TFIELD_LOW
	ldi		t_field_addr_h, TFIELD_HIGH
	sbrc	t_field_addr_h, 0
_cl_sek_full_line:
	set
	ser		t_line
_cl_nxt_colmn_check:
	ld		t_field_byte, X+	
	and		t_line, t_field_byte
	cpi		t_field_addr_l, TFIELD_LOW + 8
	breq	_cl_tst_line
	cpi		t_field_addr_l, TFIELD_LOW + 16
	brne	_cl_nxt_colmn_check
_cl_tst_line:
	cpi		t_line, 0
	brne	_cl_shft_cycle
	brtc	_cl_sek_full_line
	clc
	ret
_cl_shft_cycle:
	ldi		t_field_addr_l, TFIELD_LOW	
	brtc	_cl_nxt_colmn_shft
	ori		t_field_addr_l, (1 << 3)			// 8_15 field
_cl_nxt_colmn_shft:
	ld		t_field_byte, X
	mov		t_byte_tmp, t_field_byte
	lsl		t_byte_tmp

	sbrc	t_line, 7
	rjmp	_cl_80
	sbrc	t_line, 6
	rjmp	_cl_40
	sbrc	t_line, 5
	rjmp	_cl_20
	sbrc	t_line, 4
	rjmp	_cl_10
	sbrc	t_line, 3
	rjmp	_cl_08
	sbrc	t_line, 2
	rjmp	_cl_04
	sbrc	t_line, 1
	rjmp	_cl_02

_cl_01:
	andi	t_field_byte, 0xFE
	rjmp	_cl_low_shft
_cl_02:
	andi	t_field_byte, 0xFC
	andi	t_byte_tmp, 0x03
	or		t_field_byte, t_byte_tmp	
	rjmp	_cl_low_shft
_cl_04:
	andi	t_field_byte, 0xF8
	andi	t_byte_tmp, 0x07
	or		t_field_byte, t_byte_tmp	
	rjmp	_cl_low_shft
_cl_08:
	andi	t_field_byte, 0xF0
	andi	t_byte_tmp, 0x0F
	or		t_field_byte, t_byte_tmp	
	rjmp	_cl_low_shft
_cl_10:
	andi	t_field_byte, 0xE0
	andi	t_byte_tmp, 0x1F
	or		t_field_byte, t_byte_tmp	
	rjmp	_cl_low_shft
_cl_20:
	andi	t_field_byte, 0xC0
	andi	t_byte_tmp, 0x3F
	or		t_field_byte, t_byte_tmp	
	rjmp	_cl_low_shft
_cl_40:
	andi	t_field_byte, 0x80
	andi	t_byte_tmp, 0x7F
	or		t_field_byte, t_byte_tmp	
	rjmp	_cl_low_shft
_cl_80:
	lsl		t_field_byte
_cl_low_shft:
	brtc	_cl_nxt_colmn_cont

	// if 8_15 field was shifted we have to shift 0_7 field too
	andi	t_field_addr_l, ~(1 << 3)
	ld		t_byte_tmp, X
	sbrc	t_byte_tmp, 7
	ori		t_field_byte, 01
	lsl		t_byte_tmp
	st		X, t_byte_tmp
	ori		t_field_addr_l, (1 << 3)

_cl_nxt_colmn_cont:
	st		X+, t_field_byte
	cpi		t_field_addr_l, TFIELD_LOW + 8
	brlo	_cl_nxt_colmn_shft
	brtc	_cl_ext_c1
_cl_8_15:
	cpi		t_field_addr_l, TFIELD_LOW + 16
	brne	_cl_nxt_colmn_shft
_cl_ext_c1:
	sec
	ret
/*------------------------------------------------------------------------------------*/
/*
input:
		brick_x - from 0 to 15
		brick_y - from 00000001 to 10000000
		brick_type - from 0 to 4
		brick_rot - from 0 to 3
		SREG.T
	    0		just clean brick fields
		1       check fields for brick & set brick in fields
output:
		SREG.C - 1 fields already set , 0 move/rotate done
*/
BrickControl:
	ldi		XL,	brick_type_0_0 * 2
	ldi		XH,	0x40
	mov		brick_pattern, brick_type
	lsl		brick_pattern
	lsl		brick_pattern						// brick_type * 4
	add		XL, brick_pattern
	add		XL, brick_rot						// brick_type * 4 + brick_rot
	ld		brick_pattern, X					// brick_pattern[brick_type * 4 + brick_rot]
	ldi		pattern_pos, 1						// pattern position 00000001
_bc_nxt_seg:
	mov		tmp_cmn, pattern_pos
	and		tmp_cmn, brick_pattern
	brne	_bc_x_if_six
	rjmp	_bc_cont
_bc_x_if_six:
	mov		tmp_x, brick_x
	cpi		brick_type,  6						// hack for horizontal x4 bar
	brne	_bc_get_x
	sbrc	brick_rot, 0						// x only for 0,2 position
	rjmp	_bc_y_if_six
	sbrc	pattern_pos, 5
	subi	tmp_x, 3
	sbrc	pattern_pos, 3
	subi	tmp_x, 2
	sbrc	pattern_pos, 0
	dec		tmp_x
	rjmp	_bc_check_x
_bc_get_x:
	// get x coordinate from pattern position
	ldi		tmp_cmn, (4 | 16 | 128) 
	and		tmp_cmn, pattern_pos
	brne	_bc_x_p_1

	ldi		tmp_cmn, (1 | 8 | 32)	
	and		tmp_cmn, pattern_pos
	brne	_bc_x_m_1

	rjmp	_bc_check_x							 // (2 | 64) 

_bc_x_p_1:
	inc		tmp_x
	rjmp	_bc_check_x

_bc_x_m_1:
	dec		tmp_x

_bc_check_x:
	mov		tmp_cmn, tmp_x						// aka push
	eor		tmp_x, brick_x
	andi	tmp_x, (1 << 3)
	mov		tmp_x, tmp_cmn						// aka pop
	breq	_bc_y_if_six					 
	rjmp	_bc_ext_err							// tmp_x > 7 || tmp_x < 0

_bc_y_if_six:
	mov		tmp_y, brick_y
	cpi		brick_type,  6						// hack for vertical x4 bar
	brne	_bc_get_y
	sbrs	brick_rot, 0						// y only for 1,3 position
	rjmp	_bc_tst_field_bit
	sbrc	pattern_pos, 7
	rjmp	_bc_y_p_3
	sbrc	pattern_pos, 6
	rjmp	_bc_y_p_2
	sbrc	pattern_pos, 5
	rjmp	_bc_y_p_1
	rjmp	_bc_tst_field_bit

_bc_get_y:
	// get y coordinate from pattern position
	ldi		tmp_cmn, (32 | 64 | 128) 
	and		tmp_cmn, pattern_pos
	brne	_bc_y_p_1
	
	ldi		tmp_cmn, (1 | 2 | 4) 
	and		tmp_cmn, pattern_pos
	brne	_bc_y_m_1
									 
	rjmp	_bc_tst_field_bit					// (8 | 16) 

_bc_y_p_3:
	lsl		tmp_y
	brne	_bc_y_p_2
	rcall	_bc_y_p_carry
_bc_y_p_2:
	lsl		tmp_y
	brne	_bc_y_p_1
	rcall	_bc_y_p_carry
_bc_y_p_1:
	lsl		tmp_y
	brne	_bc_tst_field_bit
	rcall	_bc_y_p_carry
	rjmp	_bc_tst_field_bit
_bc_y_p_carry:
	sbrs	tmp_x, 3
	rjmp	_bc_y_p_carry_k	
	pop		tmp_x								// just remove ret addr from stack low
	pop		tmp_x								// just remove ret addr from stack high
	rjmp	_bc_ext_err
_bc_y_p_carry_k:
	ori		tmp_x, (1 << 3)						// tmp_x + 8
	ori		tmp_y, 1
	ret

_bc_y_m_1:	
	mov		tmp_y, brick_y
	cpi		brick_type,  6						// hack for vertical x4 bar
	breq	_bc_y_p_3
	lsr		tmp_y
	brne	_bc_tst_field_bit
	sbrs	tmp_x, 3
	rjmp	_bc_ext_err
	andi	tmp_x, 7							// brick_x - 8
	ori		tmp_y, (1 << 7)

_bc_tst_field_bit: 
	brtc	_bc_clear	
	rcall	GetFieldBit	
	brne	_bc_ext_err
	brid	_bc_cont
_bc_clear:
	rcall	SetFieldBit

_bc_cont:
	lsl		pattern_pos
	breq	_bc_act
	rjmp	_bc_nxt_seg
_bc_act:
	mov		t_field_x, brick_x
	mov		t_field_y, brick_y
	brtc	_bc_center_bit
	rcall	GetFieldBit							// test center field 
	brne	_bc_ext_err
	brie	_bc_center_bit
	sei
	rjmp	BrickControl
_bc_center_bit:
	rcall	SetFieldBit
	cli
_bc_ext_ok:
	clc
	ret
_bc_ext_err:
	sec
	ret

/*------------------------------------------------------------------------------------*/
/*
input:	
		t_field_x - from 0 to 15
		t_field_y - from 00000001 to 10000000
output:
		SREG.Z - 1 clear, 0 set
*/
GetFieldBit:
	ldi		t_field_addr_l, TFIELD_LOW
	add		t_field_addr_l, t_field_x
	ldi		t_field_addr_h, TFIELD_HIGH
	ld		t_field_byte, X				
	and		t_field_byte, t_field_y
	ret

/*------------------------------------------------------------------------------------*/
/*
input:	
		t_field_x - from 0 to 15
		t_field_y - from 00000001 to 10000000
		SREG.T - 1 set, 0 clear
output:
		none
*/
SetFieldBit:
	ldi		t_field_addr_l, TFIELD_LOW
	or		t_field_addr_l, t_field_x		// instead add instruction, because add interact with C flag (use carefully)
	ldi		t_field_addr_h, TFIELD_HIGH
	ld		t_field_byte, X			
	or		t_field_byte, t_field_y
	brts	_sfb_set
	com		t_field_y
	and		t_field_byte, t_field_y
	com		t_field_y
_sfb_set:
	st		X, t_field_byte
	ret

/*------------------------------------------------------------------------------------*/
/*
input:	
		none
output:
		none
*/
LcdPrintField:
	ldi		t_field_addr_l, TFIELD_LOW - 1
_lpf_nxt_byte:
	ldi		t_field_addr_h, TFIELD_HIGH
	ldi		lcd_addr_cnt, 0
	inc		t_field_addr_l

_lpf_get_byte:
	ld		t_field_byte, X
	cpi		lcd_addr_cnt, 64
	brlo	_lpf_get_bit
	ldi		arg0, 8
	add		t_field_addr_l, arg0
	ld		t_field_byte, X
	sub		t_field_addr_l, arg0
_lpf_get_bit:
	ldi		arg0, 0x00
	push	t_field_byte
	or		arg0, lcd_addr_cnt
	andi	arg0, 0x3F	
	breq	_lpf_lcd_val
_lpf_lsr:
	lsr		t_field_byte
	subi	arg0, 8
	brne	_lpf_lsr
_lpf_lcd_val:
	ldi		arg0, 0x00
	sbrc	t_field_byte, 0
	ldi		arg0, 0xFF
	pop		t_field_byte
_lpf_nxt_print:
	sec
	rcall	SendLcd8Bit
	inc		lcd_addr_cnt
	ldi		t_field_addr_h, 7
	and		t_field_addr_h, lcd_addr_cnt	// check if lcd_addr_cnt multiple of 8
	brne	_lpf_nxt_print
	cpi		lcd_addr_cnt, 128				// check if we reached last row
	brne    _lpf_get_byte
	cpi		t_field_addr_l, TFIELD_LOW + 7  // check if we print all tetris fiels (8 columns)
	brne	_lpf_nxt_byte
_lpf_ext:
	ret

/*------------------------------------------------------------------------------------*/
/*
input:
		arg0 - data8bit
		SREG.C - 1 data, 0 - cmd
output:
		none
*/
SendLcd8Bit:
	cbi		PORTB, LCD_CS		// DISPLAY CS set low
	ldi		val_i, 10
_slbc_nxt:
	cbi		PORTB, LCD_SCLK		// DISPLAY SCLK set low
	cbi		PORTB, LCD_SDIN
	dec		val_i
	breq	_slbc_ext
	brcc	_slbc_bt0
	sbi		PORTB, LCD_SDIN
_slbc_bt0:
	sbi		PORTB, LCD_SCLK		// DISPLAY SCLK set high
	rol 	arg0
	rjmp	_slbc_nxt
_slbc_ext:
	sbi		PORTB, LCD_CS		// DISPLAY CS set high
	ret

