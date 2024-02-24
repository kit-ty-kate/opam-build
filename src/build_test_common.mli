(* SPDX-License-Identifier: MIT *)

type switch_kind = Local | Global

val build :
  switch_kind:switch_kind ->
  with_test:bool ->
  unit
