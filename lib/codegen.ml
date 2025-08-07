open Ast

let zero = "zero"
let ra = "ra"
let sp = "sp"
let s0 = "s0"
let a0 = "a0"
let a5 = "a5"
let t0 = "t0"
let t1 = "t1"

let label_count = ref 0
let new_label () =
  incr label_count;
  ".L" ^ string_of_int !label_count

type codegen_env = {
  var_scopes: (string * int) list list;
  current_offset: int;
}

let new_env () = { var_scopes = [[]]; current_offset = (-20) }

let enter_scope env = 
  { env with var_scopes = [] :: env.var_scopes }

let exit_scope env =
  { env with var_scopes = List.tl env.var_scopes }

let add_var env id =
  let offset = env.current_offset in
  { var_scopes = ((id, offset) :: List.hd env.var_scopes) :: List.tl env.var_scopes;
    current_offset = offset - 4 }

let find_var env id =
  let rec find_in_scopes = function
    | [] -> failwith ("Undefined variable: " ^ id)
    | scope :: rest ->
        try List.assoc id scope
        with Not_found -> find_in_scopes rest
  in
  find_in_scopes env.var_scopes

(* 生成表达式代码 *)
let rec gen_expr env oc = function
  | EInt n ->
      Printf.fprintf oc "        li      %s,%d\n" a5 n;
      Printf.fprintf oc "        mv      %s,%s\n" a0 a5
  | EId id ->
      let offset = find_var env id in
      Printf.fprintf oc "        lw      %s,%d(%s)\n" a5 offset s0;
      Printf.fprintf oc "        mv      %s,%s\n" a0 a5
  | EUnOp (Neg, e) ->
      gen_expr env oc e;
      Printf.fprintf oc "        sub     %s,%s,%s\n" a5 zero a0;
      Printf.fprintf oc "        mv      %s,%s\n" a0 a5
  | EUnOp (Not, e) ->
      gen_expr env oc e;
      Printf.fprintf oc "        seqz    %s,%s\n" a5 a0;
      Printf.fprintf oc "        mv      %s,%s\n" a0 a5
  | EBinOp (op, e1, e2) ->
    
      (* 计算 e1，结果在 a0 *)
      gen_expr env oc e1;
      (* 保存 a0 到栈 *)
      Printf.fprintf oc "        addi    %s,%s,-4\n" sp sp;
      Printf.fprintf oc "        sw      %s,0(%s)\n" a0 sp;

      (* 计算 e2，结果在 a0 *)
      gen_expr env oc e2;
      (* e2 的结果在 a0，e1 的结果在栈 *)
      Printf.fprintf oc "        mv      %s,%s\n" t1 a0;  (* e2 → t1 *)
      Printf.fprintf oc "        lw      %s,0(%s)\n" t0 sp; (* e1 → t0 *)
      Printf.fprintf oc "        addi    %s,%s,4\n" sp sp;  (* 恢复栈 *)

      (match op with
       | Add ->
           Printf.fprintf oc "        add     %s,%s,%s\n" a5 t0 t1
       | Sub ->
           Printf.fprintf oc "        sub     %s,%s,%s\n" a5 t0 t1
       | Mul ->
           Printf.fprintf oc "        mul     %s,%s,%s\n" a5 t0 t1
       | Div ->
           Printf.fprintf oc "        div     %s,%s,%s\n" a5 t0 t1
       | Mod ->
           Printf.fprintf oc "        rem     %s,%s,%s\n" a5 t0 t1
       |  And ->
                let false_label = new_label () in
                let end_label = new_label () in
                Printf.fprintf oc "        beqz    %s,%s\n" t0 false_label;
                Printf.fprintf oc "        beqz    %s,%s\n" t1 false_label;
                Printf.fprintf oc "        li      %s,1\n" a5;
                Printf.fprintf oc "        j       %s\n" end_label;
                Printf.fprintf oc "%s:\n" false_label;
                Printf.fprintf oc "        li      %s,0\n" a5;
                Printf.fprintf oc "%s:\n" end_label
            | Or ->
                let true_label = new_label () in
                let end_label = new_label () in
                Printf.fprintf oc "        bnez    %s,%s\n" t0 true_label;
                Printf.fprintf oc "        bnez    %s,%s\n" t1 true_label;
                Printf.fprintf oc "        li      %s,0\n" a5;
                Printf.fprintf oc "        j       %s\n" end_label;
                Printf.fprintf oc "%s:\n" true_label;
                Printf.fprintf oc "        li      %s,1\n" a5;
                Printf.fprintf oc "%s:\n" end_label
            | Eq ->
                Printf.fprintf oc "        xor     %s,%s,%s\n" a5 t0 t1;
                Printf.fprintf oc "        seqz    %s,%s\n" a5 a5
            | Neq ->
                Printf.fprintf oc "        xor     %s,%s,%s\n" a5 t0 t1;
                Printf.fprintf oc "        snez    %s,%s\n" a5 a5
            | Lt ->
                Printf.fprintf oc "        slt     %s,%s,%s\n" a5 t0 t1
            | Le ->
                Printf.fprintf oc "        slt     %s,%s,%s\n" a5 t1 t0;
                Printf.fprintf oc "        xori    %s,%s,1\n" a5 a5
            | Gt ->
                Printf.fprintf oc "        slt     %s,%s,%s\n" a5 t1 t0
            | Ge ->
                Printf.fprintf oc "        slt     %s,%s,%s\n" a5 t0 t1;
                Printf.fprintf oc "        xori    %s,%s,1\n" a5 a5);
      (* 将结果移动到a0 *)
      Printf.fprintf oc "        mv      %s,%s\n" a0 a5
  | ECall (id, args) ->(*做出了调整，删除了ecall冗余处理栈帧的问题*)
      (* Printf.fprintf oc "        addi    %s,%s,-32\n" sp sp;
      Printf.fprintf oc "        sw      %s,28(%s)\n" ra sp;
      Printf.fprintf oc "        sw      %s,24(%s)\n" s0 sp;
       *)
      List.iteri (fun i e ->
        gen_expr env oc e;
        if i < 8 then
          begin
           Printf.fprintf oc "        sw      %s,%d(%s)\n"
        a0 (i * 4) sp
          end
         else
          begin
        (* 第 9+ 个参数 → 压到栈上，offset 从 0 开始 *)
        Printf.fprintf oc "        sw      %s,%d(%s)\n"
          a0 ((i)*4) sp
          end
      ) args;

      let n = List.length args in
      if n < 8 then
        begin
          for i = 0 to n - 1 do
            Printf.fprintf oc "        lw      a%d,%d(%s)\n"
        i (i * 4) sp
          done;
        end
      else
        begin
          for i = 0 to 7 do
            Printf.fprintf oc "        lw      a%d,%d(%s)\n"
        i (i * 4) sp
          done;
          for i = 8 to n - 1 do
            Printf.fprintf oc "        lw      t0,%d(%s)\n"
        ((i - 8) * 4) sp;
            Printf.fprintf oc "        sw      t0,%d(%s)\n"
        (i * 4) sp
          done;
        end;

      (* 调用函数 *)
      Printf.fprintf oc "        call    %s\n" id
      
      (* Printf.fprintf oc "        lw      %s,28(%s)\n" ra sp;
      Printf.fprintf oc "        lw      %s,24(%s)\n" s0 sp;
      Printf.fprintf oc "        addi    %s,%s,32\n" sp sp
 *)
