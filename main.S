	
.data 
.bss
ballx:		.space	8  //8 = the size of double precision float
bally:		.space 	8
batpos:		.space	64  //long uint
direction:	.space  1  //values: 1-4, (1 = 315°-44°, 2 = 45°-135°, 3 = 136°-225°, 4 = 226°-314°)
dirsign:	.space  1  //values: 0, 1. Splits every main direction in two 45° areas
angle:		.space  8  //values: 0.0 - 0.99
velocity:	.space  8
waitcounter:	.space  16

	.global mask
mask:	.space	1

	.global bm
bm:	.space	98304  //1024*768/8

	.text
	.global main
main:
	bl	lfb_init
new_game:	
	adr	x1, ballx
	ldr	d2, =0x4076800000000000 //360.0
	str	d2, [x1]
	adr	x1, bally
	str	d2, [x1]

	adr	x1, direction
	mov	w2, #4
	str	w2, [x1]

	adr	x1, angle //0.0-0.99
	ldr	d2, =0x3FC999999999999A //0.2
	str	d2, [x1]

	adr	x1, dirsign //0 indicates plus, 1 indicates minus
	mov	w2, #1
	strb	w2, [x1]
	
	adr	x1, velocity
	fmov	d2, #2.0
	str	d2, [x1]

	adr	x1, batpos
	movz  	x15, 0xA00E
	str	x15, [x1]

	adr	x1, waitcounter
	mov	w15, #100
	strh	w15, [x1]

mainloop:

	mrs	x29, cntpct_el0
	bl	clear_bm

	//If velocity == 0, skip ball related subroutines
	adr	x20, velocity
	ldr	d7, [x20]   	//For zero-check double can be loaded to a general register
	fcvtnu	w7, d7
	cbnz	w7, ballroutines
	adr	x20, waitcounter
	ldrh	w19, [x20]
	sub	w19, w19, #1
	cbz	w19, new_game
	strh	w19, [x20]
	b	contmain
ballroutines:	
	bl	update_dir
	bl	coll_detc
	bl	drawball
contmain:	
	bl	drawbat
	bl	drawscreen
fps:	
	//FPS
	mrs	x28, CNTPCT_EL0
	sub	x1, x28, x29
	movz	x2, 0x0111
	subs	x1, x2, x1
	bmi	mainloop

	add	x1, x1, x28
	msr	cntp_cval_el0, x1
	wfi
	ret
	
	b	mainloop

coll_detc:

	adr	x27, ballx
	ldr	d5, [x27]
	adr	x26, bally
	ldr	d6, [x26]

	fcvtnu	w6, d6
	fcvtnu	w5, d5

	mov	w7, #52
	cmp	w6, w7
	bls	upwall

	mov	w7, #716
	cmp	w6, w7
	bge	downwall

	mov	w7, #17
	cmp	w5, w7
	bls	ballout
	
	mov	w7, #126
	cmp	w5, w7
	bls	leftside
	
	mov	w7, #912
	cmp	w5, w7
	bge	backwall
	
	ret

ballout:
	adr	x26, velocity
	movi	d7, #0
	str	d7, [x26]
	ret
	
leftside:
	//If bat's vertical line has been already crossed, bathits must not be registered
	adr	x1, velocity
	ldr	d2, [x1]
	fcvtnu	w2, d2
	sub	w7, w7, w2
	cmp	w7, w5
	blt	leftside1
	ret
	
	//If not, do ball & bat collide?
leftside1:
	adr	x27, batpos
	ldr	x10, [x27]
	mov	x15, #128
	udiv	x10, x10, x15	//Bat's y-position (bitmap's row)
	//If (ball's y position + ball's height) is greater than bat's y-position, it's a hit.
	//If ball's height was not taken into account, the uppest hits will not be registered
	add	w7, w6, #16
	cmp	w7, w10
	bgt	leftside2
	ret
leftside2:
	add	w7, w10, #62  //Bat's lowest point (bat's y position plus bat's height, 62)
	cmp	w6, w7
	blt	leftside3  //Collision occurs if ball's y position is smaller than bat's lowest point
	ret
