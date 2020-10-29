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
open EzCompat

type build_args =
  { mutable arg_switch : switch_arg option;
    mutable arg_yes : bool;
    mutable arg_edition : string option;
    mutable arg_upgrade : bool
  }

let build_args () =
  let args =
    { arg_switch = None;
      arg_yes = false;
      arg_edition = None;
      arg_upgrade = false
    }
  in
  let specs =
    [ ( [ "switch" ],
        Arg.String (fun s -> args.arg_switch <- Some (Global s)),
        Ezcmd.info "Use global switch SWITCH instead of creating a local switch"
      );
      ( [ "local" ],
        Arg.Unit (fun () -> args.arg_switch <- Some Local),
        Ezcmd.info "Create a local switch instead of using a global switch" );
      ( [ "edition" ],
        Arg.String (fun s -> args.arg_edition <- Some s),
        Ezcmd.info "Use this OCaml edition" );
      ( [ "y"; "yes" ],
        Arg.Unit (fun () -> args.arg_yes <- true),
        Ezcmd.info "Reply yes to all questions" );
      ( [ "upgrade" ],
        Arg.Unit (fun () -> args.arg_upgrade <- true),
        Ezcmd.info "Upgrade project files from drom.toml" )
    ]
  in
  (args, specs)

let build ~args ?(setup_opam = true) ?(build_deps = true)
    ?(force_build_deps = false)
    ?((* only for `drom build-deps` *)
    dev_deps = false) ?(force_dev_deps = false)
    ?((* only for `drom dev-deps` *)
    build = true) () =
  let p, _inferred_dir = Project.get () in

  let { arg_switch; arg_yes = y; arg_edition = edition; arg_upgrade } = args in
  ( match edition with
  | None -> ()
  | Some edition -> (
    match VersionCompare.compare p.min_edition edition with
    | 1 ->
      Error.raise
        "Option --edition %s should specify a version compatible with the \
         project, whose min-edition is currently %s"
        edition p.min_edition
    | _ -> () ) );
  ( match arg_switch with
  | None
  | Some Local ->
    ()
  | Some (Global switch) -> (
    match VersionCompare.compare p.min_edition switch with
    | 1 ->
      Error.raise
        "Option --switch %s should specify a version compatible with the \
         project, whose min-edition is currently %s"
        switch p.min_edition
    | _ -> () ) );

  ( if arg_upgrade then
    let create = false in
    Update.update_files ~create p
  else
    let hashes = Hashes.load () in
    if
      match Hashes.get hashes "." with
      | exception Not_found -> true
      | old_hash ->
        let files =
          ( match p.file with
          | None -> assert false
          | Some file -> file )
          :: List.map
               (fun package ->
                 match package.p_file with
                 | None -> assert false
                 | Some file -> file)
               p.packages
        in
        old_hash
        <> Update.compute_config_hash
             (List.map (fun file -> (file, EzFile.read_file file)) files)
    then
      Printf.eprintf
        "Warning: 'drom.toml' changed since last update,\n\
        \  you should run `drom project` to regenerate files.\n\
         %!" );

  EzFile.make_dir ~p:true "_drom";
  let opam_filename = (Globals.drom_dir // p.package.name) ^ "-deps.opam" in

  let had_switch, switch_packages =
    if setup_opam then (
      let had_switch =
        match arg_switch with
        | None -> Sys.file_exists "_opam"
        | Some Local ->
          (try Sys.remove "_opam" with _ -> ());
          Sys.file_exists "_opam"
        | Some (Global switch) ->
          ( match Unix.lstat "_opam" with
          | exception _ -> ()
          | st -> (
            match st.Unix.st_kind with
            | Unix.S_DIR ->
              Error.raise
                "You must remove the local switch `_opam` before using option \
                 --switch"
            | Unix.S_LNK -> ()
            | _ -> Error.raise "Corrupted local switch '_opam'" ) );
          Opam.run ~y ~switch ?edition [ "switch"; "link" ] [ switch ];
          false
      in

      let env_switch =
        match Sys.getenv "OPAM_SWITCH_PREFIX" with
        | exception Not_found -> None
        | switch_dir -> Some switch_dir
      in

      ( match Unix.lstat "_opam" with
      | exception _ -> Opam.run ~y [ "switch"; "create" ] [ "."; "--empty" ]
      | st -> (
        let current_switch =
          match st.Unix.st_kind with
          | Unix.S_LNK -> Filename.basename (Unix.readlink "_opam")
          (* | Unix.S_DIR *)
          | _ -> Unix.getcwd () // "_opam"
        in
        if Misc.verbose 1 then
          Printf.eprintf "In opam switch %s\n%!" current_switch;
        match env_switch with
        | None -> ()
        | Some env_switch ->
          let env_switch =
            if Filename.basename env_switch = "_opam" then
              env_switch
            else
              Filename.basename env_switch
          in
          if env_switch <> current_switch then
            Printf.eprintf
              "Warning: your current environment contains a different opam \
               switch %S, be careful.\n\
               %!"
              env_switch ) );

      let packages_dir = "_opam" // ".opam-switch" // "packages" in
      let packages =
        match Sys.readdir packages_dir with
        | exception _ -> [||]
        | packages -> packages
      in
      let map = ref StringMap.empty in
      Array.iter
        (fun nv ->
          let n, v = EzString.cut_at nv '.' in
          map := StringMap.add n v !map;
          map := StringMap.add nv v !map)
        packages;
      (had_switch, !map)
    ) else
      (true, StringMap.empty)
  in

  if setup_opam then (
    let vscode_dir = ".vscode" in
    let vscode_file = vscode_dir // "settings.json" in
    if not (Sys.file_exists vscode_file) then (
      EzFile.make_dir ~p:true vscode_dir;
      EzFile.write_file vscode_file
        (Printf.sprintf
           {|
{
    "ocaml.sandbox": {
        "kind": "opam"
        "switch": "%s"
    }
}
|}
           (Sys.getcwd ()))
    );

    match StringMap.find "ocaml" switch_packages with
    | exception Not_found ->
      let ocaml_nv =
        "ocaml."
        ^
        match edition with
        | None -> p.edition
        | Some edition -> edition
      in
      Opam.run ~y [ "install" ] [ ocaml_nv ];
      Opam.run [ "switch"; "set-base" ] [ "ocaml" ]
    | v -> (
      match edition with
      | Some edition ->
        if edition = v then
          Error.raise
            "Switch edition %s is not compatible with option --edition %s. You \
             should remove the switch first."
            v edition
      | None -> (
        match VersionCompare.compare p.min_edition v with
        | 1 ->
          Error.raise
            "Wrong ocaml version %S in _opam. Expecting %S. You may want to \
             remove _opam, or change the project min-edition field."
            v p.min_edition
        | _ -> () ) )
  );

  let deps_package = Misc.deps_package p in
  EzFile.write_file opam_filename (Opam.opam_of_project Deps deps_package);

  let drom_opam_filename = "_drom/opam.current" in
  let drom_opam_deps = "_drom/opam.deps" in
  let former_opam_file =
    if Sys.file_exists drom_opam_filename then
      Some (EzFile.read_file drom_opam_filename)
    else
      None
  in
  let new_opam_file = EzFile.read_file opam_filename in
  let has_dev_deps =
    try EzFile.read_file drom_opam_deps = "dev-deps" with _ -> false
  in
  let need_update =
    force_build_deps || force_dev_deps
    || (build_deps || dev_deps)
       && (former_opam_file <> Some new_opam_file || not had_switch)
    || (dev_deps && not has_dev_deps)
  in
  let need_dev_deps =
    dev_deps || force_dev_deps || (has_dev_deps && not force_build_deps)
  in

  (*
  Printf.eprintf
    {|need_update :%b
force_build_deps: %b
force_dev_deps: %b
build_deps: %b
dev_deps: %b
diff_opam: %b
had_switch: %b
|}
    need_update
    force_build_deps
    force_dev_deps
    build_deps
    dev_deps
    (former_opam_file <> Some new_opam_file)
    had_switch
  ; *)
  Git.update_submodules ();

  if need_update then (
    let tmp_opam_filename = "_drom/new.opam" in
    EzFile.write_file tmp_opam_filename new_opam_file;

    let vendor_packages = Misc.vendor_packages () in

    Opam.run ~y [ "install" ]
      ( [ "--deps-only"; "." // tmp_opam_filename ]
      @ ( if need_dev_deps then
          [ "--with-doc"; "--with-test" ]
        else
          [] )
      @ vendor_packages );

    (try Sys.remove drom_opam_filename with _ -> ());
    Sys.rename tmp_opam_filename drom_opam_filename;
    EzFile.write_file drom_opam_deps
      ( if need_dev_deps then
        "dev-deps"
      else
        "build-deps" )
  );

  if build then
    Opam.run [ "exec" ]
      ( [ "--"; "dune"; "build"; "@install" ]
      @
      match p.profile with
      | None -> []
      | Some profile -> [ "--profile"; profile ] );
  p
