/* Copyright 2026 Chipmind AG. */
/* Solderpad Hardware License, Version 0.51, see LICENSE for details. */
/* SPDX-License-Identifier: SHL-0.51 */
/*
 * Designed by: Chipmind Agents
 * Module:      insn_cnt_increment
 */

/*
 * Test that INSN_CNT increments correctly
 * Execute 4 addi instructions, then read CSR 0xfe1
 * Expected: x6 should contain 4 (the count before the CSR read)
 */

.text
.globl _start
_start:
  /* Execute 4 addi instructions */
  addi x5, x0, 1
  addi x2, x0, 2
  addi x3, x0, 3
  addi x4, x0, 4
  
  /* Read INSN_CNT CSR (address 0xfe1) into x6 */
  /* The count should be 4 (before this instruction executes) */
  csrrs x6, 0xfe1, x0
  
  ecall
