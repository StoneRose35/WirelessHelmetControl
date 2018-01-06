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


// ADC0-2 als Eing�nge
ldi r16,(0<<DDC0)|(0<<DDC1)|(0<<DDC2)
out DDRC,r16

// adc einrichten
// AVCC mit kapazit�t am Aref-Pin, Resultat linksb�ndig
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

lds r16,decoder_cntr
cpi r16,min_pulses
brne led_off
in r16,PORTB
ori r16,0x02
out PORTB,r16

rjmp main
led_off:
in r16,PORTB
andi r16,0xff-0x02
out PORTB,r16

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
in r16,SREG
push r16

in r16,ICR1L
in r17,ICR1H
subi r16,low(pulse_duration+pulse_tolerance)
sbci r17,high(pulse_duration+pulse_tolerance)
brmi inputCapture_cont1
rjmp inputCapture_error
inputCapture_cont1:
in r16,ICR1L
in r17,ICR1H
subi r16,low(pulse_duration-pulse_tolerance)
sbci r17,high(pulse_duration-pulse_tolerance)
brpl inputCapture_cont2
rjmp inputCapture_error
inputCapture_cont2:
// pulse had the correct duration

// invert edge trigger slope
in r16,TCCR1B
ldi r17,(1<<ICES1)
eor r16,r17
out TCCR1B,r16

// reset counter
ldi r16,0x00
out TCNT1H,r16
out TCNT1L,r16

// increase the decoder counter
lds r16,decoder_cntr
cpi r16,min_pulses
breq inputCapture_end
inc r16
sts decoder_cntr,r16
rjmp inputCapture_end

inputCapture_error:
ldi r16,0x00 // reset the decoder counter to zero
sts decoder_cntr,r16



inputCapture_end:
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