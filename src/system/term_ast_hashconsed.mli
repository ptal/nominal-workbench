(* Distributed under the MIT License.
  (See accompanying file LICENSE.txt)
  (C) Copyright Pierrick Couderc
*)

open Term_ast_typed

(** Renaming only for comprehension of the hterm structure *)
type id = int
type ident = string

(** This type is created by the hashconsing algorithm.
    It allows to store the already calculated hashed value, which is used byt
    the hlist and permits a more efficient hashconsing of lists *)
type 'a hashed = private { id: id; hash : int; value : 'a }

(** /!\ Should be private but causes a typing issue in matching. To fix /!\

    Type of a hashsconsed list, for the subterms of a term.
*)
type 'a hlist = 'a hashed list

(** The representation is the following:
    - Free variables and constants are represented by their real value;
    - A binded variables uses a de Bruijn index, which is mandatory to be able
    to reason about the context;
    - A binder is a list of ids, which are the ids of hashed values in a hlist;
    - A term is simply a name with a hashconsed list of already hashconsed
    terms.
*)
type hterm_raw = private
  | HConst of ident
  | HTerm of ident * hterm_raw hlist
  | HBinder of id hlist (* refers to the id of the head of an hashconsed
                           list. *)
  | HVar of int
  | HFreeVar of ident

(** Since the hashconsed term loses the variables name to be able to reason
    modulo alpha-conversion, we export a representation of the lost binders and
    variables names into a tree identical as the hterm_raw created. *)
type hterm_name = private
  | NTerm of hterm_name list
  | NName of string
  | NAny

(** A hterm contains then the hashconsed term and its name tree representation. *)
type hterm = private { term: hterm_raw; binders: hterm_name }

(** [create_term t] hashconses [t] into a hterm. *)
val create_term : Term_ast_typed.term_ast_with_binders -> hterm

(** [create_dterm ht] recreates a dterm from the hashconsed term [ht]. *)
val create_dterm : hterm -> Term_ast_typed.term_ast_with_binders

(** [dot ht filename] prints the dot representation of [t] into [filename]. *)
val dot : hterm -> string -> unit


(* All those functions and types are debug functions, only used for unit tests.
   Will disappear when push in "production" *)


type bindings = (ident * id list ref) list

val create_hlist : bindings -> hterm_name list ->(Term_ast_typed.ident * int) list ->
           Term_ast_typed.term_ast_with_binders list ->
           hterm_raw hlist * hterm_name list

val string_of_hterm : hterm_raw -> string

val pretty_print_list : hterm_raw hlist -> unit

(** Pretty prints a hterm without its name, to be able to see the representation *)
val pretty_print : hterm -> unit

val pretty_print_names : hterm_name -> unit