#include <stdio.h>
#include <stdlib.h>
#include <string.h>

FILE* fd;
int pos = 0;
int pre = 1;

#define EMPTY		0

#define REG_ZERO	0
#define REG_ZEROL	0
#define REG_ZEROH	1
#define REG_RA		2
#define REG_RAL		2
#define REG_RAH		3
#define REG_SP		4
#define REG_SPL		4
#define REG_SPH		5
#define REG_FP		6
#define REG_FPL		6
#define REG_FPH		7
#define REG_S0		6
#define REG_S1		7

#define REG_S2		8
#define REG_S3		9
#define REG_S4		10
#define REG_S5		11
#define REG_S6		12
#define REG_S7		13
#define REG_S8		14
#define REG_S9		15
#define REG_S10		16
#define REG_S11		17

#define REG_T0		18
#define REG_T1		19
#define REG_T2		20
#define REG_T3		21
#define REG_T4		22
#define REG_T5		23

#define REG_A0		24
#define REG_A1		25
#define REG_A2		26
#define REG_A3		27
#define REG_A4		28
#define REG_A5		29
#define REG_A6		30
#define REG_A7		31


#define FMT_J		9
#define FMT_B		1
#define FMT_R		7
#define FMT_I		15
#define FMT_LS		5
#define FMT_SR		13
#define FMT_LRA		11
#define FMT_HT		3

struct flag_t {
	const char* name;
	unsigned int pos;
	int count;
};

int len = 0;
struct flag_t* flags;

void init_flag() {
	flags = (struct flag_t*)malloc(1024 * sizeof(flags));
	for(int i = 0; i < 1024; i++) flags[i].count = 0;
	return;
}

void set_flag(const char* name) {
	if(!pre) return;
	flags[len].name = name;
	flags[len].pos = pos;
	len++;
	return;
}

unsigned int get_flag(const char* name) {
	for(int i = 0; i < len; i++) {
		if(strcmp(flags[i].name, name) == 0) {
			flags[i].count++;
			return flags[i].pos;
		}
	}
	printf("missing flags! name:%s\n", name);
	exit(-1);
	return 0;
}

void print_flag() {
	for(int i = 0; i < len; i++) {
		printf("symbol %s @ %x, used %d times.\n", flags[i].name, flags[i].pos, flags[i].count);
//		printf("%s\n", flags[i].name);
	}
	return;
}

#define FLAG(x)		set_flag(x)

#define FUNC_B		0
#define FUNC_BL		1
#define FUNC_BLR	5
#define FUNC_RET	2
#define FUNC_ERET	6

void j(int func3, int rd, int rb, char* flag){
	if(pre) {
		pos = pos + 4;
		return;
	}
	unsigned int inst = FMT_J + (func3 << 9);
	if(func3 == FUNC_B || func3 == FUNC_BL) {
		int imm = get_flag(flag) - ftell(fd); //pc = ftell(fd)
		if(imm > 0x3ffffff && imm < 0xffc00000) {
			printf("too far jump, func3: %d, flag: %d, imm: %d\n", func3, get_flag(flag), imm);
		}
		inst += (imm & 0x3e) << 3;
		inst += (imm & 0xffc0) << 16;
		inst += ((imm >> 16) & 0x3ff) << 12;
	} else {
		inst += rd << 12;
		inst += rb << 17;
	}
	fwrite(&inst, 4, 1, fd);
	return;
}

#define B(flag)		j(FUNC_B, EMPTY, EMPTY, flag)
#define BL(flag)	j(FUNC_BL, EMPTY, EMPTY, flag)
#define BR(rb)		j(FUNC_BLR, EMPTY, rb, EMPTY)
#define BLR(rd, rb)	j(FUNC_BLR, rd, rb, EMPTY)
#define RET()		j(FUNC_RET, EMPTY, REG_RA, EMPTY)
#define ERET(rb)	j(FUNC_ERET, EMPTY, rb, EMPTY)

