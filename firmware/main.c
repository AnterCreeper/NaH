#define TARGET_NRA
#ifdef TARGET_NRA
#define NULL (void*)0
#else
//#define TEST
#endif

#ifdef TARGET_NRA
#define exit(x) return x;
#else
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#endif

#define DISK_SR_BASE_ADDRESS 0x4
#define FLAC_SR_BASE_ADDRESS 0x2

#define DISK_HEAP_ADDRESS 0x0000
#define DISK_BUFFER_ADDRESS 0x0000 + 0x200

#define DISK_START_POS 0x1000

#define RES_ADDRESS 0x1000
#define RES_PAGE_SIZE 0x4800

#define likely(x)      __builtin_expect(!!(x), 1)
#define unlikely(x)    __builtin_expect(!!(x), 0)

#define clflush()						\
({								\
	__asm__ __volatile__ ("clflush\t");			\
})

#define csr_write(csr, val)					\
({								\
	unsigned long __v = (unsigned long)(val);		\
	__asm__ __volatile__ ("wsrh\t%0,%1"			\
			      : : "r" (__v),			\
				  "r" (csr));			\
})

#define csr_writehi(csr, val)					\
({								\
	unsigned long __v = (unsigned long)(val);		\
	__asm__ __volatile__ ("wsrhh\t%0,%1"			\
			      : : "r" (__v),			\
				  "r" (csr));			\
})

struct bitstream {
#ifndef TARGET_NRA
	FILE* fd;	//file description
#endif
	int bytepos;	//heap position
	int bitlen;	//bit length
	unsigned char* heap;
	unsigned char* buffer;
};

typedef struct {
	int l;
	int h;
} largeint_t;

void bitstream_init(char* filename, struct bitstream* inp) {
	inp->bytepos = 0;
	inp->bitlen  = 8;
#ifdef TARGET_NRA
	inp->heap = (unsigned char*)DISK_HEAP_ADDRESS;
	inp->buffer = (unsigned char*)DISK_BUFFER_ADDRESS;
	int addr;
	addr = (DISK_SR_BASE_ADDRESS << 4) + 0x0;
	csr_write(addr, DISK_START_POS);
	addr = (DISK_SR_BASE_ADDRESS << 4) + 0x2;
	csr_write(addr, inp->heap);
	addr = (DISK_SR_BASE_ADDRESS << 4) + 0x2;
	csr_write(addr, inp->buffer); //will be block to wait previous one done
#else
	inp->fd = fopen(filename, "rb");
	inp->heap = (char*)malloc(512);
	inp->buffer = (char*)malloc(512);
	fread(inp->heap, 1, 512, inp->fd);
	fread(inp->buffer, 1, 512, inp->fd);
#endif
	return;
}

void bitstream_close(struct bitstream* inp){
#ifndef TARGET_NRA
	fclose(inp->fd);
	free(inp->heap);
	free(inp->buffer);
#endif
}

void bitstream_swapin(struct bitstream* inp) {
	unsigned char* tmp;
	tmp = inp->buffer;
	inp->buffer = inp->heap;
	inp->heap = tmp; //swap buffer to heap
#ifdef TARGET_NRA
	clflush();
	int addr;
	addr = (DISK_SR_BASE_ADDRESS << 4) + 0x2;
	csr_write(addr, inp->buffer);
#else
	fread(inp->buffer, 1, 512, inp->fd); //issue a async read 1 page into buffer
#endif
	return;
}

void bitstream_prepare(struct bitstream* inp) {
	if(inp->bytepos == 511) {
		bitstream_swapin(inp);
		inp->bytepos = 0;
	} else ++inp->bytepos;
	inp->bitlen = 8;
	return;
}

unsigned int bitstream_readbits(int len, struct bitstream* inp) {
	unsigned int dst;
	if (len == 0) return 0;
	if (inp->bitlen < len) {
		dst = inp->heap[inp->bytepos] << 8;
		dst = dst >> (16 - len);
		len = len - inp->bitlen;
		bitstream_prepare(inp);
		dst = dst | bitstream_readbits(len, inp);
	} else {
		dst = inp->heap[inp->bytepos] >> (8 - len);
		inp->heap[inp->bytepos] = inp->heap[inp->bytepos] << len;
		inp->bitlen = inp->bitlen - len;
	}
	return dst;
}

