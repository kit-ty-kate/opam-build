(* SPDX-License-Identifier: MIT *)

type switch_kind = Local | Global

let dev_version = OpamPackage.Version.of_string "dev"

let get_pkg OpamStateTypes.{pin_name = name; _} =
  OpamPackage.create name dev_version

let get_pkgs () =
  List.map get_pkg (OpamAuxCommands.opams_of_dir (OpamFilename.cwd ()))

(* TODO: Temporary code while https://github.com/ocaml/opam/issues/5855 gets fixed *)
(* TODO: but maybe we actually want those packages to be pinned in local mode
   e.g. what happens if the pins are simulated and users do opam upgrade? *)
let local_nonsimulated_pin ~pkgs st =
  let st =
    OpamCoreConfig.update ~yes:(Some true) (); (* TODO: do better *)
    List.fold_left (fun st pkg ->
      let name = OpamPackage.name pkg in
      (* TODO: make it non-verbose *)
      OpamPinCommand.source_pin st name
        ~edit:false
        ~version:dev_version
        ~quiet:true
        (Some (OpamUrl.of_string "."))
    ) st pkgs
  in
  OpamCoreConfig.update ~yes:None ();
  let atoms =
    OpamPackage.Set.fold (fun pkg acc ->
      let name = OpamPackage.name pkg in
      let version = OpamPackage.version pkg in
      (name, Some (`Eq, version)) :: acc
    ) st.OpamStateTypes.pinned []
  in
  (st, atoms)

let create_switch ~pkgs gt =
  print_endline "A local switch is being created...";
  OpamRepositoryState.with_ `Lock_none gt @@ fun rt ->
  let (), st =
    OpamSwitchCommand.create gt ~rt
      ~update_config:true
      ~invariant:OpamFormula.Empty
      (OpamSwitch.of_string ".") @@ fun st ->
    let st, atoms = local_nonsimulated_pin ~pkgs st in
    let st =
      OpamClient.install_t st
        ~ask:false (* TODO *)
        atoms (Some true)
        ~deps_only:true ~assume_built:false
    in
    ((), st)
  in
  st

let check_switch ~pkgs ~switch_kind gt k =
  match switch_kind with
  | Local ->
      begin match OpamStateConfig.get_current_switch_from_cwd gt.OpamStateTypes.root with
      | None -> k (create_switch ~pkgs gt)
      | Some switch -> OpamSwitchState.with_ `Lock_write ~switch gt k
      end
  | Global ->
      begin match (!OpamStateConfig.r).current_switch with
      | None -> failwith "TODO"
      | Some switch when OpamSwitch.is_external switch -> failwith "TODO"
      | Some switch -> OpamSwitchState.with_ `Lock_write ~switch gt k
      end

let check_dependencies ~pkgs ~switch_kind st =
  let st, atoms =
    match switch_kind with
    | Local ->
        local_nonsimulated_pin ~pkgs st
    | Global ->
        OpamAuxCommands.simulate_autopin st ~recurse:false ~quiet:true [`Dirname (OpamFilename.cwd ())]
  in
  let missing = OpamClient.check_installed ~build:true ~post:true st atoms in
  if not (OpamPackage.Map.is_empty missing) then
    OpamClient.install st ~deps_only:true atoms
  else
    st

let add_post_to_variables st =
  let switch_config = st.OpamStateTypes.switch_config in
  let switch_config =
    let variables = switch_config.OpamFile.Switch_config.variables in
    let variables = (OpamVariable.of_string "post", OpamVariable.B true) :: variables in
    {switch_config with OpamFile.Switch_config.variables}
  in
  {st with OpamStateTypes.switch_config}

let rec iter_job = function
  | OpamProcess.Job.Op.Done _ -> ()
  | Run (cmd, k) ->
      print_newline ();
      print_endline (OpamConsole.colorise `yellow ("# "^OpamProcess.string_of_command cmd));
      print_newline ();
      let result = OpamProcess.run cmd in
      List.iter print_endline result.OpamProcess.r_stdout;
      match result.OpamProcess.r_code with
      | 0 -> iter_job (k result)
      | exit_code -> print_endline (OpamConsole.colorise `yellow ("# exit-code: "^string_of_int exit_code))

let build ~switch_kind ~with_test =
  try
    (* TODO: Disable sandbox by default? Make it configurable? *)
    OpamClientConfig.opam_init ~build_test:with_test ();
    OpamGlobalState.with_ `Lock_write @@ fun gt ->
    let pkgs = get_pkgs () in
    check_switch ~pkgs ~switch_kind gt @@ fun st ->
    let st = check_dependencies ~pkgs ~switch_kind st in
    let st = if with_test then add_post_to_variables st else st in
    print_endline (OpamConsole.colorise `yellow ("# Using "^(match switch_kind with Local -> "local" | Global -> "global")^" switch"));
    List.iter (fun package ->
      let job = OpamAction.build_package st ~test:with_test ~doc:false (OpamFilename.cwd ()) package in
      print_newline ();
      print_endline (OpamConsole.colorise `yellow ("# Building "^OpamPackage.to_string package^"..."));
      iter_job job
    ) pkgs
  with
  | OpamStd.Sys.Exit 0 -> ()
  | OpamStd.Sys.Exit n -> exit n