#define FUNC_CBZ	1
#define FUNC_CBNZ	5
#define FUNC_CBGE	3
#define FUNC_CBLT	6
#define FUNC_CBGT	2
#define FUNC_CBLE	7

void b(int func3, int rb, char* flag){
	if(pre) {
		pos = pos + 4;
		return;
	}
	unsigned int inst = FMT_B + (func3 << 9);
	int imm = get_flag(flag) - ftell(fd); //pc = ftell(fd)
	if(imm > 0x1fffff && imm < 0xffe00000) {
		printf("too far branch, func3: %d, flag: %d, imm: %d\n", func3, get_flag(flag), imm);
	}
	inst += (imm & 0x3e) << 3;
	inst += (imm & 0xffc0) << 16;
	inst += ((imm >> 16) & 0x1f) << 12;
	inst += rb << 17;
	fwrite(&inst, 4, 1, fd);
	return;
}

#define CBZ(rb, flag)	b(FUNC_CBZ, rb, flag)
#define CBNZ(rb, flag)	b(FUNC_CBNZ, rb, flag)
#define CBGE(rb, flag)	b(FUNC_CBGE, rb, flag)
#define CBLT(rb, flag)	b(FUNC_CBLT, rb, flag)
#define CBGT(rb, flag)	b(FUNC_CBGT, rb, flag)
#define CBLE(rb, flag)	b(FUNC_CBLE, rb, flag)

#define FUNC_AU		0
#define TAG_ADD		0
#define TAG_ADC		2
#define TAG_SUB		3
#define TAG_SBB		1
#define TAG_SLT		4
#define TAG_SLTU	6

#define FUNC_LU		1
#define TAG_OR		0
#define TAG_AND		4
#define TAG_XOR		2
#define TAG_NOR		6

#define FUNC_SU		2
#define TAG_SLL		0
#define TAG_SRL		2
#define TAG_SRA		4
#define TAG_SRR		6

#define FUNC_BIT	5
#define TAG_REV		1
#define TAG_HPAK	6
#define TAG_BPAK	2
#define TAG_CLZ		5
#define TAG_BFX		4
#define TAG_XMUL	3
#define TAG_XMULH	7
#define TAG_BET		0

#define FUNC_CMOV	4
#define TAG_CMOVZ	0
#define TAG_CMOVNZ	4

#define FUNC_LEA	6

void a(int fmt, int func3, int tag3, int rs1, int rs2, int rd, int imm){
	if(pre) {
		pos = pos + 4;
		return;
	}
	unsigned int inst = fmt;
	inst += rd << 4;
	inst += func3 << 9;
	inst += rs1 << 12;
	if(fmt == FMT_R) {
		inst += rs2 << 17;
		inst += tag3 << 29;
	} else {
		inst += (imm & 0x1ffe) << 16;
		inst += tag3 << 29;
		inst += (imm & 1) << 29;
	}
	fwrite(&inst, 4, 1, fd);
	return;
}

#define ADD(rd, rs1, rs2)	a(FMT_R, FUNC_AU, TAG_ADD, rs1, rs2, rd, EMPTY)
#define ADC(rd, rs1, rs2)	a(FMT_R, FUNC_AU, TAG_ADC, rs1, rs2, rd, EMPTY)
#define SUB(rd, rs1, rs2)	a(FMT_R, FUNC_AU, TAG_SUB, rs1, rs2, rd, EMPTY)
#define SBB(rd, rs1, rs2)	a(FMT_R, FUNC_AU, TAG_SBB, rs1, rs2, rd, EMPTY)
#define SLT(rd, rs1, rs2)	a(FMT_R, FUNC_AU, TAG_SLT, rs1, rs2, rd, EMPTY)
#define SLTU(rd, rs1, rs2)	a(FMT_R, FUNC_AU, TAG_SLTU, rs1, rs2, rd, EMPTY)

