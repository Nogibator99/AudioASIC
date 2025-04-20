/* Copyright (c) 2024 ETH Zurich and University of Bologna.
 * Licensed under the Apache License, Version 2.0, see LICENSE for details.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Authors:
 * - Paul Scheffler <paulsc@iis.ee.ethz.ch>
 * - Philippe Sauter <phsauter@iis.ee.ethz.ch> 
 */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY 
{
   SRAM (rwxail) : ORIGIN = 0x10000000, LENGTH = 4K
}

SECTIONS
{
  /DISCARD/ : { *(.riscv.attributes) *(.comment) }

  /* Code */
  .text._start 0x10000000 : { *(.text._start) } >SRAM
  .text : { *(.text) *(.text.*) } >SRAM

  /* Read-only data (e.g., const char[]) */
  .rodata : { *(.rodata) *(.rodata.*) } >SRAM

  /* Initialized data */
  .data : { *(.data) *(.data.*) } >SRAM

  /* Small initialized data */
  .sdata : { *(.sdata) *(.sdata.*) } >SRAM

  /* Small uninitialized data */
  .sbss : { *(.sbss) *(.sbss.*) } >SRAM

  /* Uninitialized data (zeroed at startup) */
  .bss : { *(.bss) *(.bss.*) *(COMMON) } >SRAM

  /* Global pointer in middle of sdata for GP-relative access */
  __global_pointer$ = ADDR(.sdata) + 0x800;

  /* Stack pointer at top of SRAM */
  __stack_pointer$  = ORIGIN(SRAM) + LENGTH(SRAM);

  /* Optional symbol for peripherals or debug */
  status  = 0x03000008;
}
