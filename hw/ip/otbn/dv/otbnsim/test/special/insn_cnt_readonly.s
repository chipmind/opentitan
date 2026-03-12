/* Copyright 2026 Chipmind AG. */
/* Solderpad Hardware License, Version 0.51, see LICENSE for details. */
/* SPDX-License-Identifier: SHL-0.51 */
/*
 * Designed by: Chipmind Agents
 * Module:      insn_cnt_readonly
 */

/*
 * Test that INSN_CNT is read-only
 * Try to write to CSR 0xfe1 and verify writes are ignored
 */

.text
.globl _start
_start:
  /* Read initial INSN_CNT (should be 0) */
  csrrs x1, 0xfe1, x0
  
  /* Try to write 0xFFFFFFFF to INSN_CNT using csrrw */
  addi x5, x0, -1
  csrrw x2, 0xfe1, x5
  
  /* Read INSN_CNT again - should be 3, not 0xFFFFFFFF */
  /* (after csrrs, addi, csrrw - writes are ignored) */
  csrrs x3, 0xfe1, x0
  
  /* Try to set bits using csrrs */
  lui x6, 0xABCDE
  csrrs x4, 0xfe1, x6
  
  /* Read INSN_CNT again - should be 6, not modified by set */
  csrrs x7, 0xfe1, x0
  
  ecall
