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

(*
TODO: it's not clear how to correctly format dune files so that
they will not trigger a promotion with 'dune build @fmt'. The use
of sexplib0 does not immediately generate files in the correct format.
'dune' does not export a module for that in its library either.
We end up adding '(formatting (enabled_for ocaml reason))' to dune-project
to completely disable formatting of dune files.
*)

let package_dune_files package =
  let b = Buffer.create 1000 in
  let p_generators =
    match package.p_generators with
    | None -> [ "ocamllex" ; "ocamlyacc" ]
    | Some generators -> generators
  in
  ( match Sys.readdir package.dir with
  | exception _ -> ()
  | files ->
    Array.iter
      (fun file ->
        if Filename.check_suffix file ".mll" then begin
          if
            List.mem "ocamllex" p_generators
          then
            Printf.bprintf b "(ocamllex %s)\n"
              (Filename.chop_suffix file ".mll")
        end else if Filename.check_suffix file ".mly" then
          if List.mem "ocamlyacc" p_generators then
            Printf.bprintf b "(ocamlyacc %s)\n"
              (Filename.chop_suffix file ".mly")
          else if List.mem "menhir" p_generators then
            Printf.bprintf b "(menhir (modules %s))\n"
              (Filename.chop_suffix file ".mly")
          else
            Printf.eprintf "no generator for %s\n%!" file)
      files );
  begin
    match package.p_gen_version with
    | None -> ()
    | Some file ->
        Buffer.add_string b @@
        GenVersion.dune package file
  end;
  Buffer.contents b

let packages p =
  let b = Buffer.create 100000 in
  let add_package package =
    Printf.bprintf b {|
(package
 (name %s)
 (synopsis %S)
 (description %S)
|}
      package.name (Misc.p_synopsis package)
      (Misc.p_description package);

    Printf.bprintf b " (depends\n";
    Printf.bprintf b "   (ocaml (>= %s))\n" package.project.min_edition;
    let depend_of_dep name d =
      match d.depversions with
      | [] -> Printf.bprintf b "   %s\n" name
      | _ ->
        Printf.bprintf b "   (%s " name;
        let rec iter versions =
          match versions with
          | [] -> ()
          | [ version ] -> (
            match version with
            | Version -> Printf.bprintf b "(= version)"
            | NoVersion -> ()
            | Semantic (major, minor, fix) ->
              Printf.bprintf b "(and (>= %d.%d.%d) (< %d.0.0))" major minor fix
                (major + 1)
            | Lt version -> Printf.bprintf b "( < %s )" version
            | Le version -> Printf.bprintf b "( <= %s )" version
            | Eq version -> Printf.bprintf b "( = %s )" version
            | Ge version -> Printf.bprintf b "( >= %s )" version
            | Gt version -> Printf.bprintf b "( > %s )" version )
          | version :: tail ->
            Printf.bprintf b "(and ";
            iter [ version ];
            iter tail;
            Printf.bprintf b ")"
        in
        iter d.depversions;
        Printf.bprintf b ")\n"
    in
    List.iter
      (fun (name, d) -> depend_of_dep name d)
      (Misc.p_dependencies package);
    List.iter (fun (name, d) -> depend_of_dep name d) (Misc.p_tools package);
    Printf.bprintf b " ))\n"
  in

  List.iter add_package p.packages;
  Buffer.contents b
