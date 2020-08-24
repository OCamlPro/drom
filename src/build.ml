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

let switch_args switch =
  [
    [ "global" ], Arg.Unit (fun () -> switch := Some `Global),
    Ezcmd.info "Use a global switch instead of creating a local switch" ;

    [ "local" ], Arg.Unit (fun () -> switch := Some `Local),
    Ezcmd.info "Create a local switch instead of using a global switch" ;
  ]

let build ~switch
    ?( setup_opam = true )
    ?( build_deps = true )
    ?( dev_deps = false )
    ?( build = true )
    () =
  let p = Project.project_of_toml "drom.toml" in
  let create = false in
  Update.update_files ~create p ;

  EzFile.make_dir ~p:true "_drom";
  let opam_filename =
    match p.kind with
    | Both -> p.name ^ "-lib.opam"
    | Library | Program -> p.name ^ ".opam"
  in

  let had_switch, switch_packages =
    if setup_opam then

      let had_switch =
        match !switch with
        | None -> Sys.file_exists "_opam"
        | Some `Local ->
          ( try Sys.remove "_opam" with _ -> () );
          Sys.file_exists "_opam"
        | Some `Global ->
          begin
            match Unix.lstat "_opam" with
            | exception _ -> ()
            | st ->
              match st.Unix.st_kind with
              | Unix.S_DIR ->
                Error.printf
                  "You must remove the local switch `_opam` before using option --global"
              | Unix.S_LNK -> ()
              | _ ->
                Error.printf "Corrupted local switch '_opam'"
          end;
          match Sys.getenv "OPAM_SWITCH_PREFIX" with
          | exception Not_found ->
            Error.printf
              "You must use 'eval $(opam env)' before using option --global"
          | switch_dir ->
            let switch = Filename.basename switch_dir in
            if switch = "_opam" then
              Error.printf "You must be using a global switch to use option --global. Current switch %s is local." switch_dir ;
            Misc.call [| "opam" ; "switch" ; "link" ; switch |];
            false
      in

      if not ( Sys.file_exists "_opam" ) then
        Misc.call [| "opam" ; "switch" ; "create"; "." ; "--empty" |] ;

      let packages_dir = "_opam" // ".opam-switch" // "packages" in
      let packages =
        match Sys.readdir packages_dir with
        | exception _ -> [||]
        | packages -> packages
      in
      let map = ref StringMap.empty in
      Array.iter (fun nv ->
          let n,v = EzString.cut_at nv '.' in
          map := StringMap.add n v !map ;
          map := StringMap.add nv v !map ;
        )  packages ;
      had_switch, !map
    else
      true, StringMap.empty
  in

  begin
    match StringMap.find "ocaml" switch_packages with
    | exception Not_found ->
      let ocaml_nv = "ocaml." ^ p.edition in
      Misc.call ( Array.of_list
                    ( "opam" :: "install" :: "-y" :: [ ocaml_nv ] ) );
    | v ->
      match VersionCompare.compare p.min_edition v with
      | 1 ->
        Error.printf
          "Wrong ocaml version %S in _opam. Expecting %S. You may want to remove _opam, or change the project min-edition field."
          v p.min_edition
      | _ -> ()
  end ;

  if dev_deps then
    begin
      let dev_packages =  [
        "ocamlformat" ;
        "user-setup" ;
        "merlin" ;
        "odoc" ;
      ] in
      let to_install = ref [] in
      List.iter (fun n ->
          match StringMap.find n switch_packages with
          | exception Not_found -> to_install := n :: !to_install
          | _ -> ()
        ) dev_packages ;
      match !to_install with
      | [] -> ()
      | packages ->
        Misc.call ( Array.of_list
                      ( "opam" :: "install" :: "-y" :: packages ) );
    end;

  if build_deps then begin
    let drom_opam_filename = "_drom/opam" in
    let former_opam_file =
      if Sys.file_exists drom_opam_filename then
        Some ( EzFile.read_file drom_opam_filename )
      else None
    in
    let new_opam_file = EzFile.read_file opam_filename in
    if former_opam_file <> Some new_opam_file || not had_switch then begin

      let tmp_opam_filename = "_drom/new.opam" in
      EzFile.write_file tmp_opam_filename new_opam_file ;

      Misc.call [| "opam" ; "install" ; "-y" ; "--deps-only";
                   "." // tmp_opam_filename |];

      begin try Sys.remove drom_opam_filename with _ -> () end ;
      Sys.rename tmp_opam_filename drom_opam_filename;

    end ;
  end;

  if build then begin
    Misc.call [| "opam" ; "exec"; "--" ; "dune" ; "build" |] ;
  end;
  p
