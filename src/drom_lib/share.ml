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
open Ez_file.V1
open EzFile.OP
open Ezcmd.V2
open EZCMD.TYPES

open Types


let share_repo_default = "https://github.com/OCamlPro/drom-share"

let share_repo_default () =
  match ( Config.config () ). config_share_repo with
  | None -> share_repo_default
  | Some repo -> repo


type args = {
  mutable arg_reclone : bool ;
  mutable arg_no_fetch : bool ;
  mutable arg_version : string option ;
  mutable arg_repo : string option ;
}

let default_args () =
  {
    arg_reclone = false ;
    arg_no_fetch = false ;
    arg_version = None ;
    arg_repo = None ;
  }

let args ?(set=false) () =
  let args = default_args () in
  let specs =
    [
      [ "no-fetch-share" ],
      Arg.Unit (fun () -> args.arg_no_fetch <- true),
      EZCMD.info
        "Prevent fetching updates from the share repo (in particular without network connection"
      ;

      [ "reclone-share" ],
      Arg.Unit (fun () -> args.arg_reclone <- true),
      EZCMD.info
        "Reclone share repository"
      ;
    ]
  in
  let specs =
    if set then
      ( [ "share-version" ],
        Arg.String (fun s ->
            args.arg_version <- Some s
          ),
        EZCMD.info ~docv:"SHARE_VERSION"
          "Set the version of share database (use 'latest' for latest version)" )
      ::
      ( [ "share-repo" ],
        Arg.String (fun s ->
            match s with
            | "default" -> args.arg_repo <-  Some ( share_repo_default () )
            | _ -> args.arg_repo <- Some s),
        EZCMD.info ~docv:"SHARE_REPO"
          "Set the repository URL of the share database (use 'default' for default repo)" )
      ::
      specs
    else
      specs
  in
  (args, specs)

let load ?(args=default_args()) ?p () =
  let default_repo, default_version = match p with
    | None -> None, None
    | Some p ->
        match p.project_share_repo with
        | None -> None, Some "0.8.0"
        | _ -> p.project_share_repo, p.project_share_version
  in
  let repo = match args.arg_repo with
    | None -> default_repo
    | _ -> args.arg_repo
  in
  let version = match args.arg_version with
    | None -> default_version
    | _ -> args.arg_version
  in
  let repo = match repo with
    | None | Some "default" -> share_repo_default ()
    | Some repo -> repo
  in
  (* version = None => use latest version *)

  (* Used to ensure `shares_dir` is created *)
  let _config = Config.config () in

  let hash = Digest.to_hex (Digest.string repo) in
  let shares_dir = Globals.config_dir // "shares" in
  if not ( Sys.file_exists shares_dir ) then
    Unix.mkdir shares_dir 0o755;

  let share_dir = shares_dir // hash in
  if Sys.file_exists share_dir && args.arg_reclone then
    Call.call [| "rm"; "-rf" ; share_dir |];

  if not ( Sys.file_exists share_dir ) then begin
    Git.call [ "clone"; repo ; share_dir ];
  end;

  let git cmd args = Git.call ( "-C" :: share_dir :: cmd :: args ) in
  let git_silent_fail cmd args =
    try git cmd args with _ -> ()
  in
  let git_fetch_all () =
    if not args.arg_no_fetch then
      let fetch_args = [ "-a"; "--all"; "--tags"; "-f" ] in
      git "fetch" fetch_args
  in
  let git_checkout_branch ?(remote="origin") branch =
    if branch = "master" then
      Error.raise "Don't use 'master' as a development branch of the share-repo.";
    git "checkout" [ "master" ];
    git_silent_fail "branch" [ "-D" ; branch ];
    git "checkout" [ "-b"; branch ; "--track" ; remote ^ "/" ^ branch ];
  in
  let get_version () =
    String.trim ( EzFile.read_file ( share_dir // "VERSION" ))
  in
  let get_latest () =
    String.trim ( EzFile.read_file ( share_dir // "LATEST" ))
  in
  let get_drom_version () =
    String.trim ( EzFile.read_file ( share_dir // "DROM_VERSION" ))
  in
  let share_version = match version with
    | None
    | Some "latest" ->
        git_fetch_all ();
        git "checkout" [ "master" ];
        git "merge" [ "--ff-only" ];
        let latest = get_latest () in
        git "checkout" [ latest ];
        let version = get_version () in
        if version <> latest then
          Error.raise
            "Version %S in VERSION does not match tag version %S"
            version latest;
        version

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
        | _ ->
            let current_version = get_version () in
            if current_version <> version then begin
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
            end;
            version
  in
  let drom_version = get_drom_version () in

  if VersionCompare.compare drom_version Version.version > 0 then begin
    Printf.eprintf "Error: you cannot update this project files:\n%!";
    Printf.eprintf "  Your drom version is too old: %s\n%!" Version.version;
    Printf.eprintf "  Minimal version to update files: %s\n%!" drom_version;
  end;

  {
    share_dir ;
    share_version ;
    share_licenses = None ;
    share_projects = None ;
    share_packages = None ;
  }
