/*
 * Copyright 2017, Data61
 * Commonwealth Scientific and Industrial Research Organisation (CSIRO)
 * ABN 41 687 119 230.
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(DATA61_GPL)
 */

#include <assembler.h>
#include <armv/assembler.h>

.text

.extern flush_dcache
.extern invalidate_dcache
.extern invalidate_icache
.extern _boot_pgd_down

BEGIN_FUNC(disable_caches_hyp)
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    bl      flush_dcache
    disable_id_cache sctlr_el2, x9
    ldp     x29, x30, [sp], #16
    ret
END_FUNC(disable_caches_hyp)

BEGIN_FUNC(leave_hyp)
    /* We call nested functions, follow the ABI. */
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    bl      flush_dcache

    /* Ensure I-cache, D-cache and mmu are disabled for EL2/Stage1 */
    disable_mmu sctlr_el2, x9

    /*
     * Invalidate the local I-cache so that any instructions fetched
     * speculatively are discarded.
     */
    bl      invalidate_icache

    /* Ensure I-cache, D-cache and mmu are disabled for EL1/Stage2 */
    mov     x9, #(1 << 31)
    msr     hcr_el2, x9

    /* Ensure traps to EL2 are disabled */
    mov     x9, #0x33ff
    msr     cptr_el2, x9
    msr     hstr_el2, xzr
    msr     vttbr_el2, xzr

    /* Ensure I-cache, D-cache and mmu are disabled for EL1/Stage1 */
    disable_mmu sctlr_el1 , x9

    mov     x9, #(PSR_F_BIT | PSR_I_BIT | PSR_A_BIT | PSR_D_BIT | PSR_MODE_EL1h)
    msr     spsr_el2, x9

    /* Let's the caller use our stack, in case it needs to pop something */
    ldp     x29, x30, [sp], #16
    mov     x10, sp
    msr     sp_el1, x10
    msr     elr_el2, x30
    eret
END_FUNC(leave_hyp)

BEGIN_FUNC(arm_enable_hyp_mmu)
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    bl      flush_dcache

    disable_mmu sctlr_el2, x8

    bl      invalidate_icache

    /*
     *   DEVICE_nGnRnE      000     00000000
     *   DEVICE_nGnRE       001     00000100
     *   DEVICE_GRE         010     00001100
     *   NORMAL_NC          011     01000100
     *   NORMAL             100     11111111
     */
    ldr     x5, =MAIR(0x00, MT_DEVICE_nGnRnE) | \
                 MAIR(0x04, MT_DEVICE_nGnRE) | \
                 MAIR(0x0c, MT_DEVICE_GRE) | \
                 MAIR(0x44, MT_NORMAL_NC) | \
                 MAIR(0xff, MT_NORMAL)
    msr     mair_el2, x5
    ldr     x8, =TCR_T0SZ(48) | TCR_IRGN0_WBWC | TCR_ORGN0_WBWC | TCR_SH0_ISH | TCR_TG0_4K | TCR_PS_16T | TCR_EL2_RES1
    msr     tcr_el2, x8
    isb

    adrp    x8, _boot_pgd_down
    msr     ttbr0_el2, x8
    isb

    tlbi    alle2is
    dsb     ish
    isb

    enable_mmu  sctlr_el2, x8
    ic  ialluis
    dsb ish
    isb
    tlbi    alle2is
    dsb     ish
    isb
    ldp     x29, x30, [sp], #16
    ret
END_FUNC(arm_enable_hyp_mmu)

BEGIN_FUNC(leave_el3)
    /* We call nested functions, follow the ABI. */
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    /* Disable caches and MMU in EL3 */
    disable_mmu sctlr_el3, x19
    bl      flush_dcache
    bl      invalidate_icache

    /* Disable coprocessor traps to EL3&2 */
    msr     cptr_el3, xzr

    mov     x19, #0x33ff /* RES1 bits */
    msr     cptr_el2, x19

    /* Initialize EL2 */
    msr     cntvoff_el2, xzr

    ldr     x19, =0x30C50830 /* RES1 bits */
    msr     sctlr_el2, x19

    /* EL2 is AArch64 and Non-secure EL1/0 */
    mov     x19, #(SCR_RW_BIT | SCR_HCE_BIT | SCR_SMD_BIT | SCR_NS_BIT)
    msr     scr_el3, x19

    /* Return to the EL2_SP2 mode from EL3 with MMUs and cache disabled */
    mov     x19, #(PSR_F_BIT | PSR_I_BIT | PSR_A_BIT | PSR_D_BIT | PSR_MODE_EL2h)
    msr     spsr_el3, x19

    ldp     x29, x30, [sp], #16
    mov     x28, sp
    msr     sp_el2, x28

    msr     elr_el3, x30

    /* Return to EL2 */
    eret
END_FUNC(leave_el3)