#define ADDI(rd, rs1, imm)	a(FMT_I, FUNC_AU, TAG_ADD, rs1, EMPTY, rd, imm)
#define ADCI(rd, rs1, imm)	a(FMT_I, FUNC_AU, TAG_ADC, rs1, EMPTY, rd, imm)
#define SLTI(rd, rs1, imm)	a(FMT_I, FUNC_AU, TAG_SLT, rs1, EMPTY, rd, imm)
#define SLTUI(rd, rs1, imm)	a(FMT_I, FUNC_AU, TAG_SLTU, rs1, EMPTY, rd, imm)

#define OR(rd, rs1, rs2)	a(FMT_R, FUNC_LU, TAG_OR, rs1, rs2, rd, EMPTY)
#define AND(rd, rs1, rs2)	a(FMT_R, FUNC_LU, TAG_AND, rs1, rs2, rd, EMPTY)
#define XOR(rd, rs1, rs2)	a(FMT_R, FUNC_LU, TAG_XOR, rs1, rs2, rd, EMPTY)
#define NOR(rd, rs1, rs2)	a(FMT_R, FUNC_LU, TAG_NOR, rs1, rs2, rd, EMPTY)

#define ORI(rd, rs1, imm)	a(FMT_I, FUNC_LU, TAG_OR, rs1, EMPTY, rd, imm)
#define ANDI(rd, rs1, imm)	a(FMT_I, FUNC_LU, TAG_AND, rs1, EMPTY, rd, imm)
#define XORI(rd, rs1, imm)	a(FMT_I, FUNC_LU, TAG_XOR, rs1, EMPTY, rd, imm)
#define IMPI(rd, rs1, imm)	a(FMT_I, FUNC_LU, TAG_IMP, rs1, EMPTY, rd, imm)

#define SLL(rd, rs1, rs2)	a(FMT_R, FUNC_SU, TAG_SLL, rs1, rs2, rd, EMPTY)
#define SRL(rd, rs1, rs2)	a(FMT_R, FUNC_SU, TAG_SRL, rs1, rs2, rd, EMPTY)
#define SRA(rd, rs1, rs2)	a(FMT_R, FUNC_SU, TAG_SRA, rs1, rs2, rd, EMPTY)
#define SRR(rd, rs1, rs2)	a(FMT_R, FUNC_SU, TAG_SRR, rs1, rs2, rd, EMPTY)

#define SLLI(rd, rs1, imm)	a(FMT_I, FUNC_SU, TAG_SLL, rs1, EMPTY, rd, imm)
#define SRLI(rd, rs1, imm)	a(FMT_I, FUNC_SU, TAG_SRL, rs1, EMPTY, rd, imm)
#define SRAI(rd, rs1, imm)	a(FMT_I, FUNC_SU, TAG_SRA, rs1, EMPTY, rd, imm)
#define SRRI(rd, rs1, imm)	a(FMT_I, FUNC_SU, TAG_SRR, rs1, EMPTY, rd, imm)

#define REV(rd, rs1)		a(FMT_R, FUNC_BIT, TAG_REV, rs1, EMPTY, rd, EMPTY)
#define BPAK(rd, rs1, rs2)	a(FMT_R, FUNC_BIT, TAG_BPAK, rs1, rs2, rd, EMPTY)
#define CLZ(rd, rs1)		a(FMT_R, FUNC_BIT, TAG_CLZ, rs1, EMPTY, rd, EMPTY)
#define BFX(rd, rs1, rs2)	a(FMT_R, FUNC_BIT, TAG_BFX, rs1, rs2, rd, EMPTY)
#define XMUL(rd, rs1, rs2)	a(FMT_R, FUNC_BIT, TAG_XMUL, rs1, rs2, rd, EMPTY)
#define XMULH(rd, rs1, rs2)	a(FMT_R, FUNC_BIT, TAG_XMULH, rs1, rs2, rd, EMPTY)
#define BET(rd, rs1, rs2)	a(FMT_R, FUNC_BIT, TAG_BET, rs1, rs2, rd, EMPTY)