leftside3:
	//Hitting the bat
	adr	x15, direction
	ldrb	w14, [x15]

	//Changing the angle according to which part of the bat is collided
	//Upper & lower sixths add 0.2 to angle, areas 2/6 & 5/6 add 0.1 to angle, middle area decreases 0.1 from the angle
	//w6 = bally, w10 = batpos
	adr	x4, angle
	ldr	d19, [x4]
	mov	w17, #0

	add	w11, w10, #10
	cmp	w6, w11
	bgt	leftside3a
	mov	w17, #3
	b	leftside4
leftside3a:	
	add	w11, w10, #21
	cmp	w6, w11
	bgt	leftside3b
	mov	w17, #2
	b	leftside4
leftside3b:	
	add	w11, w10, #41
	cmp	w6, w11
	bgt	leftside3c
	mov	w17, #1
	b	leftside4
leftside3c:	
	add	w11, w10, #52
	cmp	w6, w11
	bgt	leftside3d
	mov	w17, #2
	b 	leftside4
leftside3d:	
	mov	w17, #3
leftside4:
	cmp	w14, #1
	beq	fromdir1
	cmp	w14, #3
	beq	fromdir3
	adr	x8, dirsign
	ldrb	w9, [x8]

	cmp	w17, #3
	bne	fromdir4a
	ldr	d18, =0x3FD999999999999A //0.4
	fadd	d19, d19, d18
	b	fromdir4c
fromdir4a:
	ldr	d18, =0x3FB999999999999A  //0.1
	cmp	w17, #2
	bne 	fromdir4b
	fadd	d19, d19, d18 	//smallplus
	b	fromdir4c
fromdir4b:
	fsub	d19, d19, d18	//minus
fromdir4c:
	//Floor 0.4 for the angle
	ldr	d18, =0x3FD999999999999A //0.4
	fcmp	d19, d18
	bgt	fromdir4d
	fmov	d19, d18
	b	fromdir4e
fromdir4d:
	ldr	d18, =0x3FEFAE147AE147AE //0.99
	fcmp	d19, d18
	bgt	fromdir4f
fromdir4e:
	//Without adjusting angle, the new direction is -2
	mov	w14, #2
	eor	w9, w9, #1
	strb	w9, [x8]
	b	fromdir4h
fromdir4f:	//adjust
	fmov	d18, #2.0
	fsub	d19, d18, d19

	cbnz	w9, fromdir4g
	mov	w14, #1
	b	fromdir4h
fromdir4g:	
	eor	w9, w9, #1
	strb	w9, [x8]
	mov	w14, #3
	
fromdir4h:	
	strb	w14, [x15]	//storing the direction
	str	d19, [x4]  	//storing the angle
	ret

fromdir1:	
	//if direction == 1
	adr	x8, dirsign
	ldrb	w9, [x8]
	eor	w9, w9, #1
	strb	w9, [x8]

	//Hitting bat's border (values 2, 3) angle decreases, otherwise largens
	cmp	w17, #3 //w17 = hit position
	bne	fromdir1b
	ldr	d18, =0x3FC999999999999A
	fsub	d19, d19, d18
	b	fromdir1d

fromdir1b:
	cmp	w17, #2
	bne	fromdir1c
	ldr	d18, =0x3FB999999999999A //0.1 smallplus
	fsub	d19, d19, d18
	b	fromdir1d
fromdir1c: //minus
	fadd	d19, d19, d18
fromdir1d:
	ldr	d18, =0x3FD999999999999A //0.4
	fcmp	d19, d18
	bgt	fromdir1e
	fmov	d19, d18
fromdir1e:
	ldr	d18, =0x3FEFAE147AE147AE //0.99
	fcmp	d19, d18
	bgt	fromdir1f
	b	fromdir1g
fromdir1f:
	mov	w14, #2
	fmov	d18, 2.0
	fsub	d19, d18, d19
fromdir1g:	
	strb	w14, [x15] //storing the direction
	str	d19, [x4]  //storing the angle
	ret
	
fromdir3:

	//direction 3
	adr	x8, dirsign
	ldrb	w9, [x8]
	eor	w9, w9, #1
	strb	w9, [x8]

	//Hitting bat's border (values 2, 3) angle decreases, otherwise largens
	cmp	w17, #3 //w17 = hit position
	bne	fromdir3b
	ldr	d18, =0x3FC999999999999A //0.2
	fsub	d19, d19, d18
	b	fromdir3d
