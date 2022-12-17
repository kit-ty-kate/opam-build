(* SPDX-License-Identifier: MIT *)

module Term = Cmdliner.Term
module Arg = Cmdliner.Arg
module Cmd = Cmdliner.Cmd
module Manpage = Cmdliner.Manpage

let ( $ ) = Cmdliner.Term.( $ )
let ( & ) = Cmdliner.Arg.( & )

let main dirname =
  Build_test_common.build ~with_test:false ~dirname;
  `Ok ()

let dirname =
  let doc = "" in (* TODO *)
  Arg.value &
  Arg.pos 0 (Arg.some Arg.dir) None &
  Arg.info [] ~docv:"DIR" ~doc

let cmd =
  let doc = "" in (* TODO *)
  let sdocs = Manpage.s_common_options in
  let exits = Cmd.Exit.defaults in
  let man = [] in (* TODO *)
  let term = Term.ret (Term.const main $ dirname) in
  let info = Cmd.info "opam-build" ~version:Opam_build_config.version ~doc ~sdocs ~exits ~man in
  Cmd.v info term

let () =
  exit (Cmd.eval cmd)
