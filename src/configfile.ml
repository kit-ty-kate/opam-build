(* SPDX-License-Identifier: MIT *)

module Parser = OpamParserTypes.FullPos

let ( // ) = Filename.concat

let config_file = lazy (
  let xdg = Xdg.create ~win32:Sys.win32 ~env:Sys.getenv_opt () in
  OpamFile.make (OpamFilename.raw (Xdg.config_dir xdg // "opam-build" // "config"))
)

let read () =
  match OpamFile.OPAM.read_opt (Lazy.force config_file) with
  | None -> OpamFile.OPAM.empty
  | Some x -> x

let switch_kind () =
  let file = read () in
  match OpamStd.String.Map.find_opt "x-switch-kind" (OpamFile.OPAM.extensions file) with
  | Some Parser.{pelem = Ident "global"; _} -> Some Build_test_common.Global
  | Some Parser.{pelem = Ident "local"; _} -> Some Build_test_common.Local
  | Some _ | None -> None

let with_pos_null pelem =
  {Parser.pelem; pos = {Parser.filename = ""; start = (-1, -1); stop = (-1, -1)}}

let set_switch_kind switch_kind =
  let file = read () in
  let switch_kind = match switch_kind with
    | Build_test_common.Global -> "global"
    | Build_test_common.Local -> "local"
  in
  let switch_kind = with_pos_null (Parser.Ident switch_kind) in
  let file = OpamFile.OPAM.add_extension file "x-switch-kind" switch_kind in
  OpamFile.OPAM.write_with_preserved_format (Lazy.force config_file) file
