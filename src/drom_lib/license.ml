(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzCompat
open Types
open EzFile.OP

(* Most used licenses in the opam repository:
    117 license: "GPL-3.0-only"
    122 license: "LGPL-2.1"
    122 license: "LGPL-2.1-only"
    130 license:      "MIT"
    180 license: "BSD-2-Clause"
    199 license: "LGPL-2.1-or-later with OCaml-LGPL-linking-exception"
    241 license: "LGPL-3.0-only with OCaml-LGPL-linking-exception"
    418 license: "LGPL-2.1-only with OCaml-LGPL-linking-exception"
    625 license:      "ISC"
    860 license: "BSD-3-Clause"
   1228 license: "Apache-2.0"
   1555 license: "ISC"
   2785 license: "MIT"
*)

let licenses = StringMap.of_list Skel_licenses.licenses

let known_licenses () =
  let b = Buffer.create 100 in
  Printf.bprintf b "Licenses known by drom:\n";
  StringMap.iter
    (fun name m ->
      let module M = (val m : LICENSE) in
      Printf.bprintf b "* %s -> %s\n" name M.name)
    licenses;
  Buffer.contents b

let name p =
  let license = p.license in
  try
    let m = StringMap.find license licenses in
    let module M : LICENSE = (val m : LICENSE) in
    M.name
  with Not_found ->
    let maybe_file = Globals.config_dir // "licenses" // license // "NAME" in
    if Sys.file_exists maybe_file then
      String.trim (EzFile.read_file maybe_file)
    else
      license

let c_sep = ("/*", '*', "*/")

let ml_sep = ("(*", '*', "*)")

let header ?(sep = ml_sep) p =
  let boc, sec, eoc = sep in
  let boc_len = String.length boc in
  assert (boc_len = 2);
  let eoc_len = String.length eoc in
  assert (eoc_len = 2);

  let lines =
    let license = p.license in
    try
      let m = StringMap.find license licenses in
      let module M : LICENSE = (val m : LICENSE) in
      M.header
    with Not_found ->
      let maybe_file = Globals.config_dir // "licences" // license // "HEADER" in
      if Sys.file_exists maybe_file then
        List.map String.trim (EzFile.read_lines maybe_file |> Array.to_list)
      else
        ["This file is distributed under the terms of the"; Printf.sprintf "%s license." license]
  in
  let starline = Printf.sprintf "%s%s%s" boc (String.make 72 sec) eoc in
  let line s = Printf.sprintf "%s  %-70s%s" boc s eoc in
  String.concat "\n"
    ( [ starline; line "" ]
    @ ( match p.copyright with
      | None -> []
      | Some copyright ->
        [ Printf.kprintf line "Copyright (c) %d %s" (Misc.date ()).Unix.tm_year
            copyright;
          line ""
        ] )
    @ [ line "All rights reserved." ]
    @ List.map line lines @ [ line ""; starline; "" ] )

let header_ml p = header p

let header_mll p = header p

let header_mly p = header ~sep:c_sep p

let license p =
  let key = p.license in
  try
    let m = StringMap.find key licenses in
    let module M = (val m : LICENSE) in
    M.license
  with Not_found ->
    let maybe_file = Globals.config_dir // "licenses" // key // "LICENSE.md" in
    if Sys.file_exists maybe_file then
      EzFile.read_file maybe_file
    else begin
      Printf.eprintf "Warning: unknown license %S. You can fix this problem by either:\n" key;
      Printf.eprintf "* Choosing one of the known licenses in '_drom/known-licences.txt'\n";
      Printf.eprintf "* Adding 'licence' to the 'skip' field in 'drom.toml'\n%!";
      Printf.eprintf "* Adding a file %s and NAME\n%!" maybe_file;
      Printf.sprintf "This software is distributed under license %S.\n%!" key
    end
