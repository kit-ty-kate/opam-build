let get_pkg (name, opam, _) =
  let opam = OpamFile.OPAM.read opam in
  let version = match OpamFile.OPAM.version_opt opam with
    | Some v -> v
    | None -> OpamPackage.Version.of_string "~dev"
  in
  OpamPackage.create name version

let create_switch gt dirname =
  OpamRepositoryState.with_ `Lock_none gt @@ fun rt ->
  let (), st =
    OpamSwitchCommand.create gt ~rt
      ~update_config:true
      ~invariant:OpamFormula.Empty
      (OpamSwitch.of_string ".") @@ fun st ->
      let st, additional_installs =
        OpamAuxCommands.simulate_autopin st ~recurse:false ~quiet:true [`Dirname dirname]
      in
      let st =
        OpamSwitchCommand.install_compiler st
          ~additional_installs
          ~deps_only:true
          ~ask:false (* TODO *)
      in
      ((), st)
  in
  st

let check_switch gt st dirname =
  match OpamStateConfig.get_current_switch_from_cwd gt.OpamStateTypes.root with
  | None -> create_switch gt dirname (* TODO: Ask the user if they want to create a local
                                        or leave them with global switch *)
  | Some _ -> st

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
      print_endline ("  - "^OpamProcess.string_of_command cmd);
      let result = OpamProcess.run cmd in
      iter_job (k result)

let build ~with_test ~dirname =
  OpamStd.Option.iter Sys.chdir dirname;
  let dirname = OpamFilename.cwd () in
  (* TODO: Disable sandbox by default? Make it configurable? *)
  OpamClientConfig.opam_init ~build_test:with_test ();
  OpamGlobalState.with_ `Lock_write @@ fun gt ->
  OpamSwitchState.with_ `Lock_write gt @@ fun st ->
  let st = check_switch gt st dirname in
  let st = check_dependencies st dirname in
  let st = if with_test then add_post_to_variables st else st in
  OpamAuxCommands.opams_of_dir dirname |>
  List.map get_pkg |>
  List.iter (fun package ->
    let job = OpamAction.build_package st ~test:with_test ~doc:false dirname package in
    print_endline ("Building "^OpamPackage.to_string package^"...");
    iter_job job
  )
