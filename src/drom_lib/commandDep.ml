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
open Update
open Types

let cmd_name = "dep"

let print_dep (name, d) =
  Printf.printf "Dependency: %S\n%!" name;
  Printf.printf "  version (--ver) : %s\n%!"
    ( Project.string_of_versions d.depversions );
  Printf.printf "  libname (--lib) : %s\n%!"
    (match d.depname with
     | None -> name
     | Some name -> name);
  Printf.printf "  for-test (--test) : %b\n%!" d.deptest;
  Printf.printf "  for-doc (--test) : %b\n%!" d.depdoc;
  ()

let action ?dep
    ~package ~tool
    ~add ~remove
    ~version ~depname ~deptest ~depdoc ~args =
  let p, _inferred_dir = Project.get () in
  let upgrade = ref args.arg_upgrade in
  let update package_kind dep_kind deps setdeps =

    match dep with
    | None ->
        Printf.printf "Printing %s %s dependencies:\n%!" package_kind dep_kind;
        List.iter print_dep deps

    | Some dep ->
        if add then begin
          if List.mem_assoc dep deps then
            Error.raise "%S is already a dependency" dep;

          let d = {
            depversions = ( match version with
                | None -> []
                | Some version -> Project.versions_of_string version );
            depname ;
            deptest = ( match deptest with
                | None -> false
                | Some b -> b );
            depdoc = ( match depdoc with
                | None -> false
                | Some b -> b );
          } in
          upgrade := true;
          Printf.eprintf "Adding %s %s dependency %S\n%!"
            package_kind dep_kind dep;
          setdeps ( (dep, d) :: deps )

        end else begin
          if not ( List.mem_assoc dep deps ) then
            Error.raise "%S is not a current dependency" dep;

          if remove then begin
            let deps = List.filter (fun (name, _) -> name <> dep) deps in
            setdeps deps;
            upgrade := true;
            Printf.eprintf "Removed %s %s dependency %S\n%!"
              package_kind dep_kind dep
          end else
            let deps = List.map (fun (name, d) ->
                if name = dep then
                  let d = match version with
                    | None -> d
                    | Some version ->
                        upgrade := true;
                        { d with
                          depversions = Project.versions_of_string version }
                  in
                  let d = match depname with
                    | None -> d
                    | Some depname ->
                        upgrade := true;
                        { d with
                          depname =
                            if depname = dep then None else Some depname }
                  in
                  let d = match deptest with
                    | None -> d
                    | Some deptest ->
                        upgrade := true; { d with deptest }
                  in
                  let d = match depdoc with
                    | None -> d
                    | Some depdoc ->
                        upgrade := true; { d with depdoc }
                  in

                  if not !upgrade then begin
                    print_dep (dep, d);
                    exit 0;
                  end;
                  Printf.eprintf "Updating %s %s dependency %S\n%!"
                    package_kind dep_kind dep;
                  (name, d)
                else
                  (name, d)
              ) deps in
            setdeps deps

        end
  in

  begin
    match package with
    | None ->
        let kind, deps, setdeps =
          if tool then
            "tools", p.tools, (fun deps -> p.tools <- deps)
          else
            "libs", p.dependencies, (fun deps -> p.dependencies <- deps)
        in
        update "project" kind deps setdeps
    | Some name ->
        List.iter (fun package ->
            if package.name = name then
              let kind, deps, setdeps =
                if tool then
                  "tools", package.p_tools,
                  (fun deps -> package.p_tools <- deps)
                else
                  "libs", package.p_dependencies,
                  (fun deps -> package.p_dependencies <- deps)
              in
              update "package" kind deps setdeps
          ) p.packages
  end;

  if !upgrade then
    let args = { args with arg_upgrade = !upgrade } in
    Update.update_files ~create:false ~git:true p ~args;
    ()

let cmd =
  let package = ref None in
  let dep = ref None in
  let tool = ref false in
  let add = ref false in
  let remove = ref false in
  let version = ref None in
  let depname = ref None in
  let deptest = ref None in
  let depdoc = ref None in
  let args, specs = Update.update_args () in
  { cmd_name;
    cmd_action =
      (fun () ->
         action ?dep:(!dep)
           ~package:!package ~tool:!tool
           ~add:!add ~remove:!remove
           ~version:!version ~depname:!depname
           ~deptest:!deptest ~depdoc:!depdoc
           ~args
      );
    cmd_args =
      specs @
      [ [ "package" ],
        Arg.String (fun s -> package := Some s),
        Ezcmd.info "Attach dependency to this package name" ;
        [ "tool" ], Arg.Unit (fun () -> tool := true),
        Ezcmd.info "Dependency is a tool, not a library" ;
        [ "add" ], Arg.Unit (fun () -> add := true),
        Ezcmd.info "Add as new dependency" ;
        [ "remove" ], Arg.Unit (fun () -> tool := true),
        Ezcmd.info "Remove this dependency" ;
        [ "ver" ], Arg.String (fun s -> version := Some s),
        Ezcmd.info "Dependency should have this version" ;
        [ "lib" ], Arg.String (fun s -> depname := Some s),
        Ezcmd.info "Dependency should have this libname in dune" ;
        [ "test" ], Arg.Bool (fun b -> deptest := Some b),
        Ezcmd.info "Whether dependency is only for tests" ;
        [ "doc" ], Arg.Bool (fun b -> depdoc := Some b),
        Ezcmd.info "Whether dependency is only for doc" ;
        ( [],
          Arg.Anon (0, fun name -> dep := Some name),
          Ezcmd.info "Name of dependency" )
      ];
    cmd_man = [];
    cmd_doc = "Manage dependency of a package"
  }
