(* SPDX-License-Identifier: MIT *)

type switch_kind = Local | Global

exception No_switch

let dev_version = OpamPackage.Version.of_string "dev"

let add_pkg map OpamStateTypes.{pin_name = name; pin = {pin_file; _}} =
  let pkg = OpamPackage.create name dev_version in
  let opam = OpamFile.OPAM.safe_read pin_file in
  let opam = OpamFile.OPAM.with_name name opam in
  let opam = OpamFile.OPAM.with_version dev_version opam in
  OpamPackage.Map.add pkg opam map

let get_pkgs () =
  List.fold_left
    add_pkg
    OpamPackage.Map.empty
    (OpamAuxCommands.opams_of_dir (OpamFilename.cwd ()))

let pkg_to_atom (pkg, _opam) =
  let name = OpamPackage.name pkg in
  let version = dev_version in
  (name, Some (`Eq, version))

let pkgs_to_atoms pkgs =
  List.map pkg_to_atom (OpamPackage.Map.bindings pkgs)

let simulate_autopin ~pkgs (st : [< OpamStateTypes.ro] OpamStateTypes.switch_state) =
  OpamPackage.Map.fold OpamSwitchState.update_pin pkgs st

let autopin ~pkgs (st : [< OpamStateTypes.rw] OpamStateTypes.switch_state) =
  let st = simulate_autopin ~pkgs st in
  OpamSwitchAction.write_selections st;
  st

let create_switch ~pkgs gt =
  print_endline "A local switch is being created...";
  OpamRepositoryState.with_ `Lock_none gt @@ fun rt ->
  let (), st =
    OpamSwitchCommand.create gt ~rt
      ~update_config:true
      ~invariant:OpamFormula.Empty
      (OpamSwitch.of_string ".") @@ fun st ->
    let st = simulate_autopin ~pkgs st in
    let atoms = pkgs_to_atoms pkgs in
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
      begin match OpamFile.Config.switch gt.OpamStateTypes.config with
      | None -> raise No_switch
      | Some switch when OpamSwitch.is_external switch -> assert false
      | Some switch -> OpamSwitchState.with_ `Lock_write ~switch gt k
      end

let check_dependencies ~pkgs ~switch_kind st =
  let st, atoms =
    let st = match switch_kind with
      | Local -> autopin ~pkgs st
      | Global -> simulate_autopin ~pkgs st
    in
    (st, pkgs_to_atoms pkgs)
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

let dummy_result = {
  OpamProcess.r_code = 0;
  r_signal = None;
  r_duration = 0.0;
  r_info = [];
  r_stdout = [];
  r_stderr = [];
  r_cleanup = [];
}

let global_env = Lazy.from_fun Unix.environment

let print prefix str =
  print_endline (OpamConsole.colorise `yellow prefix^" "^str)

let switch_kind_to_string = function
  | Local -> "local"
  | Global -> "global"

let rec iter_job = function
  | OpamProcess.Job.Op.Done _ -> ()
  | Run ({cmd; args; cmd_env; _} as opam_cmd, k) ->
      print "###" (OpamConsole.colorise `bold (OpamProcess.string_of_command opam_cmd));
      let args = Array.of_list (cmd::args) in
      let env = match cmd_env with
        | None -> Lazy.force global_env
        | Some env -> env
      in
      let stdin = Unix.dup ~cloexec:true Unix.stdin in
      let pid = Unix.create_process_env cmd args env stdin Unix.stdout Unix.stderr in
      match Unix.waitpid [] pid with
      | _pid, WEXITED 0 ->
          iter_job (k dummy_result)
      | _pid, WEXITED exit_code ->
          print "###" (OpamConsole.colorise `red "exit-code"^": "^string_of_int exit_code)
      | _pid, (WSIGNALED _ | WSTOPPED _) ->
          print "###" (OpamConsole.colorise `red "command stopped unexpectedly")

let build ~switch_kind ~with_test =
  try
    (* TODO: Disable sandbox by default? Make it configurable? *)
    OpamClientConfig.opam_init ~build_test:with_test ();
    OpamGlobalState.with_ `Lock_write @@ fun gt ->
    let pkgs = get_pkgs () in
    check_switch ~pkgs ~switch_kind gt @@ fun st ->
    let st = check_dependencies ~pkgs ~switch_kind st in
    let st = if with_test then add_post_to_variables st else st in
    print "#" ("Using "^OpamConsole.colorise `bold (switch_kind_to_string switch_kind)^" switch");
    OpamPackage.Map.iter (fun package _opam ->
      let job = OpamAction.build_package st ~test:with_test ~doc:false (OpamFilename.cwd ()) package in
      print "##" ("Building "^OpamConsole.colorise `blue (OpamPackage.to_string package)^"...");
      iter_job job
    ) pkgs
  with
  | OpamStd.Sys.Exit 0 -> ()
  | OpamStd.Sys.Exit n -> exit n
  | No_switch ->
      prerr_endline "Error: no switch is currently set by opam. Please set a global switch first.";
      exit 1
