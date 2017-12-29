/*
 *----------------------------------------------------------------------
 *    T-Kernel 2.0 Software Package
 *
 *    Copyright 2011 by Ken Sakamura.
 *    This software is distributed under the latest version of T-License 2.x.
 *----------------------------------------------------------------------
 *
 *    Released by T-Engine Forum(http://www.t-engine.org/) at 2011/05/17.
 *    Modified by T-Engine Forum at 2013/02/28.
 *    Modified by TRON Forum(http://www.tron.org/) at 2015/06/01.
 *
 *----------------------------------------------------------------------
 */

/*
 *	base on monitor/driver/sio/src/ns16550.c
 *
 *       serial port I/O
 */

#include <tmonitor.h>

/*
 * serial port hardware configuration definition
 */
typedef struct {
	UW	iob;		/* I/O base address */
} DEFSIO;

#ifdef _TEF_EM1D_

#include <arm/em1d512.h>

   LOCAL const DEFSIO	DefSIO[1] = {
			{ 0x80074000 },
   };

#endif

#define	N_DEFSIO	( sizeof(DefSIO) / sizeof(DEFSIO) )
#define	IOB	( scb->info )		/* I/O base address */

#define	RSDRV_PWON(siocb)		/* no operation */

#define HW_UARTDBG_FR	0x80074018
#define TXFE		(1<<7)
#define RXFF		(1<<6)
#define TXFF		(1<<5)
#define RXFE		(1<<4)


#define HW_UARTDBG_DR	0x80074000

/*
 * debug serial port
 */
int __tsc(int flag)
{
	volatile int *r1 = (void *)HW_UARTDBG_FR;
	flag &= r1[0];
	return flag;
}

int __kgetc(void)
{
	volatile unsigned char *r0 = (void *)HW_UARTDBG_DR;
	return r0[0];
}

int __kputc(int ch)
{
	volatile unsigned char *r1 = (void *)HW_UARTDBG_DR;
	r1[0] = ch;
	return ch;
}

int kgetc(int tmo)
{
	while(__tsc(RXFE)) {
		if(tmo--<=0) return -1;
	}
	return __kgetc();
}

int kgetchar(void)
{
	while(__tsc(RXFE));
	return __kgetc();
}

int kputc(int ch)
{
	while(__tsc(TXFF) != 0);
	return __kputc(ch);
}

int kputs(const char *s)
{
	char ch;
	while(ch = *s++) {
		kputc(ch);
	}
	kputc('\r');
	kputc('\n');
}

/*
 * serial port I/O
 */
LOCAL	void putSIO_imx28x( SIOCB *scb, UB c )
{
	RSDRV_PWON(scb);

        /* wait until transmission is ready. */
	while ((in_w(HW_UARTDBG_FR) & TXFF) != 0);

        /* write transmission data */
	out_b(HW_UARTDBG_DR, c);

	return;
}

/*
 * serial port input
 *       tmo     timeout (milliseconds)
 *              You can not wait forever.
 *       return value       >= 0 : character code
 *                 -1 : timeout
 *       input data using buffer.
 *       receive error is ignored.
 */
LOCAL	W getSIO_imx28x(SIOCB *scb, W tmo )
{
	W	sts, err, c = 0;

	RSDRV_PWON();

	tmo *= 1000/20;		/* convert tmo to 20 usec units */

        /* receive as much data as possible in the receive buffer */
	while (scb->iptr - scb->optr < SIO_RCVBUFSZ) {
		sts = in_w(HW_UARTDBG_FR);
		err = 0;

                /* is there data in FIFO? */
		if((sts & RXFE) || err & 0x00000F00 ) {
			if (scb->iptr != scb->optr) break;  /* already received */
			if (tmo-- <= 0) break;		    /* timeout */
			waitUsec(20);
			continue;
		}

                /* receive data input */
		if ((sts & RXFE) == 0) c = in_b(HW_UARTDBG_DR);

                /* error check */
		if (err & 0x00000F00) continue;

                /* set data to rcvbuf */
		scb->rcvbuf[scb->iptr++ & SIO_PTRMSK] = c;
	}

        /* return the data in rcvbuf */
	return (scb->iptr == scb->optr)?
			-1 : scb->rcvbuf[scb->optr++ & SIO_PTRMSK];
}

/* ------------------------------------------------------------------------ */

/*
 * initialize serial port
 *       serial port that is supported by the initialization of CFGSIO
 *       speed   communication speed (bps)
 *       initialize the serial port according to the specified parameters and set SIOCB
 *       SIOCB is given in 0-cleared state initially.
 *       Subsequent I/O operations uses the SIOCB.
 *
 *       Only for PC/AT version
 *      if speed = 0, we use the value in biosp->siomode.
 *       But we use only the transmission speed and other settings are ignored.
 *       Efforts were made to be compatible B-right/V, but because of the ignorance of no-speed settings such as data length and stop bit length,
 *       we have reduced functionality.
 */
EXPORT ER initSIO_imx28x(SIOCB *scb, const CFGSIO *csio, W speed)
{
	UH	div;
	W ch;

	if ( (UW)csio->info >= N_DEFSIO ) return E_PAR;

        /* select the target port */
	scb->info = DefSIO[csio->info].iob;

	scb->iptr = 0;
	scb->optr = 0;
	scb->rcvbuf[0] = 0;

        /* I/O function default */
	scb->put = putSIO_imx28x;
	scb->get = getSIO_imx28x;

	while(0) {
		ch = scb->get(scb, 1<<7);
		scb->put(scb, ch);
	}


	return E_OK;
}
