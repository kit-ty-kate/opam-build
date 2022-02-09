(* SPDX-License-Identifier: MIT *)

val build :
  upgrade:bool ->
  lower_bounds:bool ->
  with_test:bool ->
  dirname:string option ->
  unit
