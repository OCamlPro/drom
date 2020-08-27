(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Types

let dev_repo p =
  match p.dev_repo with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "git+https://github.com/%s/%s.git"
               organization p.package.name )
    | None -> None

let opam_of_project kind package =
  let p = package.project in
  let open OpamParserTypes in
  let file_name = "opam" in
  let pos = file_name, 0,0 in
  let string s = String (pos, s) in
  let list v = List (pos, v) in
  let var_string s v = Variable (pos, s, string v) in
  let var_list s v = Variable (pos, s, list v) in
  let optionals = ref [] in
  let add_optional_string s = function
    | None -> ()
    | Some v -> optionals := ( var_string s v ) :: !optionals
  in
  add_optional_string "homepage" ( Misc.homepage p );
  add_optional_string "doc" ( Misc.doc_gen p );
  add_optional_string "bug-reports" ( Misc.bug_reports p );
  add_optional_string "dev-repo" (dev_repo p );
  add_optional_string "tags" (match p.github_organization with
      | None -> None
      | Some github_organization ->
        Some ( Printf.sprintf "org:%s" github_organization) );
  let file_contents = [
    var_string "opam-version" "2.0";
    var_string "name" ( match kind with
        | LibraryPart -> package.name ^ "_lib"
        | Single | ProgramPart -> package.name ) ;
    var_string "version" ( Misc.p_version package ) ;
    var_string "license" ( License.name p ) ;
    var_string "synopsis" ( match kind with
        | LibraryPart -> Misc.p_synopsis package ^ " (library)"
        | Single | ProgramPart -> Misc.p_synopsis package );
    var_string "description" (Misc.p_description package ) ;
    var_list "authors" ( List.map string ( Misc.p_authors package ) ) ;
    var_list "maintainer" ( List.map string p.authors ) ;
  ] @ List.rev !optionals @
    [
      Variable (pos, "build",
                OpamParser.value_from_string
                  {|
[
  ["dune" "subst"] {pinned}
  ["dune" "build" "-p" name "-j" jobs "@install"
     "@runtest" {with-test}
    "@doc" {with-doc}
  ]
]
|} file_name);
      Variable (pos, "depends",
                match kind with
                | ProgramPart ->
                  List (pos,
                        [
                          OpamParser.value_from_string
                            ( Printf.sprintf {|
                                "%s_lib" { = version }
|} package.name ) file_name
                        ]
                       )
                | Single | LibraryPart ->
                  List (pos,
                        OpamParser.value_from_string
                          ( Printf.sprintf {| "ocaml" { >= "%s" } |}
                              p.min_edition
                          )
                          file_name
                        ::
                        List.map (fun (name, d) ->
                              OpamParser.value_from_string (
                                match Misc.semantic_version d.depversion with
                                | Some (major, minor, fix) ->
                                  Printf.sprintf
                                    {| "%s" { >= "%d.%d.%d" & < "%d.0.0" }|}
                                    name major minor fix (major+1)
                                | None ->
                                  Printf.sprintf
                                    {| "%s" {>= "%s" } |} name d.depversion
                              )
                                file_name
                          )
                          ( Misc.p_dependencies package )
                        @
                        List.map (fun (name, version) ->
                            OpamParser.value_from_string (
                              match Misc.semantic_version version with
                              | Some (major, minor, fix) ->
                                Printf.sprintf
                                  {| "%s" { >= "%d.%d.%d" & < "%d.0.0" }|}
                                  name major minor fix (major+1)
                              | None ->
                                Printf.sprintf
                                  {| "%s" {>= "%s" } |} name version
                            )
                              file_name
                          )
                          ( Misc.p_tools package ) )
               )
    ]
  in
  let f =
    {
      file_contents ;
      file_name
    }
  in
  let s = OpamPrinter.opamfile f in
  Printf.sprintf
    {|# This file was generated by `drom` from `drom.toml`.
# Do not modify or add to the `skip` field of `drom.toml`.
%s|}
    s
