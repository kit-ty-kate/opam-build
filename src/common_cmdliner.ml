(* SPDX-License-Identifier: MIT *)

module Term = Cmdliner.Term
module Arg = Cmdliner.Arg
module Cmd = Cmdliner.Cmd
module Manpage = Cmdliner.Manpage

let ( $ ) = Cmdliner.Term.( $ )
let ( & ) = Cmdliner.Arg.( & )

let switch_kind =
  let local =
    let doc = "" in (* TODO *)
    Arg.info ["local"] ~doc
  in
  let global =
    let doc = "" in (* TODO *)
    Arg.info ["global"] ~doc
  in
  Arg.value &
  Arg.vflag (Configfile.switch_kind ()) [
    (Build_test_common.Global, global);
    (Build_test_common.Local, local);
  ]

let dirname =
  let doc = "" in (* TODO *)
  Arg.value &
  Arg.pos 0 (Arg.some Arg.dir) None &
  Arg.info [] ~docv:"DIR" ~doc

let args f = Term.const f $ switch_kind $ dirname
