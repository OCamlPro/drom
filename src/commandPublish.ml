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

let select = EzFile.select ~deep:true
    ~filter:(fun is_dir basename _path ->
        if is_dir then
          ( match basename.[0] with
            | '_' | '.' -> false
            | _ -> true ) &&
          ( match basename with
            | "test" -> false
            | _ -> true
          )
        else
          basename = "drom.toml"
      )
    ()

let action ~opam_repo () =
  let config = Lazy.force Config.config in
  let opam_repo = match !opam_repo with
    | Some repo -> repo
    | None -> match config.config_opam_repo with
      | Some repo -> repo
      | None ->
        Error.raise "You must specify the path to a copy of opam-repository"
  in
  let opam_packages_dir = opam_repo // "packages" in
  if not ( Sys.file_exists opam_packages_dir ) then
    Error.raise "packages dir does not exist in repo %S" opam_repo ;
  EzFile.iter_dir ~select
    (fun ~basename ~localpath ~file ->
       Printf.eprintf "%s %s %s\n%!" basename localpath file ;
       let p = Project.project_of_toml file in
       let dir = Filename.dirname file in
       let archive =
         match p.archive with
         | Some archive -> archive
         | None ->
           match p.github_organization with
           | Some github_organization ->
             Printf.sprintf
               "https://github.com/%s/${name}/archive/v${version}.tar.gz"
               github_organization
           | None ->
             Error.raise "Cannot detect archive path for %s" file
       in
       let archive =
         Misc.subst archive (function
             | "name" -> p.package.name
             | "version" -> p.version
             | s -> Error.raise "Unknown archive variable %S" s)
       in
       let output = Filename.temp_file "archive" ".tgz" in
       Misc.wget ~url:archive ~output;
       let md5 = Digest.file output in
       let url = Printf.sprintf {|
url {
    src: "%s"
    checksum: [ "md5=%s" ]
}
|} archive (Digest.to_hex md5)
       in
       Sys.remove output ;
       let files = Sys.readdir dir in
       let created = ref [] in
       try

         Array.iter (fun file ->
             if Filename.check_suffix file ".opam" then
               let name = Filename.chop_suffix file ".opam" in
               let content = EzFile.read_file file in
               let package_dir =
                 opam_repo // "packages" // name //
                 Printf.sprintf "%s.%s" name p.version
               in
               if Sys.file_exists package_dir then
                 Error.raise "%s already exists" package_dir ;
               EzFile.make_dir ~p:true package_dir ;
               EzFile.write_file
                 ( package_dir // "opam" )
                 ( Printf.sprintf "%s\n%s" content url ) ;
               created := package_dir :: !created
           ) files
       with exn ->
         List.iter (fun dir ->
             ignore ( Printf.kprintf Sys.command "rm -rf %s" dir )
           ) !created ;
         raise exn
    )
    ".";

  ()

let cmd =
  let opam_repo = ref None in
  {
    cmd_name ;
    cmd_action = (fun () -> action ~opam_repo ());
    cmd_args = [

      [ "opam-repo" ], Arg.String (fun s -> opam_repo := Some s),
      Ezcmd.info "Path to local opam-repository" ;

    ];
    cmd_man = [];
    cmd_doc = "Generate a set of packages from all found drom.toml files" ;
  }
