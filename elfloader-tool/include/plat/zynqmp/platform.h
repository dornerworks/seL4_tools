/*
 * Copyright 2017, DornerWorks
 * Copyright 2017, Data61
 * Commonwealth Scientific and Industrial Research Organisation (CSIRO)
 * ABN 41 687 119 230.
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(DATA61_DORNERWORKS_GPL)
 */
/*
 * This data was produced by DornerWorks, Ltd. of Grand Rapids, MI, USA under
 * a DARPA SBIR, Contract Number D16PC00107.
 *
 * Approved for Public Release, Distribution Unlimited.
 */

#ifndef _PLATFORM_H_
#define _PLATFORM_H_

#define ZYNQMP_UART0_BASE        0xFF000000
#define ZYNQMP_UART1_BASE        0xFF010000

#define UART_PPTR              ZYNQMP_UART0_BASE

#define IOU_SECURE_SCLR_WR       0xFF240000
#define IOU_SECURE_SCLR_RD       0xFF240000

#define IOU_SECURE_SLCR_PRIV     0x1
#define IOU_SECURE_SLCR_NS       0x2
#define IOU_SECURE_SLCR_INST     0x4

#define IOU_SECURE_SLCR_BITS     3

#define IOU_SECURE_SLCR_DEVMASK(x) (0x7 << (x))
#define IOU_SECURE_SLCR_DEVBITS(x,y) (((x) & IOU_SECURE_SLCR_DEVMASK(x)) \
                                      << ((y) * IOU_SECURE_SLCR_BITS))

enum iou_secure_slcr_dev
{
   GEM0 = 0,
   GEM1,
   GEM2,
   GEM3,
   RES,
   SD0,
   SD1,
   NAND,
   QSPI,
   NUM_IOU_SECURE_SLCR_DEVS,
};

#endif /* _PLATFORM_H_ */
