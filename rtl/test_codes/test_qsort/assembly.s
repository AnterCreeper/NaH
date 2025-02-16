# 概述：对数组进行原地快速排序
# derived from WangXuan95

# zero = x0, x1
# ra = x2
# x3 reserved

# sp = x4
# t0 = x5
# t1 = x6
# t2 = x7

# a0 = x10
# a1 = x11
# a2 = x12
# a3 = x13
# a4 = x14

# t3 = x28
# t4 = x29
# t5 = x30

.org 0x0
    .global _start
_start:
                                                # tag2 i0 imm[12:6] Rb    Rs/Rd func3 imm[5:1]
main: # pc = 0

    xori   a3, zero, 0x200                      # 01   0  0001000   00000 00000 001   01101    1111 #0
    # 指定排序问题的规模。0x200则代表要给0x200=512个数字进行快速排序。
    lui    sp, 0x2                              # 00   0  0000000   00001 00000 001   00100    1011 #1
    # 设置栈顶指针 sp=0x2000

    xor    a0, zero, zero                       # 01   0  0000000   00000 00000 001   01010    0111 #2
    # 准备函数参数，a0=0, 说明要排序的数组的RAM起始地址为0
    xor    a1, zero, zero                       # 01   0  0000000   00000 00000 001   01011    0111 #3
    # 准备函数参数，a1=0，说明从第0个字开始排序
    addi   a2, a3, -1                           # 00   1  1111111   11111 01101 000   01100    1111 #4
    slli   a2, a2, 1                            # 00   1  0000000   00000 01100 010   01100    1111 #5
    # 准备函数参数，a2=数组最后一个元素的地址偏移。我们要排0x200=512个数，最后一个数的地址为0x3fe

    bl     qsort                                # 00   0  0000000   00000 00000 001   00100    1001 #6
    # 开始排序 pc = 24
    b      program_finish                       # 00   0  0000011   00000 00000 000   11000    1001 #7 [60]
    # 排序结束 pc = 28

