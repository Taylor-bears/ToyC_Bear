open Ir 
open Ast

let indent = "\t"

(* 计算本函数需要多少个临时槽：0..max_temp *)
let max_temp (f:func) =
  List.fold_left (fun acc blk ->
    List.fold_left (fun acc instr ->
      let record acc = function
        | Temp t -> max acc t
        | _      -> acc
      in
      match instr with
      | Move(d, op) ->
          let acc = record acc (Temp d) in
          record acc op

      | UnOp(d,_,op) ->
          let acc = record acc (Temp d) in
          record acc op

      | BinOp(d,_,op1,op2) ->
          let acc = record acc (Temp d) in
          let acc = record acc op1 in
          record acc op2

      | Call (Some d, _, args) ->
          (* 绑定了 d 和 args，就写在一个分支里 *)
          let acc = record acc (Temp d) in
          List.fold_left record acc args

      | Call (None, _, args) ->
          (* 只绑定了 args *)
          List.fold_left record acc args

      | IfZero (op, _) ->
          (* 只绑定了 op *)
          record acc op

      | IfNotZero (op, _) ->
          record acc op

      | Return (Some op) ->
          record acc op

      | _ ->
          acc
    ) acc blk.code
  ) (-1) f.blocks


(* 不要任何前导空格 *)
(*w函数用于输入输出*)
let w buf s =
  Buffer.add_string buf s;
  Buffer.add_char   buf '\n'

let emit_load_operand buf rd = function
  | Const n ->
      w buf (Printf.sprintf "li %s,%d" rd n)(*常数直接使用li指令加载到目标寄存器rd*)
  | Temp t ->
      let offset = -(t+1)*4 in
      w buf (Printf.sprintf "lw %s,%d(s0)" rd offset)(*临时变量从栈上取，注意使用帧指针s0*)
  | Var id ->
      failwith ("全局变量未支持: " ^ id)

let emit_instr ~epilogue buf = function
  | Move(d, op) ->(*Move 指令*)
      emit_load_operand buf "t0" op;
      let off = -(d+1)*4 in
      w buf (Printf.sprintf "sw t0,%d(s0)" off)(*从帧指针+偏移取变量*)

  | UnOp(d, Neg, arg) ->
      emit_load_operand buf "t0" arg;
      w buf "sub t0,x0,t0";
      let off = -(d+1)*4 in
      w buf (Printf.sprintf "sw t0,%d(s0)" off)
      
  | UnOp(d, Not, arg) ->
      emit_load_operand buf "t0" arg;
      w buf "seqz t0,t0";
      let off = -(d+1)*4 in
      w buf (Printf.sprintf "sw t0,%d(s0)" off)

  | BinOp(d, op, a1, a2) ->
      emit_load_operand buf "t0" a1;
      emit_load_operand buf "t1" a2;
      (match op with
       | Add -> w buf "add t0,t0,t1"
       | Sub -> w buf "sub t0,t0,t1"
       | Mul -> w buf "mul t0,t0,t1"
       | Div -> w buf "div t0,t0,t1"
       | Mod -> w buf "rem t0,t0,t1"
       | Eq  -> w buf "xor t0,t0,t1"; w buf "seqz t0,t0"
       | Neq -> w buf "xor t0,t0,t1"; w buf "snez t0,t0"
       | Lt  -> w buf "slt t0,t0,t1"
       | Le  -> w buf "slt t0,t1,t0"; w buf "xori t0,t0,1"
       | Gt  -> w buf "slt t0,t1,t0"
       | Ge  -> w buf "slt t0,t0,t1"; w buf "xori t0,t0,1"
       | _   -> failwith "短路逻辑应该已展开");
      let off = -(d+1)*4 in
      w buf (Printf.sprintf "sw t0,%d(s0)" off)

  | Goto lbl ->
      w buf (Printf.sprintf "j %s" lbl)

  | IfZero (op, lbl) ->
      emit_load_operand buf "t0" op;
      w buf (Printf.sprintf "beq t0,x0,%s" lbl)

  | IfNotZero (op, lbl) ->
      emit_load_operand buf "t0" op;
      w buf (Printf.sprintf "bne t0,x0,%s" lbl)

  | Return None ->
      w buf "li a0,0";
      w buf  (Printf.sprintf "j %s" epilogue)

  | Return (Some op) ->
      emit_load_operand buf "a0" op;
      w buf (Printf.sprintf "j %s" epilogue)

  | Call (dst, fname, args) ->
    let _ = List.length args in (* 明确标记为忽略 *)
    List.iteri (fun i arg ->
      if i < 8 then
        emit_load_operand buf (Printf.sprintf "a%d" i) arg
      else begin
        emit_load_operand buf "t0" arg;
        w buf (Printf.sprintf "sw t0,%d(sp)" (-(i+1)*4))  (* 参数从sp+16开始 *)
      end
    ) args;
    
    (* 调用函数 *)
    w buf (Printf.sprintf "call %s" fname);
    
    
    (* 存储返回值 *)
    match dst with
    | Some d ->
        let off = -(d+1)*4 in
        w buf (Printf.sprintf "sw a0,%d(s0)" off)
    | None -> ()

