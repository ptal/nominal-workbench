(* Distributed under the MIT License.
  (See accompanying file LICENSE.txt)
  (C) Copyright Vincent Botbol
*)

(** Toplevel loop functions *)


(** Toplevel's main loop. [loop ppf] dumps the outputs on [ppf] *)
val loop : Format.formatter -> unit