int bitstream_readunary(struct bitstream* inp) {
	int val = 0;
	if (inp->heap[inp->bytepos] == 0) {
		val = inp->bitlen;
		bitstream_prepare(inp);
		val += bitstream_readunary(inp);
	} else {
#ifdef TARGET_NRA
		val = __builtin_clz(inp->heap[inp->bytepos]) - 8;
#else
		val = __builtin_clz(inp->heap[inp->bytepos]) - 24;
#endif
		int x = val + 1;
		inp->heap[inp->bytepos] <<= x;
		inp->bitlen -= x;
	}
	return val;
}

largeint_t bitstream_readrice(int len, struct bitstream* inp) {
	int msb = bitstream_readunary(inp);
	largeint_t result;
	if(len == 0) {
		result.l = (msb >> 1) ^ -(msb & 1);
		result.h = result.l < 0 ? -1 : 0;
	} else {
		int x;
		result.l = (msb << (len - 1)) | bitstream_readbits(len - 1, inp);
//		result.h = msb >> (17 - len);
		result.h = 0; //should no bits enter high register, as the max bits is 17bits, and one is left below, so only 16bits and all fits in the low reg.
		int zigzag = -bitstream_readbits(1, inp);
		result.l ^= zigzag;
		result.h ^= zigzag;
	}
	return result;
}

void bitstream_align(struct bitstream* inp) {
	if(inp->bitlen != 8) bitstream_prepare(inp);
	return;
}

void bitstream_alignread(unsigned char* dst, struct bitstream* inp) {
	*dst = inp->heap[inp->bytepos];
	bitstream_prepare(inp);
	return;
}

void bitstream_alignpass(struct bitstream* inp) {
	bitstream_prepare(inp);
	return;
}

//17bits, excluding the most positive value, 17'h0ffff
void write_residuals(short* residuals, int* pos, largeint_t input){
#ifdef TEST
	printf("pos%10d result.h:%10d result.l:%10d\n", 1, input.h < 0 ? 65536 + input.h : input.h, input.l < 0 ? 65536 + input.l : input.l);
#endif
	int loc = *pos;
	if(input.h != 0 && input.l == -1) {
		residuals[loc++] = -1;
	} else {
	if((input.h == 0 && input.l < 0) || (input.h != 0 && input.l >= 0))
		residuals[loc++] = -1;
	}
	residuals[loc++] = input.l;
	*pos = loc;
	return;
}

int decode_residuals(int lpcorder, int blocksize, short* residuals, struct bitstream* inp){

	int method = bitstream_readbits(2, inp);
#ifndef TARGET_NRA
	if(method >= 2) {
		printf("reserved residual coding method\n");
		exit(-1);
	}
	if(method == 1) {
		printf("doesn't support 5-bit residual coding method\n");
		exit(-1);
	}
#endif

	int partitionorder = bitstream_readbits(4, inp);
	int numpartitions = 1 << partitionorder;

#ifndef TARGET_NRA
	if (blocksize % numpartitions != 0) {
		printf("Block size not divisible by number of Rice partitions\n");
		exit(-1);
	}
#endif

	const int parambits = 4; //method == 0 ? 4 : 5;
	const int escapeparam = 0xf; //method == 0 ? 0xf : 0x1f;

	int k = 0;

	int count = blocksize >> partitionorder;
	for(int i = 0; i < numpartitions; i++) {
		int n = i == 0 ? count - lpcorder : count;
		int param = bitstream_readbits(parambits, inp);
		if (param < escapeparam) {
			for (int j = 0; j < n; j++) write_residuals(residuals, &k, bitstream_readrice(param, inp));
		} else {
			int numbits = bitstream_readbits(5, inp);
			for (int j = 0; j < n; j++) write_residuals(residuals, &k, bitstream_readrice(numbits, inp));
		}
	}
	return 0;
}

const short fixed_coefs[5][4] = {{}, {1}, {2, -1}, {3, -3, 1}, {4, -6, 4, -1}};

#ifndef TARGET_NRA
FILE* fd_tb;
FILE* fd_mem;
#endif

