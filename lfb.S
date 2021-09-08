
charimage_width:	.word	1024
charimage_height:	.word	768

.bss

	
width:		.space	4  //unsigned int
height:		.space	4
pitch:		.space	4
isrgb:		.space	4

x:		.space	4 //int
y:		.space	4 //int
pixel:		.space	4 //char-array, 4 length

		.align 3  //(4 = word, 8 = doubleword) -> .align 3
lfb:		.space	8  //unsigned char pointer for 64-bit addresses

char:		.space	8 //pointer (*char)
	
	.text

	//resolution 1024x768
	.global lfb_init
lfb_init:
	mov	x28, x30

	adrp	x2, mbox
	add     x2, x2, :lo12:mbox
	
	mov	w1, #140
	str	w1, [x2], #4
	str	wzr, [x2], #4  //mbox[1]
	ldr	w1, =0x48003  //set phy wh
	str	w1, [x2], #4  //mbox[2]
	mov	w3, #8
	str	w3, [x2], #4  //mbox[3]
	str	w3, [x2], #4  //mbox[4]
	mov	w1, #1024	//width
	str	w1, [x2], #4  //mbox[5]
	mov	w1, #768	//height
	str	w1, [x2], #4  //mbox[6]

	ldr	w1, =0x48004  //set virt wh
	str	w1, [x2], #4  //mbox[7]
	str	w3, [x2], #4  //[8]
	str	w3, [x2], #4  //[9]
	mov	w1, #1024  //width
	str	w1, [x2], #4 //[10]  
	mov	w1, #768  //height
	str	w1, [x2], #4 //[11]

	ldr	w1, =0x48009  //set virt offset
	str	w1, [x2], #4  //[12]
	str	w3, [x2], #4  //[13]
	str	w3, [x2], #4  //[14]
	str	wzr, [x2], #4  //[15]
	str	wzr, [x2], #4  //[16]

	ldr	w1, =0x48005  //set depth
	str	w1, [x2], #4  //[17]
	mov	w4, #4
	str	w4, [x2], #4 //[18]
	str	w4, [x2], #4 //[19]
	mov	w1, #32  //depth
	str	w1, [x2], #4 //[20]

	ldr	w1, =0x48006  //set pixel order
	str	w1, [x2], #4  //[21]
	str	w4, [x2], #4 //[22]
	str	w4, [x2], #4 //[23]
	mov	w1, #1
	str	w1, [x2], #4 //[24]  //RGB, not BGR

	ldr	w1, =0x40001  //get framebuffer, get alignment or request
	str	w1, [x2], #4  //[25]
	str	w3, [x2], #4  //[26]
	str	w3, [x2], #4  //[27]
	mov	w1, #4096
	str	w1, [x2], #4  //[28]
	str	wzr, [x2], #4  //[29]
	
	ldr	w1, =0x40008  //get pitch
	str	w1, [x2], #4  //[30]
	str	w4, [x2], #4  //[31]
	str	w4, [x2], #4  //[32]	
	str	wzr, [x2], #4  //[33]

	str	wzr, [x2]  //[34]

	adrp	x2, mbox
	add     x2, x2, :lo12:mbox
	
	mov	x0, #8  //argument to mbox_call
	
	bl	mbox_call
	cbz	x0, unable  //branch if mbox_call returned zero
mbox_check:	
	adrp	x1, mbox+80   //mbox[20]
	add     x1, x1, :lo12:mbox+80
	ldr	w2, [x1]
	cmp	w2, 32
	bne	unable

	adrp	x1, mbox+112  //mbox[28]
	add     x1, x1, :lo12:mbox+112
	ldr	w2, [x1]
	cbz	w2, unable

	//convert GPU address to ARM address
	ldr	w3, =0x3FFFFFFF
	and	w2, w2, w3  //w2 still bears mbox[28] contents
	str	w2, [x1] //x1 is still address to mbox[28]

	adrp	x1, mbox+20  //5x4 = 20 = mbox[5]
	add     x1, x1, :lo12:mbox+20
	ldr	w2, [x1]
	adrp	x3, width
	add     x3, x3, :lo12:width
	str	w2, [x3]

	adrp	x1, mbox+24  //6x4 = 24 = mbox[6]
	add     x1, x1, :lo12:mbox+24
	ldr	w2, [x1]
	adrp	x3, height
	add     x3, x3, :lo12:height
	str	w2, [x3]

	adrp	x1, mbox+132  //33x4 = 132 = mbox[33]
	add     x1, x1, :lo12:mbox+132
	ldr	w2, [x1]
	adrp	x3, pitch
	add     x3, x3, :lo12:pitch
	str	w2, [x3]

	adrp	x1, mbox+96  //24x4 = 96 = mbox[24]
	add     x1, x1, :lo12:mbox+96
	ldr	w2, [x1]
	adrp	x3, isrgb
	add     x3, x3, :lo12:isrgb
	str	w2, [x3]

	adrp	x1, mbox+112 //28x4 = 112 = mbox[28]
	add     x1, x1, :lo12:mbox+112
	ldr	w2, [x1]
	adrp	x3, lfb
	add     x3, x3, :lo12:lfb
	str	w2, [x3]

	b	go_on

unable:	 //unable to set screen resolution to 1024x768x32
	wfe

go_on:
	ret	x28

	.global drawscreen
drawscreen:

	adrp	x1, lfb
	add     x1, x1, :lo12:lfb
	ldr	x7, [x1]

	adrp	x6, bm
	add	x6, x6, :lo12:bm

	mov	w0, #0
	mov	w2, #98304 //1024*768/8
	mov	w3, #0  //black pixel
	mov	w4, #-1 //white pixel
bitloop_start:	
	mov	w12, 1  //bitmask
	ldrb	w9, [x6]
bitloop_cont:
	//bitmap-loop
	ands	w13, w9, w12
	beq	black_pixel
//white pixel:
checkpoint2:	
	str	w4, [x7], #4
	b	bitloop_tail
black_pixel:	
	str	w3, [x7], #4
bitloop_tail:
	lsl	w12, w12, #1  //updating bitmask
	cmp	w12, #256
	bne	bitloop_cont
draw_loop_tail:
	add	w0, w0, #1
	add	x6, x6, #1
	cmp	w0, w2
	bne	bitloop_start
	ret

	