#define BPAKI(rd, rs1, imm)	a(FMT_I, FUNC_BIT, TAG_BPAK, rs1, EMPTY, rd, imm)
#define BFXI(rd, rs1, imm)	a(FMT_I, FUNC_BIT, TAG_BFX, rs1, EMPTY, rd, imm)
#define XMULI(rd, rs1, imm)	a(FMT_I, FUNC_BIT, TAG_XMUL, rs1, EMPTY, rd, imm)
#define XMULHI(rd, rs1, imm)	a(FMT_I, FUNC_BIT, TAG_XMULH, rs1, EMPTY, rd, imm)
#define BETI(rd, rs1, imm)	a(FMT_I, FUNC_BIT, TAG_BET, rs1, EMPTY, rd, imm)

#define CMOVZ(rd, rs1, rs2)	a(FMT_R, FUNC_CMOV, TAG_CMOVZ, rs1, rs2, rd, EMPTY)
#define CMOVNZ(rd, rs1, rs2)	a(FMT_R, FUNC_CMOV, TAG_CMOVNZ, rs1, rs2, rd, EMPTY)

#define CMOVZI(rd, rs1, imm)	a(FMT_I, FUNC_CMOV, TAG_CMOVZ, rs1, EMPTY, rd, imm)
#define CMOVNZI(rd, rs1, imm)	a(FMT_I, FUNC_CMOV, TAG_CMOVNZ, rs1, EMPTY, rd, imm)

//SHIFT RANGE 3bit, 1-8
#define LEA(rd, rs1, rs2, shift) a(FMT_R, FUNC_LEA, shift - 1, rs1, rs2, rd, EMPTY)

#define ZERO(rd)		a(FMT_R, FUNC_AU, TAG_ADD, REG_ZERO, REG_ZERO, rd, EMPTY)
#define ONE(rd)			a(FMT_R, FUNC_LU, TAG_NOR, REG_ZERO, REG_ZERO, rd, EMPTY)
#define MV(rd, rs)		a(FMT_R, FUNC_AU, TAG_ADD, rs, REG_ZERO, rd, EMPTY)
#define NEG(rd,rs)		a(FMT_R, FUNC_AU, TAG_SUB, REG_ZERO, rs, rd, EMPTY)

#define FUNC_L		1
#define FUNC_LR		3
#define FUNC_S		0
#define FUNC_SC		2
#define FUNC_FSH	5
#define FUNC_ZERO	6

#define TAG_LSW		1
#define TAG_LSH		0
#define TAG_LSB		2
#define TAG_LBU		3

#define FUNC_NM		0
#define FUNC_DW		4
#define FUNC_DR		2

#define TAG_W		3
#define TAG_H		2
#define TAG_L		1

void lsmr(int fmt, int func3, int tag2, int rb_ra, int rs_rd, int imm){
	if(pre) {
		pos = pos + 4;
		return;
	}
	unsigned int inst = fmt;
	inst += func3 << 9;
	inst += rs_rd << 12;
	inst += rb_ra << 17;
	inst += (imm & 0x3e) << 3;
	inst += (imm & 0x1fc0) << 16;
	inst += tag2 << 30;
	inst += (imm & 1) << 29;
	fwrite(&inst, 4, 1, fd);
	return;
}

#define LW(rd, rb, imm)		lsmr(FMT_LS, FUNC_L, TAG_LSW, rb, rd, imm)
#define LH(rd, rb, imm)		lsmr(FMT_LS, FUNC_L, TAG_LSH, rb, rd, imm)
#define LB(rd, rb, imm)		lsmr(FMT_LS, FUNC_L, TAG_LSB, rb, rd, imm)
#define LBU(rd, rb, imm)	lsmr(FMT_LS, FUNC_L, TAG_LBU, rb, rd, imm)

#define SW(rs, rb, imm)		lsmr(FMT_LS, FUNC_S, TAG_LSW, rb, rs, imm)
#define SH(rs, rb, imm)		lsmr(FMT_LS, FUNC_S, TAG_LSH, rb, rs, imm)
#define SB(rs, rb, imm)		lsmr(FMT_LS, FUNC_S, TAG_LSB, rb, rs, imm)

