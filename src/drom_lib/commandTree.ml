(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.V2
open Types

open EzPrintTree.TYPES

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
    with
    | Not_found -> ()
  in
  List.iter
    (fun package ->
      List.iter add_dep package.p_dependencies;
      List.iter add_dep package.p_tools )
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
    with
    | Not_found ->
      let dep_descr =
        Printf.sprintf "%s%s %s" name kind
          (String.concat " " (List.map string_of_version d.depversions))
      in
      Branch (dep_descr, [])
  and tree_of_package package =
    let package_descr =
      Printf.sprintf "%s %s (/%s)"
        (Misc.string_of_kind package.kind)
        package.name package.dir
    in
    Branch
      ( package_descr,
        List.map (tree_of_dep "") package.p_dependencies
        @ List.map (tree_of_dep "(tool)") package.p_tools )
  in

  let branches = ref [] in
  let print p =
    let _package, counter, printed = Hashtbl.find h p.name in
    if (not !printed) && !counter <> 1 then (
      printed := true;
      branches := tree_of_package p :: !branches
    )
  in
  print p.package;
  List.iter
    (fun package -> if package != p.package then print package)
    p.packages;
  let print_deps kind list =
    branches :=
      Branch
        ( Printf.sprintf "[%s]" kind,
          List.map
            (fun (name, d) ->
              Branch
                ( Printf.sprintf "%s %s" name
                    (String.concat " "
                       (List.map string_of_version d.depversions) ),
                  [] ) )
            list )
      :: !branches
  in
  print_deps "dependencies" p.dependencies;
  print_deps "tools" p.tools;
  EzPrintTree.print_tree (Branch ("File drom.toml", List.rev !branches));
  ()

let cmd =
  EZCMD.sub cmd_name action ~doc:"Display a tree of dependencies"
    ~man:
      [ `S "DESCRIPTION";
        `Blocks
          [ `P
              "Print the project as a tree of dependencies, i.e. dependencies \
               are printed as branches of the package they are dependencies \
               of. If a package is itself a dependency of another package, it \
               will be printed there."
          ];
        `S "EXAMPLE";
        `Pre
          {|
└──drom (/src/drom)
   └──drom_lib (/src/drom_lib)
      └──toml 5.0.0
      └──opam-file-format 2.1.1
      └──ez_subst >= 0.1
      └──ez_file 0.2.0
      └──ez_config 0.1.0
      └──ez_cmdliner 0.2.0
      └──directories >= 0.2
[tools]
└── ppx_inline_test
└── ppx_expect
└── odoc
└── ocamlformat
|}
      ]