(*函数调用
# ── 1. 分配栈帧 ───────────────────────────────
addi sp, sp, -<frame_size>    # frame_size >= 局部变量 + ra + s0

# ── 2. 保存 callee‑saved 寄存器 ─────────────
sw   ra, <off_ra>(sp)         # 保存返回地址
sw   s0, <off_fp>(sp)         # 保存旧的帧指针

# ── 3. 建立新的帧指针 ───────────────────────
mv   s0, sp                   # 之后所有局部变量、参数都通过 s0+固定偏移访问
*)

(*函数结尾
__epilogue:
# ── 1. 恢复栈顶到帧指针 ─────────────────────
mv   sp, s0                   # 把 sp 恢复到进入函数时的位置

# ── 2. 恢复 callee‑saved 寄存器 ─────────────
lw   s0, <off_fp>(sp)         # 恢复上层的帧指针
lw   ra, <off_ra>(sp)         # 恢复返回地址

# ── 3. 释放栈帧 ─────────────────────────────
addi sp, sp, <frame_size>     # 回收本函数的栈空间

# ── 4. 返回 ─────────────────────────────────
ret

*)

let emit_prologue_params buf (f:func)   =
  let params = f.params in
  let para_count = List.length params in
  (* 计算最大参数个数 *)
  for i = 0 to (min 8 para_count-1) do
    let dest_off = -(i+1)*4 in
      (* 前8个参数从a0-a7寄存器获取 *)
      w buf (Printf.sprintf "sw a%d,%d(s0)" i dest_off)
      (* w buf (Printf.sprintf "PARA:%d" para_count) *)
    (* else
      (* 额外参数从调用者的栈帧获取 *)
      let src_off = frame_size + (i - 8) * 4 in
      w buf (Printf.sprintf "lw t0,%d(s0)" src_off);
      w buf (Printf.sprintf "sw t0,%d(s0)" dest_off) *)
  done

let emit_func (f:func) =
  let buf = Buffer.create 4096 in
  let max_t = max_temp f in
  (* 计算栈帧大小，保证16字节对齐 *)
  let frame_size = ((max_t + 3) * 4 + 15) land (lnot 15) in
  let epilogue = f.name ^ "__epilogue" in
  
  w buf (Printf.sprintf "%s:" f.name);
  
  (* prologue *)
  w buf (Printf.sprintf "addi sp,sp,-%d" frame_size);
  w buf "sw ra,0(sp)";          (* 保存返回地址 *)
  w buf "sw s0,4(sp)";          (* 保存帧指针 *)
  w buf (Printf.sprintf "addi s0,sp,%d" frame_size);  (* 设置新帧指针 *)
  
  (* 保存参数到栈帧 *)
  emit_prologue_params buf f ;
  
  (* 生成基本块代码 *)
  List.iter (fun blk ->
    w buf (blk.lbl ^ ":");
    List.iter (emit_instr ~epilogue buf) blk.code
  ) f.blocks;
  
  (* epilogue *)
  w buf (Printf.sprintf "%s:" epilogue);
  w buf "lw ra,0(sp)";          (* 恢复返回地址 *)
  w buf "lw s0,4(sp)";          (* 恢复帧指针 *)
  w buf (Printf.sprintf "addi sp,sp,%d" frame_size);  (* 恢复栈指针 *)
  w buf "ret";

  Buffer.contents buf

(* 2. 在 emit_program 里统一输出 .text/.global main *)
let emit_program (prog:program) =
  let buf = Buffer.create 8192 in
  (* 整个汇编文件头，且仅此一次 *)
  w buf ".text";
  w buf ".globl main";
  (* 然后把所有函数的代码拼上来 *)
  List.iter (fun f ->
    w buf "";               (* 空行分隔 *)
    Buffer.add_string buf (emit_func f)
  ) prog;
  Buffer.contents buf