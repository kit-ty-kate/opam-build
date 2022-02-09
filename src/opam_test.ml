(* SPDX-License-Identifier: MIT *)

module Term = Cmdliner.Term
module Arg = Cmdliner.Arg
module Manpage = Cmdliner.Manpage

let ( $ ) = Cmdliner.Term.( $ )
let ( & ) = Cmdliner.Arg.( & )

let main dirname =
  Build_test_common.build ~upgrade:false ~lower_bounds:false ~with_test:true ~dirname;
  `Ok ()

let dirname =
  let doc = "" in (* TODO *)
  Arg.value &
  Arg.pos 0 (Arg.some Arg.dir) None &
  Arg.info [] ~docv:"DIR" ~doc

let cmd =
  let doc = "" in (* TODO *)
  let sdocs = Manpage.s_common_options in
  let exits = Term.default_exits in
  let man = [] in (* TODO *)
  Term.ret (Term.const main $ dirname),
  Term.info "opam-test" ~version:Opam_test_config.version ~doc ~sdocs ~exits ~man

let () =
  Term.exit @@ match Term.eval cmd with
  | `Ok () -> `Ok ()
  | (`Error _ | `Version | `Help) as x -> x
