(* SPDX-License-Identifier: MIT *)

type switch_kind = Local | Global

let get_pkg st OpamStateTypes.{pin_name = name; _} =
  let version = OpamPinCommand.default_version st name in
  OpamPackage.create name version

let create_switch gt dirname =
  print_endline "A local switch is being created...";
  OpamRepositoryState.with_ `Lock_none gt @@ fun rt ->
  let (), st =
    OpamSwitchCommand.create gt ~rt
      ~update_config:true
      ~invariant:OpamFormula.Empty
      (OpamSwitch.of_string ".") @@ fun st ->
    let st, atoms =
      OpamAuxCommands.simulate_autopin st ~recurse:false ~quiet:true [`Dirname dirname]
    in
    let st =
      OpamClient.install_t st
        ~ask:false (* TODO *)
        atoms (Some true)
        ~deps_only:true ~assume_built:false
    in
    ((), st)
  in
  st

let check_switch ~switch_kind gt dirname k =
  match switch_kind with
  | Local ->
      begin match OpamStateConfig.get_current_switch_from_cwd gt.OpamStateTypes.root with
      | None -> k (create_switch gt dirname)
      | Some switch -> OpamSwitchState.with_ `Lock_write ~switch gt k
      end
  | Global ->
      begin match (!OpamStateConfig.r).current_switch with
      | None -> failwith "TODO"
      | Some switch when OpamSwitch.is_external switch -> failwith "TODO"
      | Some switch -> OpamSwitchState.with_ `Lock_write ~switch gt k
      end

let check_dependencies st dirname =
  let st, atoms =
    OpamAuxCommands.simulate_autopin st ~recurse:false ~quiet:true [`Dirname dirname]
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

let build ~switch_kind ~with_test ~dirname =
  try
    OpamStd.Option.iter Sys.chdir dirname;
    let dirname = OpamFilename.cwd () in
    (* TODO: Disable sandbox by default? Make it configurable? *)
    OpamClientConfig.opam_init ~build_test:with_test ();
    OpamGlobalState.with_ `Lock_write @@ fun gt ->
    check_switch ~switch_kind gt dirname @@ fun st ->
    let st = check_dependencies st dirname in
    let st = if with_test then add_post_to_variables st else st in
    print_endline (OpamConsole.colorise `yellow ("# Using "^(match switch_kind with Local -> "local" | Global -> "global")^" switch"));
    OpamAuxCommands.opams_of_dir dirname |>
    List.map (get_pkg st) |>
    List.iter (fun package ->
      let job = OpamAction.build_package st ~test:with_test ~doc:false dirname package in
      print_newline ();
      print_endline (OpamConsole.colorise `yellow ("# Building "^OpamPackage.to_string package^"..."));
      iter_job job
    )
  with
  | OpamStd.Sys.Exit 0 -> ()
  | OpamStd.Sys.Exit n -> exit n
