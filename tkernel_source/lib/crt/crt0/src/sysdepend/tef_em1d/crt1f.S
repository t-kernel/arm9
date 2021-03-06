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
 *	crt1f.S
 *
 *	C startup
 *
 *	Static link version
 *	Shared library loader is not linked.
 */

#include <machine.h>

	.data
	.globl	Csym(__initloading)
	.globl	Csym(__callinit)
	.globl	Csym(__callfini)

	.balign	4
Csym(__initloading):	.int	initloading
Csym(__callinit):	.int	Csym(_init)
Csym(__callfini):	.int	Csym(_fini)

	.text
	.balign	4
initloading:
	/* do nothing */
	bx lr
