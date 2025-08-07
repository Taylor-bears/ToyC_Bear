 .text
        .globl  main

main:
        addi    sp,sp,-32
        sw      ra,28(sp)
        sw      s0,24(sp)
        addi    s0,sp,32
        li      a5,0
        mv      a0,a5
        sw      a0,-20(s0)
        #将x存入栈上
.L1:
        lw      a5,-20(s0)
        mv      a0,a5
        mv      t0,a0
        li      a5,5
        mv      a0,a5
        mv      t1,a0
        slt     a5,t0,t1
        mv      a0,a5
        beqz    a0,.L2
        #while的循环判断
        lw      a5,-20(s0)
        mv      a0,a5
        mv      t0,a0
        li      a5,2
        mv      a0,a5
        mv      t0,a0#问题 t0被覆盖！
        li      a5,0
        mv      a0,a5
        mv      t1,a0
        xor     a5,t0,t1
        seqz    a5,a5
        mv      a0,a5
        mv      t1,a0
        rem     a5,t0,t1
        mv      a0,a5
        beqz    a0,.L3
        lw      a5,-20(s0)
        mv      a0,a5
        mv      t0,a0
        li      a5,2
        mv      a0,a5
        mv      t1,a0
        add     a5,t0,t1
        mv      a0,a5
        sw      a0,-20(s0)
        j       .L4
.L3:
        lw      a5,-20(s0)
        mv      a0,a5
        mv      t0,a0
        li      a5,1
        mv      a0,a5
        mv      t1,a0
        add     a5,t0,t1
        mv      a0,a5
        sw      a0,-20(s0)
.L4:
        j       .L1
.L2:
        lw      a5,-20(s0)
        mv      a0,a5
        lw      ra,28(sp)
        lw      s0,24(sp)
        addi    sp,sp,32
        jr      ra
        li      a0,0
        lw      ra,28(sp)
        lw      s0,24(sp)
        addi    sp,sp,32
        jr      ra