open Lex_project
(* open Ast *)

let dump_ast = ref false
let dump_ir = ref false
let dump_asm = ref false
let dump_opt = ref false

(* 解析命令行参数 *)
let speclist = [
  ("-ast",Arg.Set dump_ast,"PRINT AST");
  ("-ir",Arg.Set dump_ir,"PRINT IR");
  ("-asm",Arg.Set dump_asm,"PRINT ASM");
  ("-opt",Arg.Set dump_opt,"PRINT OPT");
]
(*
用法介绍：终端输入：
    dune exec toyc_compiler -- -para 
其中： -para是编译器参数
  -ast: 打印 AST
  -ir: 打印 IR
  -asm: 打印汇编代码
  -opt : 打印优化后的 代码
*)
let usage = "usage: compiler [-ast] [-ir] [-S] < source.c"
(* 主函数 *)
let () =
  Arg.parse speclist (fun _ -> ()) usage;
  try
    let lexbuf = Lexing.from_channel stdin in
    let ast = Parser.comp_unit Lexer.token lexbuf in
    let ir_prog = Irgen.lower ast in
    (* let _ = Semantic.check_comp_unit ast in *)
    if ! dump_ast then Ast.print_comp_unit ast;
    if ! dump_ir then
      begin
      Format.fprintf Format.std_formatter "%a" Pp_ir.pp_program ir_prog;
      
      end;
    if !dump_opt then
      begin
      Ir_codegen.emit_program ir_prog |> print_string
      end;
   (* 若要求生成汇编，或者用户没给任何标志（默认后端） *)
    if !dump_asm || not (!dump_ast || !dump_ir || !dump_opt) then
      begin
        Ir_codegen.emit_program ir_prog |> print_string
      end;


    (* 这里可以调用代码生成器将 IR 转换为目标代码 *)
    (* Codegen.gen_program stdout ir_prog; *)
    (* 最后输出结果 *)
    flush stdout
  with
  | Semantic.Semantic_error "缺少 int main() 函数" ->
      Printf.eprintf "错误：必须定义 int main() 函数\n";
      exit 1
  | Lexer.Error msg -> Printf.eprintf "词法错误: %s\n" msg; exit 1
  | Parser.Error -> Printf.eprintf "语法错误\n"; exit 1
  | Semantic.Semantic_error msg -> Printf.eprintf "语义错误: %s\n" msg; exit 1
  | e -> Printf.eprintf "未知错误: %s\n" (Printexc.to_string e); exit 1