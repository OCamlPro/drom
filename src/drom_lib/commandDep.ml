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
open Update
open Types

let cmd_name = "dep"

let print_dep (name, d) =
  Printf.printf "Dependency: %S\n%!" name;
  Printf.printf "  version (--ver) : %s\n%!"
    (Package.string_of_versions d.depversions);
  Printf.printf "  libname (--lib) : %s\n%!"
    ( match d.depname with
    | None -> name
    | Some name -> name );
  Printf.printf "  for-test (--test) : %b\n%!" d.deptest;
  Printf.printf "  for-doc (--test) : %b\n%!" d.depdoc;
  ()

let action ~dep ~package ~tool ~add ~remove ~version ~depname ~deptest ~depdoc
    ~depopt ~args =
  let p, _inferred_dir = Project.get () in
  let upgrade = ref (fst args).arg_upgrade in
  let update package_kind dep_kind deps setdeps =
    match dep with
    | None ->
      Printf.printf "Printing %s %s dependencies:\n%!" package_kind dep_kind;
      List.iter print_dep deps
    | Some dep ->
      if add then begin
        if List.mem_assoc dep deps then
          Error.raise "%S is already a dependency" dep;

        let d =
          { depversions =
              ( match version with
              | None -> []
              | Some version -> Package.versions_of_string version );
            depname;
            deptest =
              ( match deptest with
              | None -> false
              | Some b -> b );
            depdoc =
              ( match depdoc with
              | None -> false
              | Some b -> b );
            depopt =
              ( match depopt with
              | None -> false
              | Some b -> b );
            dep_pin = None ; (* TODO *)
          }
        in
        upgrade := true;
        Printf.eprintf "Adding %s %s dependency %S\n%!" package_kind dep_kind
          dep;
        setdeps ((dep, d) :: deps)
      end else begin
        if not (List.mem_assoc dep deps) then
          Error.raise "%S is not a current dependency" dep;

        if remove then begin
          let deps = List.filter (fun (name, _) -> name <> dep) deps in
          setdeps deps;
          upgrade := true;
          Printf.eprintf "Removed %s %s dependency %S\n%!" package_kind dep_kind
            dep
        end else
          let deps =
            List.map
              (fun (name, d) ->
                if name = dep then (
                  let d =
                    match version with
                    | None -> d
                    | Some version ->
                      upgrade := true;
                      { d with
                        depversions = Package.versions_of_string version
                      }
                  in
                  let d =
                    match depname with
                    | None -> d
                    | Some depname ->
                      upgrade := true;
                      { d with
                        depname =
                          ( if depname = dep then
                            None
                          else
                            Some depname )
                      }
                  in
                  let d =
                    match deptest with
                    | None -> d
                    | Some deptest ->
                      upgrade := true;
                      { d with deptest }
                  in
                  let d =
                    match depdoc with
                    | None -> d
                    | Some depdoc ->
                      upgrade := true;
                      { d with depdoc }
                  in
                  let d =
                    match depopt with
                    | None -> d
                    | Some depopt ->
                      upgrade := true;
                      { d with depopt }
                  in

                  if not !upgrade then begin
                    print_dep (dep, d);
                    exit 0
                  end;
                  Printf.eprintf "Updating %s %s dependency %S\n%!" package_kind
                    dep_kind dep;
                  (name, d)
                ) else
                  (name, d) )
              deps
          in
          setdeps deps
      end
  in

  begin
    match package with
    | None ->
      let kind, deps, setdeps =
        if tool then
          ("tools", p.tools, fun deps -> p.tools <- deps)
        else
          ("libs", p.dependencies, fun deps -> p.dependencies <- deps)
      in
      update "project" kind deps setdeps
    | Some name ->
      List.iter
        (fun package ->
          if package.name = name then
            let kind, deps, setdeps =
              if tool then
                ("tools", package.p_tools, fun deps -> package.p_tools <- deps)
              else
                ( "libs",
                  package.p_dependencies,
                  fun deps -> package.p_dependencies <- deps )
            in
            update "package" kind deps setdeps )
        p.packages
  end;

  if !upgrade then (
    let args, share_args = args in
    let share = Share.load ~args:share_args ~p () in
    let args = { args with
                 arg_share_version = Some share.share_version ;
                 arg_share_repo = share_args.arg_repo ;
                 arg_upgrade = !upgrade ;
               }
    in
    Update.update_files share ~twice:false ~git:true p ~args;
    ()
  )

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
  let depopt = ref None in
  let update_args, update_specs = Update.args () in
  let share_args, share_specs = Share.args ~set:true () in
  let args = (update_args, share_args) in
  let specs = update_specs @ share_specs in
  EZCMD.sub cmd_name
    (fun () ->
      action ~dep:!dep ~package:!package ~tool:!tool ~add:!add ~remove:!remove
        ~version:!version ~depname:!depname ~deptest:!deptest ~depdoc:!depdoc
        ~depopt:!depopt ~args )
    ~args:
      ( specs
      @ [ ( [ "package" ],
            Arg.String (fun s -> package := Some s),
            EZCMD.info ~docv:"PACKAGE" "Attach dependency to this package name"
          );
          ( [ "tool" ],
            Arg.Unit (fun () -> tool := true),
            EZCMD.info "Dependency is a tool, not a library" );
          ( [ "add" ],
            Arg.Unit (fun () -> add := true),
            EZCMD.info "Add as new dependency" );
          ( [ "remove" ],
            Arg.Unit (fun () -> tool := true),
            EZCMD.info "Remove this dependency" );
          ( [ "ver" ],
            Arg.String (fun s -> version := Some s),
            EZCMD.info ~docv:"VERSION" "Dependency should have this version" );
          ( [ "lib" ],
            Arg.String (fun s -> depname := Some s),
            EZCMD.info ~docv:"LIBNAME"
              "Dependency should have this libname in dune" );
          ( [ "test" ],
            Arg.Bool (fun b -> deptest := Some b),
            EZCMD.info "Whether dependency is only for tests" );
          ( [ "doc" ],
            Arg.Bool (fun b -> depdoc := Some b),
            EZCMD.info "Whether dependency is only for doc" );
          ( [ "opt" ],
            Arg.Bool (fun b -> depopt := Some b),
            EZCMD.info "Whether dependency is optional or not" );
          ( [],
            Arg.Anon (0, fun name -> dep := Some name),
            EZCMD.info ~docv:"DEPENDENCY" "Name of dependency" )
        ] )
    ~doc:"Manage dependency of a package" ~version:"0.2.1"
    ~man:
      [ `S "DESCRIPTION";
        `Blocks
          [ `P
              "Add, remove and modify dependencies from $(b,drom.toml) and  \
               $(b,package.toml) files.";
            `P
              "If the argument $(b,--package) is not specified, the dependency \
               is added project-wide (i.e. for all packages), updating the \
               $(i,drom.toml) file.";
            `P
              "If the argument $(b,--package) is provided, the dependency is \
               added to the $(i,package.toml) file for that particular \
               package.";
            `P
              "Dependencies can be added $(b,--add), removed $(b,--remove) or \
               just modified. The $(b,--tool) argument should be used for tool \
               dependencies, i.e. dependencies that are not linked to the \
               library/program.";
            `P
              "If no modification argument is provided, the dependency is \
               printed in the terminal. Modification arguments are $(b,--ver \
               VERSION) for the version, $(b,--lib LIBNAME) for the $(i,dune) \
               library name, $(b,--doc BOOL) for documentation deps and \
               $(b,--test BOOL) for test deps."
          ];
        `S "EXAMPLE";
        `Pre
          {|
drom dep --package drom_lib --add ez_cmdliner --ver ">0.1"
drom dep --package drom_lib --remove ez_cmdliner
drom dep --add --tool odoc --ver ">1.0 <3.0" --doc true
|};
        `S "VERSION SPECIFICATION";
        `P
          "The version specified in the $(b,--ver VERSION) argument should \
           follow the following format:";
        `I
          ( "1.",
            "Spaces are used to separate a conjunction of version constraints."
          );
        `I ("2.", "An empty string is equivalent to no version constraint.");
        `I
          ( "3.",
            "Constraints are specified using a comparison operation directly \
             followed by the version, like $(b,>1.2) or $(b,<=1.0)." );
        `I
          ( "4.",
            {|A semantic version like $(b,1.2.3) is equivalent to the constraints  $(b,>=1.2.3) and $(b,<2.0.0).|}
          )
      ]
