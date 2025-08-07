.text
.global main

factorial:
addi sp,sp,-32
sw ra,0(sp)
sw s0,4(sp)
addi s0,sp,32
sw a0,-4(s0)
factorial_entry:
li t0,1
sw t0,-8(s0)
lw t0,-4(s0)
li t1,0
slt t0,t1,t0
xori t0,t0,1
sw t0,-12(s0)
lw t0,-12(s0)
beq t0,x0,factorial_else_1
j factorial_then_0
factorial_then_0:
li a0,1
j factorial__epilogue
j factorial_endif_2
factorial_else_1:
j factorial_while_cond_3
factorial_while_cond_3:
lw t0,-4(s0)
li t1,1
slt t0,t1,t0
sw t0,-16(s0)
lw t0,-16(s0)
beq t0,x0,factorial_while_end_5
j factorial_while_body_4
factorial_while_body_4:
lw t0,-8(s0)
lw t1,-4(s0)
mul t0,t0,t1
sw t0,-20(s0)
lw t0,-20(s0)
sw t0,-8(s0)
lw t0,-4(s0)
li t1,1
sub t0,t0,t1
sw t0,-24(s0)
lw t0,-24(s0)
sw t0,-4(s0)
j factorial_while_cond_3
factorial_while_end_5:
lw a0,-8(s0)
j factorial__epilogue
j factorial_endif_2
factorial_endif_2:
li a0,0
j factorial__epilogue
factorial__epilogue:
lw ra,0(sp)
lw s0,4(sp)
addi sp,sp,32
ret

main:
addi sp,sp,-112
sw ra,0(sp)
sw s0,4(sp)
addi s0,sp,112
main_entry:
li t0,1
sub t0,x0,t0
lw t0,-8(s0)
sw t0,-4(s0)
li t0,3
sub t0,x0,t0
lw t0,-16(s0)
sw t0,-12(s0)
li t0,0
sw t0,-20(s0)
lw t0,-4(s0)
lw t1,-12(s0)
slt t0,t1,t0
sw t0,-28(s0)
lw t0,-28(s0)
beq t0,x0,main_land_false_3
lw t0,-4(s0)
lw t1,-12(s0)
sub t0,t0,t1
sw t0,-32(s0)
lw t0,-32(s0)
li t1,1
slt t0,t1,t0
sw t0,-36(s0)
lw t0,-36(s0)
sw t0,-24(s0)
j main_land_end_4
main_land_false_3:
li t0,0
sw t0,-24(s0)
j main_land_end_4
main_land_end_4:
lw t0,-24(s0)
beq t0,x0,main_else_1
j main_then_0
main_then_0:
addi sp,sp,-16
sw ra,12(sp)
sw s0,8(sp)
lw a0,-4(s0)
call factorial
lw s0,8(sp)
lw ra,12(sp)
addi sp,sp,16
sw a0,-40(s0)
lw t0,-40(s0)
sw t0,-20(s0)
j main_endif_2
main_else_1:
lw t0,-4(s0)
lw t1,-12(s0)
slt t0,t0,t1
sw t0,-48(s0)
lw t0,-48(s0)
bne t0,x0,main_lor_true_8
lw t0,-4(s0)
lw t1,-12(s0)
xor t0,t0,t1
seqz t0,t0
sw t0,-52(s0)
lw t0,-52(s0)
bne t0,x0,main_lor_true_8
li t0,0
sw t0,-44(s0)
j main_lor_end_9
main_lor_true_8:
li t0,1
sw t0,-44(s0)
j main_lor_end_9
main_lor_end_9:
lw t0,-44(s0)
beq t0,x0,main_else_6
j main_then_5
main_then_5:
lw t0,-4(s0)
lw t1,-12(s0)
add t0,t0,t1
sw t0,-56(s0)
lw t0,-56(s0)
sub t0,x0,t0
addi sp,sp,-16
sw ra,12(sp)
sw s0,8(sp)
lw a0,-60(s0)
call factorial
lw s0,8(sp)
lw ra,12(sp)
addi sp,sp,16
sw a0,-64(s0)
lw t0,-64(s0)
sw t0,-20(s0)
j main_endif_7
main_else_6:
lw t0,-4(s0)
lw t1,-12(s0)
mul t0,t0,t1
sw t0,-68(s0)
addi sp,sp,-16
sw ra,12(sp)
sw s0,8(sp)
lw a0,-68(s0)
call factorial
lw s0,8(sp)
lw ra,12(sp)
addi sp,sp,16
sw a0,-72(s0)
lw t0,-72(s0)
sw t0,-20(s0)
j main_endif_7
main_endif_7:
j main_endif_2
main_endif_2:
j main_while_cond_10
main_while_cond_10:
lw t0,-20(s0)
li t1,100
slt t0,t1,t0
sw t0,-76(s0)
lw t0,-76(s0)
beq t0,x0,main_while_end_12
j main_while_body_11
main_while_body_11:
lw t0,-20(s0)
li t1,2
rem t0,t0,t1
sw t0,-80(s0)
lw t0,-80(s0)
li t1,0
xor t0,t0,t1
seqz t0,t0
sw t0,-84(s0)
lw t0,-84(s0)
beq t0,x0,main_else_14
j main_then_13
main_then_13:
lw t0,-20(s0)
li t1,2
div t0,t0,t1
sw t0,-88(s0)
lw t0,-88(s0)
sw t0,-20(s0)
j main_endif_15
main_else_14:
lw t0,-20(s0)
li t1,1
sub t0,t0,t1
sw t0,-92(s0)
lw t0,-92(s0)
sw t0,-20(s0)
j main_endif_15
main_endif_15:
j main_while_cond_10
main_while_end_12:
lw t0,-20(s0)
li t1,8
rem t0,t0,t1
sw t0,-96(s0)
addi sp,sp,-16
sw ra,12(sp)
sw s0,8(sp)
li a0,3
call factorial
lw s0,8(sp)
lw ra,12(sp)
addi sp,sp,16
sw a0,-100(s0)
lw t0,-96(s0)
lw t1,-100(s0)
div t0,t0,t1
sw t0,-104(s0)
lw a0,-104(s0)
j main__epilogue
main__epilogue:
lw ra,0(sp)
lw s0,4(sp)
addi sp,sp,112
ret