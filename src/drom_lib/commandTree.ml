(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.TYPES
open Types

let cmd_name = "tree"

let string_of_version = function
  | Version -> "version"
  | Semantic (major, minor, fix) -> Printf.sprintf "%d.%d.%d" major minor fix
  | Lt version -> Printf.sprintf "< %s" version
  | Le version -> Printf.sprintf "<= %s" version
  | Eq version -> Printf.sprintf "= %s" version
  | Ge version -> Printf.sprintf ">= %s" version
  | Gt version -> Printf.sprintf "> %s" version
  | NoVersion -> ""

let action () =
  let p, _ = Project.get () in

  let h = Hashtbl.create 97 in
  List.iter
    (fun package -> Hashtbl.add h package.name (package, ref 0, ref false))
    p.packages;
  let add_dep (name, d) =
    try
      match d.depversions with
      | []
      | [ Version ] ->
        let _, counter, _ = Hashtbl.find h name in
        incr counter
      | _ -> ()
    with Not_found -> ()
  in
  List.iter
    (fun package ->
      List.iter add_dep package.p_dependencies;
      List.iter add_dep package.p_tools)
    p.packages;

  let rec tree_of_dep kind (name, d) =
    try
      match d.depversions with
      | []
      | [ Version ] ->
        let package, counter, printed = Hashtbl.find h name in
        if (not !printed) && !counter = 1 then (
          printed := true;
          tree_of_package package
        ) else
          raise Not_found
      | _ -> raise Not_found
    with Not_found ->
      let dep_descr =
        Printf.sprintf "%s%s %s" name kind
          (String.concat " " (List.map string_of_version d.depversions))
      in
      EzPrintTree.Branch (dep_descr, [])
  and tree_of_package package =
    let package_descr = Printf.sprintf "%s (/%s)" package.name package.dir in
    EzPrintTree.Branch
      ( package_descr,
        List.map (tree_of_dep "") package.p_dependencies
        @ List.map (tree_of_dep "(tool)") package.p_tools )
  in

  let print indent p =
    let _package, counter, printed = Hashtbl.find h p.name in
    if (not !printed) && !counter <> 1 then (
      printed := true;
      EzPrintTree.print_tree indent (tree_of_package p)
    )
  in
  print "" p.package;
  List.iter
    (fun package -> if package != p.package then print "" package)
    p.packages;
  let print_deps indent kind list =
    match list with
    | [] -> ()
    | _ ->
      Printf.printf "%s[%s]\n" indent kind;
      let indent = indent ^ "\226\148\148\226\148\128\226\148\128" in
      List.iter
        (fun (name, d) ->
          Printf.printf "%s %s %s\n" indent name
            (String.concat " " (List.map string_of_version d.depversions)))
        list
  in
  print_deps "" "dependencies" p.dependencies;
  print_deps "" "tools" p.tools;
  ()

let cmd =
  { cmd_name;
    cmd_action = (fun () -> action ());
    cmd_args = [];
    cmd_man = [];
    cmd_doc = "Display a tree of dependencies"
  }
