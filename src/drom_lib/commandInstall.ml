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
open EzFile.OP

let cmd_name = "install"

let action ~args ~packages () =
  if Misc.vendor_packages () <> [] then
    Error.raise "Cannot install project if the project has vendors/ packages";

  let _p = Build.build ~args () in
  let y = args.arg_yes in
  let packages = match packages with
    | [] -> Misc.list_opam_packages "."
    | packages -> packages
  in
  let overlay_dir = "_opam" // ".opam-switch" // "overlay" in
  let some_pinned = ref [] in
  let already_pinned = ref true in
  let pinned_as_path = ref true in
  List.iter (fun p ->
      let pin_dir = overlay_dir // p in
      if Sys.file_exists pin_dir then begin
        some_pinned := p :: !some_pinned ;
        if Sys.file_exists ( pin_dir // "path" ) then
          ()
        else
          pinned_as_path := false
      end else begin
        already_pinned := false ;
      end
    ) packages ;
  if !already_pinned && !pinned_as_path then
    ()
  else begin
    begin
      match !some_pinned with
      | [] -> ()
      | packages ->
          Opam.run ~y [ "unpin" ] ( "--no-action" :: packages )
    end;
    Opam.run ~y [ "pin" ] [ "--no-action"; "-k"; "path"; "." ];
    List.iter (fun p ->
        let pin_dir = overlay_dir // p in
        if Sys.file_exists pin_dir then
          EzFile.write_file ( pin_dir // "path" ) "path"
      ) packages ;
  end;
  let exn =
    match Opam.run ~y [ "install" ] ("-y" :: packages) with
    | () -> None
    | exception exn -> Some exn
  in
  match exn with
  | None -> Printf.eprintf "\nInstallation OK\n%!"
  | Some exn -> raise exn

let cmd =
  let args, specs = Build.build_args () in
  let packages = ref [] in
  EZCMD.sub
    cmd_name
    (fun () -> action
        ~args ~packages:!packages ())
    ~args:
      ( specs
        @
        [
          [], EZCMD.Anons (fun list -> packages := list),
          EZCMD.info ~docv:"PACKAGES" "Specify the list of packages to install";
        ])
    ~doc: "Build & install the project in the project opam switch"
