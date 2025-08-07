open Ir
open Ast

(* 简单 env：局部变量名 -> temp/地址，这里直接用 temp 映射 *)
type env = (string, temp) Hashtbl.t


(* —— 新增一个小帮手，用来给每个 label 加上函数名前缀 —— *)
 let label_of (b: builder) (kind: string) : label =
   (* builder.func_name 已经是当前函数名 *)
   new_label b (b.func_name ^ "_" ^ kind)


let rec gen_expr (b:builder) (env:env) (e:expr):operand =
  match e with
  | EInt n-> Const n
  | EId x ->
    let t = Hashtbl.find env x in
    Temp t
  | EUnOp (op, e1) ->
    let operand = gen_expr b env e1 in
    let t = new_temp b in
    emit b (UnOp (t, op, operand));
    Temp t

  | EBinOp (And, e1, e2) ->
      (* 短路：if (!e1) => false，否则求 e2 *)
      let t = new_temp b in
      let l_false = label_of b "land_false_" in
      let l_end   = label_of b "land_end_"   in

      let v1 = gen_expr b env e1 in
      emit b (IfZero (v1, l_false));          (* if !v1 goto false *)
      let v2 = gen_expr b env e2 in
      emit b (Move (t, v2));
      emit b (Goto l_end);

      start_block b l_false;
      emit b (Move (t, Const 0));
      emit b (Goto l_end);

      start_block b l_end;
      Temp t

  | EBinOp (Or, e1, e2) ->
      (* 短路：if (e1) => true，否则求 e2 *)
      let t = new_temp b in
      let l_true = label_of b "lor_true_" in
      let l_end  = label_of b "lor_end_"  in

      let v1 = gen_expr b env e1 in
      (* if v1 == 0 不跳，非 0 跳到 true *)
      (* 这里简单用 Not + IfZero，也可定制 IfNZ 指令 *)
      (* 先生成: ifZero(v1) -> else ；否则走 true *)
      (* 为简单：把 Or 拆成: ifZero v1 goto L_else;  t=v1; goto end; else: eval e2; t=e2 *)
      emit b (IfNotZero (v1, l_true));(*如果v1不是0直接跳*)
      (*如果没跳，计算e2*)
      let v2 = gen_expr b env e2 in
      emit b (IfNotZero (v2, l_true)); (*如果v2不是0直接跳*)
      (*false分支*)
      emit b (Move (t,Const 0));
      emit b (Goto l_end);
      (*true分支*)
      start_block b l_true;
      emit b (Move (t, Const 1));
      emit b (Goto l_end);
      start_block b l_end;
      Temp t

  | EBinOp (op, e1, e2) ->
    let op1 = gen_expr b env e1 in
    let op2 = gen_expr b env e2 in
    let t = new_temp b in
    emit b (BinOp (t, op, op1, op2));
    Temp t
  | ECall (fname,args) ->
    let args_ops = List.map (gen_expr b env) args in
    let t = new_temp b in
    emit b (Call (Some t, fname, args_ops));
    Temp t
  

