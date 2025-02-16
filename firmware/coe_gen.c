#include <stdio.h>
#include <string.h>

int main(){
	FILE* fsrc = fopen("test_instructions.bin", "rb");
	FILE* fdst = fopen("test_instructions.coe", "w");
	int i = 0;
	unsigned int insn[4];
	fprintf(fdst, "memory_initialization_radix=16;\nmemory_initialization_vector=\n");
	while(!feof(fsrc)) {
		fread(&insn[i], 4, 1, fsrc);
		if(i == 3) {
			fprintf(fdst, "%08x%08x%08x%08x\n", insn[3], insn[2], insn[1], insn[0]);
			memset(insn, 0, 4 * 4),
			i = 0;
		} else i++;
	}
	if(i == 0) {
		fprintf(fdst, ";\n");
	} else {
		fprintf(fdst, "%08x%08x%08x%08x;\n", insn[3], insn[2], insn[1], insn[0]);
	}
	return 0;
}
