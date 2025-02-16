	.file	"main.c"
	.option nopic
	.attribute arch, "rv32i2p1_zicbom_zicboz_zicond_zba1p0_zbb1p0_zbc1p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	2
	.type	bitstream_readbits.part.0, @function
bitstream_readbits.part.0:
	lw	a6,8(a1)
	lw	a4,0(a1)
	lw	a2,4(a1)
	add	a3,a6,a4
	lbu	a5,0(a3)
	blt	a2,a0,.L11
	sll	a4,a5,a0
	sb	a4,0(a3)
	lw	a4,4(a1)
	li	a3,8
	sub	a3,a3,a0
	sub	a4,a4,a0
	sw	a4,4(a1)
	sra	a0,a5,a3
	ret
.L11:
	addi	sp,sp,-16
	li	a3,16
	sub	a3,a3,a0
	sw	s0,8(sp)
	slli	a5,a5,8
	sw	ra,12(sp)
	li	a7,511
	srl	s0,a5,a3
	sub	a0,a0,a2
	beq	a4,a7,.L12
	addi	a4,a4,1
.L4:
	li	a5,8
	sw	a4,0(a1)
	sw	a5,4(a1)
	call	bitstream_readbits.part.0
	lw	ra,12(sp)
	or	a0,s0,a0
	lw	s0,8(sp)
	addi	sp,sp,16
	jr	ra
.L12:
	lw	a5,12(a1)
	sw	a6,12(a1)
	sw	a5,8(a1)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a4,66
	lw	a5,12(a1)
 #APP
# 107 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	li	a4,0
	j	.L4
	.size	bitstream_readbits.part.0, .-bitstream_readbits.part.0
	.align	2
	.globl	bitstream_init
	.type	bitstream_init, @function
bitstream_init:
	li	a5,512
	li	a4,8
	sw	a4,4(a1)
	sw	zero,0(a1)
	sw	zero,8(a1)
	sw	a5,12(a1)
	li	a4,4096
	li	a3,64
 #APP
# 75 "./main.c" 1
	wsrh	a4,a3
# 0 "" 2
 #NO_APP
	li	a4,66
	li	a3,0
 #APP
# 77 "./main.c" 1
	wsrh	a3,a4
# 0 "" 2
# 79 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	ret
	.size	bitstream_init, .-bitstream_init
	.align	2
	.globl	bitstream_close
	.type	bitstream_close, @function
bitstream_close:
	ret
	.size	bitstream_close, .-bitstream_close
	.align	2
	.globl	bitstream_swapin
	.type	bitstream_swapin, @function
