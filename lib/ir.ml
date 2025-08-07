open Ast


(*定义三地址码的数据结构*)
type temp = int
type label = string

type operand =
  | Temp of temp
  | Const of int
  | Var of string


type instr =
(*计算/赋值指令*)
  | Move of temp * operand
  | UnOp of temp * unop * operand
  | BinOp of temp * binop * operand * operand
(*控制流指令*)
  | Goto of label
  | IfZero of operand * label
  | IfNotZero of operand * label
  | Return of operand option
(*函数调用指令*)
  | Call of temp option* string * operand list


(*CFG*)
type block = {
  lbl   : label;
  mutable code : instr list;   (* 不包含 Label 指令，lbl 字段即块名 *)
  mutable succ : label list;   (* 后继块标签 *)
  mutable pred : label list;   (* 前驱块标签 *)
}

type func = {
  name   : string;
  params : string list;        (* 源语言参数名，可用来建初始 env *)
  blocks : block list;
}

type program = func list

(*builder*)
type builder = {
  func_name : string;  (* 函数名 *)
  mutable cur_block : block;        (* 正在写入的基本块 *)
  mutable blocks    : block list;   (* 已完成的块列表（含最后会收进去的当前块） *)
  mutable tcnt      : int;          (* 下一个可用的临时变量编号 *)
  mutable lcnt      : int;          (* 下一个可用的标签编号 *)
  break_stack       : label list ref;   (* 当前所在循环的 break 目标标签栈 *)
  continue_stack    : label list ref;   (* 当前所在循环的 continue 目标标签栈 *)
}

(*builder中的常用函数*)
let mk_block lbl = { lbl; code = []; succ = []; pred = [] }
let new_temp b = 
  let t = b.tcnt in
  b.tcnt <- b.tcnt + 1;
  t

let new_label b prefix =
  let l = prefix ^ string_of_int b.lcnt in
  b.lcnt <- b.lcnt + 1;
  l

let start_block b lbl =
  b.blocks <- b.cur_block::b.blocks;
  b.cur_block <- { lbl = lbl; code = []; succ = []; pred = [] }

(*注意emit算法，效率较低，需要修改！*)
let emit b i =
  b.cur_block.code <- b.cur_block.code @ [i]

