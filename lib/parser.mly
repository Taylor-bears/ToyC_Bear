%{
  open Ast (* Give access to the AST types *)
%}

/* Token Declarations */
%token <int> NUMBER
%token <string> ID
%token INT VOID IF ELSE WHILE BREAK CONTINUE RETURN
%token LPAREN RPAREN LBRACE RBRACE SEMI COMMA
%token ASSIGN EQ NEQ LT LE GT GE AND OR
%token NOT PLUS MINUS TIMES DIV MOD
%token EOF

/* Operator Precedence and Associativity (Lowest to Highest) */
%right ASSIGN
%left OR
%left AND
%left EQ NEQ
%left LT LE GT GE
%left PLUS MINUS
%left TIMES DIV MOD
%right NOT/* Unary operators */

%start <Ast.comp_unit> comp_unit

%%

/* Grammar Rules */
comp_unit:
  | f = list(func_def); EOF { CUnit f }

func_def:
  | rt=func_type; n=ID; LPAREN; p=separated_list(COMMA, param); RPAREN; b=block {
      { return_type = rt; name = n; params = p; body = b }
    }

func_type:
  | INT  { TInt }
  | VOID { TVoid }

param:
  | INT; i=ID { PInt i }

// block:
//   | LBRACE; stmts=list(stmt); RBRACE { SBlock stmts }

stmt:
  | SEMI                                     { SBlock [] }
  | expr; SEMI                               { SExpr $1 }
  | ID; ASSIGN; expr; SEMI                   { SAssign($1, $3) }
  | INT; ID; ASSIGN; expr; SEMI              { SDecl($2, $4) }
  | IF; LPAREN; cond=expr; RPAREN; s1=stmt; ELSE; s2=stmt { SIf(cond, s1, Some s2) }
  | IF; LPAREN; cond=expr; RPAREN; s=stmt    { SIf(cond, s, None) }
  | WHILE; LPAREN; cond=expr; RPAREN; s=stmt { SWhile(cond, s) }
  | BREAK; SEMI                              { SBreak }
  | CONTINUE; SEMI                           { SContinue }
  | RETURN; expr; SEMI                       { SReturn (Some $2) }
  | RETURN; SEMI                             { SReturn None }
  | LBRACE; stmts=list(stmt); RBRACE { SBlock stmts }

expr:
  | i=NUMBER                                 { EInt i }
  | i=ID                                     { EId i }
  | LPAREN; e=expr; RPAREN                   { e }
  | MINUS; e=expr %prec NOT                  { EUnOp(Neg, e) }
  | PLUS;  e=expr %prec NOT                  { e }
  | NOT; e=expr                              { EUnOp(Not, e) }
  | e1=expr; op=binop; e2=expr                { EBinOp(op, e1, e2) }
  | ID; LPAREN; args=separated_list(COMMA, expr); RPAREN { ECall($1, args) }

%inline binop:
  | PLUS  { Add } | MINUS { Sub } | TIMES { Mul } | DIV   { Div } | MOD   { Mod }
  | EQ    { Eq }  | NEQ   { Neq } | LT    { Lt }  | LE    { Le }  | GT    { Gt }  | GE    { Ge }
  | AND   { And } | OR    { Or }

%%