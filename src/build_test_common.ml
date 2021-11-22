let get_pkg (name, opam, _) =
  let opam = OpamFile.OPAM.read opam in
  let version = match OpamFile.OPAM.version_opt opam with
    | Some v -> v
    | None -> OpamPackage.Version.of_string "~dev"
  in
  OpamPackage.create name version

let check_dependencies st dirname =
  let st, atoms =
    OpamAuxCommands.simulate_autopin st ~recurse:false ~quiet:true [`Dirname dirname]
  in
  let missing = OpamClient.check_installed ~build:true ~post:true st atoms in
  if not (OpamPackage.Map.is_empty missing) then
    OpamClient.install st ~deps_only:true atoms
  else
    st

let rec iter_job = function
  | OpamProcess.Job.Op.Done _ -> ()
  | Run (cmd, k) ->
      print_endline ("  - "^OpamProcess.string_of_command cmd);
      let result = OpamProcess.run cmd in
      iter_job (k result)

let build dirname =
  (* TODO: Disable sandbox by default? Make it configurable? *)
  OpamClientConfig.opam_init ();
  OpamGlobalState.with_ `Lock_none @@ fun gt ->
  OpamSwitchState.with_ `Lock_write gt @@ fun st ->
  (* TODO: setup a local switch by default, but make it configurable *)
  let st = check_dependencies st dirname in
  OpamAuxCommands.opams_of_dir dirname |>
  List.map get_pkg |>
  List.iter (fun package ->
    let job = OpamAction.build_package st ~test:false ~doc:false dirname package in
    print_endline ("Building "^OpamPackage.to_string package^"...");
    iter_job job
  )