fromdir3b:
	cmp	w17, #2
	bne	fromdir3c
	ldr	d18, =0x3FB999999999999A //0.1 smallplus
	fsub	d19, d19, d18
	b	fromdir3d
fromdir3c: //minus
	fadd	d19, d19, d18
fromdir3d:
	ldr	d18, =0x3FD999999999999A //0.4
	fcmp	d19, d18
	bgt	fromdir3e
	fmov	d19, d18
fromdir3e:
	ldr	d18, =0x3FEFAE147AE147AE //0.99
	fcmp	d19, d18
	bgt	fromdir3f
	mov	w14, #3
	b	fromdir3g
fromdir3f:
	mov	w14, #2
	fmov	d18, 2.0
	fsub	d19, d18, d19
fromdir3g:	
	strb	w14, [x15] //storing the direction
	str	d19, [x4]  //storing the angle
	ret

backwall:	
	adr	x8, dirsign
	ldrb	w9, [x8]
	eor	w9, w9, #1
	strb	w9, [x8]
	
	adr	x5, direction
	ldrb	w6, [x5]
	mov	w7, #2
	cmp	w7, w6
	beq	back2
	ret
back2:
	mov	w6, #4
	strb	w6, [x5]
	ret
	
upwall:
	adr	x9, direction
	ldrb	w10, [x9]

	//Is the ball inside the cage
	add	w8, w5, #16 	//w5 = ballx, 16 = ball's width
	cmp	w8, #128
	bgt	upwall_b
	//Is the ball inside the screen
	cbz	w6, ballout	//w6 = bally
	ret
upwall_b:
	mov	w7, #1
	cmp	w7, w10
	beq	upwall2

	adr	x8, dirsign
	ldrb	w10, [x8]
	eor	w10, w10, #1
	strb	w10, [x8]
	ret
upwall2:	
	mov	w10, #3
	strb	w10, [x9]
	ret

downwall:
	adr	x11, direction
	ldrb	w10, [x11]

	//Is the ball inside the cage
	add	w8, w5, #16 	//w5 = ballx, 16 = ball's width
	cmp	w8, #128
	bgt	downwall_b
	//Is the ball inside the screen
	cmp	w6, #767
	bgt	ballout
	ret
downwall_b:

	mov	w7, #3
	cmp	w7, w10
	beq	downwall2

	adr	x8, dirsign
	ldrb	w10, [x8]
	eor	w10, w10, #1
	strb	w10, [x8]
	ret
downwall2:	
	mov	w10, #1
	strb	w10, [x11] //jos dir1 -> dir3
	ret

update_dir:
	adr	x27, ballx
	ldr	d5, [x27]
	adr	x26, bally
	ldr	d6, [x26]
	adr	x4, direction
	ldrb	w7, [x4]
	adr	x4, velocity
	ldr	d8, [x4]
	adr	x4, angle
	ldr	d11, [x4]

	//If dirsign == 1, angle is negative
	adr	x4, dirsign
	ldrb	w25, [x4]
	cbz	w25, dirplus
	fmov	d24, #-1.0

	fmul	d11, d11, d24
dirplus:	
	fmul	d15, d11, d8

	fmov	d20, #1.0
	fcmp	d8, d20
	ble	vel1
	fmul	d11, d11, d8
	
vel1:	

	mov	w9, #1		//Which main direction?
	cmp	w7, w9
	bne	dir2
	fsub	d6, d6, d8	//Moving towards the main direction (when going upwards: ball's y position - velocity)
	fadd	d5, d5, d15	//Moving towards the secondary direction
	b	dirend
dir2:
	mov	w9, #2
	cmp	w7, w9
	bne	dir3
	fadd	d5, d5, d8
	fadd	d6, d6, d15
	b	dirend
dir3:
	mov	w9, #3
	cmp	w7, w9
	bne	dir4
	fadd	d6, d6, d8
	fadd	d5, d5, d15
	b	dirend
dir4:
	fsub	d5, d5, d8
	fsub	d6, d6, d15
