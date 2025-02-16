#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <x86intrin.h>

FILE* fd_mem;

void ram_seek(int pos) {
	fseek(fd_mem, pos, SEEK_SET);
	return;
}

int ram_read(){
	short val;
	int result;
	fread(&val, 2, 1, fd_mem);
	if(val == -1) {
		fread(&val, 2, 1, fd_mem);
		if(val == -1) return -1;
		result = val < 0 ? (unsigned short)val : 0xffff0000 + (unsigned short)val;
	} else {
		result = val;
	}
	return result;
}

void verbatim_issue(int* dst, int blocksize, int wasted){
	for(int i = 0; i < blocksize; i++) {
		int residual = ram_read();
		dst[i] = residual << wasted;
	}
	return;
}

void lpc_issue(int* dst, int blocksize, int shift, int order, int* coefs, int* warmup, int wasted){
	for(int i = 0; i < order; i++) {
		dst[i] = warmup[i];
	}
	for(int i = order; i < blocksize; i++) {
		int sum = 0;
		for(int k = 0; k < order; k++) {
			sum += dst[i - 1 - k] * coefs[k];
		}
		int residual = ram_read();
		int result = residual + (sum >> shift);
		dst[i] = result;
	}
	for(int i = 0; i < blocksize; i++) {
		dst[i] <<= wasted;
	}
	return;
}

void write_result(FILE* fdst, int result[2][32768], int blocksize, int chan){
	int16_t tmp[65536];
   	for(int i = 0; i < blocksize; i++) {
		int m = result[0][i];
		int n = result[1][i];
		int pos = i << 1;
		if(chan == 0) {
			tmp[pos] = m;
			tmp[pos + 1] = n;
		} else
		if(chan == 1) {
			tmp[pos] = m;
			tmp[pos + 1] = m - n;
		} else
		if(chan == 2) {
			tmp[pos] = m + n;
			tmp[pos + 1] = n;
		} else {
			tmp[pos + 1] = m - (n >> 1);
			tmp[pos] = m + (n >> 1) + (n & 1);
		}
	}
	fwrite(tmp, 2, blocksize * 2, fdst);
	return;
}

//int test = 0;

int main(){
    int result[2][32768];
    int sel = 0; //channel 0 or 1
    int blocksize = 0;
    int chan = 0;
    int shift = 0;
    int order = 0;
    int wasted = 0;
    int coefs[32];
    int warmup[32];
    FILE* fcmd = fopen("testbench.bin", "rb");
    fd_mem = fopen("ram.bin", "rb");

    FILE* fdst = fopen("result.bin", "wb");
    while(!feof(fcmd)) {
        int cmd, data;
        fread(&cmd, 4, 1, fcmd);
        fread(&data, 4, 1, fcmd);
        switch(cmd){
        case 0: //const issue
//            printf("const\n");
            for(int i = 0; i < blocksize; i++){
                result[sel][i] = data << wasted;
            }
            sel = sel ? 0 : 1;
            if(!sel) write_result(fdst, result, blocksize, chan);
            break;
        case 1: //verbatim issue
//            printf("verbatim\n");
            ram_seek(data);
            verbatim_issue(result[sel], blocksize, wasted);
            sel = sel ? 0 : 1;
            if(!sel) write_result(fdst, result, blocksize, chan);
            break;
        case 2:
//            printf("lpc\n");
            ram_seek(data);
            lpc_issue(result[sel], blocksize, shift, order + 1, coefs, warmup, wasted);
            sel = sel ? 0 : 1;
            if(!sel) write_result(fdst, result, blocksize, chan);
//	if(test) exit(-1);
	test = 1;
            break;
        case 3:
            blocksize = data;
            break;
        case 4:
            chan = data;
            break;
        case 5:
            shift = data;
            break;
        case 6:
            order = data;
	    if(order > 11) {
		printf("too big order!\n");
		exit(-1); //bigger than 12 is out of streamable subset of flac.
	    }
            break;
        case 7:
            coefs[data >> 17] = (data << 16) >> 16;
            break;
        case 8:
            warmup[data >> 17] = (data << 15) >> 15;
            break;
	case 9:
	    wasted = data;
	    break;
        default:
            printf("wrong cmd %d\n", cmd);
            exit(-1);
        }
    }
}
