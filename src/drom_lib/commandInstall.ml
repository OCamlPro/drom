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

let cmd_name = "install"

let action ~args () =
  if Misc.vendor_packages () <> [] then
    Error.raise "Cannot install project if the project has vendors/ packages";

  let _p = Build.build ~args () in
  let y = args.arg_yes in
  let packages = Misc.list_opam_packages "." in
  Opam.run ~y [ "pin" ] [ "--no-action"; "-k"; "path"; "." ];
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
  EZCMD.sub
    cmd_name
    (fun () -> action ~args ())
    ~args: specs
    ~doc: "Build & install the project in the project opam switch"