let rec gen_stmt (b:builder) (env:env) (s:stmt):unit =
  match s with
  | SExpr e-> ignore (gen_expr b env e)
  | SDecl (id,e) ->
    let t = new_temp b in
    Hashtbl.add env id t;
    let v = gen_expr b env e in
    emit b (Move (t, v))
  | SAssign (id,e)->
    let t = Hashtbl.find env id in
    let v = gen_expr b env e in
    emit b (Move (t, v))
  | SReturn None ->
    emit b (Return None)
  | SReturn (Some e) ->
    let v = gen_expr b env e in
    emit b (Return (Some v))
  | SBlock stmts ->
    (*进入新的作用域*)
    let env_backup = Hashtbl.copy env in
    List.iter (gen_stmt b env) stmts;
    (*作用域结束*)
    Hashtbl.clear env;
    Hashtbl.iter (fun id t -> Hashtbl.add env id t) env_backup
  | SIf (cond, then_stmt, else_stmt_opt) ->
    let l_then = label_of b "then_" in
    let l_else = label_of b "else_" in
    let l_end = label_of b "endif_" in

    let c = gen_expr b env cond in
    emit b (IfZero (c, l_else));
    emit b (Goto l_then);
    (*条件不成立的模块*)
    (*条件成立的模块*)
    start_block b l_then;
    gen_stmt b env then_stmt;
    emit b (Goto l_end);
    (*条件不成立的模块*)
    start_block b l_else;
    (match else_stmt_opt with
       | Some s -> gen_stmt b env s
       | None -> ());
    emit b (Goto l_end);
    (*结束模块*)
    start_block b l_end; 
  | SWhile (cond, body) ->
    let l_cond = label_of b "while_cond_" in
    let l_body = label_of b "while_body_" in
    let l_end = label_of b "while_end_" in

    emit b (Goto l_cond);
    start_block b l_cond;
    let c = gen_expr b env cond in
    emit b (IfZero (c, l_end));
    emit b (Goto l_body);
    
    (*循环体*)
    
    start_block b l_body;
    (* push break/continue 目标 *)
      b.break_stack   := l_end  :: !(b.break_stack);
      b.continue_stack := l_cond :: !(b.continue_stack);
      gen_stmt b env body;
      (* pop *)
      b.break_stack   := List.tl !(b.break_stack);
      b.continue_stack := List.tl !(b.continue_stack);
    emit b (Goto l_cond);
    
    start_block b l_end;

   | SBreak ->
      let target = List.hd !(b.break_stack) in
      emit b (Goto target)

  | SContinue ->
      let target = List.hd !(b.continue_stack) in
      emit b (Goto target)
let gen_func (f:func_def) : func =
  (* 初始化 builder *)
  let entry = mk_block (f.name^"_entry") in
  let b = {
    func_name = f.name;
    (* 当前块：从 entry 开始 *)
    cur_block = entry;
    blocks    = [];
    tcnt      = 0;
    lcnt      = 0;
    break_stack = ref [];
    continue_stack = ref [];
  } in

  (* 建 env: 给形参分配 temp *)
  let env = Hashtbl.create 64 in
  let params =
    List.map (function PInt id ->
      let t = new_temp b in
      Hashtbl.add env id t;
      id
    ) f.params
  in

  (* 函数体 *)
  gen_stmt b env f.body;


  (* 若最后块没有 Return/Goto，补一个返回 0（对 void 则 Return None） *)
  
    (match List.rev b.cur_block.code with
    | Return _ :: _ | Goto _ :: _ -> ()
    | _ ->
        emit b (Return (if f.return_type = TInt then Some (Const 0) else None)));
  
  (* 收尾：把当前块也放进去 *)
  b.blocks <- b.cur_block :: b.blocks;
  let blocks = List.rev b.blocks in

  (* 建 CFG 边 *)
  let tbl = Hashtbl.create (List.length blocks) in
  List.iter (fun bl -> Hashtbl.add tbl bl.lbl bl) blocks;
  let add_edge from_l to_l =
    let from_b = Hashtbl.find tbl from_l
    and to_b   = Hashtbl.find tbl to_l in
    from_b.succ <- to_l :: from_b.succ;
    to_b.pred   <- from_l :: to_b.pred
  in
  (*判断是不是终结指令*)
  let is_term = function
    | Goto _ | IfZero _ | IfNotZero _ | Return _ -> true
    | _ -> false
in

let  collect_terms code = 
  let rec loop acc = function
    | []->acc
    | i::tl when is_term i->loop (i::acc) tl
    | _::tl -> loop acc tl
in loop [] (List.rev code)
in
List.iter (fun bl ->
  let terms = collect_terms bl.code in
  List.iter (function
    | Goto l              -> add_edge bl.lbl l
    | IfZero    (_, l)    -> add_edge bl.lbl l
    | IfNotZero (_, l)    -> add_edge bl.lbl l
    | Return _            -> ()
    | _ -> ()
  ) terms
) blocks;

  { name = f.name; params; blocks }

(*顶层调用函数*)
let lower (CUnit fs) : program =
  List.map gen_func fs



