(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Types
open Ezcmd.TYPES

let cmd_name = "new"

(* lookup for "drom.toml" and update it *)
let action ~project_name ~kind =
  let config = Lazy.force Config.config in
  let project, create = match !project_name with
    | None ->
      Project.project_of_toml "drom.toml", false
    | Some name ->
      let p =
        {
          name ;
          version = "0.1.0" ;
          edition = Globals.current_ocaml_edition ;
          kind = !kind ;
          authors = [ Project.find_author config ] ;
          synopsis = Globals.default_synopsis ~name ;
          description = Globals.default_description ~name ;
          dependencies = [];
          tools = [ "dune", Globals.current_dune_version ];
          github_organization = config.config_github_organization ;
          homepage = None ;
          documentation = None ;
          bug_reports = None ;
          license = config.config_license ;
          dev_repo = None ;
          copyright = config.config_copyright ;
          ignore = [];
        } in
      let create = not ( Sys.file_exists name ) in
      if create then
        EzFile.make_dir ~p:true name ;
      Unix.chdir name ;
      p, create
  in
  let build = false in
  Update.update_files ~create ~build project

let cmd =
  let project_name = ref None in
  let kind = ref Program in
  {
    cmd_name ;
    cmd_action = (fun () -> action ~project_name ~kind);
    cmd_args = [
      [ "both" ], Arg.Unit (fun () -> kind := Both ),
      Ezcmd.info "Project contains both a library and a program" ;

      [ "library" ], Arg.Unit (fun () -> kind := Library ),
      Ezcmd.info "Project contains only a library" ;

      [], Arg.Anon (0, fun name -> project_name := Some name),
      Ezcmd.info "Name of the project" ;
    ];
    cmd_man = [];
    cmd_doc = "Create an initial project";
  }
