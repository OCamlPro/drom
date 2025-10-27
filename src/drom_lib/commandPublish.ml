(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.V2
open EZCMD.TYPES
open Ez_file.V1
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
        | "share" -> false
        | _ -> true
      else
        basename = "drom.toml" )
    ()

let action ~force ~opam_repo ~use_md5 () =
  let config = Config.get () in
  let opam_repo =
    match !opam_repo with
    | Some repo -> repo
    | None -> (
      match config.config_opam_repo with
      | Some repo -> repo
      | None ->
        Error.raise "You must specify the path to a copy of opam-repository" )
  in
  Call.before_hook ~command:"publish" ~args:[ opam_repo ] ();
  let opam_packages_dir = opam_repo // "packages" in
  if not (Sys.file_exists opam_packages_dir) then
    Error.raise "packages dir does not exist in repo %S" opam_repo;
  EzFile.iter_dir ~select (* search drom.toml files *)
    ~f:(fun file ->
      let p = Project.of_file file in
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
          | s -> Error.raise "Unknown archive variable %S" s )
      in
      let output = Filename.temp_file "archive" ".tgz" in
      Call.wget ~url:archive ~output;
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
      let created = ref [] in
      try
        List.iter
          (fun dir ->
            let files = Sys.readdir dir in
            Array.iter
              (fun file ->
                if Filename.check_suffix file ".opam" then (
                  let name = Filename.chop_suffix file ".opam" in
                  let lines = EzFile.read_lines_to_list (dir // file) in
                  let lines =
                    List.filter
                      (fun line ->
                        line = ""
                        || line.[0] <> '#'
                           &&
                           let prefix, _ = EzString.cut_at line ':' in
                           match prefix with
                           | "version"
                           | "name" ->
                             false
                           | _ -> true )
                      lines
                  in
                  let content = String.concat "\n" lines in
                  let package_dir =
                    opam_repo // "packages" // name
                    // Printf.sprintf "%s.%s" name p.version
                  in
                  if (not force) && Sys.file_exists package_dir then
                    Error.raise "%s already exists" package_dir;
                  EzFile.make_dir ~p:true package_dir;
                  EzFile.write_file (package_dir // "opam")
                    (Printf.sprintf "%s\n%s" content url);
                  created := package_dir :: !created
                ) )
              files )
          [ dir // "opam"; dir ];
        if !created = [] then Error.raise "No opam file found.";
        List.iter
          (fun package_dir ->
            Printf.eprintf "File %s/opam created\n%!" package_dir )
          !created;
        Printf.eprintf
          "You should:\n\
          \ * upgrade to master\n\
          \ * create a new branch\n\
          \ * git add these files\n\
          \ * push to Github and create a pull-request\n\
           %!"
      with
      | exn ->
        List.iter
          (fun dir -> ignore (Printf.ksprintf Sys.command "rm -rf %s" dir))
          !created;
        raise exn )
    ".";
  Call.after_hook ~command:"publish" ~args:[ opam_repo ] ();
  ()

let cmd =
  let opam_repo = ref None in
  let use_md5 = ref false in
  let force = ref false in
  EZCMD.sub cmd_name
    (fun () -> action ~force:!force ~opam_repo ~use_md5:!use_md5 ())
    ~args:
      [ ( [ "opam-repo" ],
          Arg.String (fun s -> opam_repo := Some s),
          EZCMD.info ~docv:"DIRECTORY"
            "Path to local git-managed opam-repository. The path should be \
             absolute. Overwrites the value $(i,opam-repo) from \
             $(i,\\$HOME/.config/drom/config)" );
        ( [ "md5" ],
          Arg.Set use_md5,
          EZCMD.info "Use md5 instead of sha256 for checksums" );
        ([ "f"; "force" ], Arg.Set force, EZCMD.info "Overwrite existing files")
      ]
    ~doc:
      "Update opam files with checksums and copy them to a local \
       opam-repository for publication"
    ~man:
      [ `S "DESCRIPTION";
        `Blocks
          [ `P
              "Before running this command, you should edit the file \
               $(b,\\$HOME/.config/drom/config) and set the value of the \
               $(i,opam-repo) option, like:";
            `Pre
              {|
[user]
author = "John Doe <john.doe@ocaml.org>"
github-organization = "ocaml"
license = "LGPL2"
copyright = "OCamlPro SAS"
opam-repo = "/home/john/GIT/opam-repository"
|};
            `P
              "Alternatively, you can run it with option $(b,--opam-repo \
               REPOSITORY).";
            `P
              "In both case, $(b,REPOSITORY) should be the absolute path to \
               the location of a local git-managed opam repository.";
            `P "$(b,drom publish) will perform the following actions:";
            `I
              ( "1.",
                "Download the source archive corresponding to the current \
                 version" );
            `I ("2.", "Compute the checksum of the archive");
            `I
              ( "3.",
                "Copy updated opam files to the git-managed opam repository. \
                 During this operation, comment lines, :code:`version:` and \
                 :code:`name` lines are removed to conform to opam-repository \
                 policies." );
            `P
              "Note that, prior to calling $(b,drom publish), you should \
               update the opam-repository to the latest version of the \
               $(b,master) branch:";
            `Pre "git checkout master\ngit pull ocaml master";
            `P
              "Once the opam files have been added, you should push them to \
               your local fork of opam-repository and create a merge request:";
            `Pre
              {|cd ~/GIT/opam-repository
git checkout -b z-\$(date --iso)-new-package-version
git add packages
git commit -a -m "New version of my package"
git push
|};
            `P
              "To download the project source archive, $(b,drom publish) will \
               either use the $(i,archive) URL of the drom.toml file, or the \
               Github URL (if the $(i,github-organization) is set in the \
               project), assuming in this later case that the version starts \
               with 'v' (like v1.0.0). Two substitutions are allowed in \
               $(i,archive): $(i,\\${version}) for the version, $(i,\\${name}) \
               for the package name."
          ]
      ]
