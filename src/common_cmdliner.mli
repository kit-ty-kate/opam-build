(* SPDX-License-Identifier: MIT *)

val args : (Build_test_common.switch_kind -> string option -> ([> `Ok of int] as 'a)) -> 'a Cmdliner.Term.t
