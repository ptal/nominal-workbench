


val rewrite:
  Rewriting_ast.pattern * Rewriting_ast.effect ->
  (Matching.placeholders -> Rewriting_ast.effect -> 'b) ->
  (Term_ast_dag.term_dag -> 'b) -> Term_ast_dag.term_dag -> 'b


val rewrite_rec: Strategy_ast.strategy ->
  Symbols.system -> Term_ast.term_ast list -> Term_ast.term_ast list
