(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.TYPES
open EzFile.OP

let cmd_name = "publish"

let select =
  EzFile.select ~deep:true
    ~filter:(fun for_rec path ->
      let basename = Filename.basename path in
      if for_rec then
        ( match basename.[0] with
        | '_'
        | '.' ->
          false
        | _ -> true )
        &&
        match basename with
        | "test" -> false
        | _ -> true
      else
        basename = "drom.toml")
    ()

let action ~opam_repo ~use_md5 () =
  let config = Lazy.force Config.config in
  let opam_repo =
    match !opam_repo with
    | Some repo -> repo
    | None -> (
      match config.config_opam_repo with
      | Some repo -> repo
      | None ->
        Error.raise "You must specify the path to a copy of opam-repository" )
  in
  let opam_packages_dir = opam_repo // "packages" in
  if not (Sys.file_exists opam_packages_dir) then
    Error.raise "packages dir does not exist in repo %S" opam_repo;
  EzFile.iter_dir ~select
    ~f:(fun file ->
      let p = Project.read file in
      let dir = Filename.dirname file in
      let archive =
        match p.archive with
        | Some archive -> archive
        | None -> (
          match p.github_organization with
          | Some github_organization ->
            Printf.sprintf
              "https://github.com/%s/${name}/archive/v${version}.tar.gz"
              github_organization
          | None -> Error.raise "Cannot detect archive path for %s" file )
      in
      let archive =
        Misc.subst archive (function
          | "name" -> p.package.name
          | "version" -> p.version
          | s -> Error.raise "Unknown archive variable %S" s)
      in
      let output = Filename.temp_file "archive" ".tgz" in
      Misc.wget ~url:archive ~output;
      let checksum =
        if use_md5 then
          let md5 = Digest.file output in
          Printf.sprintf "md5=%s" (Digest.to_hex md5)
        else
          let sha256 = OpamSHA.sha256_file output in
          Printf.sprintf "sha256=%s" sha256
      in
      let url =
        Printf.sprintf
          {|
url {
    src: "%s"
    checksum: [ "%s" ]
}
|}
          archive checksum
      in
      Sys.remove output;
      let files = Sys.readdir dir in
      let created = ref [] in
      try
        Array.iter
          (fun file ->
            if Filename.check_suffix file ".opam" then (
              let name = Filename.chop_suffix file ".opam" in
              let content = EzFile.read_file file in
              let package_dir =
                opam_repo // "packages" // name
                // Printf.sprintf "%s.%s" name p.version
              in
              if Sys.file_exists package_dir then
                Error.raise "%s already exists" package_dir;
              EzFile.make_dir ~p:true package_dir;
              EzFile.write_file (package_dir // "opam")
                (Printf.sprintf "%s\n%s" content url);
              created := package_dir :: !created
            ))
          files;
        if !created = [] then Error.raise "No opam file found.";
        List.iter
          (fun package_dir ->
            Printf.eprintf "File %s/opam created\n%!" package_dir)
          !created;
        Printf.eprintf
          "You should:\n\
          \ * upgrade to master\n\
          \ * create a new branch\n\
          \ * git add these files\n\
          \ * push to Github and create a pull-request\n\
           %!"
      with exn ->
        List.iter
          (fun dir -> ignore (Printf.kprintf Sys.command "rm -rf %s" dir))
          !created;
        raise exn)
    ".";

  ()

let cmd =
  let opam_repo = ref None in
  let use_md5 = ref false in
  { cmd_name;
    cmd_action = (fun () -> action ~opam_repo ~use_md5:!use_md5 ());
    cmd_args =
      [ ( [ "opam-repo" ],
          Arg.String (fun s -> opam_repo := Some s),
          Ezcmd.info "Path to local opam-repository" );
        ( [ "md5" ],
          Arg.Unit (fun () -> use_md5 := true),
          Ezcmd.info "Use md5 instead of sha256 for checksums" )
      ];
    cmd_man = [];
    cmd_doc = "Generate a set of packages from all found drom.toml files"
  }
