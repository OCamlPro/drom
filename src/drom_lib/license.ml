(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzCompat
open Types
open Ez_file.V1
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

let load_licenses_dir dir =
  let map = StringMap.empty in
  if Sys.file_exists dir then (
    let map = ref map in
    EzFile.make_select EzFile.iter_dir ~deep:true dir ~kinds:[ S_REG; S_LNK ]
      ~f:(fun path ->
        if Filename.check_suffix path ".toml" then
          let file = dir // path in
          match EzToml.from_file file with
          | `Error _ ->
            Printf.eprintf "Warning: could not read file %s\n%!" file
          | `Ok table ->
            let license_key = EzToml.get_string table [ "license"; "key" ] in
            let license_name = EzToml.get_string table [ "license"; "name" ] in
            let license_header =
              EzToml.get_string table [ "license"; "header" ]
            in
            let license_header = EzString.split license_header '\n' in
            let license_contents =
              EzToml.get_string table [ "license"; "contents" ]
            in
            let license =
              { license_name; license_key; license_header; license_contents }
            in
            map := StringMap.add license_key license !map );
    !map
  ) else
    map

let licenses share =
  match share.share_licenses with
  | None ->
    let dir = share.share_dir in
    let global_licenses_dir = dir // "licenses" in
    let licenses = load_licenses_dir global_licenses_dir in
    share.share_licenses <- Some licenses;
    licenses
  | Some licenses -> licenses

let known_licenses share =
  let licenses = licenses share in
  let b = Buffer.create 100 in
  Printf.bprintf b "Licenses known by drom:\n";
  StringMap.iter
    (fun key m -> Printf.bprintf b "* %s -> %s\n" key m.license_name)
    licenses;
  Buffer.contents b

let name share p =
  let license = p.license in
  try
    let m = StringMap.find license (licenses share) in
    m.license_name
  with
  | Not_found ->
    let maybe_file = Globals.config_dir // "licenses" // license // "NAME" in
    if Sys.file_exists maybe_file then
      String.trim (EzFile.read_file maybe_file)
    else
      license

let c_sep = ("/*", '*', "*/")

let ml_sep = ("(*", '*', "*)")

let header share ?(sep = ml_sep) p =
  let boc, sec, eoc = sep in
  let boc_len = String.length boc in
  assert (boc_len = 2);
  let eoc_len = String.length eoc in
  assert (eoc_len = 2);

  let lines =
    let license = p.license in
    try
      let m = StringMap.find license (licenses share) in
      m.license_header
    with
    | Not_found ->
      let maybe_file =
        Globals.config_dir // "licences" // license // "HEADER"
      in
      if Sys.file_exists maybe_file then
        List.map String.trim (EzFile.read_lines maybe_file |> Array.to_list)
      else
        [ "This file is distributed under the terms of the";
          Printf.sprintf "%s license." license
        ]
  in
  let starline = Printf.sprintf "%s%s%s" boc (String.make 72 sec) eoc in
  let line s = Printf.sprintf "%s  %-70s%s" boc s eoc in
  String.concat "\n"
    ( [ starline; line "" ]
    @ ( match p.copyright with
      | None -> []
      | Some copyright ->
        let current_year = (Misc.date ()).Unix.tm_year in
        let years =
          if current_year = p.year then
            string_of_int current_year
          else
            Printf.sprintf "%d-%d" p.year current_year
        in
        [ Printf.ksprintf line "Copyright (c) %s %s" years copyright; line "" ]
      )
    @ [ line "All rights reserved." ]
    @ List.map line lines
    @ [ line ""; starline; "" ] )

let header_ml share p = header share p

let header_mll share p = header share p

let header_mly share p = header ~sep:c_sep share p

let header_c share p = header ~sep:c_sep share p

let license share p =
  let key = p.license in
  try
    let m = StringMap.find key (licenses share) in
    m.license_contents
  with
  | Not_found ->
    let maybe_file = Globals.config_dir // "licenses" // key // "LICENSE.md" in
    if Sys.file_exists maybe_file then
      EzFile.read_file maybe_file
    else begin
      Printf.eprintf
        "Warning: unknown license %S. You can fix this problem by either:\n" key;
      Printf.eprintf
        "* Choosing one of the known licenses in '_drom/known-licences.txt'\n";
      Printf.eprintf "* Adding 'licence' to the 'skip' field in 'drom.toml'\n%!";
      Printf.eprintf "* Adding a file %s and NAME\n%!" maybe_file;
      Printf.sprintf "This software is distributed under license %S.\n%!" key
    end