#define CLFLUSH(rb, imm)	lsmr(FMT_LS, FUNC_FSH, EMPTY, rb, EMPTY, imm)
#define CLZERO(rb, imm)		lsmr(FMT_LS, FUNC_ZERO, EMPTY, rb, EMPTY, imm)

#define XSRW(rd, rb, imm)	lsmr(FMT_SR, FUNC_NM, TAG_W, rb, rd, imm)
#define XSRHH(rd, rb, imm)	lsmr(FMT_SR, FUNC_NM, TAG_H, rb, rd, imm)
#define XSRH(rd, rb, imm)	lsmr(FMT_SR, FUNC_NM, TAG_L, rb, rd, imm)

#define WSRW(rd, rb, imm)	lsmr(FMT_SR, FUNC_DR, TAG_W, rb, rd, imm)
#define WSRH(rd, rb, imm)	lsmr(FMT_SR, FUNC_DR, TAG_L, rb, rd, imm)
#define WSRHH(rd, rb, imm)	lsmr(FMT_SR, FUNC_DR, TAG_H, rb, rd, imm)

#define RSRW(rd, rb, imm)	lsmr(FMT_SR, FUNC_DW, TAG_W, rb, rd, imm)
#define RSRHH(rd, rb, imm)	lsmr(FMT_SR, FUNC_DW, TAG_H, rb, rd, imm)
#define RSRH(rd, rb, imm)	lsmr(FMT_SR, FUNC_DW, TAG_L, rb, rd, imm)

#define FUNC_SRC_PC		0
#define FUNC_SRC_ZERO		1

void lra(int func3, int rd, int imm){
	if(pre) {
		pos = pos + 4;
		return;
	}
	unsigned int inst = FMT_LRA;

	inst += rd << 4;
	inst += func3 << 9;
	inst += (imm & 0x7fff) << 17;
	inst += ((imm >> 15) & 0x1f) << 12;
	fwrite(&inst, 4, 1, fd);
	return;
}

#define FUNC_USR	0
#define TAG_NOP		0
#define TAG_WFI		1
#define TAG_FENCE	2
#define TAG_SEV		4
#define TAG_WFE		6

#define FUNC_SYS	1

#define FUNC_ECALL	5
#define TAG_NM		0
#define TAG_DEBUG	1

void ht(int func3, int flag7, int tag3){
	if(pre) {
		pos = pos + 4;
		return;
	}
	unsigned int inst = FMT_HT;
	inst += func3 << 9;
	inst += flag7 << 22;
	inst += tag3 << 29;
	fwrite(&inst, 4, 1, fd);
	return;
}

#define NOP()		ht(FUNC_USR, EMPTY, TAG_NOP)
#define WFI()		ht(FUNC_USR, EMPTY, TAG_WFI)
#define ECALL()		ht(FUNC_ECALL, EMPTY, EMPTY)

void LA(int rd, char* flag) {
	int imm = 0;
	if(!pre) imm = get_flag(flag) - ftell(fd); //pc = ftell(fd)
	lra(FUNC_SRC_PC, rd, imm >> 12);
	ADDI(rd, rd, imm & 0xfff);
	return;
}

void LI(int rd, int imm) { //imm should be pow2 number
	lra(FUNC_SRC_ZERO, rd, imm >> 12);
	return;
}

void CALL(char* flag) {
	LA(REG_RA, flag);
	BLR(REG_RA, REG_RA);
	return;
}