bitstream_swapin:
	lw	a4,8(a0)
	lw	a5,12(a0)
	sw	a4,12(a0)
	sw	a5,8(a0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a4,66
	lw	a5,12(a0)
 #APP
# 107 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	ret
	.size	bitstream_swapin, .-bitstream_swapin
	.align	2
	.globl	bitstream_prepare
	.type	bitstream_prepare, @function
bitstream_prepare:
	lw	a5,0(a0)
	li	a4,511
	beq	a5,a4,.L19
	addi	a5,a5,1
	sw	a5,0(a0)
	li	a5,8
	sw	a5,4(a0)
	ret
.L19:
	lw	a4,8(a0)
	lw	a5,12(a0)
	sw	a4,12(a0)
	sw	a5,8(a0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a4,66
	lw	a5,12(a0)
 #APP
# 107 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	li	a5,0
	sw	a5,0(a0)
	li	a5,8
	sw	a5,4(a0)
	ret
	.size	bitstream_prepare, .-bitstream_prepare
	.align	2
	.globl	bitstream_readbits
	.type	bitstream_readbits, @function
bitstream_readbits:
	beq	a0,zero,.L21
	tail	bitstream_readbits.part.0
.L21:
	ret
	.size	bitstream_readbits, .-bitstream_readbits
	.align	2
	.globl	bitstream_readunary
	.type	bitstream_readunary, @function
bitstream_readunary:
	lw	a6,8(a0)
	lw	a4,0(a0)
	mv	a5,a0
	add	a3,a6,a4
	lbu	a2,0(a3)
	bne	a2,zero,.L27
	lw	a0,4(a0)
	li	a1,0
	li	t1,511
	li	t3,66
	li	a7,8
.L26:
	beq	a4,t1,.L30
	addi	a4,a4,1
	mv	a3,a4
.L25:
	sw	a4,0(a5)
	sw	a7,4(a5)
	add	a3,a6,a3
	lbu	a2,0(a3)
	add	a1,a1,a0
	li	a0,8
	beq	a2,zero,.L26
.L23:
	clz	a0,a2
	addi	a6,a0,-7
	sll	a2,a2,a6
	sb	a2,0(a3)
	lw	a4,4(a5)
	addi	a0,a0,-8
	add	a0,a0,a1
	sub	a4,a4,a6
	sw	a4,4(a5)
	ret
.L30:
	lw	a4,12(a5)
	sw	a6,12(a5)
	sw	a4,8(a5)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	lw	a4,12(a5)
 #APP
# 107 "./main.c" 1
	wsrh	a4,t3
# 0 "" 2
 #NO_APP
	li	a3,0
	lw	a6,8(a5)
	li	a4,0
	j	.L25
.L27:
	li	a1,0
	j	.L23
	.size	bitstream_readunary, .-bitstream_readunary
	.align	2
	.globl	bitstream_readrice
	.type	bitstream_readrice, @function
bitstream_readrice:
	lw	a7,8(a1)
	lw	a5,0(a1)
	add	a4,a7,a5
	lbu	a3,0(a4)
	bne	a3,zero,.L39
	lw	a6,4(a1)
	li	a2,0
	li	t3,511
	li	t4,66
	li	t1,8
.L35:
	beq	a5,t3,.L48
	addi	a5,a5,1
	mv	a4,a5
.L34:
	sw	a5,0(a1)
	sw	t1,4(a1)
	add	a4,a7,a4
	lbu	a3,0(a4)
	add	a2,a2,a6
	li	a6,8
	beq	a3,zero,.L35
.L32:
	clz	a5,a3
	addi	a6,a5,-7
	sll	a3,a3,a6
	sb	a3,0(a4)
	lw	a4,4(a1)
	addi	a5,a5,-8
	add	a5,a5,a2
	sub	a4,a4,a6
	sw	a4,4(a1)
	bne	a0,zero,.L36
	andi	a4,a5,1
	neg	a4,a4
	srai	a0,a5,1
	xor	a0,a4,a0
	srai	a1,a0,31
	ret
.L48:
	lw	a5,12(a1)
	sw	a7,12(a1)
	sw	a5,8(a1)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	lw	a5,12(a1)
 #APP
# 107 "./main.c" 1
	wsrh	a5,t4
# 0 "" 2
 #NO_APP
	li	a4,0
	lw	a7,8(a1)
	li	a5,0
	j	.L34
.L36:
	addi	sp,sp,-48
	sw	s0,40(sp)
	addi	a0,a0,-1
	sw	ra,44(sp)
	sll	s0,a5,a0
	beq	a0,zero,.L38
	sw	a1,12(sp)
	call	bitstream_readbits.part.0
	lw	a1,12(sp)
	or	s0,s0,a0
.L38:
	li	a0,1
	call	bitstream_readbits.part.0
	neg	a1,a0
	lw	ra,44(sp)
	xor	a0,a1,s0
	lw	s0,40(sp)
	addi	sp,sp,48
	jr	ra
.L39:
	li	a2,0
	j	.L32
	.size	bitstream_readrice, .-bitstream_readrice
	.align	2
	.globl	bitstream_align
	.type	bitstream_align, @function
bitstream_align:
	lw	a4,4(a0)
	li	a5,8
	bne	a4,a5,.L53
	ret
.L53:
	lw	a5,0(a0)
	li	a4,511
	beq	a5,a4,.L54
	addi	a5,a5,1
.L52:
	sw	a5,0(a0)
	li	a5,8
	sw	a5,4(a0)
	ret
.L54:
	lw	a4,8(a0)
	lw	a5,12(a0)
	sw	a4,12(a0)
	sw	a5,8(a0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a4,66
	lw	a5,12(a0)
 #APP
# 107 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	li	a5,0
	j	.L52
	.size	bitstream_align, .-bitstream_align
	.align	2
	.globl	bitstream_alignread
	.type	bitstream_alignread, @function
bitstream_alignread:
	lw	a5,8(a1)
	lw	a3,0(a1)
	li	a4,511
	add	a5,a5,a3
	lbu	a5,0(a5)
	sb	a5,0(a0)
	lw	a5,0(a1)
	beq	a5,a4,.L58
	addi	a5,a5,1
	sw	a5,0(a1)
	li	a5,8
	sw	a5,4(a1)
	ret
.L58:
	lw	a4,8(a1)
	lw	a5,12(a1)
	sw	a4,12(a1)
	sw	a5,8(a1)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a4,66
	lw	a5,12(a1)
 #APP
# 107 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	li	a5,0
	sw	a5,0(a1)
	li	a5,8
	sw	a5,4(a1)
	ret
	.size	bitstream_alignread, .-bitstream_alignread
	.align	2
	.globl	bitstream_alignpass
	.type	bitstream_alignpass, @function
bitstream_alignpass:
	lw	a5,0(a0)
	li	a4,511
	beq	a5,a4,.L62
	addi	a5,a5,1
	sw	a5,0(a0)
	li	a5,8
	sw	a5,4(a0)
	ret
.L62:
	lw	a4,8(a0)
	lw	a5,12(a0)
	sw	a4,12(a0)
	sw	a5,8(a0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a4,66
	lw	a5,12(a0)
 #APP
# 107 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	li	a5,0
	sw	a5,0(a0)
	li	a5,8
	sw	a5,4(a0)
	ret
	.size	bitstream_alignpass, .-bitstream_alignpass
	.align	2
	.globl	write_residuals
	.type	write_residuals, @function
write_residuals:
	lw	a5,0(a1)
	addi	sp,sp,-16
	bne	a3,zero,.L69
	blt	a2,zero,.L67
.L66:
	addi	a4,a5,1
	sh1add	a5,a5,a0
	sh	a2,0(a5)
	sw	a4,0(a1)
	addi	sp,sp,16
	jr	ra
.L69:
	li	a4,-1
	beq	a2,a4,.L67
	blt	a2,zero,.L66
.L67:
	li	a3,-1
	sh1add	a4,a5,a0
	addi	a5,a5,1
	sh	a3,0(a4)
	addi	a4,a5,1
	sh1add	a5,a5,a0
	sh	a2,0(a5)
	sw	a4,0(a1)
	addi	sp,sp,16
	jr	ra
	.size	write_residuals, .-write_residuals
	.align	2
	.globl	decode_residuals
	.type	decode_residuals, @function
decode_residuals:
	addi	sp,sp,-80
	sw	s1,68(sp)
	sw	s6,48(sp)
	mv	s1,a0
	mv	s6,a1
	li	a0,2
	mv	a1,a3
	sw	ra,76(sp)
	sw	s2,64(sp)
	sw	s4,56(sp)
	mv	s2,a3
	sw	s7,44(sp)
	mv	s4,a2
	sw	s0,72(sp)
	sw	s3,60(sp)
	sw	s5,52(sp)
	sw	s8,40(sp)
	call	bitstream_readbits.part.0
	mv	a1,s2
	li	a0,4
	call	bitstream_readbits.part.0
	li	s7,1
	sll	s7,s7,a0
	sw	zero,12(sp)
	sra	s6,s6,a0
	ble	s7,zero,.L71
	mv	a1,s2
	li	a0,4
	call	bitstream_readbits.part.0
	li	s8,14
	sub	s1,s6,s1
	li	s5,0
	mv	s3,a0
	bgt	a0,s8,.L72
.L81:
	ble	s1,zero,.L73
	li	s0,0
.L74:
	mv	a1,s2
	mv	a0,s3
	call	bitstream_readrice
	mv	a2,a0
	mv	a3,a1
	addi	s0,s0,1
	addi	a1,sp,12
	mv	a0,s4
	call	write_residuals
	bne	s1,s0,.L74
.L73:
	addi	s5,s5,1
	beq	s7,s5,.L71
.L77:
	mv	a1,s2
	li	a0,4
	call	bitstream_readbits.part.0
	mv	s1,s6
	mv	s3,a0
	ble	a0,s8,.L81
.L72:
	mv	a1,s2
	li	a0,5
	call	bitstream_readbits.part.0
	mv	s3,a0
	ble	s1,zero,.L73
	li	s0,0
.L75:
	mv	a1,s2
	mv	a0,s3
	call	bitstream_readrice
	mv	a2,a0
	mv	a3,a1
	addi	s0,s0,1
	addi	a1,sp,12
	mv	a0,s4
	call	write_residuals
	bne	s1,s0,.L75
	addi	s5,s5,1
	bne	s7,s5,.L77
.L71:
	lw	ra,76(sp)
	lw	s0,72(sp)
	lw	s1,68(sp)
	lw	s2,64(sp)
	lw	s3,60(sp)
	lw	s4,56(sp)
	lw	s5,52(sp)
	lw	s6,48(sp)
	lw	s7,44(sp)
	lw	s8,40(sp)
	li	a0,0
	addi	sp,sp,80
	jr	ra
	.size	decode_residuals, .-decode_residuals
	.align	2
	.globl	decodesubframe
	.type	decodesubframe, @function
decodesubframe:
	addi	sp,sp,-64
	sw	s2,48(sp)
	sw	s4,40(sp)
	mv	s2,a0
	mv	s4,a1
	li	a0,8
	mv	a1,a3
	sw	s0,56(sp)
	sw	s1,52(sp)
	sw	s3,44(sp)
	sw	s5,36(sp)
	sw	ra,60(sp)
	sw	s6,32(sp)
	sw	s7,28(sp)
	sw	s8,24(sp)
	sw	s9,20(sp)
	mv	s0,a3
	mv	s3,a2
	call	bitstream_readbits.part.0
	andi	s1,a0,1
	srai	s5,a0,1
	beq	s1,zero,.L84
	li	s1,1
	j	.L83
.L85:
	addi	s1,s1,1
.L83:
	mv	a1,s0
	li	a0,1
	call	bitstream_readbits.part.0
	beq	a0,zero,.L85
	sub	s4,s4,s1
.L84:
	li	a5,41
 #APP
# 280 "./main.c" 1
	wsrh	s1,a5
# 0 "" 2
 #NO_APP
	bne	s5,zero,.L86
	li	a5,16
	bgt	s4,a5,.L124
	beq	s4,zero,.L109
	mv	a1,s0
	mv	a0,s4
	call	bitstream_readbits.part.0
	srli	s0,a0,31
.L88:
	li	a5,32
 #APP
# 300 "./main.c" 1
	wsrh	a0,a5
# 0 "" 2
# 301 "./main.c" 1
	wsrhh	s0,a5
# 0 "" 2
 #NO_APP
.L93:
	li	a0,0
.L82:
	lw	ra,60(sp)
	lw	s0,56(sp)
	lw	s1,52(sp)
	lw	s2,48(sp)
	lw	s3,44(sp)
	lw	s4,40(sp)
	lw	s5,36(sp)
	lw	s6,32(sp)
	lw	s7,28(sp)
	lw	s8,24(sp)
	lw	s9,20(sp)
	addi	sp,sp,64
	jr	ra
.L86:
	li	a5,1
	beq	s5,a5,.L125
	addi	a5,s5,-8
	li	a4,4
	bleu	a5,a4,.L126
	addi	a5,s5,-32
	li	a4,31
	bgtu	a5,a4,.L113
	andi	s5,s5,31
	addi	s6,s5,1
	li	a5,38
 #APP
# 436 "./main.c" 1
	wsrh	s5,a5
# 0 "" 2
 #NO_APP
	li	s9,0
	addi	s8,s4,-1
	slli	s5,s6,1
	li	s7,40
	j	.L105
.L128:
	call	bitstream_readbits.part.0
	neg	a5,s1
	sll	a5,a5,s8
	or	a0,a5,a0
 #APP
# 453 "./main.c" 1
	wsrh	a0,s7
# 0 "" 2
 #NO_APP
	add	s1,s9,s1
 #APP
# 454 "./main.c" 1
	wsrhh	s1,s7
# 0 "" 2
 #NO_APP
	addi	s9,s9,2
	beq	s5,s9,.L127
.L105:
	mv	a1,s0
	li	a0,1
	call	bitstream_readbits.part.0
	li	a5,1
	mv	s1,a0
	mv	a1,s0
	mv	a0,s8
	bne	s4,a5,.L128
	neg	a5,s1
	sll	a5,a5,s8
	li	a0,0
	or	a0,a5,a0
 #APP
# 453 "./main.c" 1
	wsrh	a0,s7
# 0 "" 2
 #NO_APP
	add	s1,s9,s1
 #APP
# 454 "./main.c" 1
	wsrhh	s1,s7
# 0 "" 2
 #NO_APP
	addi	s9,s9,2
	bne	s5,s9,.L105
.L127:
	mv	a1,s0
	li	a0,4
	call	bitstream_readbits.part.0
	mv	s7,a0
	mv	a1,s0
	li	a0,5
	call	bitstream_readbits.part.0
	li	a5,37
 #APP
# 466 "./main.c" 1
	wsrh	a0,a5
# 0 "" 2
 #NO_APP
	li	s4,0
	li	s8,39
.L107:
	mv	a1,s0
	li	a0,1
	call	bitstream_readbits.part.0
	mv	s1,a0
	neg	s1,s1
	mv	a1,s0
	mv	a0,s7
	sll	s1,s1,s7
	beq	s7,zero,.L106
	call	bitstream_readbits.part.0
	or	s1,s1,a0
.L106:
 #APP
# 481 "./main.c" 1
	wsrh	s1,s8
# 0 "" 2
# 482 "./main.c" 1
	wsrhh	s4,s8
# 0 "" 2
 #NO_APP
	addi	s4,s4,2
	bne	s4,s5,.L107
	li	a5,4096
	sh3add	s1,s3,s3
	slli	s1,s1,11
	add	s1,s1,a5
	mv	a3,s0
	mv	a2,s1
	mv	a1,s2
	mv	a0,s6
	call	decode_residuals
 #APP
# 500 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a5,34
 #APP
# 511 "./main.c" 1
	wsrh	s1,a5
# 0 "" 2
 #NO_APP
	j	.L93
.L125:
	li	a5,4096
	sh3add	s3,s3,s3
	sw	zero,4(sp)
	slli	s5,s3,11
	add	s5,s5,a5
	ble	s2,zero,.L97
	li	s3,0
	li	s8,16
	addi	s6,s4,-1
	addi	s7,s4,-16
	j	.L92
.L129:
	call	bitstream_readbits.part.0
	mv	s1,a0
	mv	a1,s0
	li	a0,16
	call	bitstream_readbits.part.0
	mv	a2,a0
.L95:
	addi	s3,s3,1
	mv	a3,s1
	addi	a1,sp,4
	mv	a0,s5
	sw	a2,8(sp)
	sw	s1,12(sp)
	call	write_residuals
	beq	s2,s3,.L97
.L92:
	mv	a1,s0
	mv	a0,s7
	bgt	s4,s8,.L129
	li	a0,1
	call	bitstream_readbits.part.0
	mv	s1,a0
	addi	s1,s1,-1
	mv	a1,s0
	mv	a0,s6
	seqz	s1,s1
	beq	s6,zero,.L111
	call	bitstream_readbits.part.0
.L96:
	neg	a2,s1
	sll	a2,a2,s6
	or	a2,a2,a0
	j	.L95
.L124:
	mv	a1,s0
	addi	a0,s4,-1
	call	bitstream_readbits.part.0
	mv	a5,a0
	mv	a1,s0
	li	a0,16
	mv	s0,a5
	call	bitstream_readbits.part.0
	j	.L88
.L126:
	li	a5,4096
	sh3add	s3,s3,s3
	andi	s5,s5,7
	slli	s3,s3,11
	add	s3,s3,a5
	bne	s5,zero,.L99
	mv	a3,s0
	mv	a2,s3
	mv	a1,s2
	li	a0,0
	call	decode_residuals
	li	a5,33
.L100:
 #APP
# 419 "./main.c" 1
	clflush	
# 0 "" 2
# 421 "./main.c" 1
	wsrh	s3,a5
# 0 "" 2
 #NO_APP
	j	.L93
.L111:
	li	a0,0
	j	.L96
.L97:
 #APP
# 338 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a5,33
 #APP
# 340 "./main.c" 1
	wsrh	s5,a5
# 0 "" 2
 #NO_APP
	j	.L93
.L109:
	li	s0,0
	li	a0,0
	j	.L88
.L99:
	addi	a5,s5,-1
	li	a4,38
 #APP
# 357 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	li	s9,0
	addi	s8,s4,-1
	slli	s6,s5,1
	li	s7,40
.L102:
	mv	a1,s0
	li	a0,1
	call	bitstream_readbits.part.0
	mv	s1,a0
	addi	s1,s1,-1
	li	a5,1
	mv	a1,s0
	mv	a0,s8
	seqz	s1,s1
	beq	s4,a5,.L112
	call	bitstream_readbits.part.0
.L101:
	neg	a5,s1
	sll	a5,a5,s8
	or	a5,a5,a0
 #APP
# 372 "./main.c" 1
	wsrh	a5,s7
# 0 "" 2
 #NO_APP
	add	s1,s9,s1
 #APP
# 373 "./main.c" 1
	wsrhh	s1,s7
# 0 "" 2
 #NO_APP
	addi	s9,s9,2
	bne	s9,s6,.L102
	slli	a1,s5,3
	li	a5,0
	li	a4,37
 #APP
# 385 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	lui	a2,%hi(.LANCHOR0)
	addi	a2,a2,%lo(.LANCHOR0)
	li	a3,39
.L103:
	add	a4,a5,a1
	add	a4,a2,a4
	lh	a4,0(a4)
 #APP
# 397 "./main.c" 1
	wsrh	a4,a3
# 0 "" 2
# 398 "./main.c" 1
	wsrhh	a5,a3
# 0 "" 2
 #NO_APP
	addi	a5,a5,2
	bne	a5,s6,.L103
	mv	a3,s0
	mv	a2,s3
	mv	a1,s2
	mv	a0,s5
	call	decode_residuals
	li	a5,34
	j	.L100
.L112:
	li	a0,0
	j	.L101
.L113:
	li	a0,-1
	j	.L82
	.size	decodesubframe, .-decodesubframe
	.align	2
	.globl	decodeframe
	.type	decodeframe, @function
decodeframe:
	lw	a2,8(a0)
	lw	a5,0(a0)
	addi	sp,sp,-32
	sw	s0,24(sp)
	sw	ra,28(sp)
	sw	s1,20(sp)
	sw	s2,16(sp)
	sw	s3,12(sp)
	add	a4,a2,a5
	li	a6,511
	lbu	a3,0(a4)
	mv	s0,a0
	beq	a5,a6,.L177
	addi	a4,a5,1
	li	a7,8
	add	a1,a2,a4
	sw	a4,0(a0)
	sw	a7,4(a0)
	lbu	a0,0(a1)
	li	a1,-65536
	addi	a1,a1,255
	slli	a0,a0,8
	and	a3,a3,a1
	or	a3,a3,a0
	bne	a4,a6,.L133
	lw	a5,12(s0)
	sw	a2,12(s0)
	sw	a5,8(s0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a4,66
	lw	a5,12(s0)
 #APP
# 107 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	lw	a2,8(s0)
	sw	zero,0(s0)
	sw	a7,4(s0)
	lbu	a0,0(a2)
	li	a5,1
	sw	a5,0(s0)
	li	a5,-16711680
	addi	a5,a5,-1
	slli	a4,a0,16
	and	a5,a3,a5
	lbu	s1,1(a2)
	or	a3,a5,a4
	slli	a3,a3,8
	slli	a5,s1,24
	srli	a3,a3,8
	or	a3,a3,a5
	li	a4,1
.L134:
	li	a5,65536
	addi	a1,a5,-769
	addi	a4,a4,1
	li	a6,8
	sw	a4,0(s0)
	sw	a6,4(s0)
	and	a3,a3,a1
	addi	a5,a5,-1793
	bne	a3,a5,.L135
	add	a5,a2,a4
	li	a3,511
	lbu	a5,0(a5)
	bne	a4,a3,.L139
	lw	a4,12(s0)
	sw	a2,12(s0)
	sw	a4,8(s0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a3,66
	lw	a4,12(s0)
 #APP
# 107 "./main.c" 1
	wsrh	a4,a3
# 0 "" 2
 #NO_APP
	li	a4,0
.L140:
	sw	a4,0(s0)
	li	a4,8
	sw	a4,4(s0)
	li	a4,191
	bleu	a5,a4,.L146
	li	a1,511
	li	a7,66
	li	a2,8
	li	a3,191
	j	.L141
.L144:
	addi	a4,a4,1
	slli	a5,a5,1
	sw	a4,0(s0)
	sw	a2,4(s0)
	andi	a5,a5,0xff
	bleu	a5,a3,.L146
.L141:
	lw	a4,0(s0)
	bne	a4,a1,.L144
	lw	a6,8(s0)
	lw	a4,12(s0)
	sw	a6,12(s0)
	sw	a4,8(s0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	lw	a4,12(s0)
 #APP
# 107 "./main.c" 1
	wsrh	a4,a7
# 0 "" 2
 #NO_APP
	li	a4,0
	slli	a5,a5,1
	sw	a4,0(s0)
	sw	a2,4(s0)
	andi	a5,a5,0xff
	bgtu	a5,a3,.L141
.L146:
	srli	a4,a0,4
	li	a3,1
	srli	a5,s1,4
	andi	a0,a0,15
	andi	s1,s1,15
	beq	a4,a3,.L178
	addi	a3,a4,-2
	li	a2,3
	bgtu	a3,a2,.L148
	lw	a4,0(s0)
	li	s3,576
	sll	s3,s3,a3
.L147:
	li	a3,511
	beq	a4,a3,.L179
.L152:
	addi	a4,a4,1
.L155:
	li	a3,8
	sw	a4,0(s0)
	sw	a3,4(s0)
	li	a4,10
	bne	a0,a4,.L166
	li	a4,9
	beq	a5,a4,.L167
	bgtu	a5,a4,.L157
	li	a4,1
	beq	a5,a4,.L168
	li	s2,1
	bne	a5,a3,.L170
.L156:
	li	a5,8
	bne	s1,a5,.L171
	li	a5,35
 #APP
# 631 "./main.c" 1
	wsrh	s3,a5
# 0 "" 2
 #NO_APP
	li	a5,36
 #APP
# 640 "./main.c" 1
	wsrh	s2,a5
# 0 "" 2
 #NO_APP
	addi	a1,s2,-2
	seqz	a1,a1
	mv	a3,s0
	li	a2,0
	addi	a1,a1,16
	mv	a0,s3
	call	decodesubframe
	bne	a0,zero,.L159
	andi	a1,s2,-3
	mv	a3,s0
	li	a2,1
	addi	a1,a1,16
	mv	a0,s3
	call	decodesubframe
	bne	a0,zero,.L159
	lw	a4,4(s0)
	lw	a5,0(s0)
	beq	a4,s1,.L160
	li	a4,511
	beq	a5,a4,.L180
	addi	a5,a5,1
	sw	a5,0(s0)
	sw	s1,4(s0)
.L160:
	li	a4,511
	beq	a5,a4,.L181
	addi	a5,a5,1
	li	a3,8
	sw	a5,0(s0)
	sw	a3,4(s0)
	bne	a5,a4,.L162
	lw	a4,8(s0)
	lw	a5,12(s0)
	sw	a4,12(s0)
	sw	a5,8(s0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a4,66
	lw	a5,12(s0)
 #APP
# 107 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	li	a5,0
.L164:
	sw	a5,0(s0)
	li	a5,8
	sw	a5,4(s0)
.L130:
	lw	ra,28(sp)
	lw	s0,24(sp)
	lw	s1,20(sp)
	lw	s2,16(sp)
	lw	s3,12(sp)
	addi	sp,sp,32
	jr	ra
.L133:
	addi	a4,a5,2
	add	a5,a2,a4
	sw	a4,0(s0)
	lbu	a0,0(a5)
	li	a5,-16711680
	addi	a5,a5,-1
	slli	a1,a0,16
	and	a5,a3,a5
	or	a3,a5,a1
	bne	a4,a6,.L132
	lw	a5,12(s0)
	sw	a2,12(s0)
	sw	a5,8(s0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a4,66
	lw	a5,12(s0)
 #APP
# 107 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	lw	a2,8(s0)
	sw	zero,0(s0)
	sw	a7,4(s0)
	lbu	s1,0(a2)
	slli	a3,a3,8
	srli	a3,a3,8
	slli	a5,s1,24
	or	a3,a3,a5
	li	a4,0
	j	.L134
.L179:
	lw	a3,8(s0)
	lw	a4,12(s0)
	sw	a3,12(s0)
	sw	a4,8(s0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a3,66
	lw	a4,12(s0)
 #APP
# 107 "./main.c" 1
	wsrh	a4,a3
# 0 "" 2
 #NO_APP
	li	a4,0
	j	.L155
.L157:
	bne	a5,a0,.L170
	li	s2,3
	j	.L156
.L177:
	lw	a5,12(a0)
	sw	a2,12(a0)
	sw	a5,8(a0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a4,66
	lw	a5,12(a0)
 #APP
# 107 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	lw	a2,8(a0)
	li	a5,8
	sw	zero,0(a0)
	sw	a5,4(a0)
	li	a4,1
	lbu	a5,0(a2)
	sw	a4,0(a0)
	lbu	a0,1(a2)
	slli	a5,a5,8
	or	a5,a3,a5
	slli	a3,a0,16
	or	a3,a5,a3
.L132:
	addi	a4,a4,1
	li	a1,8
	add	a5,a2,a4
	sw	a4,0(s0)
	sw	a1,4(s0)
	lbu	s1,0(a5)
	slli	a3,a3,8
	srli	a3,a3,8
	slli	a6,s1,24
	li	a5,511
	or	a3,a3,a6
	bne	a4,a5,.L134
	lw	a5,12(s0)
	sw	a2,12(s0)
	sw	a5,8(s0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a4,66
	lw	a5,12(s0)
 #APP
# 107 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	li	a5,65536
	addi	a4,a5,-769
	sw	zero,0(s0)
	sw	a1,4(s0)
	and	a4,a3,a4
	addi	a5,a5,-1793
	bne	a4,a5,.L135
	lw	a5,8(s0)
	li	a4,0
	lbu	a5,0(a5)
.L139:
	addi	a4,a4,1
	j	.L140
.L181:
	lw	a4,8(s0)
	lw	a5,12(s0)
	sw	a4,12(s0)
	sw	a5,8(s0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a4,66
	lw	a5,12(s0)
 #APP
# 107 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	li	a5,0
.L162:
	addi	a5,a5,1
	j	.L164
.L148:
	addi	a3,a4,-8
	li	a2,7
	bleu	a3,a2,.L182
	li	a3,6
	beq	a4,a3,.L183
	bne	a4,a2,.L165
	lw	a3,8(s0)
	lw	a4,0(s0)
	li	a1,511
	add	a2,a3,a4
	lbu	s3,0(a2)
	beq	a4,a1,.L184
	addi	a2,a4,1
	li	a6,8
	sw	a6,4(s0)
	sw	a2,0(s0)
	add	a6,a3,a2
	lbu	a6,0(a6)
	bne	a2,a1,.L154
	lw	a4,12(s0)
	sw	a3,12(s0)
	sw	a4,8(s0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a3,66
	lw	a4,12(s0)
 #APP
# 107 "./main.c" 1
	wsrh	a4,a3
# 0 "" 2
 #NO_APP
	addi	a6,a6,9
	sll	s3,s3,a6
	li	a4,0
	j	.L152
.L168:
	li	s2,0
	j	.L156
.L170:
	lw	ra,28(sp)
	lw	s0,24(sp)
	lw	s1,20(sp)
	lw	s2,16(sp)
	lw	s3,12(sp)
	li	a0,-4
	addi	sp,sp,32
	jr	ra
.L182:
	li	s3,256
	lw	a4,0(s0)
	sll	s3,s3,a3
	j	.L147
.L178:
	lw	a4,0(s0)
	li	s3,192
	j	.L147
.L167:
	li	s2,2
	j	.L156
.L180:
	lw	a4,8(s0)
	lw	a5,12(s0)
	sw	a4,12(s0)
	sw	a5,8(s0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a4,66
	lw	a5,12(s0)
 #APP
# 107 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
	li	a5,1
	addi	a5,a5,1
	j	.L164
.L184:
	lw	a4,12(s0)
	sw	a3,12(s0)
	sw	a4,8(s0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a3,66
	lw	a4,12(s0)
 #APP
# 107 "./main.c" 1
	wsrh	a4,a3
# 0 "" 2
 #NO_APP
	lw	a4,8(s0)
	li	a3,8
	sw	zero,0(s0)
	sw	a3,4(s0)
	lbu	a3,0(a4)
	li	a4,1
	addi	a3,a3,9
	sll	s3,s3,a3
	j	.L152
.L154:
	addi	a4,a4,2
	addi	a6,a6,9
	sw	a4,0(s0)
	sll	s3,s3,a6
	j	.L147
.L183:
	lw	a3,8(s0)
	lw	a4,0(s0)
	li	a2,511
	add	a1,a3,a4
	lbu	s3,0(a1)
	beq	a4,a2,.L185
	addi	a4,a4,1
	li	a3,8
	sw	a4,0(s0)
	sw	a3,4(s0)
	addi	s3,s3,1
	j	.L147
.L171:
	li	a0,-5
	j	.L130
.L135:
	li	a0,-1
	j	.L130
.L166:
	li	a0,-3
	j	.L130
.L159:
	li	a0,-6
	j	.L130
.L185:
	lw	a4,12(s0)
	sw	a3,12(s0)
	sw	a4,8(s0)
 #APP
# 104 "./main.c" 1
	clflush	
# 0 "" 2
 #NO_APP
	li	a3,66
	lw	a4,12(s0)
 #APP
# 107 "./main.c" 1
	wsrh	a4,a3
# 0 "" 2
 #NO_APP
	li	a4,0
	addi	s3,s3,1
	j	.L152
.L165:
	li	a0,-2
	j	.L130
	.size	decodeframe, .-decodeframe
	.section	.text.startup,"ax",@progbits
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-32
	li	a5,512
	li	a4,8
	sw	a4,4(sp)
	sw	ra,28(sp)
	sw	zero,0(sp)
	sw	zero,8(sp)
	sw	a5,12(sp)
	li	a4,4096
	li	a3,64
 #APP
# 75 "./main.c" 1
	wsrh	a4,a3
# 0 "" 2
 #NO_APP
	li	a4,66
	li	a3,0
 #APP
# 77 "./main.c" 1
	wsrh	a3,a4
# 0 "" 2
# 79 "./main.c" 1
	wsrh	a5,a4
# 0 "" 2
 #NO_APP
.L187:
	mv	a0,sp
	call	decodeframe
	beq	a0,zero,.L187
 #APP
# 679 "./main.c" 1
	wfi
# 0 "" 2
 #NO_APP
	lw	ra,28(sp)
	li	a0,0
	addi	sp,sp,32
	jr	ra
	.size	main, .-main
	.globl	fixed_coefs
	.section	.rodata
	.align	2
	.set	.LANCHOR0,. + 0
	.type	fixed_coefs, @object
	.size	fixed_coefs, 40
fixed_coefs:
	.zero	8
	.half	1
	.zero	6
	.half	2
	.half	-1
	.zero	4
	.half	3
	.half	-3
	.half	1
	.zero	2
	.half	4
	.half	-6
	.half	4
	.half	-1
	.ident	"GCC: (12.2.0-14+11+b1) 12.2.0"
