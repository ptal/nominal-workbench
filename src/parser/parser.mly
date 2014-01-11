%{
(* Distributed under the MIT License.
  (See accompanying file LICENSE.txt)
  (C) Copyright Matthieu Dien
  (C) Copyright Vincent Botbol
*)

  open Parsing
  open Lexing
  open Ast
  open Include

  let err_msg = fun kwd name msg ->
    let pos = Parsing.symbol_start_pos () in
    kwd ^ " \"" ^ name ^"\" " ^ msg ^ " line \
    " ^ (string_of_int (pos.Lexing.pos_lnum)) ^ ", col \
    " ^ (string_of_int (pos.Lexing.pos_cnum - pos.Lexing.pos_bol))

  let annote_pos item =
    let pos = Parsing.symbol_start_pos () in
    { value = item ; info = pos }

%}

/* values */
%token <float> NUM
%token <string> WORD FILENAME

/* keywords */
%token KIND TYPE ATOM OPERATOR RULE CONSTANT INCLUDE

/* punctuation */
%token LPAREN RPAREN LBRACKET RBRACKET LACCOL RACCOL SEMICOL COLON EQUAL ARROW
%token DARROW STAR COMMA QMARK NEWLINE

%token EOF

%start start
%type <Lexing.position Ast.definitions> start

%start toplevel_phrase
%type <Lexing.position Ast.definitions> toplevel_phrase

%right STAR DARROW ARROW

%%

start:
| decls EOF { $1 }

toplevel_phrase:
| decls SEMICOL SEMICOL { $1 }
| EOF { raise End_of_file }
;

decls :
| decl decls
    {
        let kind, const, operator, rule = $1 in
        let kinds, consts, operators, rules = $2 in
        (kind@kinds, const@consts, operator@operators, rule@rules)
    }
| decl { $1 }

decl:
| kind_decl { ([$1], [], [], []) }
| constant_decl { ([], [$1], [], []) }
| operator_decl { ([], [], [$1], []) }
| rule_decl { ([], [], [], [$1]) }
| INCLUDE FILENAME { ([], [], [], []) }
| NEWLINE { ([], [], [], []) }


/* kinds */

kind_decl:
| KIND WORD COLON kind_lfth { annote_pos ($2, $4) }

kind_lfth:
| kind_type { $1 }

kind_type:
| kind_type STAR kind_type
    { Type } /* TODO just to compile */
| kind_type DARROW kind_type { Type } /* TODO just to compile */
| TYPE { Type }
| ATOM { Atom }


  /* constants */

constant_decl:
| CONSTANT WORD COLON WORD
    { annote_pos ($2, annote_pos @@ Kind(annote_pos $4)) }

  /* operators */

operator_decl:
| OPERATOR WORD COLON operator_type ARROW operator_type
    { annote_pos ($2, ($4, $6)) }

operator_type:
| WORD { annote_pos @@ Kind(annote_pos $1) }
| LBRACKET WORD RBRACKET { annote_pos @@ Abs(annote_pos $2) }
| operator_type STAR operator_type { annote_pos @@ Kind(annote_pos "toto") }
  /* Only to compile, don't try do find a meaning.
     For more information : trebuchet-style-coding.com */


/* | operator_type operator_prod_tail { annote_pos @@ Prod($1::$2) } */
/* | STAR operator_type operator_prod_tail { $2::$3 } */


  /* rules */

rule_decl:
| rule_head rule_body { annote_pos ($1, $2) }
| rule_head NEWLINE rule_body { annote_pos ($1, $3) }

rule_head:
| RULE LBRACKET WORD RBRACKET COLON { $3 }

rule_body:
| rule_side DARROW rule_side { ($1, $3) }

rule_side:
| WORD { annote_pos @@ Constant(annote_pos $1) } /* obvious case of ambiguity */
| WORD LPAREN RPAREN { annote_pos @@ Operator(annote_pos $1, []) }
| WORD LPAREN rule_side_list RPAREN
    { annote_pos @@ Operator(annote_pos $1, $3) }
| QMARK WORD { annote_pos @@ Placeholder( annote_pos $2) }

rule_side_list:
| rule_side COMMA rule_side_list { $1::$3 }
| rule_side { [$1] }

%%