dirend:	
	//Storing ballx & bally
	str	d5, [x27]
	str	d6, [x26]
	ret

clear_bm:
	mov	x0, #0
	mov	x8, #768
	adrp	x1, bm
	add	x1, x1, :lo12:bm

	movi 	v20.2d, 0
	movi 	v21.2d, 0
	movi 	v22.2d, 0
	movi 	v23.2d, 0

	movi	v17.2d, 0
	movi	v18.2d, 0
	movi	v19.8h, #0xff

	movi	v24.2d, 0
	movi	v25.2d, -1
	movi	v26.2d, -1
	movi	v27.2d, -1
	movi	v28.2d, 0

	mov	x15, 0
	mov	x16, -1
	mov	x17, 0xffffffff00000000

y_loop_beg:
	add	x0, x0, #1
	cmp	x8, x0
	bne	y_loop_cont
	ret

y_loop_cont:	
	mov	x3, #26
	cmp	x0, x3
 	blt	empty_row

	mov	x5, #53
	cmp	x0, x5
	blt	horwall

	mov	x6, #730
	cmp	x0, x6
	blt	vertwall

	mov	x7, #754  
	cmp	x0, x7
	blt	horwall

	b	empty_row
drawbat:

	adr	x14, batpos
	ldr	x20, [x14]
	adr	x13, bm
	mov	x11, -1
	add	x13, x13, x20

	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]
	add	x13, x13, #128
	strh	w11, [x13]

	ret
	
drawball:
	
	adr	x4, bally
	ldr	d6, [x4]
	adr	x4, ballx
	ldr	d5, [x4]
	//Notice: If these following conversions are done in a latter stage and float instructions (fdiv, fmsub...) are used
	//the algorithm won't work. Floats give different results
	fcvtnu	w5, d5
	fcvtnu	w6, d6
	mov	w13, #128
	mul	w7, w6, w13   	//w7 = bally * 128, bits that represent rows
	mov	w14, #8
	udiv	w8, w5, w14 	//Bits representing pixels of the current row
	add	w7, w7, w8  	//w7 = on which byte of screen's bitmap we are
	msub	w9, w8, w14, w5 //Remainder (of previous udiv). 
	add	w9, w9, #1 	//w9 = the current bit

	//Without the rotate left instruction in the instruction set, the inversion needs to be used to create desired bit arrays
	mov	w11, -1           //Creates bitmask 1111_1111_1111_1111_1111_1111_1111_1110
	lsl	w10, w11, w9      //Rotates x positions to left (x = 3 gives ...1111_1000 etc.)
	mvn	w12, w10          //Negates every bit (x = 3 is now 0000_0111)
	
	adr	x13, bm
	add	x13, x13, x7

	//Including existing bitmap data from concerned bytes prevents this function from erasing walls when the ball is near them
	ldrb	w14, [x13]
	ldrb	w15, [x13, #2]
	orr	w10, w10, w14
	orr	w12, w12, w15
	
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]

	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]
	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]
	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]
	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]
	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]
	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]
	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]
	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]
	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]
	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]
	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]
	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]
	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]
	add	x13, x13, #128
	strb	w10, [x13]
	strb	w11, [x13, #1]
	strb	w12, [x13, #2]

	ret
	
empty_row:
	st1	{v20.2d, v21.2d, v22.2d, v23.2d}, [x1], #64
	st1	{v20.2d, v21.2d, v22.2d, v23.2d}, [x1], #64
	b	y_loop_beg	
horwall:
	st1	{v24.2d, v25.2d, v26.2d, v27.2d}, [x1], #64
	stp	x16, x16, [x1], #16
	stp	x16, x16, [x1], #16
	stp	x16, x16, [x1], #16
	stp	x16, x15, [x1], #16
	b	y_loop_beg
vertwall:
	stp	x15, x15, [x1], #16
	stp	x15, x15, [x1], #16
	stp	x15, x15, [x1], #16
	stp	x15, x15, [x1], #16
	stp	x15, x15, [x1], #16
	stp	x15, x15, [x1], #16
	stp	x15, x15, [x1], #16
	stp	x17, x15, [x1], #16
	b	y_loop_beg
