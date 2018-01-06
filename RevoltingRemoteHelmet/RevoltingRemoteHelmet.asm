/*
 * RevoltingRemoteHelmet.asm
 *
 *  Created: 25.11.2017 13:23:09
 *   Author: fuerh_000
 */ 


 #include <m8def.inc>
 #include "GeneralSettings.inc"

 .equ channel_nr = 0x12
 .equ secretnumber_1 = 0x42
 .equ secretnumber_2 = 0x32
 .equ min_pulses = 0x08
 .org 0x000
rjmp reset


.org ICP1addr
rjmp inputCapture

.org OVF0addr
rjmp timer0_ovflow

.org OVF1addr
rjmp timer_stop


// hauptprogramm startet hier
.org 0x013
reset:
ldi r16, high(RAMEND)
out SPH,r16
ldi r16, low(RAMEND)
out SPL,r16


// ADC0-2 als Eingänge
ldi r16,(0<<DDC0)|(0<<DDC1)|(0<<DDC2)
out DDRC,r16

// adc einrichten
// AVCC mit kapazität am Aref-Pin, Resultat linksbündig
 ldi r16,(1<<REFS0)|(1<<ADLAR)
 out ADMUX,r16

 // prescaler 8, enabled, do not start conversion
 ldi r16,(1<<ADEN)|(0<<ADSC)|(1<<ADPS1)|(1<<ADPS0)
 out ADCSRA,r16





// variablen mit standardwerten initialisieren
ldi r16,0x00
sts adc_counter,r16
sts receiver_state,r16
sts hsv_angle,r16
sts hsv_angle+1,r16
sts decoder_cntr,r16



// PB1-PB3 as output
ldi r16,(1<<DDB1)|(1<<DDB2)|(1<<DDB3)|(0<<DDB0)
out DDRB,r16
ldi r16,0x00
out PORTB,r16
// PD0 aus input
ldi r16,(0<<DDD0)
out DDRD,r17

// timer/counter 1 acts as clock cycle counter for icp pin
// overflow on OCR1A
ldi r16,(1<<WGM10)|(1<<WGM11)
out TCCR1A,r16
ldi r16,(1<<TICIE1)|(1<<OCIE1A)
out TIMSK,r16
ldi r17,high(pulse_duration+pulse_tolerance)
ldi r16,low(pulse_duration+pulse_tolerance)
out OCR1AH,r17
out OCR1AL,r16
ldi r16,(1<<ICNC1)|(1<<ICES1)|(1<<CS10)|(1<<WGM13)|(1<<WGM12) // enable noise cancelling, enable trigger on rising edge, start clock
out TCCR1B,r16



sei // enable interrupts
main:

lds r18,receiver_state
sbrs r18,7
rjmp main

// message is ready, decode it
cbr r18,128
lds r17,receiver_message+1
lds r16,receiver_message
cpi r17,0b01010101
brne main_end

andi r16,0x07
lsl r16
in r17,PORTB
or r17,r16
out PORTB,r17

main_end:
sts receiver_state,r18

rjmp main

//rcall longwait


 



// waits for about a quarter of a second
longwait:
push r16
push r17
push r18
push r19
ldi r18,0x00

start_clock:
ldi r16,0x00
out TCNT0,r16
ldi r16,(0<<CS02)|(1<<CS01)|(0<<CS00)
out TCCR0,r16
wait_oflow:
in r17,TIFR
sbrs r17,TOV0
rjmp wait_oflow
out TIFR,r17
//inc r18
//brne start_clock
pop r19
pop r18
pop r17
pop r16
ret



inputCapture:
push r16
push r17
push r18
in r16,SREG
push r16

// reset counter
ldi r16,0x00
out TCNT1H,r16
out TCNT1L,r16

//check the receiver state in order to know which pulse duration to expecte
lds r16,receiver_state
sbrc r16,7 // ignore any kind of interrupts as long as the message hasn't been consumed
rjmp ic_end
andi r16,0b0011111
cpi r16,0x00 
brne check_rs_2
// the very first pulse has been received
inc r16
sts receiver_state,r16
clc
lds r18,receiver_message + 1
lds r17,receiver_message
rol r17
rol r18
sts receiver_message + 1,r18
sts receiver_message,r17

rjmp ic_end

check_rs_2:
cpi r16,0x10
brne cont_rs_2
rjmp check_rs_3
cont_rs_2:
lds r16,receiver_state
sbrc r16,6 // we received the first short pulse and are expecting a second short pulse
rjmp check_shortpulse
// we are receiving byte so check for 1*pulse_duration and 2*pulse_duration pulses
in r16,ICR1L
in r17,ICR1H
subi r16,low(pulse_duration+pulse_tolerance)
sbci r17,high(pulse_duration+pulse_tolerance)
brmi inputCapture_cont1
rjmp ic_checkdouble
inputCapture_cont1:
in r16,ICR1L
in r17,ICR1H
subi r16,low(pulse_duration-pulse_tolerance)
sbci r17,high(pulse_duration-pulse_tolerance)
brpl ic_setshort
rjmp ic_error // pulse was short than 1 pulse_duration --> certainly an error


