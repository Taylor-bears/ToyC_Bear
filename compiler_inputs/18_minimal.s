.text
.globl main

abs:
addi sp,sp,-32
sw ra,0(sp)
sw s0,4(sp)
addi s0,sp,32
sw a0,-4(s0)
abs_entry:
lw t0,-4(s0)
li t1,0
slt t0,t0,t1
sw t0,-8(s0)
lw t0,-8(s0)
beq t0,x0,abs_else_1
j abs_then_0
abs_then_0:
lw t0,-4(s0)
sub t0,x0,t0
lw a0,-12(s0)
j abs__epilogue
j abs_endif_2
abs_else_1:
lw a0,-4(s0)
j abs__epilogue
j abs_endif_2
abs_endif_2:
li a0,0
j abs__epilogue
abs__epilogue:
lw ra,0(sp)
lw s0,4(sp)
addi sp,sp,32
ret