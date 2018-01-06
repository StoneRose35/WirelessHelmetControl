/*
 * NotUsedCode.inc
 *
 *  Created: 30.12.2017 15:49:17
 *   Author: fuerh_000
 */ 

  #include <m8def.inc>

// zaehler 1 einrichten

// FAST PWM, non-inverting mode
ldi r16,(1<<COM1A1)|(1<<COM1B1)|(0<<COM1A0)|(0<<COM1B0)|(0<<WGM11)|(1<<WGM10)
out TCCR1A,r16
// no prescaling
ldi r16,(0<<WGM13)|(1<<WGM12)|(0<<CS12)|(1<<CS11)|(1<<CS10)
out TCCR1B,r16





// zaehler 0 einrichten
// fast pwm, non-inverting mode, no prescaling
ldi r16,(1<<WGM21)|(1<<WGM20)|(1<<COM21)|(0<<COM20)|(0<<CS22)|(1<<CS21)|(1<<CS20)
out TCCR2,r16

// wert für zaehler 0
ldi r16,0x80
out OCR2,r16

// ORC1A,OCR1B und OCR0 auf Ausgang stellen
ldi r16,(1<<DDB1)|(1<<DDB2)|(1<<DDB3)
out DDRB,r16


/*
lds r16,adc_counter
inc r16
sts adc_counter,r16
andi r16,0x0F
ori r16,(1<<REFS0)|(1<<ADLAR)
out ADMUX,r16

 // start a adc conversion
 in r18,ADCSRA
 ori r18,(1<<ADSC)
 out ADCSRA,r18

 // wait until result is there
 waitForAdc:
 in r18,ADCSRA
 sbrs r18,ADIF
 rjmp waitForAdc

 // result is in r16
 in r16,ADCH
 lds r17,adc_counter
 andi r17,0x03
 ldi r18,0x00
 // wenn adc_counter gleich 0 ist
 cpi r17,0x00
 brne adc_counter_1

 // wert an OCR1A
 in r19,SREG
 cli
 out OCR1AH,r18
 out OCR1AL,r16
 out SREG,r19
 sei

 rjmp adc_read_end

 adc_counter_1:
 cpi r17,0x01
 brne adc_counter_2

  // wert an OCR1B
 in r19,SREG
 cli
 out OCR1BH,r18
 out OCR1BL,r16
 out SREG,r19
 sei
 rjmp adc_read_end

 adc_counter_2:
 cpi r17,0x02
 brne errorcase

 // wert an OCR2
 out OCR2,r16
 rjmp adc_read_end

errorcase:

adc_read_end:
*/
//rcall inc_hsv_circle

/*
lds r16,red_val
in r19,SREG
cli
out OCR1AH,r18 
out OCR1AL,r16
out SREG,r19
sei


lds r16,blue_val
in r19,SREG
cli
out OCR1BH,r18 
out OCR1BL,r16
out SREG,r19
sei

lds r16,green_val
out OCR2,r16
*/

inc_hsv_circle:
push r16
push r17
push r18
push r19

lds r17,hsv_angle // winkel
lds r16,hsv_angle+1 // phase
cpi r16,0x00
brne inc_hsv_circle_cp1
//
// PHASE 1
//
ldi r18,0xFF
sts red_val,r18
sts green_val,r17
ldi r18,0x00
sts blue_val,r18
rjmp inc_hsv_circle_inc

inc_hsv_circle_cp1:
cpi r16,0x01
brne inc_hsv_circle_cp2
//
// PHASE 2
//
ldi r18,0xFF
eor r18,r17
sts red_val,r18
ldi r18,0xFF
sts green_val,r18
ldi r18,0x00
sts blue_val,r18
rjmp inc_hsv_circle_inc

inc_hsv_circle_cp2:
cpi r16,0x02
brne inc_hsv_circle_cp3
//
// PHASE 3
//
ldi r18,0x00
sts red_val,r18
ldi r18,0xFF
sts green_val,r18
sts blue_val,r17
rjmp inc_hsv_circle_inc

inc_hsv_circle_cp3:
cpi r16,0x03
brne inc_hsv_circle_cp4
//
// PHASE 4
//
ldi r18,0x00
sts red_val,r18
ldi r18,0xFF
eor r18,r17
sts green_val,r18
ldi r18,0xFF
sts blue_val,r18
rjmp inc_hsv_circle_inc

inc_hsv_circle_cp4:
cpi r16,0x04
brne inc_hsv_circle_cp5
//
// PHASE 5
//
sts red_val,r17
ldi r18,0x00
sts green_val,r18
ldi r18,0xFF
sts blue_val,r18
rjmp inc_hsv_circle_inc

inc_hsv_circle_cp5:
cpi r16,0x05
brne inc_hsv_circle_end
//
// PHASE 6
//
ldi r18,0xFF
sts red_val,r18
ldi r18,0x00
sts green_val,r18
ldi r18,0xFF
eor r18,r17
sts blue_val,r18



