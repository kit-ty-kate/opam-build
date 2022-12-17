(* SPDX-License-Identifier: MIT *)

val args : (Build_test_common.switch_kind -> string option -> 'a) -> 'a Cmdliner.Term.t