let rec gen_stmt env oc break_label cont_label = function
  | SExpr e -> gen_expr env oc e; env
  | SBlock stmts ->
      let new_env = enter_scope env in
      let final_env = List.fold_left (fun env stmt -> 
        gen_stmt env oc break_label cont_label stmt) new_env stmts in
      exit_scope final_env
  | SIf (cond, s1, s2_opt) ->
      let else_label = new_label () in
      let end_label = new_label () in
      gen_expr env oc cond;
      Printf.fprintf oc "        beqz    %s,%s\n" a0 else_label;
      let env1 = gen_stmt env oc break_label cont_label s1 in
      Printf.fprintf oc "        j       %s\n" end_label;
      Printf.fprintf oc "%s:\n" else_label;
      let env2 = match s2_opt with
        | Some s2 -> gen_stmt env1 oc break_label cont_label s2
        | None -> env1 in
      Printf.fprintf oc "%s:\n" end_label;
      env2
  | SWhile (cond, s) ->
      let start_label = new_label () in
      let end_label = new_label () in
      Printf.fprintf oc "%s:\n" start_label;
      gen_expr env oc cond;
      Printf.fprintf oc "        beqz    %s,%s\n" a0 end_label;
      let env' = gen_stmt env oc end_label start_label s in
      Printf.fprintf oc "        j       %s\n" start_label;
      Printf.fprintf oc "%s:\n" end_label;
      env'
  | SBreak ->
      Printf.fprintf oc "        j       %s\n" break_label;
      env
  | SContinue ->
      Printf.fprintf oc "        j       %s\n" cont_label;
      env
  | SReturn None ->
      Printf.fprintf oc "        lw      %s,28(%s)\n" ra sp;
      Printf.fprintf oc "        lw      %s,24(%s)\n" s0 sp;
      Printf.fprintf oc "        addi    %s,%s,32\n" sp sp;
      Printf.fprintf oc "        jr      %s\n" ra;
      env
  | SReturn (Some e) ->
      gen_expr env oc e;
      Printf.fprintf oc "        lw      %s,28(%s)\n" ra sp;
      Printf.fprintf oc "        lw      %s,24(%s)\n" s0 sp;
      Printf.fprintf oc "        addi    %s,%s,32\n" sp sp;
      Printf.fprintf oc "        jr      %s\n" ra;
      env
  | SDecl (id, e) ->
      let new_env = add_var env id in
      gen_expr env oc e;
      let offset = find_var new_env id in
      Printf.fprintf oc "        sw      %s,%d(%s)\n" a0 offset s0;
      new_env
  | SAssign (id, e) ->
      gen_expr env oc e;
      let offset = find_var env id in
      Printf.fprintf oc "        sw      %s,%d(%s)\n" a0 offset s0;
      env

