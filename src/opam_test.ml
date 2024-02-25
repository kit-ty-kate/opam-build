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
  let doc =
    "opam-test is a tool meant to simplify testing local projects that use \
     opam by setting-up a local switch (by default) with all the dependencies, \
     building the packages as if opam was building them, and show their output \
     if something went wrong, then build their tests. \
     It also circumvents an issue with how opam handles test dependencies by \
     installing the test dependencies first, which allows you to have circular \
     dependencies. The tests dependencies that are circular have to be marked \
     with $(b,{with-test & post})"
  in
  let sdocs = Manpage.s_common_options in
  let exits = Cmd.Exit.defaults in
  let term = Term.ret (Common_cmdliner.args main) in
  let info = Cmd.info "opam-test" ~version:Opam_test_config.version ~doc ~sdocs ~exits in
  Cmd.v info term

let () =
  exit (Cmd.eval' cmd)
