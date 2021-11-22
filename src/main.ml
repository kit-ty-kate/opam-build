(* taken from tests/reftests/run.ml (opam) *)
(* TODO: Expose OpamProcess.waitpid (safe_wait) *)
let rec waitpid pid =
  match Unix.waitpid [] pid with
  | exception Unix.Unix_error (Unix.EINTR,_,_) -> waitpid pid
  | exception Unix.Unix_error (Unix.ECHILD,_,_) -> 256
  | _, Unix.WSTOPPED _ -> waitpid pid
  | _, Unix.WEXITED n -> n
  | _, Unix.WSIGNALED _ -> failwith "signal"

let get_pkg (name, opam, _) =
  let opam = OpamFile.OPAM.read opam in
  let version = match OpamFile.OPAM.version_opt opam with
    | Some v -> v
    | None -> OpamPackage.Version.of_string "dev"
  in
  let package = OpamPackage.create name version in
  (package, opam)

let check_dependencies st =
  let st, atoms =
    OpamAuxCommands.autopin st ~recurse:false ~quiet:true ~simulate:true
      [`Dirname (OpamFilename.Dir.of_string ".")]
  in
  let missing = OpamClient.check_installed ~build:true ~post:true st atoms in
  if OpamPackage.Map.is_empty missing then
    ()
  else
    (* TODO: do the thing instead of telling the user to do it *)
    OpamConsole.error_and_exit `Bad_arguments "Dependencies are missing. Hint: opam install --deps-only ."

let () =
  OpamClientConfig.opam_init ();
  OpamGlobalState.with_ `Lock_none @@ fun gt ->
  OpamSwitchState.with_ `Lock_write gt @@ fun st ->
  (* TODO: setup a local switch by default, but make it configurable *)
  check_dependencies st;
  OpamAuxCommands.opams_of_dir (OpamFilename.Dir.of_string ".") |>
  List.map get_pkg |>
  List.iter (fun (package, opam) ->
    print_endline ("Building "^OpamPackage.to_string package^"...");
    OpamFile.OPAM.build opam |>
    OpamFilter.commands (OpamPackageVar.resolve_switch ~package st) |>
    List.iter (function
      | [] -> OpamConsole.error_and_exit `Bad_arguments "Empty command, aborting..."
      | (cmd::_ as args) ->
          print_endline ("  - "^String.concat " " args);
          let args = Array.of_list args in
          (* TODO: Handle build-env *)
          let pid = Unix.create_process cmd args Unix.stdin Unix.stdout Unix.stderr in
          match waitpid pid with
          | 0 -> ()
          | n -> OpamConsole.error_and_exit `Bad_arguments "Command exited with code %d" n
    )
  )
