(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.V2
open Types
open EZCMD.TYPES
open EzFile.OP
open Update

let cmd_name = "package"

let remove_file hashes file =
  if Sys.file_exists file then
    try
      if Sys.is_directory file then
        Unix.rmdir file
      else begin
        Sys.remove file;
        Hashes.remove hashes file
      end
    with exn ->
      Printf.eprintf "remove %s failed with %s\n%!" file
        (Printexc.to_string exn)
  else
    Hashes.remove hashes file

let remove_dir hashes dir =
  if Sys.file_exists dir then
    EzFile.make_select EzFile.iter_dir dir ~deep:true ~dft:`After
      ~f:(fun path ->
        let file = Filename.concat dir path in
        remove_file hashes file)

let rename_dir hashes src dst =
  EzFile.make_dir ~p:true dst;

  EzFile.make_select EzFile.iter_dir src ~deep:true ~dft:`Before ~f:(fun path ->
      let src_file = Filename.concat src path in
      let dst_file = Filename.concat dst path in
      if Sys.is_directory src_file then
        EzFile.make_dir ~p:true dst_file
      else begin
        Misc.call [| "mv"; "-f"; src_file; dst_file |];
        Hashes.rename hashes src_file dst_file
      end);

  EzFile.make_select EzFile.iter_dir src ~deep:true ~dft:`After ~f:(fun path ->
      let src_file = Filename.concat src path in
      if Sys.is_directory src_file then remove_file hashes src_file)

let remove_package hashes package =
  remove_dir hashes package.dir;
  let file = package.name ^ ".opam" in
  remove_file hashes file;
  Printf.eprintf "Package %S removed\n%!" package.name

let rename_package hashes package new_name =
  let new_dir = "src" // new_name in
  EzFile.make_dir ~p:true "src";
  rename_dir hashes package.dir new_dir;

  let opam_file = package.name ^ ".opam" in
  remove_file hashes opam_file;

  { package with dir = new_dir; name = new_name }

let upgrade_package package ~upgrade ~kind ~mode ~files =

  ( match kind with
    | None -> ()
    | Some kind ->
        package.kind <- kind;
        upgrade := true );
  ( match mode with
    | None -> ()
    | Some mode ->
        package.p_mode <- Some mode;
        upgrade := true
  );

  begin

    match files with
      [] -> ()
    | _ ->
        let new_files = ref [] in
        List.iter (fun file ->
            let new_file = package.dir // file in
            new_files := new_file :: !new_files;

            let _, ext = EzFile.cut_extension file in
            let header =
              match ext with
                "mly" | "c" | "h" | "cpp" ->
                  License.header_mly package.project
              | _ ->
                  License.header_ml package.project
            in
            let content =
              header ^
              "\n\nlet () = ()\n"
            in

            EzFile.write_file new_file content
          ) files;
        Misc.call
          ( Array.of_list ( [ "git"; "add" ] @ List.rev !new_files ) )

  end;
  ()

let action ~edit ~package_name ~kind ~mode ~dir ?create ~remove ?rename
    ~args ~files () =
  let p, inferred_dir = Project.get () in
  let name =
    match package_name with
    | None ->
        let name = p.package.name in
        Printf.eprintf "No name specified, using project name %S\n%!" name;
        name
    | Some name -> name
  in
  let p =
    if edit then
      let found = ref false in
      List.iter (fun package ->
          if package.name = name then begin
            found := true;
            let editor = Misc.editor () in
            match Printf.kprintf Sys.command "%s '%s'" editor
                    ( package.dir // "package.toml" ) with
            | 0 -> ()
            | _ -> Error.raise "Editing command returned a non-zero status"

          end) p.packages;
      if not !found then Error.raise "No such package to modify";
      let p, _inferred_dir = Project.get () in
      p
    else
      p
  in
  let upgrade =
    Hashes.with_ctxt ~git:true (fun hashes ->
        if remove then begin

          if create <> None then
            Error.raise "--remove and --create are incompatible";

          if p.package.name = name then
            Error.raise "Cannot remove main package";
          if List.for_all (fun package -> package.name <> name) p.packages then
            Error.raise "No such package to remove";
          p.packages <-
            List.filter
              (fun package ->
                 if package.name = name then begin
                   remove_package hashes package;
                   false
                 end else
                   true)
              p.packages;
          true
        end else
          let upgrade =
            match create with
            | Some skeleton ->
                if List.exists (fun package -> package.name = name) p.packages
                then
                  Error.raise "A package with this name already exists";
                let dir =
                  match dir with
                  | None ->
                      let dir =
                        if inferred_dir = "" then
                          "src"
                        else
                          inferred_dir
                      in
                      dir // name
                  | Some dir -> dir
                in
                let kind =
                  match kind with
                  | None -> Library
                  | Some kind -> kind
                in
                let package = Project.create_package ~kind ~name ~dir in
                package.p_skeleton <- Some skeleton;
                begin
                  match mode with
                  | None -> ()
                  | Some mode -> package.p_mode <- Some mode
                end;
                package.project <- p;

                let rec iter_skeleton list =
                  match list with
                  | [] -> package
                  | content :: super ->
                      let package = iter_skeleton super in
                      let content = Subst.package () package content in
                      Project.package_of_string ~msg:"toml template" content
                in
                let skeleton = Skeleton.lookup_package skeleton in
                let package = iter_skeleton skeleton.skeleton_toml in
                p.packages <- p.packages @ [ package ];
                true
            | None -> (
                if List.for_all (fun package -> package.name <> name) p.packages
                then
                  Error.raise "No such package to modify";
                if dir <> None then
                  Error.raise "Option --dir is not available for update";
                match rename with
                | Some new_name ->
                    if p.package.name = name then
                      Error.raise "Cannot rename main package";
                    if
                      List.exists
                        (fun package -> package.name = new_name)
                        p.packages
                    then
                      Error.raise
                        "Cannot rename to an already existing package name";
                    p.packages <-
                      List.map
                        (fun package ->
                           if package.name = name then
                             rename_package hashes package new_name
                           else
                             package)
                        p.packages;
                    true
                | None ->
                    edit )
          in
          let upgrade = ref upgrade in
          List.iter
            (fun package ->
               if package.name = name then
                 upgrade_package package ~upgrade ~kind ~mode ~files
            )
            p.packages;
          !upgrade)
  in
  let args = { args with arg_upgrade = upgrade } in
  let twice = create <> None in
  Update.update_files
    ~twice ~create:false ?mode ~git:true p ~args;
  ()

let cmd =
  let package_name = ref None in
  let kind = ref None in
  let mode = ref None in
  let dir = ref None in
  let create = ref None in
  let remove = ref false in
  let rename = ref None in
  let edit = ref false in
  let args, specs = Update.update_args () in
  let files = ref [] in
  EZCMD.sub cmd_name
    (fun () ->
       action ~package_name:!package_name ~mode:!mode ~kind:!kind
         ~dir:!dir ?create:!create ~remove:!remove
         ~edit:!edit
         ?rename:!rename ~args ~files:(List.rev !files) ())
    ~args: (
      specs
      @ [ ( [ "new" ],
            Arg.String (fun s -> create := Some s),
            EZCMD.info
              ~docv:"SKELETON"
              "Add a new package to the project with skeleton NAME" );
          ( [ "remove" ],
            Arg.Set remove,
            EZCMD.info ~version:"0.2.1"
              "Remove a package from the project" );
          ( [ "dir" ],
            Arg.String (fun s -> dir := Some s),
            EZCMD.info
              ~docv:"DIRECTORY"
              "Dir where package sources are stored (src by default)"
          );
          ( [ "rename" ],
            Arg.String (fun s -> rename := Some s),
            EZCMD.info ~docv:"NEW_NAME"
              "Rename secondary package to a new name" );
          ( [ "library" ],
            Arg.Unit (fun () -> kind := Some Library),
            EZCMD.info "Package is a library" );
          ( [ "program" ],
            Arg.Unit (fun () -> kind := Some Program),
            EZCMD.info "Package is a program" );
          ( [ "virtual" ],
            Arg.Unit (fun () -> kind := Some Virtual),
            EZCMD.info "Package is virtual, i.e. no code" );
          ( [ "binary" ],
            Arg.Unit (fun () -> mode := Some Binary),
            EZCMD.info "Compile to binary" );
          ( [ "javascript" ],
            Arg.Unit (fun () -> mode := Some Javascript),
            EZCMD.info "Compile to javascript" );
          ( [ "new-file" ],
            Arg.String (fun file -> files := file :: !files),
            EZCMD.info ~docv:"FILENAME" ~version:"0.2.1"
              "Add new source file" );
          ( [ "edit" ],
            Arg.Set edit,
            EZCMD.info "Edit package.toml description with EDITOR" );
          ( [],
            Arg.Anon (0, fun name -> package_name := Some name),
            EZCMD.info ~docv:"PACKAGE" "Name of the package" )
        ]
    )
    ~doc: "Manage a package within a project"
