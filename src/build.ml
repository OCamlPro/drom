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

type switch_arg =
  | Local
  | Global of string

let build_args () =
  let switch = ref None in
  let y = ref false in
  let specs =
  [
    [ "global" ], Arg.String (fun s -> switch := Some (Global s) ),
    Ezcmd.info "Use global switch SWITCH instead of creating a local switch" ;

    [ "local" ], Arg.Unit (fun () -> switch := Some Local),
    Ezcmd.info "Create a local switch instead of using a global switch" ;

    [ "y"; "yes" ], Arg.Set y,
    Ezcmd.info "Reply yes to all questions";
  ]
  in
  let args = ( switch, !y ) in
  ( args, specs )

let build ~args
    ?( setup_opam = true )
    ?( dev_deps = false )
    ?( force_build_deps = false )
    ?( build_deps = true )
    ?( build = true )
    () =
  let ( switch, y ) = args in
  let p = Project.project_of_toml "drom.toml" in
  let create = false in
  Update.update_files ~create p ;

  EzFile.make_dir ~p:true "_drom";
  let opam_filename =
    match p.kind with
    | Both -> p.package.name ^ "_lib.opam"
    | Library | Program -> p.package.name ^ ".opam"
  in

  let had_switch, switch_packages =
    if setup_opam then

      let had_switch =
        match !switch with
        | None -> Sys.file_exists "_opam"
        | Some Local ->
          ( try
              Sys.remove "_opam";
            with _ -> () );
          Sys.file_exists "_opam"
        | Some ( Global switch ) ->
          begin
            match Unix.lstat "_opam" with
            | exception _ -> ()
            | st ->
              match st.Unix.st_kind with
              | Unix.S_DIR ->
                Error.raise
                  "You must remove the local switch `_opam` before using option --global"
              | Unix.S_LNK -> ()
              | _ ->
                Error.raise "Corrupted local switch '_opam'"
          end;
          Misc.opam ~y [ "switch" ; "link" ] [ switch ];
          false
      in

      let env_switch =
        match Sys.getenv "OPAM_SWITCH_PREFIX" with
        | exception Not_found -> None
        | switch_dir -> Some switch_dir
      in

      begin
        match Unix.lstat "_opam" with
        | exception _ ->
          Misc.opam ~y [ "switch" ; "create" ] [ "." ; "--empty" ] ;
        | st ->
          let current_switch =
            match st.Unix.st_kind with
            | Unix.S_LNK ->
              Filename.basename (Unix.readlink "_opam")
            (* | Unix.S_DIR *)
            | _  -> Unix.getcwd () // "_opam"
          in
          Printf.eprintf "In opam switch %s\n%!" current_switch ;
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
              Printf.eprintf "Warning: your current environment contains a different opam switch %S, be careful.\n%!" env_switch

      end;

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

  if setup_opam then begin
    match StringMap.find "ocaml" switch_packages with
    | exception Not_found ->
      let ocaml_nv = "ocaml." ^ p.edition in
      Misc.opam ~y [ "install" ] [ ocaml_nv ]
    | v ->
      match VersionCompare.compare p.min_edition v with
      | 1 ->
        Error.raise
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
        Misc.opam ~y [ "install" ] packages;
    end;

  let drom_opam_filename = "_drom/opam" in
  let former_opam_file =
    if Sys.file_exists drom_opam_filename then
      Some ( EzFile.read_file drom_opam_filename )
    else None
  in
  let new_opam_file = EzFile.read_file opam_filename in
  if force_build_deps ||
     (
       build_deps &&
       ( former_opam_file <> Some new_opam_file || not had_switch)
     )
  then begin

    let tmp_opam_filename = "_drom/new.opam" in
    EzFile.write_file tmp_opam_filename new_opam_file ;

    Misc.opam ~y [ "install" ]
      [ "--deps-only"; "." // tmp_opam_filename ];

    begin try Sys.remove drom_opam_filename with _ -> () end ;
    Sys.rename tmp_opam_filename drom_opam_filename;

  end ;

  if build then begin
    Misc.opam [ "exec" ]  [ "--" ; "dune" ; "build" ] ;
  end;
  p