inc_hsv_circle_inc:
// increase the angle
inc r17
breq inc_hsv_circle_incphase
rjmp inc_hsv_circle_inc_end
inc_hsv_circle_incphase:
// increase phase if angle has overflown
inc r16
cpi r16,0x06
brne inc_hsv_circle_inc_end
ldi r16,0x00 
inc_hsv_circle_inc_end:
sts hsv_angle,r17
sts hsv_angle+1,r16

inc_hsv_circle_end:
pop r19
pop r18
pop r17
pop r16
ret



// seriellen port aktivieren
// baud rate ist 19230 bei 4MHz Prozessortakt
ldi r16,0x00
ldi r17,0x0C

out UBRRH,r16
out UBRRL,r17

; enable receiver and interrupt
ldi r16, (1<<RXEN)|(1<<RXCIE)
out UCSRB,r16
; Set frame format: 8data, 1stop bit
ldi r16, (1<<URSEL)|(0<<USBS)|(3<<UCSZ0)
out UCSRC,r16


// interrupt handler if serial data has been received
// format of an entire message is:
// two secret bytes, followed by a channel number and a byte
// each for the red, green and blue value
// resulting in 6 bytes for an entire message
serialReceiverIH:

push r16
push r17
push r18 
push r19
in r16,SREG
push r16

// data is in register 16
in r16,UDR
lds r17,receiver_state
cpi r17,0x00
brne serialReceiverIH_checkstep2

//STEP 1
cpi r16,secretnumber_1
brne serialReceiverIH_step1_nok
inc r17
sts receiver_state,r17
rjmp serialReceiverIH_end
serialReceiverIH_step1_nok:
ldi r16,0x00
sts receiver_state,r16
rjmp serialReceiverIH_end

serialReceiverIH_checkstep2:
cpi r17,0x01
brne serialReceiverIH_checkstep3

// STEP 2
cpi r16,secretnumber_2
brne serialReceiverIH_step2_nok
inc r17
sts receiver_state,r17
rjmp serialReceiverIH_end
serialReceiverIH_step2_nok:
ldi r16,0x00
sts receiver_state,r16
rjmp serialReceiverIH_end

serialReceiverIH_checkstep3:
cpi r17,0x02
brne serialReceiverIH_checkstep4

// STEP 3
cpi r16,channel_nr
brne serialReceiverIH_step3_wrongchannel
inc r17
sts receiver_state,r17
rjmp serialReceiverIH_end
serialReceiverIH_step3_wrongchannel:
ldi r16,0x00
sts receiver_state,r16
rjmp serialReceiverIH_end

serialReceiverIH_checkstep4:
cpi r17,0x03
brne serialReceiverIH_checkstep5

// STEP 4
inc r17
sts receiver_state,r17
// set the red value
out OCR1AH,r19
out OCR1AL,r16
rjmp serialReceiverIH_end

serialReceiverIH_checkstep5:
cpi r17,0x04
brne serialReceiverIH_checkstep6

// STEP 5
inc r17
sts receiver_state,r17
// set the green value
out OCR1BH,r19
out OCR1BL,r16
rjmp serialReceiverIH_end

serialReceiverIH_checkstep6:
cpi r17,0x05
brne serialReceiverIH_end

// STEP 6
ldi r17,0x00
sts receiver_state,r17
// set the red value
out OCR2,r16
rjmp serialReceiverIH_end

serialReceiverIH_end:
pop r16
out SREG,r16
pop r19
pop r18
pop r17
pop r16

reti


send_command:
push r16
//push r17
//push r18
//push r19

send_cmd_wait0:
sbis UCSRA,UDRE
rjmp send_cmd_wait0

// sende erster Teil secret number
ldi r16,secretnumber_1
out UDR,r16
send_cmd_wait1:
sbis UCSRA,UDRE
rjmp send_cmd_wait1

// sende zweiter teil secret number
ldi r16,secretnumber_2
out UDR,r16
send_cmd_wait2:
sbis UCSRA,UDRE
rjmp send_cmd_wait2

// sende kanalnummer
ldi r16,channel_nr
out UDR,r16
send_cmd_wait3:
sbis UCSRA,UDRE
rjmp send_cmd_wait3

// sende rotwert
lds r16,red_val
out UDR,r16
send_cmd_wait4:
sbis UCSRA,UDRE
rjmp send_cmd_wait4

// sende grünwert
lds r16,green_val
out UDR,r16
send_cmd_wait5:
sbis UCSRA,UDRE
rjmp send_cmd_wait5

// sende blauwert
lds r16,blue_val
out UDR,r16
send_cmd_wait6:
sbis UCSRA,UDRE
rjmp send_cmd_wait6

//pop r19
//pop r18
//pop r17
pop r16
ret