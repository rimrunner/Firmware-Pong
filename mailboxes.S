

	.equ	MBOX_REQUEST, 0

	//channels 
	.equ	MBOX_CH_POWER, 0
	.equ	MBOX_CH_FB, 1
	.equ	MBOX_CH_VUART, 2
	.equ	MBOX_CH_VCHIQ, 3
	.equ	MBOX_CH_LEDS, 4
	.equ	MBOX_CH_BTNS, 5
	.equ	MBOX_CH_TOUCH, 6
	.equ	MBOX_CH_COUNT, 7
	.equ	MBOX_CH_PROP, 8

	//tags
	.equ	MBOX_TAG_GETSERIAL, 0x10004
	.equ	MBOX_TAG_LAST, 0

	.equ VIDEOCORE_MBOX, 0x3F00B880
	
	.equ MBOX_READ, VIDEOCORE_MBOX+0x0
	.equ MBOX_POLL, VIDEOCORE_MBOX+0x10
	.equ MBOX_SENDER, VIDEOCORE_MBOX+0x14
	.equ MBOX_STATUS, VIDEOCORE_MBOX+0x18
	.equ MBOX_CONFIG, VIDEOCORE_MBOX+0x1C
	.equ MBOX_WRITE, VIDEOCORE_MBOX+0x20
	
	.equ MBOX_RESPONSE, 0x80000000
	.equ MBOX_FULL, 0x80000000
	.equ MBOX_EMPTY, 0x40000000


	.bss
	.global mbox
	.align 16
mbox:         .space              144

	.text
	.global mbox_call
mbox_call:
	and	w11, w0, 0xF
	adrp	x8, mbox
	add     x8, x8, :lo12:mbox
	and 	x8, x8, 0xFFFFFFF0
	orr	x8, x8, x11
	
m_loop:
	nop
	ldr	x2, =MBOX_STATUS
	ldr	w9, [x2]
	and	w9, w9, MBOX_FULL
	cbnz	w9, m_loop
	ldr x3, =MBOX_WRITE
	str w8, [x3]

r_loop:
	nop
	ldr	w4, [x2]
	and	w4, w4, MBOX_EMPTY
	cbnz	w4, r_loop

	ldr	x5, =MBOX_READ
	ldr	w11, [x5]
	cmp	w8, w11
	beq	r_exit
	bl	r_loop
r_exit:
	adrp	x8, mbox+4
	add     x8, x8, :lo12:mbox+4
	ldr	w6, [x8]
	ldr     w7, =MBOX_RESPONSE
checkmbox:
	cmp	w6, w7
	cset	x0, eq
	ret