/* qsort */
/*
void as_code(){

	FLAG("boot");
	LA(REG_A0, "vec_in"); //0
	WSRH(REG_A0, REG_ZERO, 0); //mvec //2
	LA(REG_A0, "main"); //3
	ERET(REG_A0); //5

	FLAG("vec_in");
	ADDI(REG_S0, REG_ZERO, 0x1 << 4); //6
	RSRH(REG_S1, REG_S0, 2); //7
	XORI(REG_S1, REG_S1, 5);
	WSRH(REG_S1, REG_S0, 2);

	ONE(REG_S2);
	WSRH(REG_S2, REG_S0, 0);

	RSRH(REG_S2, REG_ZERO, 1); //mepc
	ERET(REG_S2);

	FLAG("main");
	ADDI(REG_A3, REG_ZERO, 0x200);
	LI(REG_SP, 0x2000);

	ADD(REG_A0, REG_ZERO, REG_SP);
	LH(REG_A0, REG_A0, 0);

	ZERO(REG_A0);
	ZERO(REG_A1);
	ADDI(REG_A2, REG_A3, -1);
	SLLI(REG_A2, REG_A2, 1);

	BL("qsort");
	B("program_finish");

	FLAG("qsort");

	SLT(REG_A4, REG_A1, REG_A2);
	CBZ(REG_A4, "QuickSortReturn");
	OR(REG_T1, REG_A1, REG_ZERO);
	OR(REG_T2, REG_A2, REG_ZERO);
	ADD(REG_T0, REG_A0, REG_T1);
	LH(REG_T0, REG_T0, 0);

	FLAG("PartitionStart");
	FLAG("PartitionFirstStart");
	SLT(REG_T5, REG_T1, REG_T2);
	CBZ(REG_T5, "PartitionEnd");

	ADD(REG_T3, REG_A0, REG_T2);
	LH(REG_T3, REG_T3, 0);
	SLT(REG_T5, REG_T3, REG_T0);
	CBNZ(REG_T5, "PartitionFirstEnd");
	ADDI(REG_T2, REG_T2, -2);
	B("PartitionFirstStart");

	FLAG("PartitionFirstEnd");
	ADD(REG_T4, REG_A0, REG_T1);
	SH(REG_T3, REG_T4, 0);

	FLAG("PartitionSecondStart");
	SLT(REG_T5, REG_T1, REG_T2);
	CBZ(REG_T5, "PartitionEnd");

	ADD(REG_T3, REG_A0, REG_T1);
	LH(REG_T3, REG_T3, 0);
	SLT(REG_T5, REG_T0, REG_T3);

	CBNZ(REG_T5, "PartitionSecondEnd");
	ADDI(REG_T1, REG_T1, 2);

	B("PartitionSecondStart");

	FLAG("PartitionSecondEnd");

	ADD(REG_T4, REG_A0, REG_T2);
	SH(REG_T3, REG_T4, 0);
	SLT(REG_T5, REG_T1, REG_T2);
	CBNZ(REG_T5, "PartitionStart");

	FLAG("PartitionEnd");
	ADD(REG_T4, REG_A0, REG_T1);
	SH(REG_T0, REG_T4, 0);

	ADDI(REG_SP, REG_SP, -2);
	SH(REG_RA, REG_SP, 0);

	ADDI(REG_SP, REG_SP, -2);
	SH(REG_A1, REG_SP, 0);

	ADDI(REG_SP, REG_SP, -2);
	SH(REG_A2, REG_SP, 0);

	ADDI(REG_SP, REG_SP, -2);
	SH(REG_T1, REG_SP, 0);

	ADDI(REG_A2, REG_T1, -2);
	BL("qsort");

	LH(REG_T1, REG_SP, 0);
	ADDI(REG_SP, REG_SP, 2);

	LH(REG_A2, REG_SP, 0);
	ADDI(REG_SP, REG_SP, 2);

	ADDI(REG_SP, REG_SP, -2);
	SH(REG_A2, REG_SP, 0);

	ADDI(REG_SP, REG_SP, -2);
	SH(REG_T1, REG_SP, 0);

	ADDI(REG_A1, REG_T1, 2);
	BL("qsort");

	LH(REG_T1, REG_SP, 0);
	ADDI(REG_SP, REG_SP, 2);

	LH(REG_A2, REG_SP, 0);
	ADDI(REG_SP, REG_SP, 2);

	LH(REG_A1, REG_SP, 0);
	ADDI(REG_SP, REG_SP, 2);

	LH(REG_RA, REG_SP, 0);
	ADDI(REG_SP, REG_SP, 2);

	FLAG("QuickSortReturn");
	RET();

	FLAG("program_finish");
	XORI(REG_A3, REG_ZERO, 0x1f0);

	FLAG("flushloop");
	CLFLUSH(REG_A3, 0);
	ADDI(REG_A3, REG_A3, -16);
	CBNZ(REG_A3, "flushloop");
	CLFLUSH(REG_A3, 0);

	FLAG("sleep");
	WFI();
	B("sleep");

	return;
}
*/