int decodesubframe(int blocksize, int samplebits, int channum, struct bitstream* inp) {

	int header = bitstream_readbits(8, inp);

	int type = header >> 1;
	int wasted = header & 1;

	if (wasted) {
		while(bitstream_readbits(1, inp) == 0) {
		//assume that there are not a lot of wasted bits, since readbits function is inefficient.
			wasted++;
		}
	}
	samplebits = samplebits - wasted;

	int cmd, data;
	cmd = 0x9; data = wasted;
#ifdef TARGET_NRA
	int addr;
	addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
	csr_write(addr, data);
#else
	fwrite(&cmd, 4, 1, fd_tb);
	fwrite(&data, 4, 1, fd_tb);
#endif

	if (type == 0) {
//		printf("const\n");
		largeint_t x;
		if(samplebits > 16) {
			x.h = bitstream_readbits(samplebits - 1, inp);
			x.l = bitstream_readbits(16, inp);
		} else {
			x.l = bitstream_readbits(samplebits, inp);
			x.h = x.l < 0 ? 1 : 0;
		}

		cmd = 0x0;
#ifdef TARGET_NRA
		addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
		csr_write(addr, x.l);
		csr_writehi(addr, x.h);
#else
		data = (x.h << 16) + (unsigned int)x.l;
		fwrite(&cmd, 4, 1, fd_tb);
		fwrite(&data, 4, 1, fd_tb);
#endif
	} else
	if (type == 1) {
//		printf("verbatim\n");
#ifdef TARGET_NRA
		short* mem = (short*)(RES_ADDRESS + channum * RES_PAGE_SIZE);
#else
		short* mem = (short*)malloc(RES_PAGE_SIZE);
		memset(mem, 0, RES_PAGE_SIZE);
#endif

#ifdef TARGET_NRA
		int pos = (unsigned int)mem;
#else
		int pos = ftell(fd_mem);
#endif

		int k = 0;
		for(int i = 0; i < blocksize; i++) {
			largeint_t x;
			if(samplebits > 16) {
				x.h = bitstream_readbits(samplebits - 16, inp);
				x.l = bitstream_readbits(16, inp);
			} else {
				x.h = bitstream_readbits(1, inp) == 1 ? 1 : 0;
				x.l = bitstream_readbits(samplebits - 1, inp) | ((-x.h) << (samplebits - 1));
			}
			write_residuals(mem, &k, x);
		}

		cmd = 0x1; data = pos;
#ifdef TARGET_NRA
		clflush();
		addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
		csr_write(addr, data);
#else
		fwrite(&cmd, 4, 1, fd_tb);
		fwrite(&data, 4, 1, fd_tb);
		fwrite(mem, 2, RES_PAGE_SIZE/2, fd_mem);
		free(mem);
#endif
	} else
	if (type >= 8 && type <= 12) {
//		printf("fixed\n");
		int lpcorder = type & 0x7;
		const short* coefs = fixed_coefs[lpcorder];

		if(lpcorder) {
			cmd = 0x6; data = lpcorder - 1; //write lpc orders
#ifdef TARGET_NRA
			addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
			csr_write(addr, data);
#else
			fwrite(&cmd, 4, 1, fd_tb);
			fwrite(&data, 4, 1, fd_tb);
#endif

			for(int i = 0; i < lpcorder; i++) {
				largeint_t warmup;
				warmup.h = bitstream_readbits(1, inp) == 1 ? 1 : 0;
				warmup.l = bitstream_readbits(samplebits - 1, inp) | ((-warmup.h) << (samplebits - 1));
				warmup.h += i << 1;

				cmd = 0x8;
#ifdef TARGET_NRA
				addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
				csr_write(addr, warmup.l);
				csr_writehi(addr, warmup.h);
#else
				data = warmup.l;
				data = (warmup.h << 16) | (data & 0xffff);
				fwrite(&cmd, 4, 1, fd_tb);
				fwrite(&data, 4, 1, fd_tb);
#endif
			}

			cmd = 0x5; data = 0; //write shift, fixed subframe's shift is zero.
#ifdef TARGET_NRA
			addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
			csr_write(addr, data);
#else
			fwrite(&cmd, 4, 1, fd_tb);
			fwrite(&data, 4, 1, fd_tb);
#endif

			for(int i = 0; i < lpcorder; i++) {
				cmd = 0x7;
#ifdef TARGET_NRA
				addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
				int datal = coefs[i];
				int datah = i << 1;
				csr_write(addr, datal);
				csr_writehi(addr, datah);
#else
				data = (coefs[i] & 0xffff) + (i << 17); //write coefs
				fwrite(&cmd, 4, 1, fd_tb);
				fwrite(&data, 4, 1, fd_tb);
#endif
			}
		}

#ifdef TARGET_NRA
		short* residuals = (short*)(RES_ADDRESS + channum * RES_PAGE_SIZE);
		int pos = (unsigned int)residuals;
#else
		short* residuals = malloc(RES_PAGE_SIZE);
		memset(residuals, 0, RES_PAGE_SIZE);
		int pos = ftell(fd_mem);
#endif
		decode_residuals(lpcorder, blocksize, residuals, inp);
		cmd = lpcorder ? 0x2 : 0x1; data = pos;

#ifdef TARGET_NRA
		clflush();
		addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
		csr_write(addr, data);
#else
		fwrite(&cmd, 4, 1, fd_tb);
		fwrite(&data, 4, 1, fd_tb);
		fwrite(residuals, 2, RES_PAGE_SIZE/2, fd_mem);
		free(residuals);
#endif
	} else
	if (type >= 32 && type <= 63) {
//		printf("lpc\n");
		int lpcorder = (type & 0x1f) + 1;

		cmd = 0x6; data = lpcorder - 1; //write lpc orders
#ifdef TARGET_NRA
		addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
		csr_write(addr, data);
#else
		fwrite(&cmd, 4, 1, fd_tb);
		fwrite(&data, 4, 1, fd_tb);
#endif

		for(int i = 0; i < lpcorder; i++) {
			largeint_t warmup;
			warmup.h = bitstream_readbits(1, inp);// == 1 ? 1 : 0;
			warmup.l = bitstream_readbits(samplebits - 1, inp) | ((-warmup.h) << (samplebits - 1));
			warmup.h += i << 1;

			cmd = 0x8;
			data = warmup.l;
			data = (warmup.h << 16) | (data & 0xffff);
#ifdef TARGET_NRA
			addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
			csr_write(addr, warmup.l);
			csr_writehi(addr, warmup.h);
#else
			fwrite(&cmd, 4, 1, fd_tb);
			fwrite(&data, 4, 1, fd_tb);
#endif
		}

		int precision = bitstream_readbits(4, inp);
		int shift = bitstream_readbits(5, inp);
		cmd = 0x5; data = shift; //write shift
#ifdef TARGET_NRA
		addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
		csr_write(addr, data);
#else
		fwrite(&cmd, 4, 1, fd_tb);
		fwrite(&data, 4, 1, fd_tb);
#endif

		for(int i = 0; i < lpcorder; i++) {
			largeint_t coefs;
			int sign = bitstream_readbits(1, inp);// == 1 ? 1 : 0;
			coefs.l = ((-sign) << precision) | bitstream_readbits(precision, inp);
			coefs.h = i << 1; //coefs only 16 bits

			cmd = 0x7;
#ifdef TARGET_NRA
			addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
			csr_write(addr, coefs.l);
			csr_writehi(addr, coefs.h);
#else
			data = coefs.l;
			data = (coefs.h << 16) | (data & 0xffff);
			fwrite(&cmd, 4, 1, fd_tb);
			fwrite(&data, 4, 1, fd_tb);
#endif
		}

#ifdef TARGET_NRA
		short* residuals = (short*)(RES_ADDRESS + channum * RES_PAGE_SIZE);
#else
		short* residuals = malloc(RES_PAGE_SIZE);
		memset(residuals, 0, RES_PAGE_SIZE);
#endif
		decode_residuals(lpcorder, blocksize, residuals, inp);

#ifdef TARGET_NRA
		clflush();
#endif

#ifdef TARGET_NRA
		int pos = (unsigned int)residuals;
#else
		int pos = ftell(fd_mem);
#endif
		cmd = 0x2; data = pos;
#ifdef TARGET_NRA
		addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
		csr_write(addr, data);
#else
		fwrite(&cmd, 4, 1, fd_tb);
		fwrite(&data, 4, 1, fd_tb);
		fwrite(residuals, 2, RES_PAGE_SIZE/2, fd_mem);
#endif

#ifndef TARGET_NRA
		free(residuals);
#endif

	} else {
		//issue fault
#ifndef TARGET_NRA
		printf("unknown subframe type %x\n", header);
		printf("pos %x\n", ftell(inp->fd));
		printf("bypepos %x\n", inp->bytepos);
		printf("bitlen %x\n",  inp->bitlen);
		printf("current %x\n", inp->heap[inp->bytepos]);
		printf("dump:\n");
		for(int i = 0; i < 512; i++)
			printf("%x ", inp->heap[i]);
#endif
		return -1;
	}
	return 0;
}

