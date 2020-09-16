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
open EzFile.OP

let cmd_name = "package"

(* lookup for "drom.toml" and update it *)
let action ~package_name ~kind ~mode ~promote_skip ~dir ~create ~remove =
  let p, inferred_dir = Project.get () in
  let name =
    match package_name with None -> p.package.name | Some name -> name
  in
  if create then (
    if List.exists (fun package -> package.name = name) p.packages then
      Error.raise "A package with this name already exists";
    let dir =
      match dir with
      | None ->
          let dir = if inferred_dir = "" then "src" else inferred_dir in
          dir // name
      | Some dir -> dir
    in
    let kind = match kind with None -> Library | Some kind -> kind in
    let package = Project.create_package ~kind ~name ~dir in
    package.p_mode <- mode;
    package.project <- p;
    p.packages <- p.packages @ [ package ];
    Update.update_files ~upgrade:true ~promote_skip:false ~git:true p )
  else (
    if List.for_all (fun package -> package.name <> name) p.packages then
      Error.raise "No such package";
    if dir <> None then Error.raise "Option --dir is not available for update";

    let upgrade =
      if remove then (
        if p.package.name = name then Error.raise "Cannot remove main package";
        p.packages <-
          List.filter (fun package -> package.name <> name) p.packages;
        true )
      else
        let upgrade = ref false in
        List.iter
          (fun package ->
            if package.name = name then (
              ( match kind with
              | None -> ()
              | Some kind ->
                  p.package.kind <- kind;
                  upgrade := true );
              match mode with
              | None -> ()
              | Some mode ->
                  p.package.p_mode <- Some mode;
                  upgrade := true ))
          p.packages;
        !upgrade
    in
    Update.update_files ~create:false ?mode ~upgrade ~promote_skip ~git:true p )

let cmd =
  let package_name = ref None in
  let kind = ref None in
  let mode = ref None in
  let promote_skip = ref false in
  let dir = ref None in
  let create = ref false in
  let remove = ref false in
  {
    cmd_name;
    cmd_action =
      (fun () ->
        action ~package_name:!package_name ~mode:!mode ~kind:!kind
          ~promote_skip:!promote_skip ~dir:!dir ~create:!create ~remove:!remove);
    cmd_args =
      [
        ( [ "new" ],
          Arg.Set create,
          Ezcmd.info "Add a new package to the project" );
        ( [ "remove" ],
          Arg.Set remove,
          Ezcmd.info "Remove a package from the project" );
        ( [ "dir" ],
          Arg.String (fun s -> dir := Some s),
          Ezcmd.info "Dir where package sources are stored (src by default)" );
        ( [ "library" ],
          Arg.Unit (fun () -> kind := Some Library),
          Ezcmd.info "Package is a library" );
        ( [ "program" ],
          Arg.Unit (fun () -> kind := Some Program),
          Ezcmd.info "Package is a program" );
        ( [ "virtual" ],
          Arg.Unit (fun () -> kind := Some Virtual),
          Ezcmd.info "Package is virtual, i.e. no code" );
        ( [ "binary" ],
          Arg.Unit (fun () -> mode := Some Binary),
          Ezcmd.info "Compile to binary" );
        ( [ "javascript" ],
          Arg.Unit (fun () -> mode := Some Javascript),
          Ezcmd.info "Compile to javascript" );
        ( [ "promote-skip" ],
          Arg.Unit (fun () -> promote_skip := true),
          Ezcmd.info "Promote skipped files to skip field" );
        ( [],
          Arg.Anon (0, fun name -> package_name := Some name),
          Ezcmd.info "Name of the package" );
      ];
    cmd_man = [];
    cmd_doc = "Manage a package within a project";
  }