check_shortpulse:
// we are receiving byte so check for 1*pulse_duration and 2*pulse_duration pulses
in r16,ICR1L
in r17,ICR1H
subi r16,low(pulse_duration+pulse_tolerance)
sbci r17,high(pulse_duration+pulse_tolerance)
brmi inputCapture_cont3
rjmp ic_error // a long pulse is an error here
inputCapture_cont3:
in r16,ICR1L
in r17,ICR1H
subi r16,low(pulse_duration-pulse_tolerance)
sbci r17,high(pulse_duration-pulse_tolerance)
brpl ic_clearshort
rjmp ic_error // pulse was short than 1 pulse_duration --> certainly an error


ic_setshort:
// we have a short pulse
lds r16,receiver_state
sbr r16,64
rjmp ic_cont_short

ic_clearshort:
lds r16,receiver_state
cbr r16,64
inc r16

ic_cont_short:
sts receiver_state,r16

lds r17,receiver_message // check last bit entered in receiver message, repeat it and add it to the buffer
sbrs r17,0
rjmp sp_set_zero
sec
lds r18,receiver_message + 1
lds r17,receiver_message
rol r17
rol r18
sts receiver_message + 1,r18
sts receiver_message,r17
rjmp ic_end
sp_set_zero:
clc
lds r18,receiver_message + 1
lds r17,receiver_message
rol r17
rol r18
sts receiver_message + 1,r18
sts receiver_message,r17
rjmp ic_end


ic_checkdouble:
in r16,ICR1L
in r17,ICR1H
subi r16,low(2*pulse_duration+pulse_tolerance)
sbci r17,high(2*pulse_duration+pulse_tolerance)
brmi inputCapture_cont4
rjmp ic_error // pulse is way too long --> error
inputCapture_cont4:
in r16,ICR1L
in r17,ICR1H
subi r16,low(2*pulse_duration-pulse_tolerance)
sbci r17,high(2*pulse_duration-pulse_tolerance)
brpl ic_setlong
rjmp ic_error // pulse shorter than 2*pulse_duration --> error


ic_setlong:
lds r16,receiver_state
inc r16
sts receiver_state,r16
lds r17,receiver_message // check last bit entered in receiver message, invert it and add it to the buffer
sbrs r17,0
rjmp lp_set_one
clc
lds r18,receiver_message + 1
lds r17,receiver_message
rol r17
rol r18
sts receiver_message + 1,r18
sts receiver_message,r17
rjmp ic_end
lp_set_one:
sec
lds r18,receiver_message + 1
lds r17,receiver_message
rol r17
rol r18
sts receiver_message + 1,r18
sts receiver_message, r17

rjmp ic_end


// sixteen bits have been received
check_rs_3:
in r16,ICR1L
in r17,ICR1H
subi r16,low(5*pulse_duration+pulse_tolerance)
sbci r17,high(5*pulse_duration+pulse_tolerance)
brmi inputCapture_cont5
rjmp ic_error // pulse is way too long --> error
inputCapture_cont5:
in r16,ICR1L
in r17,ICR1H
subi r16,low(5*pulse_duration-pulse_tolerance)
sbci r17,high(5*pulse_duration-pulse_tolerance)
brpl ic_finalize
rjmp ic_error // pulse shorter than 5*pulse_duration --> error

ic_finalize:
ldi r16,0x80
sts receiver_state,r16
rjmp ic_very_end

ic_error:
ldi r16,0x00 // reset the decoder counter to zero
sts receiver_state,r16
sts receiver_message+1,r16
sts receiver_message,r16



ic_end:
lds r16,receiver_state
andi r16,0b0011111
cpi r16,0x0F
brne invert_edge_trigger
rjmp check_very_last_bit
invert_edge_trigger:
// invert edge trigger slope
in r16,TCCR1B
ldi r17,(1<<ICES1)
eor r16,r17
out TCCR1B,r16
rjmp ic_very_end

check_very_last_bit:
lds r17,receiver_message
sbrs r17,0
rjmp invert_edge_trigger


ic_very_end:
pop r18
pop r17
pop r16
out SREG,r16
pop r16
reti

timer0_ovflow:
reti


timer_stop:
push r16
in r16,SREG
push r16

ldi r16,0x00 // reset the decoder counter to zero
sts decoder_cntr,r16

pop r16
out SREG,r16
pop r16
reti

.dseg
.org SRAM_START
adc_counter:
.byte 1
receiver_state:
.byte 1
receiver_message:
.byte 2
red_val:
.byte 1
green_val:
.byte 1
blue_val:
.byte 1
hsv_angle: // erstes byte: teilwinkel von 0 bis 255, zweites bytes: phase von 0 bis 5
.byte 2
decoder_cntr:
.byte 1