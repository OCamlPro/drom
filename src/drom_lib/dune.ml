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
    | None -> StringSet.of_list [ "ocamllex"; "ocamlyacc" ]
    | Some generators ->
        begin match package.p_menhir with
          | Some { parser; tokens = menhir_tokens; _ }
            when StringSet.mem "menhir" generators ->
              let { modules; tokens; merge_into; flags; infer } = parser in
              Printf.bprintf b "(menhir\n  (modules";
              List.iter (fun module_ -> Printf.bprintf b " %s" module_) modules;
              Printf.bprintf b ")";
              begin match merge_into with
                | Some merge_into ->
                    Printf.bprintf b "\n  (merge_into %s)" merge_into
                | None ->
                    if List.length modules > 1 then
                      let merge_into = List.rev modules |> List.hd in
                      Printf.bprintf b "\n  (merge_into %s)" merge_into
              end;
              begin match flags with
                | Some flags ->
                    Printf.bprintf b "\n  (flags";
                    List.iter (fun flag -> Printf.bprintf b " %s" flag) flags;
                    begin match tokens with
                      | Some tokens -> Printf.bprintf b "--external-token %s" tokens
                      | None -> ()
                    end;
                    Printf.bprintf b ")";
                | None -> ()
              end;
              begin match infer with
                | Some infer -> Printf.bprintf b "\n  (infer %B)" infer
                | None -> ()
              end;
              Printf.bprintf b ")\n";
              begin match menhir_tokens with
                | Some { modules; flags; } ->
                    Printf.bprintf b "(menhir (modules";
                    List.iter (fun module_ -> Printf.bprintf b " %s" module_) modules;
                    Printf.bprintf b ")";
                    begin match flags with
                      | Some flags ->
                          Printf.bprintf b "\n  (flags";
                          List.iter (fun flag -> Printf.bprintf b " %s" flag) flags;
                          Printf.bprintf b " --only-tokens)";
                      | None -> ()
                    end;
                    Printf.bprintf b ")\n"
                | None -> ()
              end
          | Some _ ->
              Printf.eprintf "'menhir' table defined without menhir generator"
          | None -> ()
        end;
        generators
  in
  ( match Sys.readdir package.dir with
  | exception _ -> ()
  | files ->
    Array.iter
      (fun file ->
        if Filename.check_suffix file ".mll" then begin
          if StringSet.mem "ocamllex" p_generators then begin
            match StringMap.find "ocamllex-mode" package.p_fields with
            | exception Not_found ->
              Printf.bprintf b "(ocamllex %s)\n"
                (Filename.chop_suffix file ".mll")
            | mode ->
              Printf.bprintf b "(ocamllex (modules %s)"
                (Filename.chop_suffix file ".mll");
              Printf.bprintf b "\n  (mode %s)" mode;
              Printf.bprintf b ")\n"
          end
        end else if Filename.check_suffix file ".mly" then begin
          if StringSet.mem "ocamlyacc" p_generators then begin
            match StringMap.find "ocamlyacc-mode" package.p_fields with
            | exception Not_found ->
              Printf.bprintf b "(ocamlyacc %s)\n"
                (Filename.chop_suffix file ".mly")
            | mode ->
              Printf.bprintf b "(ocamlyacc (modules %s)"
                (Filename.chop_suffix file ".mly");
              Printf.bprintf b "\n  (mode %s)" mode;
              Printf.bprintf b ")\n"
          end else if StringSet.mem "menhir" p_generators then begin
            match package.p_menhir with
            | None ->
                Printf.bprintf b "(menhir (modules %s)"
                  (Filename.chop_suffix file ".mly");
                List.iter
                  (fun ext ->
                     match StringMap.find ("menhir-" ^ ext) package.p_fields with
                     | exception Not_found -> ()
                     | s -> Printf.bprintf b "\n  (%s %s)" ext s )
                  [ "flags"; "into"; "infer" ];
                Printf.bprintf b ")\n"
            | Some _ -> ()
          end else
            Printf.eprintf "no generator for %s\n%!" file
        end )
      files );
  begin
    match package.p_gen_version with
    | None -> ()
    | Some file -> Buffer.add_string b @@ GenVersion.dune package file
  end;
  if (
    VersionCompare.(package.project.project_drom_version >= "0.9.2") &&
    package.p_sites <> Sites.default
  ) then
    (* Sites dynamic loading is available only after 0.9.2 and if really
       needed *)
    begin
      let sites_content = Sites.to_dune
        ~package:package.name
        package.p_sites in
      Buffer.add_string b sites_content
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
 %s
|}
      package.name (Misc.p_synopsis package)
      (Misc.p_description package)
      (
        (* Sites declaration is available only from 0.9.2 *)
        if VersionCompare.(package.project.project_drom_version >= "0.9.2")
        then package.p_sites |> Sites.to_dune_project
        else ""
      )
      ;

    let depend_of_dep (name, d) =
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
    let depopts = ref [] in
    let maybe_print_dep (name, d) =
      if d.depopt then
        depopts := (name, d) :: !depopts
      else
        depend_of_dep (name, d)
    in
    Printf.bprintf b " (depends\n";
    Printf.bprintf b "   (ocaml (>= %s))\n" package.project.min_edition;
    List.iter maybe_print_dep (Misc.p_dependencies package);
    List.iter maybe_print_dep (Misc.p_tools package);
    Printf.bprintf b "  )";
    begin
      match !depopts with
      | [] -> ()
      | depopts ->
        Printf.bprintf b "\n (depopts\n";
        List.iter depend_of_dep depopts;
        Printf.bprintf b " )"
    end;
    begin
      match StringMap.find "dune-project-stanzas" package.p_fields with
      | exception _ -> ()
      | s -> Printf.bprintf b "\n %s" s
    end;
    Printf.bprintf b "\n )\n"
  in

  (* If menhir is used as a generator, prevents dune from modifying
     dune-project by adding this line ourselves. *)
  if StringSet.mem "menhir" p.generators then
    begin match p.menhir_version with
    | Some version ->
        Printf.bprintf b "(using menhir %s)\n" version
    | None -> Buffer.add_string b "(using menhir 2.0)\n"
    end;

  List.iter add_package p.packages;
  Buffer.contents b
