open Rewriting_ast
open Strategy_ast
open Term_ast
open Interactive_ast

type term_expr = 
| PTermLet of string * term_expr
| PTermRewrite of term_expr * strategy
| PTerm of term_ast

type structure = structure_item list

and structure_item =
| PInteractiveCmd of interactive_ast
| PDecl of rewriting_decl
| PTermExpr of term_expr
| PFile_include of string
(* | Strategy *)