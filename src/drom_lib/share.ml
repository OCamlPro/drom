(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzCompat
open Ez_file.V1
open EzFile.OP
open Ezcmd.V2
open EZCMD.TYPES

open Types


let share_repo_default = "https://github.com/OCamlPro/drom-share"

let share_repo_default () =
  match ( Config.get () ). config_share_repo with
  | None -> share_repo_default
  | Some repo -> repo


let default_args () =
  {
    arg_share_reclone = false ;
    arg_share_no_fetch = false ;
    arg_share_version = None ;
    arg_share_repo = None ;
  }

let args ?(set=false) () =
  let args = default_args () in
  let specs =
    [
      [ "no-fetch-share" ],
      Arg.Unit (fun () -> args.arg_share_no_fetch <- true),
      EZCMD.info
        "Prevent fetching updates from the share repo (in particular without network connection"
      ;

      [ "reclone-share" ],
      Arg.Unit (fun () -> args.arg_share_reclone <- true),
      EZCMD.info
        "Reclone share repository"
      ;
    ]
  in
  let specs =
    if set then
      ( [ "share-version" ],
        Arg.String (fun s ->
            args.arg_share_version <- Some s
          ),
        EZCMD.info ~docv:"SHARE_VERSION"
          "Set the version of share database (use 'latest' for latest version)" )
      ::
      ( [ "share-repo" ],
        Arg.String (fun s ->
            match s with
            | "default" ->
               args.arg_share_repo <-  Some ( share_repo_default () )
            | _ -> args.arg_share_repo <- Some s),
        EZCMD.info ~docv:"SHARE_REPO"
          "Set the repository URL of the share database (use 'default' for default repo)" )
      ::
      specs
    else
      specs
  in
  (args, specs)

let load ?(share_args=default_args()) ?p () =
  let default_repo, default_version = match p with
    | None -> None, None
    | Some p ->
        match p.project_share_repo with
        | None -> None, Some "0.8.0"
        | _ -> p.project_share_repo, p.project_share_version
  in
  let repo = match share_args.arg_share_repo with
    | None -> default_repo
    | _ -> share_args.arg_share_repo
  in
  let version = match share_args.arg_share_version with
    | None -> default_version
    | _ -> share_args.arg_share_version
  in
  let repo = match repo with
    | None | Some "default" -> share_repo_default ()
    | Some repo -> repo
  in
  (* version = None => use latest version *)

  (* Used to ensure `shares_dir` is created *)
  let _config = Config.get () in

  let hash = Digest.to_hex (Digest.string repo) in
  let shares_dir = Globals.config_dir // "shares" in
  if not ( Sys.file_exists shares_dir ) then
    Unix.mkdir shares_dir 0o755;

  let share_dir = shares_dir // hash in
  if Sys.file_exists share_dir && share_args.arg_share_reclone then
    Call.call [ "rm"; "-rf" ; share_dir ];

  let git = Git.silent in
  if not ( Sys.file_exists share_dir ) then begin
    git "clone" [ repo ; share_dir ];
  end;

  let first_git = ref true in
  let git cmd args =
    if !first_git then begin
      Printf.eprintf "In share-repo at %s:\n%!" share_dir;
      first_git := false;
    end;
    git ~cd:share_dir cmd args
  in
  let git_fail_ok cmd args =
    try git cmd args with _ -> ()
  in
  let git_fetch_all () =
    if not share_args.arg_share_no_fetch then
      let fetch_args = [ "-a"; "--all"; "--tags"; "-f" ] in
      git "fetch" fetch_args
  in
  let git_checkout_branch ?(remote="origin") branch =
    if branch = "master" then
      Error.raise "Don't use 'master' as a development branch of the share-repo.";
    git "checkout" [ "master" ];
    git_fail_ok "branch" [ "-D" ; branch ];
    git "checkout" [ "-b"; branch ; "--track" ; remote ^ "/" ^ branch ];
  in
  let read_first_line file =
    let ic = open_in file in
    let line = input_line ic in
    close_in ic;
    String.trim line
  in
  let get_version () =
    String.trim ( read_first_line ( share_dir // "VERSION" ))
  in
  let get_latest ?(version = Version.version) () =
    let filename = share_dir // "LATEST_VERSIONS" in
    if Sys.file_exists filename then
      let lines = EzFile.read_lines_to_list filename in
      (* format:
         * '#' at 0 for line comment
         * 'dev $VERSION' for VERSION is the LATEST version
         * '$DROM_VERSION $VERSION' for $VERSION is for all drom versions
            before $DROM_VERSION
      *)
      let rec iter share_version lines =
        match lines with
          [] -> begin
            match share_version with
            | None ->
                failwith "LATEST_VERSIONS does not contain a matching version"
            | Some share_version -> share_version
          end
        | line :: lines ->
            let len = String.length line in
            if len > 0 && line.[0] = '#' then (* allow comments *)
              iter share_version lines
            else
              let drom_version, new_share_version = EzString.cut_at line ' ' in
              if
                drom_version <> "dev" &&
                VersionCompare.compare version drom_version >= 0 then
                iter share_version []
              else
                let share_version = String.trim new_share_version in
                iter ( Some share_version ) lines
      in
      iter None lines
    else
      String.trim ( read_first_line ( share_dir // "LATEST" ))
  in
  let get_drom_version () =
    String.trim ( read_first_line ( share_dir // "DROM_VERSION" ))
  in
  let git_checkout_latest () =
    (* Some testing of the algorithm...
    List.iter (fun version ->
        let latest = get_latest ~version () in
        Printf.eprintf "Latest for %s is %s\n%!" version latest)
      [ "0.8.0"; "0.8.1"; "0.9.0" ; "0.9.1" ; "0.9.2" ; "0.9.3" ];
       *)
    let latest = get_latest  () in
    git "checkout" [ latest ];
    let version = get_version () in
    if version <> latest then
      Error.raise
        "Version %S in VERSION does not match tag version %S"
        version latest;
    version
  in
  let share_version = match version with
    | None
    | Some "latest" ->
        git_fetch_all ();
        git "checkout" [ "master" ];
        git "merge" [ "--ff-only" ];
        git_checkout_latest ()

    | Some version ->

        match String.split_on_char ':' version with
        | [ "branch" ; branch ] ->
            git_fetch_all ();
            git_checkout_branch branch ;
            version
        | [ "branch" ; remote; branch ] ->
            git_fetch_all () ;
            git_checkout_branch ~remote branch;
            version
        | [ "branch" ; remote; branch ; "latest" ] ->
            git_fetch_all () ;
            git_checkout_branch ~remote branch;
            let _latest_version = git_checkout_latest () in
            version
        | _ ->
            (* always checkout the version by tag. *)
            begin
              try
                git "checkout" [ version ];
                let current_version = get_version () in
                if current_version <> version then
                  failwith "Probably buggy version, try refetch"
              with _ ->
                git_fetch_all ();
                (* TODO: in case of error, the version does not exit ? *)
                git "checkout" [ version ];
            end;
            let current_version = get_version () in
            if current_version <> version then begin
              Error.raise "Version %S does not seem to exist (latest seems to be %S).\nCheck in repo %s"
                version current_version
                share_dir
            end;
            version
  in
  let share_drom_version = get_drom_version () in
  let share_drom_version = match p with
    | None -> share_drom_version
    | Some p ->
       if VersionCompare.gt
            p.project_drom_version share_drom_version then
            p.project_drom_version
          else
            share_drom_version
  in
  if VersionCompare.compare share_drom_version Version.version > 0 then begin
    Printf.eprintf "Error: you cannot update this project files:\n%!";
    Printf.eprintf "  Your drom version is too old: %s\n%!" Version.version;
    Printf.eprintf "  Minimal version to update files: %s\n%!" share_drom_version;
    exit 2
  end;

  {
    share_dir ;
    share_drom_version ;
    share_version ;
    share_licenses = None ;
    share_projects = None ;
    share_packages = None ;
  }
