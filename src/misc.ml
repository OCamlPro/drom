(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzCompat
(* open EzConfig.OP *)
(* open EzFile.OP *)

(*
let append_text_file file s =
  let oc = open_out_gen [
      Open_creat;
      Open_append ;
      Open_text ;
    ] 0o644 file in
  output_string oc s;
  close_out oc

let date () =
  let tm = Unix.localtime (Unix.gettimeofday ()) in
  Printf.sprintf "%4d/%02d/%02d:%02d:%02d:%02d"
    (1900 + tm.tm_year)
    (1+tm.tm_mon)
    tm.tm_mday
    tm.tm_hour
    tm.tm_min
    tm.tm_sec

let log file fmt =
  Printf.kprintf (fun s ->
      append_text_file file
        (Printf.sprintf "%s: %s\n" (date()) s)) fmt

let global_log fmt =
  log OpambinGlobals.opambin_log fmt

let make_cache_dir () =
  EzFile.make_dir ~p:true OpambinGlobals.opambin_cache_dir
*)

let call ?(stdout = Unix.stdout) args =
  Printf.eprintf "Calling %s\n%!"
    (String.concat " " ( Array.to_list args ) );
  let pid = Unix.create_process args.(0) args
      Unix.stdin stdout Unix.stderr in
  let rec iter () =
    match Unix.waitpid [ ] pid with
    | exception (Unix.Unix_error (EINTR, _, _)) -> iter ()
    | _pid, status ->
      match status with
      | WEXITED 0 -> ()
      | _ ->
        Printf.kprintf failwith "Command '%s' exited with error code %s"
          (String.concat " " (Array.to_list args))
          (match status with
           | WEXITED n -> string_of_int n
           | WSIGNALED n -> Printf.sprintf "SIGNAL %d" n
           | WSTOPPED n -> Printf.sprintf "STOPPED %d" n
          )
  in
  iter ()

(*
let tar_zcf ?prefix archive files =
  let temp_archive = archive ^ ".tmp" in
  begin
    match files with
    | [] ->
      (* an empty tar achive is this... *)
      EzFile.write_file temp_archive (String.make 10240 '\000');
    | _ ->
      let args = files in
      let args =
        match prefix with
        | None -> args
        | Some prefix ->
          "--transform"  ::
          Printf.sprintf "s|^|%s/|S" prefix ::
          args
      in
      let args =
        "--mtime=2020/07/13" ::
        "--group=user:1000" ::
        "--owner=user:1000" ::
        args
      in
      let args =  "-cf" :: temp_archive :: args in
      call @@ Array.of_list ( "tar" :: args )
  end;
  call [| "gzip" ; "-n"; temp_archive |];
  Sys.rename ( temp_archive ^ ".gz" ) archive


let backup_rotation =
  [ ".8", ".9";
    ".7", ".8";
    ".6", ".7";
    ".5", ".6";
    ".4", ".5";
    ".3", ".4";
    ".2", ".3";
    ".1", ".2";
    "", ".1";
  ]

let restore_rotation =
  List.rev (List.map (fun (x,y) -> (y,x)) backup_rotation)

let rotate file rotation =
  List.iter (fun (ext1, ext2) ->
      let file1 = file ^ ext1 in
      let file2 = file ^ ext2 in
      if FileString.exists file1 then
        let s = FileString.read_file file1 in
        FileString.write_file file2 s;
    ) rotation

let backup_opam_config_done = ref false
let backup_opam_config () =
  if not !backup_opam_config_done then begin
    rotate OpambinGlobals.opam_config_file backup_rotation;
    Printf.eprintf "%s backuped under %s\n%!"
      OpambinGlobals.opam_config_file
      OpambinGlobals.opam_config_file_backup;
    backup_opam_config_done := true;
  end

let restore_opam_config () =
  rotate OpambinGlobals.opam_config_file restore_rotation;
  Printf.eprintf "%s restored from %s\n%!"
    OpambinGlobals.opam_config_file
    OpambinGlobals.opam_config_file_backup

let change_opam_config f =
  let { OpamParserTypes.file_contents ; _ } =
    OpamParser.file OpambinGlobals.opam_config_file in
  match f file_contents with
  | None -> ()
  | Some file_contents ->
    backup_opam_config ();
    let s = OpamPrinter.opamfile
        { file_name = ""; file_contents } in
    EzFile.write_file OpambinGlobals.opam_config_file s;
    Printf.eprintf "%s backuped and modified\n%!"
      OpambinGlobals.opam_config_file

let opam_variable name fmt =
  Printf.kprintf (fun s ->
      OpamParserTypes.Variable ( ("",0,0), name,
                                 OpamParser.value_from_string s ""))
    fmt

let opam_section ?name kind list =
  OpamParserTypes.Section ( ("",0,0),
                            {
                              section_kind = kind ;
                              section_name = name ;
                              section_items = list })

let current_switch () =
  let opam_switch_prefix = OpambinGlobals.opam_switch_prefix () in
  let switch = Filename.basename opam_switch_prefix in
  if String.lowercase switch = "_opam" then
    Filename.dirname opam_switch_prefix
  else switch

let not_this_switch () =
  if  !!OpambinConfig.all_switches then
    let switch = current_switch () in
    List.exists (fun s ->
        let core = Re.Glob.glob s in
        let re = Re.compile core in
        Re.execp re switch
      ) !!OpambinConfig.protected_switches
  else
    let switch = current_switch () in
    List.for_all (fun s ->
        let core = Re.Glob.glob s in
        let re = Re.compile core in
        not ( Re.execp re switch )
      ) !!OpambinConfig.switches

(*
let () =
  List.iter ( fun (s, test, matched) ->
      let core = Re.Glob.glob ~anchored:true s in
      let re = Re.compile core in
      let result = Re.execp re test in
      if result <> matched then begin
        Printf.eprintf "result %b <> expected %b: regexp=%S test=%S\n%!"
          result matched s test;
        exit 2
      end
    ) [
    "*-bin", "4.07.1-bin", true ;
    "*-bin", "4.07.1-bin-x", false ;
  ]
*)

let opam_repos () =
  let repos =
    try
      Sys.readdir OpambinGlobals.opam_repo_dir
    with _ -> [||]
  in
  Array.to_list @@
  Array.map (fun file ->
      OpambinGlobals.opam_repo_dir // file) repos

let all_repos () =
  OpambinGlobals.opambin_store_repo_dir :: opam_repos ()


(* stops if [f] returns true and returns true *)
let iter_repos ?name repos ~cont f =
  (*
  global_log "Searching repositories in:\n  %s"
    ( String.concat "\n  " repos);
  Printf.eprintf "Searching repositories in:\n  %s\n%!"
    ( String.concat "\n  " repos);
*)
  let rec iter_repos repos =
    match repos with
    | [] ->
      false
    | repo :: repos ->
      (* Printf.eprintf "Searching repo %S\n%!" repo; *)
      let packages_dir = repo // "packages" in
      let packages = match name with
        | Some name -> [ name ]
        | None ->
          try
            let files = Sys.readdir packages_dir in
            Array.sort compare files ;
            Array.to_list files
          with _ -> []
      in
      iter_packages packages repo repos

  and iter_packages packages repo repos =
    match packages with
    | [] ->
      (* Printf.eprintf "Next repo ?\n%!"; *)
      iter_repos repos
    | package :: packages ->
      (* Printf.eprintf " Searching package %S\n%!" package ; *)
      let package_dir = repo // "packages" // package in
      match Sys.readdir package_dir with
      | exception _ -> iter_packages packages repo repos
      | versions ->
        Array.sort compare versions;
        let versions = Array.to_list versions in
        iter_versions versions package packages repo repos

  and iter_versions versions package packages repo repos =
    match versions with
    | [] ->
      (* Printf.eprintf " Next package ?\n%!"; *)
      iter_packages packages repo repos
    | version :: versions ->
      (* Printf.eprintf "  Searching version %S\n%!" version ; *)
      if f ~repo ~package ~version then begin
        (* Printf.eprintf "Found, stopping\n%!"; *)
        true
      end else
        iter_versions versions package packages repo repos
  in
  iter_repos repos |> cont

let write_marker marker content =
  let dir = OpambinGlobals.opambin_switch_temp_dir () in
  if not ( Sys.file_exists dir ) then EzFile.make_dir ~p:true dir;
  global_log "writing marker %s" marker;
  EzFile.write_file marker content

let wget ~url ~output =
  let dirname = Filename.dirname output in
  if not ( Sys.file_exists dirname ) then
    EzFile.make_dir ~p:true dirname;
  call [| "curl" ;
          "--write-out" ; "%{http_code}\\n" ;
          "--retry" ; "3" ;
          "--retry-delay" ; "2" ;
          "--user-agent" ; "opam-bin/2.0.5" ;
          "-L" ;
          "-o" ; output ;
          url
       |];
  Some output
*)
