(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let file package _file =
  Printf.sprintf
    {|#!/usr/bin/env ocaml
;;
#load "unix.cma"

let query cmd =
  let chan = Unix.open_process_in cmd in
  try
    let out = input_line chan in
     if Unix.close_process_in chan = Unix.WEXITED 0 then
       Some out
     else None
   with End_of_file -> None

let commit_hash = query "git show -s --pretty=format:%%H"
let commit_date = query "git show -s --pretty=format:%%ci"
let version = %S

let string_option = function
  | None -> "None"
  | Some s -> Printf.sprintf "Some %%S" s

let () =
  Format.printf "@[<v>";
  Format.printf "let version = %%S@," version;
  Format.printf
    "let commit_hash = %%s@," (string_option commit_hash);
  Format.printf
    "let commit_date = %%s@," (string_option commit_date);
  Format.printf "@]@.";
  ()
|}
    (Misc.p_version package)

let dune _package file =
  Printf.sprintf
    {|
(rule
    (targets %s)
    (deps (:script %st) package.toml)
    (action (with-stdout-to %%{targets} (run %%{ocaml} unix.cma %%{script}))))
|}
    file file
