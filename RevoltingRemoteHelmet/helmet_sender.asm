/*
 * helmet_sender.asm
 *
 *  Created: 19.12.2017 20:58:04
 *   Author: fuerh_000
 */ 

  #include <m8def.inc>
  #include "GeneralSettings.inc"

  /*
    code für den sender, ein Schalter ist an PC0 angehängt, dieser schaltet den Helm ein- und aus
    das kontrollicht and pc1

	der Sender schickt ein Manchester-encodiertes Signal welchem 4 1-0 durchgänge vorangestellt sind, danach kommt ein byte Information, danach wird nochmals ein 
	 "1" von mindestens 4 durchgängen länge gesendet
  */

 .equ channel_nr = 0x12
 .equ secretnumber_1 = 0x42
 .equ secretnumber_2 = 0x32
 .org 0x000
rjmp reset


.org OC1Aaddr
rjmp oscillator_handler

.org OVF0addr
rjmp debounce_stop

.org 0x013
reset:
ldi r16, high(RAMEND)
out SPH,r16
ldi r16, low(RAMEND)
out SPL,r16




//port c konfigurieren
// PC0: LED (output)
// PC1: schalter (input)
// PC2: digitaler ausgang
ldi r16, (1<<DDC0)|(0<<DDC1)|(1<<DDC2)
out DDRC,r16
ldi r16,(1<<PORTC1)
out PORTC,r16


// pd0-2 as input with pull up enabled
ldi r16,0x07
out PORTD,r16

//portb konfigurieren: portb1 ist ausgang
ldi r16,(1<<DDB1)
out DDRB,r16

// setup counter 1 as CTC (clear timer on compare)
// enable interrupt on output compare 1 A and Overflow on Counter 0
ldi r16,(1<<COM1A0)
out TCCR1A,r16
ldi r16,(1<<OCIE1A)
OUT TIMSK,r16
ldi r16,(1<<WGM12) // CTC mode
out TCCR1B,r16

ldi r16,0x02
sts button_state,r16

ldi r16,0x00
sts sender_state,r16

sei


main:

// send "white" (all leds on), four times
ldi r16,0x07
ldi r17,0x03
rcall send_one_command
// wait
rcall longwait


// send "black" (all leds off), four times
ldi r16,0x00
ldi r17,0x03
rcall send_one_command
// wait
rcall longwait



rjmp main


; sends a command repeatedly, r16 holds the command, r17 the number of repetitions (1-8)
; does not return until all repetitions have been sent
send_repeated_command:

push r18
lds r18,sender_cmd_state
sbrc r18,7
rjmp send_repeated_cmd_end
andi r17,0x07
sts sender_cmd_state,r17


send_repeated_cmd_loop:
rcall send_one_command
send_repeated_cmd_wait1:
lds r17,sender_state
cpi r17,0x00
brne send_repeated_cmd_wait1

// one command has been sent, increased counter and check if enough repetitions have been made
lds r17,sender_cmd_state
sbr r17,128
ldi r18,0x10
add r17,r18
sts sender_cmd_state,r17
lds r18,sender_cmd_state
swap r18
andi r17,0x70 // the increased counter
andi r18,0x70 // the maximum number of repetitions
sub r18,r17 // max-current
brmi send_repeated_cmd_end1

// wait loop between the repetitions
ldi r17,0x00
send_repeated_cmd_wait2:
inc r17
nop
nop
nop
brne send_repeated_cmd_wait2
rjmp send_repeated_cmd_loop

send_repeated_cmd_end1:
lds r18,sender_cmd_state
cbr r18,128
sts sender_cmd_state,r18

send_repeated_cmd_end:
pop r18
ret


send_one_command:
push r17
; sends the command, the command byte is in r16
ldi r17,0b01010101
lsl r16
rol r17
sts message_word+1,r17
sts message_word,r16
ldi r17,0x01
sts sender_state,r17

ldi r17,high(pulse_duration)
ldi r16,low(pulse_duration)
out OCR1AH,r17
out OCR1AL,r16

in r16,TCCR1B
ori r16,(1<<CS10) // start clock, output should be zero, wait for 1 pulse_duration
out TCCR1B,r16


pop r17
ret






oscillator_handler:
push r16
push r17
push r18
push r19
in r16,SREG
push r16

; manually resetting the timer, the behaviour explained
; in the datasheet occurred only in simulation
; in real live timer overflows have been observed
ldi r17,0x00
ldi r16,0x15
out TCNT1H,r17
out TCNT1L,r16



//simulate output of OCR1 by toggling PC2
in r16,PORTC
ldi r17,0x04
eor r16,r17
out PORTC,r16



// first call of the interrupt handler after transmission has started

lds r16,sender_state
andi r16,0b00111111
cpi r16,0x01
brne oh_check_sender_state
// "bits sent" counter is one
inc r16
lds r18,message_word+1
lds r17,message_word
lsl r17
rol r18
brcc clearlastbit// last bit is a "0"
sbr r16,128 // set the last bit, last bit sent was a "1" 
rjmp oh_cont1
clearlastbit:
cbr r16,128
oh_cont1:
sts message_word+1,r18
sts message_word,r17
sts sender_state,r16
ldi r17,high(2*pulse_duration)
ldi r16,low(2*pulse_duration)
out OCR1AH,r17
out OCR1AL,r16


