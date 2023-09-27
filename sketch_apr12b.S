#define __SFR_OFFSET 0x00
#include "avr/io.h"
.global project
project:
LDI R17,48 ; for ascii r23
;LDI R18,7; for ascii r24
CBI DDRB, 2; D10 INPUT -  incoming IR sensor
CBI DDRB, 3; D11 INPUT - outgoing IR sensor
CBI DDRB, 4; D12 input for dht11
SBI DDRD, 2;D01 OUTPUT - ledg to signal go
SBI DDRD, 3;D02 OUTPUT -ledr to signal stop
SBI DDRD, 4;d03 LEDR TO DETECT INCREASE IN COUNT
clr R20; for counting
sbi PORTD, 2; led will be green signalling that people are free to enter
RCALL delay_2s
;start signal to IR sensor
;low signal followed by a high signal to the digital pins the IR sensors are conected to
cbi PORTB, 2
CBI PORTB, 3
rcall delay_20ms;for start signal
SBI PORTB, 2
SBI PORTB, 3
agn: 
;response signal from IR sensors
w1:
sbis PINB,2
rjmp w1; wait for high pulse on first ir sensor
sbis PINB, 3
rjmp w1; wait for high pulse on second IR sensor
w2:
SBIC PINB,2
rjmp w3; wait for low pulse on first 1r sensor and check sensor 2 in meantime
cpi R20,0x06; check if count is equal to 12 20->12
breq ledr;
rcall comparedht
SBI PORTD,4
RCALL delay_2s
CBI PORTD,4
inc R20; increment R20 for incoming if low pulse detected
RJMP w4; if low pulse detected on sensor1 move towards detecting high pulse again
w3:
sbic PINB,3
RJMP w2; if sensor2 also high jump back to checking low on sesnor 1
dec R20; if sesnsor2 low then decrement the count
; for blinking the red light
SBI PORTD,4
RCALL delay_2s
CBI PORTD,4
RJMP w4
;
w4:
sbis PINB,2
rjmp w4; wait for high pulse on first ir sensor
sbis PINB, 3
rjmp w4; wait for high pulse on second IR sensor
rcall dhtstartresponse
rcall dhtreading
;at this point of time r23 has the 8 bits of temp
mov r19,r23; now r19 has humidity
rcall dhtreading
rcall dhtreading; now r23 has temp
rcall init_serial
rcall temp; print temperature value on serial port
rcall humd; print humidity value on serial port
rcall count; print no of people in the room at the moment
backtoIR:
;RET
rjmp agn1
;for giving stop signal at the threshold of room capacity
ledr:
cbi PORTD,2; turn off green LED
sbi PORTD,3; turn on red LED
rcall init_serial
rcall stopp
RCALL my_delay; after red led lights up
RCALL agn
agn1: ; to check if the count has been decreased from threshold so that the green light can be turned on and red light can be turned off
CPI R20,0x06
breq agn
CBI PORTD,3
SBI PORTD,2
rjmp agn
;dely labels called throughout the program at various points
delay_2s:               
    LDI   R21, 255
l6: LDI   R22, 255
l7: LDI   R23, 124
l8: DEC   R23
    BRNE  l8
    DEC   R22
    BRNE  l7
    DEC   R21
    BRNE  l6
    RET
delay_20ms:             
    LDI   R21, 255
l3: LDI   R22, 210
l4: LDI   R23, 2
l5: DEC   R23
    BRNE  l5
    DEC   R22
    BRNE  l4
    DEC   R21
    BRNE  l3
    RET
my_delay:
LDI R21,255
l0:LDI R22,255
l1:LDI R23,255
l2: dec R23
    brne l2
    dec R22
    brne l1
    dec R21
    brne l0
    RET
dhtstartresponse:
;start signal
 SBI   DDRB, 4       ;pin PB0 as o/p
 CBI   PORTB, 4      ;first, send low pulse
 RCALL delay_20ms    ;for 20ms
 SBI   PORTB, 4
;response signal
CBI DDRB,4
d1: SBIC PINB,4 ; detecting low signal
    RJMP d1
d2: SBIS PINB,4 ; detecting high signal
    RJMP d2
d3: SBIC PINB,4 ; detecting low signal
    RJMP d3
RET
dhtreading:
ldi R22,8; counter for 8 bit reading to be stored in register
clr R23; clearing r23 register
d4: 
SBIS PINB,4 
RJMP d4
Rcall delay_timer0
sbis PINB,4
RJMP skp
SEC; set carry flag if high signal
ROL R23 ; to shift the read bit from lsb towards msb
RJMP d5
skp:LSL R23
d5: 
SBIC PINB,4
RJMP d5
dec R22
CPI R22,0x00
BRNE d4
RET
delay_timer0:             ;50 usec delay via Timer 0

    CLR   R25
    OUT   TCNT0, R25      ;initialize timer0 with count=0
    LDI   R25, 100
    OUT   OCR0A, R25      ;OCR0 = 100
    LDI   R25, 0b00001010
    OUT   TCCR0B, R25     ;timer0: CTC mode, prescaler 8