//8Kbytes Code
//46Kbytes Data

//0x0000 - 0x0fff disk //4Kbytes
//0x1000 - 0x57ff lpc residual0 //18Kbytes
//0x5800 - 0x9fff lpc residual1 //18Kbytes
//0xa000 - 0xafff stack //4Kbytes
//0xb000 - 0xb7ff global //2Kbytes

#define GLOBAL_LANCHOR 0xb000

void as_code(){

FLAG("boot");

LA(REG_A0,"vec"); //interrupt exception entry
WSRH(REG_A0,REG_ZERO,0);

LI(REG_A0,GLOBAL_LANCHOR); //global

ADDI(REG_SP,REG_A0,-4); //stack pointer
ADDI(REG_A1,REG_ZERO,16);

CLZERO(REG_A0, 0); //coefs[0] ~ [1]
ADDI(REG_A2,REG_ZERO,1);
SH(REG_A2,REG_A0,8);
ADD(REG_A0,REG_A0,REG_A1);

CLZERO(REG_A0, 0); //coefs[2] ~ [3]
ADDI(REG_A2,REG_ZERO,2);
SH(REG_A2,REG_A0,0);
ADDI(REG_A2,REG_ZERO,-1);
SH(REG_A2,REG_A0,2);
ADDI(REG_A2,REG_ZERO,3);
SH(REG_A2,REG_A0,8);
ADDI(REG_A2,REG_ZERO,-3);
SH(REG_A2,REG_A0,10);
ADDI(REG_A2,REG_ZERO,1);
SH(REG_A2,REG_A0,12);
ADD(REG_A0,REG_A0,REG_A1);

CLZERO(REG_A0, 0); //coefs[4]
ADDI(REG_A2,REG_ZERO,4);
SH(REG_A2,REG_A0,0);
ADDI(REG_A2,REG_ZERO,-6);
SH(REG_A2,REG_A0,2);
ADDI(REG_A2,REG_ZERO,4);
SH(REG_A2,REG_A0,4);
ADDI(REG_A2,REG_ZERO,-1);
SH(REG_A2,REG_A0,6);
ADD(REG_A0,REG_A0,REG_A1);

ADDI(REG_A0,REG_ZERO,2); //enable sdhci
WSRH(REG_A0,REG_ZERO,(0x4 << 4) + 0x1);
//LI(REG_A0,4096); //set lrclk divider
ADDI(REG_A0,REG_ZERO,512);
WSRH(REG_A0,REG_ZERO,(0x3 << 4) + 0x2);
//ADDI(REG_A0,REG_ZERO,100); //set bclk divider
ADDI(REG_A0,REG_ZERO,15); //set bclk divider
WSRH(REG_A0,REG_ZERO,(0x3 << 4) + 0x1);
ADDI(REG_A0,REG_ZERO,2); //enable phy
WSRH(REG_A0,REG_ZERO,(0x3 << 4) + 0x0);

LA(REG_A0, "main"); //eret to main
ERET(REG_A0);

FLAG("vec"); //interrupt handler
ADDI(REG_T4, REG_ZERO, 0x1 << 4);
RSRH(REG_T5, REG_T4, 2);
XORI(REG_T5, REG_T5, 5);
WSRH(REG_T5, REG_T4, 2);

ONE(REG_T5);
WSRH(REG_T5, REG_T4, 0);

RSRH(REG_T5, REG_ZERO, 1);
ERET(REG_T5);

#include "main.s.h"

return;
}

int main() {
	fd = fopen("test_instructions.bin", "wb");
	init_flag();
	pre = 1;
	as_code();
	pre = 0;
	as_code();
	print_flag();
	fclose(fd);
	return 0;
}
