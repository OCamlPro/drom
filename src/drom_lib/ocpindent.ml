(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzFile.OP

let find_global () =
  let file = Globals.xdg_config_dir // "ocp" // "ocp-indent.conf" in
  try Some (EzFile.read_file file)
  with _exn -> (
    let file = Globals.home_dir // ".ocp" // "ocp-indent.conf" in
    try Some (EzFile.read_file file) with _exn -> None )