rjmp oh_end

//message transmitted, transmit the end part consisting of 5 times pulse_duration of "1" or 1 pulse duration of zero followed by 4 pulse durations of 1
oh_check_sender_state:
cpi r16,0x0F // 16 bits transmitted, send a "1" that lasts 4 pulse_duration's
brne oh_check_sender_state2
lds r16,sender_state
sbrc r16,6
rjmp onepulse2 // finish second half "same-bit" pulse
in r16,PORTC
sbrs r16,2
rjmp end_with_one // send one clock cycle with 0 level and 4 clock cycles with 1 level

lds r16,sender_state
inc r16
sts sender_state,r16

ldi r17,high(5*pulse_duration)
ldi r16,low(5*pulse_duration)
out OCR1AH,r17
out OCR1AL,r16
rjmp oh_end

end_with_one:


lds r16,sender_state
inc r16
sts sender_state,r16

ldi r17,high(pulse_duration)
ldi r16,low(pulse_duration)
out OCR1AH,r17
out OCR1AL,r16
rjmp oh_end



//at the very end: switch everything off when 5 pulse durations of one were transmitted or send out another pulse of 4 pulse durations

oh_check_sender_state2:
cpi r16,0x10 // six bit set, long pulse ends
brne oh_check_sender_state3
lds r16,sender_state
sbrc r16,7
rjmp end_with_one2

// switch off clock
andi r17,0xFF-0x07
out TCCR1B,r17
ldi r16,0x00
sts sender_state,r16


// reset counter
out TCNT1H,r16
out TCNT1L,r16
rjmp oh_end

end_with_one2:
cbr r16,128 // clear the bit declaring 1 was the last bit sent making it jump into the "very end" part on next interrupt
sts sender_state,r16
ldi r17,high(4*pulse_duration)
ldi r16,low(4*pulse_duration)
out OCR1AH,r17
out OCR1AL,r16


rjmp oh_end

 
//in the middle of transmission, first bit already transmitted

oh_check_sender_state3:
lds r16,sender_state
sbrc r16,6 // bit 6 indicates that only one pulse of length pulse_duration has been sent, automatically send the second one
rjmp onepulse2
inc r16
mov r19,r16 // copy r16 to r19
lds r18,message_word+1
lds r17,message_word
lsl r17
rol r18
brcc clearlastbit2// last bit is a "0"
sbr r16,128 // set the last bit, last bit sent was a "1" 
rjmp oh_cont2
clearlastbit2:
cbr r16,128
oh_cont2:
sts message_word+1,r18
sts message_word,r17
sts sender_state,r16
// check if last bit sent and current bit is different
andi r16,0x80
andi r19,0x80
eor r16,r19
cpi r16,0x00
breq onepulse1 // bits are equal, send a pulse of only half duration

// send a double pulse
ldi r17,high(2*pulse_duration)
ldi r16,low(2*pulse_duration)
out OCR1AH,r17
out OCR1AL,r16
rjmp oh_end



onepulse1:
lds r16,sender_state
sbr r16,64
sts sender_state,r16
ldi r17,high(pulse_duration)
ldi r16,low(pulse_duration)
out OCR1AH,r17
out OCR1AL,r16
rjmp oh_end

onepulse2:
cbr r16,64
sts sender_state,r16
ldi r17,high(pulse_duration)
ldi r16,low(pulse_duration)
out OCR1AH,r17
out OCR1AL,r16


oh_end:
pop r16
out SREG,r16
pop r19
pop r18
pop r17
pop r16
reti

debounce_stop:
push r16 
in r16,SREG
push r16

ldi r16,0x00
out TCCR0,r16
out TCNT0,r16

pop r16
out SREG,r16
pop r16
reti


// waits for about a quarter of a second
longwait:
push r16
push r17
push r18
push r19
ldi r18,0x00

ldi r18,0x00
start_clock:
ldi r16,0x00
out TCNT0,r16
ldi r16,(1<<CS02)|(0<<CS01)|(1<<CS00)
out TCCR0,r16
wait_oflow:
in r17,TIFR
sbrs r17,TOV0
rjmp wait_oflow
out TIFR,r17
inc r18
cpi r18,0x0F
brne start_clock
ldi r16,0x00
out TCCR0,r16

pop r19
pop r18
pop r17
pop r16
ret


.dseg
.org SRAM_START
sender_state: // is zero when the sender is not sending, greater zero otherwise
.byte 1
button_state:
.byte 1
message_word: // the message word itself, the first byte always needs to be 0b01010101 (synchronzation byte)
.byte 2
sender_cmd_state: //lower 3 bits: number of times a command should be sent repeatedly, an reserved bit, next 3 byte the number of times a command is sent, uppermost
//bit 1 if the sender is sending, 0 otherwise 
.byte 1