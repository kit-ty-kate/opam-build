(* SPDX-License-Identifier: MIT *)

module Term = Cmdliner.Term
module Arg = Cmdliner.Arg
module Cmd = Cmdliner.Cmd
module Manpage = Cmdliner.Manpage

let ( $ ) = Cmdliner.Term.( $ )
let ( & ) = Cmdliner.Arg.( & )

let switch_kind =
  let local =
    let doc =
      "Enforce to use a local switch to build the project in \
       the current directory. This is the default"
    in
    Arg.info ["local"] ~doc
  in
  let global =
    let doc =
      "Enforce to use the currently set global switch to build \
       the project in the current directory. \
       See $(b,--write-config-only) to set this behaviour to be the default."
    in
    Arg.info ["global"] ~doc
  in
  Arg.value &
  Arg.vflag None [
    (Some Build_test_common.Global, global);
    (Some Build_test_common.Local, local);
  ]

let write_config_only =
  let doc =
    "Writes to the configuration file with the values of \
     the other arguments if applicable, then exits. \
     For example, $(b,--write-config-only --global) will \
     set the mode to be global by default."
  in
  Arg.value & Arg.flag & Arg.info ["write-config-only"] ~doc

let args f =
  let f switch_kind write_config_only =
    if write_config_only then begin
      Stdlib.Option.iter Configfile.set_switch_kind switch_kind;
      `Ok 0
    end else
      let switch_kind = match switch_kind with
        | Some v -> Some v
        | None ->
            match Configfile.switch_kind () with
            | Some v -> Some v
            | None ->
                if
                  OpamConsole.confirm "By default a local switch will be created.\n\
                                       This can be overriden using %s.\n\
                                       If you do not want to see this message, please use %s together with either %s or %s.\n\
                                       Do you want to continue?"
                    (OpamConsole.colorise `bold "--global")
                    (OpamConsole.colorise `bold "--write-config-only")
                    (OpamConsole.colorise `bold "--global")
                    (OpamConsole.colorise `bold "--local")
                then
                  Some Build_test_common.Local
                else
                  None
      in
      match switch_kind with
      | Some switch_kind -> f switch_kind
      | None -> `Ok 1
  in
  Term.const f $ switch_kind $ write_config_only
