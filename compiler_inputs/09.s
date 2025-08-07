.text
.global main

fact:
addi sp,sp,-32
sw ra,0(sp)
sw s0,4(sp)
addi s0,sp,32
sw a0,-4(s0)
fact_entry:
lw t0,-4(s0)
li t1,1
slt t0,t1,t0
xori t0,t0,1
sw t0,-8(s0)
lw t0,-8(s0)
beq t0,x0,fact_else_1
j fact_then_0
fact_then_0:
li a0,1
j fact__epilogue
j fact_endif_2
fact_else_1:
lw t0,-4(s0)
li t1,1
sub t0,t0,t1
sw t0,-12(s0)
lw a0,-12(s0)
call fact
sw a0,-16(s0)
lw t0,-4(s0)
lw t1,-16(s0)
mul t0,t0,t1
sw t0,-20(s0)
lw a0,-20(s0)
j fact__epilogue
j fact_endif_2
fact_endif_2:
li a0,0
j fact__epilogue
fact__epilogue:
lw ra,0(sp)
lw s0,4(sp)
addi sp,sp,32
ret

main:
addi sp,sp,-16
sw ra,0(sp)
sw s0,4(sp)
addi s0,sp,16
main_entry:
li a0,5
call fact
sw a0,-4(s0)
lw a0,-4(s0)
j main__epilogue
main__epilogue:
lw ra,0(sp)
lw s0,4(sp)
addi sp,sp,16
ret