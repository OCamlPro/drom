(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Types
open Ezcmd.V2
open EZCMD.TYPES
open Ez_file.V1
open EzFile.OP
open EzCompat

let is_local_directory file =
  match Unix.lstat file with
  | exception _ -> false
  | st -> st.Unix.st_kind = Unix.S_DIR

type build_args =
  { mutable arg_switch : switch_arg option;
    mutable arg_yes : bool;
    mutable arg_edition : string option;
    mutable arg_upgrade : bool;
    mutable arg_profile : string option
  }

let build_args () =
  let args =
    { arg_switch = None;
      arg_yes = false;
      arg_edition = None;
      arg_upgrade = false;
      arg_profile = None
    }
  in
  let specs =
    [ ( [ "switch" ],
        Arg.String (fun s -> args.arg_switch <- Some (Global s)),
        EZCMD.info ~docv:"OPAM_SWITCH"
          "Use global switch SWITCH instead of creating a local switch" );
      ( [ "local" ],
        Arg.Unit (fun () -> args.arg_switch <- Some Local),
        EZCMD.info "Create a local switch instead of using a global switch" );
      ( [ "edition" ],
        Arg.String (fun s -> args.arg_edition <- Some s),
        EZCMD.info ~docv:"VERSION" "Use this OCaml edition" );
      ( [ "y"; "yes" ],
        Arg.Unit (fun () -> args.arg_yes <- true),
        EZCMD.info "Reply yes to all questions" );
      ( [ "upgrade" ],
        Arg.Unit (fun () -> args.arg_upgrade <- true),
        EZCMD.info "Upgrade project files from drom.toml" );
      ( [ "profile" ],
        Arg.String (fun s -> args.arg_profile <- Some s),
        EZCMD.info ~docv:"PROFILE" "Build profile to use" )
    ]
  in
  (args, specs)

let build ~args ?(setup_opam = true) ?(build_deps = true)
    ?(force_build_deps = false)
    ?((* only for `drom build-deps` *)
    dev_deps = false) ?(force_dev_deps = false)
    ?((* only for `drom dev-deps` *) build = true) ?(extra_packages = []) () =
  let p, _inferred_dir = Project.get () in

  let { arg_switch;
        arg_yes = y;
        arg_edition = edition;
        arg_upgrade;
        arg_profile
      } =
    args
  in
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

  let config = Config.get () in

  let share = Share.load ~p () in
  begin
    if arg_upgrade then
      Update.update_files share ~twice:false p
    else
      let hashes = Hashes.load () in
      begin
        if
          match Hashes.get hashes "." with
          | exception Not_found -> true
          | old_hashes ->
              let files =
                ( match p.file with
                  | None -> assert false
                  | Some file -> file )
                :: List.flatten
                  (List.map
                     (fun package ->
                        match package.p_file with
                        | None -> []
                        | Some file -> [ file ] )
                     p.packages )
              in
              let new_hash =
                Update.compute_config_hash
                  (List.map (fun file -> (file, EzFile.read_file file)) files)
              in
              List.for_all ( (<>) new_hash ) old_hashes
        then
          if config.config_auto_upgrade <> Some false then
            Update.update_files share ~twice:false ~git:true p
          else
            Printf.eprintf
              "Warning: 'drom.toml' changed since last update,\n\
              \  you should run `drom project` to regenerate files.\n\
               %!";
      end;
  end;
  EzFile.make_dir ~p:true "_drom";
  let drom_project_deps_opam = (Globals.drom_dir // p.package.name) ^ "-deps.opam" in

  let had_switch, switch_packages =
    if setup_opam then (
      let had_switch =
        match arg_switch with
        | None -> Sys.file_exists "_opam"
        | Some Local ->
            ( try Sys.remove "_opam" with
              | _ -> () );
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

      let env_switch = Globals.opam_switch_prefix in

      ( match Unix.lstat "_opam" with
        | exception _ ->
            Opam.run ~y:true [ "switch"; "create" ] [ "."; "--empty" ]
        | st -> (
            let current_switch =
              match st.Unix.st_kind with
              | Unix.S_LNK -> Filename.basename (Unix.readlink "_opam")
              (* | Unix.S_DIR *)
              | _ -> Unix.getcwd () // "_opam"
            in
            if Globals.verbose 1 then
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
           map := StringMap.add nv v !map )
        packages;
      (had_switch, !map)
    ) else
      (true, StringMap.empty)
  in

  if setup_opam then (

    match StringMap.find "ocaml" switch_packages with
    | exception Not_found ->
        let ocaml_nv =
          "ocaml."
          ^
          match edition with
          | None -> p.edition
          | Some edition -> edition
        in
        let y =
          y
          || config.config_auto_opam_yes <> Some false
             && is_local_directory "_opam"
        in
        Opam.run ~y [ "install" ] [ ocaml_nv ];
        Opam.run [ "switch"; "set-invariant" ] [ ocaml_nv ]
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
  let new_opam_file_content = Opam.opam_of_package Deps share deps_package in

  let drom_opam_current = "_drom/opam.current" in
  let drom_opam_deps = "_drom/opam.deps" in
  let former_deps_status =
    match EzFile.read_file drom_opam_deps with
    | exception _ -> Deps_build
    | "devel-deps" -> Deps_devel
    | "build-deps" -> Deps_build
    (*    | "locked-deps" -> Deps_locked *)
    | _ -> Deps_build
  in
  let former_opam_file_content =
    if Sys.file_exists drom_opam_current then
      Some (EzFile.read_file drom_opam_current)
    else
      None
  in
  let new_deps_status =
    if dev_deps then
      Deps_devel
    else
      former_deps_status
  in
  let project_deps_opam_locked = p.package.name ^ "-deps.opam.locked" in
  let opam_diff = former_opam_file_content <> Some new_opam_file_content in
  let need_update =
    force_build_deps || force_dev_deps
    || (build_deps || dev_deps)
       && (opam_diff || not had_switch)
    || former_deps_status <> new_deps_status
  in
  let need_dev_deps =
    dev_deps || force_dev_deps
    || (former_deps_status = Deps_devel && not force_build_deps)
  in
  let with_locked =
    not need_dev_deps &&
    ( former_opam_file_content = None || not opam_diff ) in
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

  let to_install =
    let extra_packages =
      if force_dev_deps then
        let config = Config.get () in
        ( match config.config_dev_tools with
          | None -> [ "merlin"; "ocp-indent" ]
          | Some dev_tools -> dev_tools )
        @ extra_packages
      else
        extra_packages
    in
    match extra_packages with
    | [] -> []
    | _ ->
        let to_install = ref [] in
        List.iter
          (fun nv ->
             if not (StringMap.mem nv switch_packages) then
               to_install := nv :: !to_install )
          extra_packages;
        !to_install
  in

  if need_update || to_install <> [] then begin
    EzFile.write_file drom_project_deps_opam new_opam_file_content;

    let vendor_packages = Misc.vendor_packages () in

    Printf.eprintf "current dir: %s\n%!" (Sys.getcwd ());

    let drom_project_deps_opam_locked = "_drom" // project_deps_opam_locked in
    if Sys.file_exists project_deps_opam_locked then begin
      let s = EzFile.read_file project_deps_opam_locked in
      EzFile.write_file drom_project_deps_opam_locked s
    end else
    if Sys.file_exists drom_project_deps_opam_locked then
      Sys.remove drom_project_deps_opam_locked;

    Opam.run ~y [ "install" ]
      ( ( if with_locked then [ "--locked" ] else [] )
        @ [ "--deps-only"; "." // drom_project_deps_opam ]
        @ ( if need_dev_deps then
              [ "--with-doc"; "--with-test" ]
            else
              [] )
        @ vendor_packages
        @ to_install );

    (* Generate lock file only if no dev deps *)
    if not need_dev_deps then
      Opam.run ~y [ "lock" ] [ "-d" ; "." // drom_project_deps_opam ];

    EzFile.write_file drom_opam_current new_opam_file_content ;
    EzFile.write_file drom_opam_deps
      ( match new_deps_status with
        | Deps_devel -> "devel-deps"
        | Deps_build -> "build-deps"
      )
  end;

  if build then begin
    Call.before_hook ~command:"build" ();
    Opam.exec
      ( [ "dune"; "build"; "@install" ]
        @ ( match arg_profile with
            | Some profile -> [ "--profile"; profile ]
            | None -> (
                match p.profile with
                | None -> []
                | Some profile -> [ "--profile"; profile ] ) )
        @
        match !Globals.verbosity with
        | 0 -> [ "--display=quiet" ]
        | 1 -> []
        | 2 -> [ "--display=short" ]
        | _ -> [ "--display=verbose" ] );
    Call.after_hook ~command:"build" ()
  end;
  p