let gen_func oc f =
  Printf.fprintf oc "%s:\n" f.name;
  Printf.fprintf oc "        addi    %s,%s,-32\n" sp sp;
  Printf.fprintf oc "        sw      %s,28(%s)\n" ra sp;
  Printf.fprintf oc "        sw      %s,24(%s)\n" s0 sp;
  Printf.fprintf oc "        addi    %s,%s,32\n" s0 sp;
  
  let env = List.fold_left (fun env p ->
    match p with 
    | PInt id -> add_var env id
  ) (new_env ()) f.params in
  
  List.iteri (fun i p ->
    match p with
    | PInt id ->
        let offset = find_var env id in
        if i < 8 then(*注意这里加begin……end*)
          begin
          Printf.fprintf oc "        sw      %s,%d(%s)\n" (Printf.sprintf "a%d" i) offset s0
          end
        else
          begin
          Printf.fprintf oc "        lw      %s,%d(%s)\n" a5 ((i-8)*4) sp;
          Printf.fprintf oc "        sw      %s,%d(%s)\n" a5 offset s0
          end
  ) f.params;
  
  let _ = gen_stmt env oc "" "" f.body in
  
  if f.return_type = Ast.TInt then (
    Printf.fprintf oc "        li      %s,0\n" a0
  );
  
  Printf.fprintf oc "        lw      %s,28(%s)\n" ra sp;
  Printf.fprintf oc "        lw      %s,24(%s)\n" s0 sp;
  Printf.fprintf oc "        addi    %s,%s,32\n" sp sp;
  Printf.fprintf oc "        jr      %s\n\n" ra

let gen_comp_unit oc = function
  | CUnit funcs ->
      Printf.fprintf oc "        .text\n";
      Printf.fprintf oc "        .globl  main\n\n";
      List.iter (fun f -> gen_func oc f) funcs