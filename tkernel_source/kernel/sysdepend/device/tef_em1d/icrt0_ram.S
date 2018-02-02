/*
 *----------------------------------------------------------------------
 *    T-Kernel 2.0 Software Package
 *
 *    Copyright 2011 by Ken Sakamura.
 *    This software is distributed under the latest version of T-License 2.x.
 *----------------------------------------------------------------------
 *
 *    Released by T-Engine Forum(http://www.t-engine.org/) at 2011/05/17.
 *    Modified by TRON Forum(http://www.tron.org/) at 2015/06/01.
 *
 *----------------------------------------------------------------------
 */

/*
 *	icrt0_ram.S (EM1-D512)
 *	System Startup
 */

#include <machine.h>
#include <tk/asm.h>

#if _Csym == 0
#define	START	_start
#else
#define	START	start
#endif

	/* Low level memory manager information */
	.comm	Csym(lowmem_top), 4	// Head of area (Low address)
	.comm	Csym(lowmem_limit), 4	// End of area (High address)

	.lcomm	monitor_stacktop, 4	// Monitor stack pointer for re-startup

#define	SYSINFO		0x30004400	// System common information
#define	RAM_TOP		(SYSINFO + 0)	// Head of ext. RAM free area
#define	RAM_END		(SYSINFO + 4)	// End of ext. RAM free area
#define	SYSCONF		(SYSINFO + 8)	// SYSCONF top

	.text
	.balign	4
	.globl	START
	.type	START, %function
START:
	/* Use the stack set by the monitor */
	ldr	ip, =PSR_SVC|PSR_DI|PSR_F	// SVC mode/Interrupt disable
	msr	cpsr_xc, ip

	/* MMU is already ON. The initial setting is done.
	   Only cache should be ON */
#ifdef CONFIG_MMU
	mrc	p15, 0, r4, cr1, c0
	orr	r4, r4, #CR1_C
	orr	r4, r4, #CR1_I|CR1_Z
	mcr	p15, 0, r4, cr1, c0
	ldr	r4, =0
	mcr	p15, 0, r4, cr7, c7, 0	// Cache flush
#endif

	ldr	r5, =__data_org		// Initialization of 'data' area (ROM startup)
	ldr	r6, =__data_start
	subs	r10, r5, r6		// If r10 != 0, start Rom
	beq	nocopy_data
	ldr	r7, =_edata
	cmp	r6, r7
	bhs	nocopy_data
  copy_data:
	ldr	r4, [r5], #4
	str	r4, [r6], #4
	cmp	r6, r7
	blo	copy_data
  nocopy_data:

	ldr	r4, =0			// Clear 'bss' area
	ldr	r5, =__bss_start
	ldr	r6, =_end
	cmp	r5, r6
	bhs	nobss
  clrbss:
	str	r4, [r5], #4
	cmp	r5, r6
	blo	clrbss
  nobss:

	ldr	ip, =monitor_stacktop	// Monitor stack pointer for re-startup
	str	sp, [ip]		// Save
	bic	sp, sp, #7		// align stack module 8 bytes

	ldr	ip, =RAM_TOP		// Low level memory manager initial setting
	ldr	r5, [ip]
	cmp	r6, r5			// _end or RAM_TOP
	movhi	r5, r6			// Either of High addresses
	ldr	ip, =lowmem_top
	str	r5, [ip]		// lowmem_top = _end or RAM_TOP
	ldr	ip, =RAM_END
	ldr	r5, [ip]
	ldr	ip, =lowmem_limit
	str	r5, [ip]		// lowmem_limit = RAM_END

	ldr	r4, =SYSCONF
	ldr	r5, [r4]
	cmp	r5, #0
	bleq	l1
	
	cmp	r10, #0
	bleq	l2

  l1:
	bl	Csym(ROM_startup)	// Initialization at ROM startup

  l2:
	bl	Csym(main)		// System startup

  l_end:				// Not suppose to return from 'main,'
	b	l_end			// but, just in case, prepare for out of control.

@
	.globl	kputc
kputc:
1:	ldr	r1, =0x80074018
	ldr	r1, [r1]
	tst	r1, #(1<<5)
	bne	1b

	ldr	r1, =0x80074000
	strb	r0, [r1]
	bx	lr

	.globl	kgetc
kgetc:
	ldr	r3, =0x80074018
	ldr	r3, [r3]
	tst	r3, #(1<<4)
	bne	kgetc

	ldr	r3, =0x80074000
	ldrb	r0, [r3]
	bx	lr

	.globl	kputs
kputs:
	mov	r3, lr
	bl	_puts
	mov	r0, #'\r'
	bl	kputc
	mov	r0, #'\n'
	bl	kputc
	bx	r3

	.globl	_puts
_puts:
1:	ldrb	r2, [r0], #1
	cmp	r2, #0
	bxeq	lr

2:	ldr	r1, =0x80074018
	ldr	r1, [r1]
	tst	r1, #(1<<5)
	bne	2b

	ldr	r1, =0x80074000
	strb	r2, [r1]

	b	1b


	.globl	kputx
	.globl	kputp
kputp:
	ldr	r0, [r0]
kputx:
	mov	r3, #8
	ldr	r1, =0x80074000

__tsc:	ldr	r2, [r1, #0x18]
	tst	r2, #(1<<5)
	bne	__tsc

	ror	r0, r0, #28
	and	r2, r0, #15

	cmp	r2, #9
	addle	r2, #'0'
	addgt	r2, #('A'-10)

	strb	r2, [r1]

	subs	r3, #1
	bne	__tsc

	bx	lr

	.globl	kgets
kgets:
	bx	lr