int decodeframe(struct bitstream* inp){

	int header;
	char* header_bytes = (char*)&header;

	int i = 0;
	bitstream_alignread(&header_bytes[i++], inp);
	bitstream_alignread(&header_bytes[i++], inp);
	bitstream_alignread(&header_bytes[i++], inp);
	bitstream_alignread(&header_bytes[i], 	inp);

	if((header & 0xfcff) != 0xf8ff) {
#ifndef TARGET_NRA
		printf("sync code missing, %x\n", header);
#endif
		exit(-1);
	}

	unsigned char utf8;
	bitstream_alignread(&utf8, inp);
	while(utf8 >= 0xc0) {
		bitstream_alignpass(inp); //utf
		utf8 = (utf8 << 1) & 0xff;
	}

	int blocksizecode  	= ((unsigned char)header_bytes[2]) >> 4;
	int sampleratecode	= ((unsigned char)header_bytes[2]) & 0xf;
	int chanasgn 		= ((unsigned char)header_bytes[3]) >> 4;
	int samplesizecode 	= ((unsigned char)header_bytes[3]) & 0xf;

	int blocksize;
	if (blocksizecode == 1) {
		blocksize = 192;
	} else
	if (blocksizecode >= 2 && blocksizecode <= 5) {
		blocksize = 576 << (blocksizecode - 2);
	} else
	if (blocksizecode >= 8 && blocksizecode <= 15) {
		blocksize = 256 << (blocksizecode - 8);
	} else
	if (blocksizecode == 6) {
		unsigned char x;
		bitstream_alignread(&x, inp);
		blocksize = x + 1;
	} else
	if (blocksizecode == 7) {
		unsigned char x;
		bitstream_alignread(&x, inp);
		blocksize = x;
		bitstream_alignread(&x, inp);
		blocksize = blocksize << 8 + x + 1;
	} else {
#ifndef TARGET_NRA
		printf("unsupported blocksizecode: %d\n", blocksizecode);
#endif
		exit(-2);
	}

	bitstream_alignpass(inp); //crc

	if(sampleratecode != 0xa) {
#ifndef TARGET_NRA
		printf("only 48kHz supported.\n");
#endif
		exit(-3);
	}

	int mode;
	if (chanasgn == 1) mode = 0;
	else if (chanasgn == 8) mode = 1;
	else if (chanasgn == 9) mode = 2;
	else if (chanasgn == 10) mode = 3;
	else {
#ifndef TARGET_NRA
		printf("only stereo supported.\n");
#endif
		exit(-4);
	}

	int samplebits = 16;
	if (samplesizecode != 0x8) {
#ifndef TARGET_NRA
		printf("only 16bits supported.\n");
#endif
		exit(-5);
	}

	int cmd, data;
	cmd = 0x3; data = blocksize; //write blocksizes
#ifdef TARGET_NRA
	int addr;
	addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
	csr_write(addr, data);
#else
	fwrite(&cmd, 4, 1, fd_tb);
	fwrite(&data, 4, 1, fd_tb);
#endif

	cmd = 0x4; data = mode; //write channel assignment mode
#ifdef TARGET_NRA
	addr = (FLAC_SR_BASE_ADDRESS << 4) + cmd;
	csr_write(addr, data);
#else
	fwrite(&cmd, 4, 1, fd_tb);
	fwrite(&data, 4, 1, fd_tb);
#endif

	if(decodesubframe(blocksize, samplebits + ((mode == 2) ? 1 : 0), 0, inp)) exit(-6);
	if(decodesubframe(blocksize, samplebits + ((mode == 2) ? 0 : ((mode == 0) ? 0 : 1)), 1, inp)) exit(-6);

	bitstream_align(inp);

	bitstream_alignpass(inp);
	bitstream_alignpass(inp); //crc

	return 0;
}

int main() {
	struct bitstream inp;
#ifdef TARGET_NRA
	bitstream_init(NULL, &inp);
#else
	fd_tb = fopen("testbench.bin", "wb");
	fd_mem = fopen("ram.bin", "wb");
	bitstream_init("stream.flac", &inp);
#endif
#ifndef TARGET_NRA
	fd_tb = fopen("testbench.bin", "wb");
	fd_mem = fopen("ram.bin", "wb");
#endif
#ifdef TARGET_NRA
	while(decodeframe(&inp) == 0);
#else
	while(!feof(inp.fd)) {
		decodeframe(&inp);
	}
#endif
	bitstream_close(&inp);
#ifdef TARGET_NRA
	__asm__ __volatile__ ("wfi");
#else
	fclose(fd_tb);
	fclose(fd_mem);
#endif
	return 0;
}