d6: IN    R25, TIFR0      ;get TIFR0 byte & check
    SBRS  R25, OCF0A      ;if OCF0=1, skip next instruction
    RJMP  d6              ;else, loop back & check OCF0 flag

    CLR   R25
    OUT   TCCR0B, R25     ;stop timer0

    LDI   R25, (1<<OCF0A)
    OUT   TIFR0, R25      ;clear OCF0 flag
    RET
init_serial:
    CLR   R24
    STS   UCSR0A, R24     ;clear UCSR0A register
    STS   UBRR0H, R24     ;clear UBRR0H register
    LDI   R24, 103        ;& store in UBRR0L 103
    STS   UBRR0L, R24     ;to set baud rate 9600
    LDI   R24, 1<<RXEN0 | 1<<TXEN0
    STS   UCSR0B, R24     ;enable RXB & TXB
    LDI   R24, 1<<UCSZ00 | 1<<UCSZ01
    STS   UCSR0C, R24     ;asynch, no parity, 1 stop, 8 bits
    RET
temp:
;ldi r27,0xf0; for upper nibble
;ldi r18,0x0f; for lower nibble
;ldi r18,1
;add r18,r17
;mov r28,r19; for upper nibble
;mov r29,r19; for lower nibble
;and r28,27;for upper nibble
;lsr r28;for upper nibble
;and r29,r18;for lower nibble
;add r29,R17
;mov r21,r28; r21 has upper nibble of hex humidity
;add r28,R17
ldi r29,84
s01: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s01
STS   UDR0, R29
ldi r29,69
s02: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s02
STS   UDR0, R29
ldi r29,77
s03: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s03
STS   UDR0, R29
ldi r29,80
s04: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s04
STS   UDR0, R29
ldi r29,61
s05: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s05
STS   UDR0, R29
ldi r18,8
start:
rol r23
brcc else; label if carry is clear
ldi r27,1
add r27,r17
s1: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s1
STS   UDR0, R27
dec r18
cpi r18,0x00
breq wapas
rjmp start
else:
ldi r27,0
add r27,r17
s2: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s2
STS   UDR0, R27
dec r18
cpi r18,0x00
breq wapas
rjmp start
wapas:
ldi r29,32
s06: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s06
STS   UDR0, R29
ret
humd:
;ldi r27,0xf0; for upper nibble
;ldi r18,0x0f; for lower nibble
;ldi r18,1
;add r18,r17
;mov r28,r19; for upper nibble
;mov r29,r19; for lower nibble
;and r28,27;for upper nibble
;lsr r28;for upper nibble
;and r29,r18;for lower nibble
;add r29,R17
;mov r21,r28; r21 has upper nibble of hex humidity
;add r28,R17
ldi r29,72
s11: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s11
STS   UDR0, R29
ldi r29,85
s12: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s12
STS   UDR0, R29
ldi r29,77
s13: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s13
STS   UDR0, R29
ldi r29,68
s14: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s14
STS   UDR0, R29
ldi r29,61
s15: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s15
STS   UDR0, R29
ldi r18,8
start2:
rol r19
brcc else2; label if carry is clear
ldi r27,1
add r27,r17
s3: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s3
STS   UDR0, R27
dec r18
cpi r18,0x00
breq wapas2
rjmp start2
else2:
ldi r27,0
add r27,r17
s4: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s4
STS   UDR0, R27
dec r18
cpi r18,0x00
breq wapas2
rjmp start2
wapas2:
ldi r29,10
ldi r29,32
s16: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s16
STS   UDR0, R29
ret
count:
ldi r29,67
;add r27,r17
s21: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s21
STS   UDR0, R29
ldi r29,79
;add r27,r17
s22: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s22
STS   UDR0, R29
ldi r29,85
;add r27,r17
s23: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s23
STS   UDR0, R29
ldi r29,78
;add r27,r17
s24: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s24
STS   UDR0, R29
ldi r29,84
;add r27,r17
s25: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s25
STS   UDR0, R29
ldi r29,61
s26: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s26
STS   UDR0, R29
mov r29,r20
add r29,r17
s27: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s27
STS   UDR0, R29
ldi r29,10
s28: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  s28
STS   UDR0, R29
ret
stopp:
ldi r29,83
;add r27,r17
st21: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  st21
STS   UDR0, R29
ldi r29,84
;add r27,r17
st22: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  st22
STS   UDR0, R29
ldi r29,79
;add r27,r17
st23: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  st23
STS   UDR0, R29
ldi r29,80
;add r27,r17
st24: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  st24
STS   UDR0, R29
ldi r29,10
st28: LDS   R26, UCSR0A
    SBRS  R26, UDRE0      ;test data buffer if data can be sent
    RJMP  st28
STS   UDR0, R29
ret
comparedht:
rcall dhtstartresponse
rcall dhtreading
;at this point of time r23 has the 8 bits of temp
mov r19,r23; now r19 has humidity
rcall dhtreading
rcall dhtreading; now r23 has temp
rcall init_serial
clc
;cpi r23, 0b00011110; to show sir
cpi r23,0b00011010; anything above 35 is uncomfortable
breq cmp1
;brcc
;rcall ledr
;cpi r19, 0b00011111; to show sir
cpi r19, 0b00111100; till 60% people find comfortable
breq cmp1
;rcall ledr
ret
cmp1:
rcall ledr ; give stop signal and start detecting response signal rom ir sensors again
