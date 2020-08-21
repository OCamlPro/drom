(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open DromTypes
open Ezcmd.TYPES

let cmd_name = "new"

(*
`opam-new create project` will generate the tree:
* project/
    drom.toml
    .git/
    .gitignore
    dune-workspace
    dune-project     [do not edit]
    project.opam     [do not edit]
    src/
       dune          [do not edit]
       main.ml

drom.toml looks like:
```
[package]
authors = ["Fabrice Le Fessant <fabrice.le_fessant@origin-labs.com>"]
edition = "4.10.0"
library = false
name = "project"
version = "0.1.0"

[dependencies]

[tools]
dune = "2.6.0"
```

*)

(* lookup for "drom.toml" and update it *)
let action ~project_name ~library =
  let config = Lazy.force DromConfig.config in
  let project, create = match !project_name with
    | None ->
      DromToml.project_of_toml "drom.toml", false
    | Some name ->
      let p =
        {
          name ;
          version = "0.1.0" ;
          edition = DromGlobals.current_ocaml_edition ;
          library = !library ;
          authors = [ DromToml.find_author config ] ;
          synopsis = DromGlobals.default_synopsis ~name ;
          description = DromGlobals.default_description ~name ;
          dependencies = [];
          tools = [ "dune", DromGlobals.current_dune_version ];
          github_organization = config.config_github_organization ;
          homepage = None ;
          documentation = None ;
          bug_reports = None ;
          license = config.config_license ;
          dev_repo = None ;
          copyright = config.config_copyright ;
        } in
      let create = not ( Sys.file_exists name ) in
      if create then
        EzFile.make_dir ~p:true name ;
      Unix.chdir name ;
      p, create
  in
  let build = false in
  DromUpdate.update_files ~create ~build project

let cmd =
  let project_name = ref None in
  let library = ref false in
  {
    cmd_name ;
    cmd_action = (fun () -> action ~project_name ~library);
    cmd_args = [
      [ "lib" ], Arg.Set library,
      Ezcmd.info "Project is a library" ;

      [], Arg.Anon (0, fun name -> project_name := Some name),
      Ezcmd.info "Name of the project" ;
    ];
    cmd_man = [];
    cmd_doc = "Create an initial project";
  }
