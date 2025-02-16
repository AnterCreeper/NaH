`timescale 1ns/1ps

`define FMT_J       4'b1001
`define FMT_B       4'b0001
`define FMT_R       4'b0111
`define FMT_I       4'b1111
`define FMT_LS      4'b0101
`define FMT_SR      4'b1101
`define FMT_LRA     4'b1011
`define FMT_HT      4'b0011

//alias
`define FMT_jump    3'b001 //FMT_J + FMT_B
`define FMT_arith   3'b111 //FMT_R + FMT_I
`define FMT_bus     3'b101 //FMT_LS + FMT_SR

`define FUNC_B      3'b000
`define FUNC_BL     3'b001
`define FUNC_BLR    3'b101
`define FUNC_RET    3'b010
`define FUNC_ERET   3'b110

`define FUNC_CBZ    3'b001
`define FUNC_CBNZ   3'b101
`define FUNC_CBGE   3'b011
`define FUNC_CBLT   3'b110
`define FUNC_CBGT   3'b010
`define FUNC_CBLE   3'b111

`define FUNC_AU     3'b000
`define FUNC_LU     3'b001
`define FUNC_SU     3'b010
`define FUNC_BIT    3'b101
`define FUNC_CMOV   3'b100
`define FUNC_LEA    3'b110

`define TAG_ADD     3'b000 //I
`define TAG_ADC     3'b010 //I
`define TAG_SUB     3'b011
`define TAG_SBB     3'b001
`define TAG_SLT     3'b100 //I
`define TAG_SLTU    3'b110 //I

`define TAG_OR      3'b000 //I
`define TAG_AND     3'b100 //I
`define TAG_XOR     3'b010 //I
`define TAG_NOR     3'b110 //I

`define TAG_SLL     3'b000 //I
`define TAG_SRL     3'b010 //I
`define TAG_SRA     3'b100 //I
`define TAG_SRR     3'b110 //I

`define TAG_REV     3'b001
`define TAG_HPAK    3'b110 //I
`define TAG_BPAK    3'b010 //I
`define TAG_CLZ     3'b101
`define TAG_BFX     3'b100 //I
`define TAG_XMUL    3'b011
`define TAG_XMULH   3'b111
`define TAG_BET     3'b000 //I

`define TAG_CMOVZ   3'b000
`define TAG_CMOVNZ  3'b100

`define FUNC_L      3'b001
`define FUNC_LR     3'b011
`define FUNC_S      3'b000
`define FUNC_SC     3'b010
`define FUNC_FSH    3'b101
`define FUNC_ZERO   3'b110

`define TAG_LSW     2'b01
`define TAG_LSH     2'b00
`define TAG_LSB     2'b10
`define TAG_LBU     2'b11

`define FUNC_NM     3'b000
`define FUNC_DW     3'b100
`define FUNC_DR     3'b010

`define TAG_W     2'b11
`define TAG_H     2'b10
`define TAG_L     2'b01

`define FUNC_LRA_PC     3'b000
`define FUNC_LRA_ZERO   3'b001

`define FUNC_USR    3'b000

`define TAG_NOP     3'b000
`define TAG_WFI     3'b001
`define TAG_FENCE   3'b010
`define TAG_SEV     3'b100
`define TAG_WFE     3'b110

`define FUNC_SYS    3'b001

`define FUNC_ECALL  3'b101
`define TAG_NM      3'b000
`define TAG_DEBUG   3'b001

`define EVB_MASK_W      2'b11
`define EVB_MASK_H      2'b10
`define EVB_MASK_L      2'b01
`define EVB_MASK_DUMMY  2'b00
