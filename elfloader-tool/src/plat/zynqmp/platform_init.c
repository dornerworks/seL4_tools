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

#include <autoconf.h>

#include <elfloader.h>
#include <sys_fputc.h>
#include <cpuid.h>

#include <platform.h>

void platform_init(void)
{
    enable_uart();

#ifdef CONFIG_ARM_HYPERVISOR_SUPPORT
    if(is_el3())
    {
#ifdef CONFIG_ARM_SMMU
       /*
          Peripherals default to secure, which doesn't work with a hypervisor
          that is by definition non-secure.  Set perpipherals used by the
          system to non-secure.
       */
       uint32_t *reg = (uint32_t*)IOU_SECURE_SCLR_WR;
       uint32_t val = *reg;

       val &= ~IOU_SECURE_SLCR_DEVMASK(GEM0);
       val |= IOU_SECURE_SLCR_DEVBITS(IOU_SECURE_SLCR_NS, GEM0);

       *reg = val;

       reg = (uint32_t*)IOU_SECURE_SCLR_RD;
#endif

       leave_el3();
    }
#endif

}