qsort: # pc = 32

    # 函数 qsort：以a0为基地址的原地升序快速排序，a1是start即开始下标，a2是end即结束下标
    # 例:  a0=0x00000100，a1=0, a2=31*4，则计算从0x00000100开始的32个字的快速排序
    # 注:  以有符号数为比较标准。例如0xffffffff应该排在0x00000001前面，因为0xffffffff代表-1，比1要小
    # 之所以使用低13位，因为13位二进制数取值范围位0~8191，不会超过4位十进制数
    # 改变数据RAM： 除了被排序的数组外，还使用了以sp寄存器为栈顶指针的栈。使用栈的大小根据排序长度而不同，调用前合理设置sp的值以防爆栈
    # 改变的寄存器： t0, t1, t2, t3, t4

        slt    a4, a1, a2                           # 10   0  0000000   01100 01011 000   01110    0111 #8
        # a4 = a1 < a2; a4 should be 1
        cbz    a4, QuickSortReturn                  # 00   0  0000011   01110 00000 001   10010    0001 #9 [57]
        # if a4 = 0, aka end <= start, jump to return; else continue;
        or     t1, a1, zero                         # 00   0  0000000   00000 01011 001   00110    0111 #10
        # t1 = i = a1 = start
        or     t2, a2, zero                         # 00   0  0000000   00000 01100 001   00111    0111 #11
        # t2 = j = a2 = end
        add    t0, a0, t1                           # 00   0  0000000   00110 01010 000   00101    0111 #12
        lh     t0, 0(t0)                            # 00   0  0000000   00101 00101 001   00000    0101 #13
        # t0 = key = lst[start]

        PartationStart:
            PartationFirstStart:
            # start of for loop
                slt    t5, t1, t2               # 10   0  0000000   00111 00110 000   11110    0111 #14
                # t5 = i < j
                cbz    t5, PartationEnd         # 00   0  0000001   11110 00000 001   01010    0001 #15 [21]
                # if i >= j, branch to next step
                add    t3, a0, t2               # 00   0  0000000   00111 01010 000   11100    0111 #16
                lh     t3, 0(t3)                # 00   0  0000000   11100 11100 001   00000    0101 #17
                # t3 = lst[j]
                slt    t5, t3, t0               # 10   0  0000000   00101 11100 000   11110    0111 #18
                # t5 = lst[j] < key
                cbnz   t5, PartationFirstEnd    # 00   0  0000000   11110 00000 101   00110    0001 #19
                # if lst[j] < key, branch to next step
                addi   t2, t2, -2               # 00   0  1111111   11111 00111 000   00111    1111 #20
                # t2 -= 2, aka j--
                b      PartationFirstStart      # 11   1  1111111   00000 00000 000   10010    1001 #21
                # for loop
            PartationFirstEnd:
            # end of for loop
                add    t4, a0, t1               # 00   0  0000000   00110 01010 000   11101    0111 #22
                # t4 = lst + i
                sh     t3, 0(t4)                # 00   0  0000000   11101 11100 000   00000    0101 #23
                # lst[i] = t3 = lst[j]

            PartationSecondStart:
            # start of for loop
                slt    t5, t1, t2               # 10   0  0000000   00111 00110 000   11110    0111 #24
                # t5 = i < j
                cbz    t5, PartationEnd         # 00   0  0000000   11110 00000 001   10110    0001 #25 [11]
                # if i >= j, branch to next step
                add    t3, a0, t1               # 00   0  0000000   00110 01010 000   11100    0111 #26
                lh     t3, 0(t3)                # 00   0  0000000   11100 11100 001   00000    0101 #27
                # t3 = lst[i]
                slt    t5, t0, t3               # 10   0  0000000   11100 00101 000   11110    0111 #28
                # t5 = key < lst[i]
                cbnz   t5, PartationSecondEnd   # 00   0  0000000   11110 00000 101   00110    0001 #29
                # if key < lst[i], branch to next step
                addi   t1, t1, 2                # 00   0  0000000   00001 00110 000   00110    1111 #30
                # t1 += 2, aka i++
                b      PartationSecondStart     # 11   1  1111111   00000 00000 000   10010    1001 #31 [-7]
                # for loop
            PartationSecondEnd:
            # end of for loop 
                add    t4, a0, t2               # 00   0  0000000   00111 01010 000   11101    0111 #32
                # t4 = lst + j
                sh     t3, 0(t4)                # 00   0  0000000   11101 11100 000   00000    0101 #33
                # lst[j] = t3 = lst[i]
            
            slt    t5, t1, t2                   # 10   0  0000000   00111 00110 000   11110    0111 #34
            cbnz   t5, PartationStart           # 11   1  1111110   11110 00000 101   10110    0001 #35 [-21]
            # if t1 < t2, branch to while start
            
        PartationEnd:
            add    t4, a0, t1                   # 00   0  0000000   00110 01010 000   11101    0111 #36
            # t4 = lst + i
            sh     t0, 0(t4)                    # 00   0  0000000   11101 00101 000   00000    0101 #37
            # lst[i] = t0 = key

            addi   sp, sp, -2                   # 00   0  1111111   11111 00100 000   00100    1111 #38
            sh     ra, 0(sp)                    # 00   0  0000000   00100 00010 000   00000    0101 #39
            # push ra to stack
            # ra
            addi   sp, sp, -2                   # 00   0  1111111   11111 00100 000   00100    1111 #40
            sh     a1, 0(sp)                    # 00   0  0000000   00100 01011 000   00000    0101 #41
            # push a1 to stack, save start
            # ra a1
            addi   sp, sp, -2                   # 00   0  1111111   11111 00100 000   00100    1111 #42
            sh     a2, 0(sp)                    # 00   0  0000000   00100 01100 000   00000    0101 #43
            # push a2 to stack, save end
            # ra a1 a2
            addi   sp, sp, -2                   # 00   0  1111111   11111 00100 000   00100    1111 #44
            sh     t1, 0(sp)                    # 00   0  0000000   00100 00110 000   00000    0101 #45
            # push t1 to stack, save i
            # ra a1 a2 t1

            addi   a2, t1, -2                   # 00   0  1111111   11111 00110 000   01100    1111 #46
            bl     qsort                        # 11   1  1111101   00000 00000 001   10010    1001 #47 [-39]

            lh     t1, 0(sp)                    # 00   0  0000000   00100 00110 001   00000    0101 #48
            addi   sp, sp, 2                    # 00   0  0000000   00001 00100 000   00100    1111 #49
            # pop i form stack
            # ra a1 a2
            lh     a2, 0(sp)                    # 00   0  0000000   00100 01100 001   00000    0101 #50
            addi   sp, sp, 2                    # 00   0  0000000   00001 00100 000   00100    1111 #51
            # pop end form stack
            # ra a1

            addi   sp, sp, -2                   # 00   0  1111111   11111 00100 000   00100    1111 #52
            sh     a2, 0(sp)                    # 00   0  0000000   00100 01100 000   00000    0101 #53
            # push a2 to stack, save end
            # ra a1 a2
            addi   sp, sp, -2                   # 00   0  1111111   11111 00100 000   00100    1111 #54
            sh     t1, 0(sp)                    # 00   0  0000000   00100 00110 000   00000    0101 #55
            # push t1 to stack, save i
            # ra a1 a2 t1
        
            addi   a1, t1, 2                    # 00   0  0000000   00001 00110 000   01011    1111 #56
            bl     qsort                        # 11   1  1111100   00000 00000 001   11110    1001 #57 [-49]
        
            lh     t1, 0(sp)                    # 00   0  0000000   00100 00110 001   00000    0101 #58
            addi   sp, sp, 2                    # 00   0  0000000   00001 00100 000   00100    1111 #59
            # pop i form stack
            # ra a1 a2
            lh     a2, 0(sp)                    # 00   0  0000000   00100 01100 001   00000    0101 #60
            addi   sp, sp, 2                    # 00   0  0000000   00001 00100 000   00100    1111 #61
            # pop end form stack 
            # ra a1
            lh     a1, 0(sp)                    # 00   0  0000000   00100 01011 001   00000    0101 #62
            addi   sp, sp, 2                    # 00   0  0000000   00001 00100 000   00100    1111 #63
            # pop start form stack
            # ra
            lh     ra, 0(sp)                    # 00   0  0000000   00100 00010 001   00000    0101 #64
            addi   sp, sp, 2                    # 00   0  0000000   00001 00100 000   00100    1111 #65
            # pop ra form stack

    QuickSortReturn:
    # 函数结尾
        ret   ra                                # 00   0  0000000   00010 00000 010   00000    1001 #66
        # 返回

program_finish:
    xori   a3, zero, 0x1F0                      # 01   0  0000111   11000 00000 001   01101    1111 #67
    flushloop:
    # cache line flush
        clflush x0, 0(a3)                       # 00   0  0000000   01101 00000 101   00000    0101 #68
        addi   a3, a3, -16                      # 00   0  1111111   11000 01101 000   01101    1111 #69
        cbnz   a3, flushloop                    # 11   1  1111111   01101 00000 101   11100    0001 #70
    clflush x0, 0(a3)                           # 00   0  0000000   01101 00000 101   00000    0101 #71
    wfi                                         # 00   1  0000000   00000 00000 000   00000    0011 #72

# QuickSort函数的等效C代码:
#   void qsort(int *lst, int start, int end) {
#       if(end > start) {
#           int i = start, j = end, key = lst[start];
#           while(i < j) {
#               for (;i < j && key <= lst[j]; j--);
#               lst[i] = lst[j];
#               for (;i < j && key >= lst[i]; i++);
#               lst[j] = lst[i];
#           }
#           lst[i] = key;
#           qsort(lst, start, i - 1);
#           qsort(lst, i + 1, end);
#       }
#       return 0;
#   }
