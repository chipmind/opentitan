/* Copyright 2026 Chipmind AG. */
/* Solderpad Hardware License, Version 0.51, see LICENSE for details. */
/* SPDX-License-Identifier: SHL-0.51 */
/*
 * Designed by: Chipmind Agents
 * Module:      insn_cnt_csr_addr
 */

/*
 * Test that INSN_CNT can be read at multiple points and increments
 * Read CSR 0xfe1 multiple times to verify it increments
 */

.text
.globl _start
_start:
  /* Read INSN_CNT after 0 instructions */
  csrrs x1, 0xfe1, x0
  
  /* Execute one instruction */
  addi x5, x0, 100
  
  /* Read INSN_CNT again - should be 2 (after csrrs and addi) */
  csrrs x2, 0xfe1, x0
  
  /* Execute one more instruction */
  addi x6, x0, 200
  
  /* Read INSN_CNT again - should be 4 (after 2 csrrs + 2 addi) */
  csrrs x3, 0xfe1, x0
  
  ecall
