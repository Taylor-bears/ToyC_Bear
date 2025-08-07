(* pp_ir.ml *)
open Format
open Ir
open Ast

let pp_binop = function
  | Add -> "+" | Sub -> "-" | Mul -> "*"
  | Div -> "/" | Mod -> "%"
  | Eq  -> "=="| Neq -> "!="
  | Lt  -> "<" | Le  -> "<="
  | Gt  -> ">" | Ge  -> ">="
  | And -> "&&"| Or  -> "||"

let pp_unop = function
  | Not -> "!"
  | Neg -> "-"

let pp_operand = function
  | Const n    -> string_of_int n
  | Temp  t    -> Printf.sprintf "t%d" t
  | Var v      -> Printf.sprintf "%s" v
let pp_phi_sources srcs =
  srcs
  |> List.map (fun (lbl, t) -> Printf.sprintf "[%s: t%d]" lbl t)
  |> String.concat ", "

let pp_instr = function
  | Move   (t,op) ->
      Printf.sprintf "t%d = %s" t (pp_operand op)
  | UnOp   (t,u,op) ->
      Printf.sprintf "t%d = %s %s" t (pp_unop u) (pp_operand op)
  | BinOp  (t,a,op,b) ->
      Printf.sprintf "t%d = %s %s %s" t (pp_operand op) (pp_binop a) (pp_operand b)
  | Goto   l ->
      Printf.sprintf "goto %s" l
  | IfZero (op,l) ->
      Printf.sprintf "if %s == 0 goto %s" (pp_operand op) l
  | Return None ->
      "return"
  | Return (Some op) ->
      Printf.sprintf "return %s" (pp_operand op)
  | Call (Some t, f, args) ->
      let args_s = String.concat ", " (List.map pp_operand args) in
      Printf.sprintf "t%d = call %s(%s)" t f args_s
  | Call (None, f, args) ->
      let args_s = String.concat ", " (List.map pp_operand args) in
      Printf.sprintf "call %s(%s)" f args_s
  | IfNotZero (op, l) ->
      Printf.sprintf "if %s != 0 goto %s" (pp_operand op) l

(* 打印一个基本块 *)
let pp_block fmt (b:block) =
  fprintf fmt "@[<v 2>%s:@," b.lbl;
  List.iteri (fun i ins ->
    fprintf fmt "  %-3d %s@," i (pp_instr ins)
  ) b.code;
  fprintf fmt "  succ: %s@," (String.concat ", " b.succ);
  fprintf fmt "  pred: %s@," (String.concat ", " b.pred);
  fprintf fmt "@]@."

(* 打印函数 *)
let pp_func fmt (f:func) =
  fprintf fmt "@[<v>function %s(%s) {@," f.name
    (String.concat ", " f.params);
  List.iter (pp_block fmt) f.blocks;
  fprintf fmt "}@.@."

(* 打印整个程序 *)
let pp_program fmt (p:program) =
  List.iter (pp_func fmt) p
