.text
.global main

add:
addi sp,sp,-20
sw ra,16(sp)
sw s0,12(sp)
mv s0,sp
sw a0,0(s0)
sw a1,4(s0)
add_entry:
lw t0,-4(s0)
lw t1,-8(s0)
add t0,t0,t1
sw t0,-12(s0)
lw a0,-12(s0)
j __epilogue
__epilogue:
mv sp,s0
lw s0,12(sp)
lw ra,16(sp)
addi sp,sp,20
ret

main:
addi sp,sp,-16
sw ra,12(sp)
sw s0,8(sp)
mv s0,sp
main_entry:
li a0,3
li a1,4
call add
sw a0,-8(s0)
lw t0,-8(s0)
sw t0,-4(s0)
lw a0,-4(s0)
j __epilogue
__epilogue:
mv sp,s0
lw s0,8(sp)
lw ra,12(sp)
addi sp,sp,16
ret