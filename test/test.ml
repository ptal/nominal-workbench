(* Distributed under the MIT License.
  (See accompanying file LICENSE.txt)
  (C) Copyright Pierre Talbot
*)

open Printf
open Display_test
open Test_ast
open Test_from_xml

(* Test framework. *)
let string_of_error (Error(name, domain)) =
  sprintf "%s.%s" domain name

let equal_error (Error(name1, domain1)) (Error(name2, domain2)) =
  (name1 = name2) && (domain1 = domain2)

let strip_ws str =
  Str.global_replace (Str.regexp " +") "" str

(* Only a textual equality test. *)
let equal_term t1 t2 =
  (strip_ws t1) = (strip_ws t2)

(* Term rewriting tests. *)
let check_term_expectation expectation result domain success_cont =
  match (expectation, result) with
  | (TMustPass(_), TFailed(e)) ->
    print_failure (sprintf "Failure with error %s." ( string_of_error e))
  | (TMustFail(e), TPassed(t)) -> print_failure
      (sprintf "Should have failed with %s but passed with %s." (string_of_error e) t)
  | (TMustFail(expected), TFailed(e)) when not ( equal_error expected e ) ->
      print_failure (sprintf "Expected error %s but failed with %s."
        (string_of_error expected)
        (string_of_error e))
  | (TMustFail(_), TFailed(e)) ->
      print_success (sprintf "Failure with %s as expected." (string_of_error e))
  | (TMustPass(t1), TPassed(t2)) when not (equal_term t1 t2) ->
      print_failure (sprintf "Bad term rewriting, expected %s but got %s." t1 t2)
  | (TMustPass(t1), TPassed(t2)) -> success_cont ()

let rewritten_success t1 t2 () =
  print_success (sprintf "Term %s has been correctly rewritten in %s." t1 t2)

let check_processed_term term rules expectation =
  let open Rewriting_error in
  let open Symbols in
  try
    let strategy = Strategy_ast.(bottomup any_rule) in
    let rewritten_term = Rewriting.rewrite_rec strategy rules term in
    let srewritten_term = Term_ast.string_of_term rewritten_term in
    check_term_expectation expectation (TPassed(srewritten_term)) domain_name
     (rewritten_success (Term_ast.string_of_term term) srewritten_term)
  with
  | RewritingError(code, _) ->
      check_term_expectation expectation (TFailed(Error(string_of_error_code code, domain_name)))
        domain_name ignore
  | e -> print_unknown_exc e "term rewriting"


let check_term system (TermTest(libs, term, expectation)) =
  let open Term_parsing_error in
  let open Symbols in
  try
    let term =
      begin 
	match Parser.start Lexer.token (Lexing.from_string term) with
	| [Parsetree.PTerm t] -> t
	| (Parsetree.PTerm _)::_ ->
	  print_system_error "You can only test one item at a time";
	  raise (TermParsingError(SyntaxError, "Expected one term"))
	| _ -> print_system_error "This is not a term."; 
	  raise (TermParsingError(SyntaxError, "Expected a term"))
      end
    in
    check_processed_term term system expectation
  with
  | TermParsingError(code, _) ->
    check_term_expectation expectation (TFailed(Error(string_of_error_code code, domain_name)))
      domain_name ignore
  | e -> print_unknown_exc e "parsing of the terms"

let check_terms system terms () =
  List.iter (check_term system) (List.rev terms)

(* Rewriting System test *)
let check_expectation expectation result domain success_cont =
  match (expectation, result) with
  | (MustPass, Failed(e)) -> print_failure (sprintf "Failure with error %s." (string_of_error e))
  | (MustFail(e), Passed) -> print_failure (sprintf "Should have failed with %s." (string_of_error e))
  | (MustFail(expected), Failed(e)) when not ( equal_error expected e ) ->
      print_failure (sprintf "Expected error %s but failed with %s."
        (string_of_error expected)
        (string_of_error e))
  | (MustFail(_), Failed(e)) ->
      print_success (sprintf "Failure with %s as expected." (string_of_error e))
  | (MustPass, Passed) -> success_cont ()

let check_rewriting_system ast (SystemTest(name, file, expectation, terms)) =
  let open Parsetree in
  let decls_and_includes = 
    List.filter (function PDecl _ | PFile_include _ -> true | _ -> false) 
      ast in
  let open Rewriting_system_error in
    try 
      let system = List.fold_left Eval.evaluate_structure_item 
	Symbols.empty_system decls_and_includes in
	Eval.run_type_check system ast;
	let success_cont = match terms with
	  | [] -> (fun () -> print_success (sprintf "%s passed." name))
	  | _ -> check_terms system terms 
	in
	  check_expectation expectation Passed domain_name success_cont
    with
      | RewritingSystemError(code, _) ->
	  check_expectation expectation (Failed(Error(string_of_error_code code, domain_name)))
            domain_name ignore
      | e -> print_unknown_exc e "check of the rewriting system"

let test_rewriting_system channel (SystemTest(_,_, expectation, _) as sys_test)  =
  let open Rewriting_parsing_error in
  try
    check_rewriting_system (Parser_include.parse_rewriting_system channel) sys_test
  with
  | RewritingParsingError(code,_) ->
      check_expectation expectation (Failed(Error(string_of_error_code code, domain_name)))
        domain_name ignore
  | e -> print_unknown_exc e "parsing of the rewriting system"

let launch_test no (SystemTest(name, file, _, _) as sys_test) =
  print_test no name file;
  try
    if Sys.is_directory file then
      print_system_error (sprintf "%s: is a directory" file)
    else
      let f = open_in file in
      test_rewriting_system f sys_test;
      close_in f
  with
  | Sys_error(e) -> print_system_error e

let rec launch_tests_impl no tests =
  match tests with
  | [] -> ()
  | hd::tl ->
    launch_test no hd;
    launch_tests_impl (no+1) tl

let launch_tests tests =
  launch_tests_impl 1 tests

let () =
try
  Printexc.record_backtrace true;
  let xtest = Xml.parse_file "data/test/test.xml" in
  let dtd = Dtd.parse_file "data/test/test.dtd" in
  let valid_xtest = Dtd.prove (Dtd.check dtd) "test" xtest in
  launch_tests (test_of_xml valid_xtest)
with
| Dtd.Check_error(e) -> print_endline ("Dtd.Check_error: " ^ (Dtd.check_error e))
| Dtd.Prove_error(e) -> print_endline ("Dtd.Prove_error: " ^ (Dtd.prove_error e))
| Dtd.Parse_error(e) -> print_endline ("Dtd.Parse_error: " ^ (Dtd.parse_error e))
| Xml.Error(e) -> print_endline ("Xml.Error: " ^ (Xml.error e))
| Xml.File_not_found(s) -> printf "File %s not found.\n" s
| e ->
    printf "Something got really wrong, here the exception backtrace:\n";
    printf "Exception: %s.\n" ( Printexc.to_string e );
    Printexc.print_backtrace stdout
