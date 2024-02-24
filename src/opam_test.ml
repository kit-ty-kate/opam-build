(* SPDX-License-Identifier: MIT *)

module Term = Cmdliner.Term
module Arg = Cmdliner.Arg
module Cmd = Cmdliner.Cmd
module Manpage = Cmdliner.Manpage

let ( $ ) = Cmdliner.Term.( $ )
let ( & ) = Cmdliner.Arg.( & )

let main switch_kind =
  Build_test_common.build ~switch_kind ~with_test:true;
  `Ok 0

let cmd =
  let doc = "" in (* TODO *)
  let sdocs = Manpage.s_common_options in
  let exits = Cmd.Exit.defaults in
  let man = [] in (* TODO *)
  let term = Term.ret (Common_cmdliner.args main) in
  let info = Cmd.info "opam-test" ~version:Opam_test_config.version ~doc ~sdocs ~exits ~man in
  Cmd.v info term

let () =
  exit (Cmd.eval' cmd)
