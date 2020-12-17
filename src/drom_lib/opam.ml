(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ez_opam_file.V1
open Types
open EzFile.OP

module OpamParser = struct
  module FullPos = struct
    let value_from_string s f =
      try OpamParser.FullPos.value_from_string s f
      with exn ->
        Printf.eprintf "Error with [%s]:\n" s;
        raise exn
  end
end

let dev_repo p =
  match Misc.dev_repo p with
  | Some s -> Some (Printf.sprintf "git+%s.git" s)
  | None -> None

let opam_of_project kind package =
  let p = package.project in
  let open OpamParserTypes.FullPos in
  let filename = "opam" in
  let pos = { filename ; start = 0,0 ; stop = 0, 0 } in
  let elem pelem = { pelem ; pos } in
  let string s = elem ( String s ) in
  let list v = elem ( List ( elem v ))  in
  let var s v = elem ( Variable ( elem s, v)) in
  let var_string s v = var s ( string v ) in
  let var_list s v = var s ( list v ) in
  let optionals = ref [] in
  let add_optional_string s = function
    | None -> ()
    | Some v -> optionals := var_string s v :: !optionals
  in
  add_optional_string "homepage" (Misc.homepage p);
  add_optional_string "doc" (Misc.doc_gen p);
  add_optional_string "bug-reports" (Misc.bug_reports p);
  add_optional_string "dev-repo" (dev_repo p);
  add_optional_string "tags"
    ( match p.github_organization with
      | None -> None
      | Some github_organization ->
          Some (Printf.sprintf "org:%s" github_organization) );

  let build_commands =
    match kind, package.kind with
    | Deps, _
    | _, Virtual -> []
    | _ ->
        [
          var "build"
            (
              OpamParser.FullPos.value_from_string
                {|
[
  ["dune" "subst"] {dev}
  ["sh" "-c" "./scripts/before.sh" "build" name]
  ["dune" "build" "-p" name "-j" jobs "@install"
     "@runtest" {with-test} "@doc" {with-doc}
  ]
  ["sh" "-c" "./scripts/after.sh" "build" name]
]
|}
                filename );
          var "install"
            (
              OpamParser.FullPos.value_from_string
                {|
[
  ["sh" "-c" "./scripts/before.sh" "install" name]
]
|} filename
            );
        ]
  in
  let depend_of_dep name d =
    let b = Buffer.create 100 in
    Printf.bprintf b {| "%s" { |} name;
    List.iteri
      (fun i version ->
         if i > 0 then Printf.bprintf b "& ";
         match version with
         | Version -> Printf.bprintf b "= version"
         | NoVersion -> ()
         | Semantic (major, minor, fix) ->
             Printf.bprintf b {|>= "%d.%d.%d" & < "%d.0.0" |} major minor fix
               (major + 1)
         | Lt version -> Printf.bprintf b {| < "%s" |} version
         | Le version -> Printf.bprintf b {| <= "%s" |} version
         | Eq version -> Printf.bprintf b {| = "%s" |} version
         | Ge version -> Printf.bprintf b {| >= "%s" |} version
         | Gt version -> Printf.bprintf b {| > "%s" |} version)
      d.depversions;
    if d.deptest then Printf.bprintf b " with-test ";
    if d.depdoc then Printf.bprintf b " with-doc ";
    Printf.bprintf b "}\n";
    (*  Printf.eprintf "parse: %s\n%!" s; *)
    OpamParser.FullPos.value_from_string (Buffer.contents b) filename
  in
  let depends =
    [ var "depends" (
          match kind with
          | ProgramPart ->
              list
                [ OpamParser.FullPos.value_from_string
                    (Printf.sprintf
                       {|
                                "%s" { = version }
|}
                       (Misc.package_lib package))
                    filename
                ]
          | Single
          | LibraryPart
          | Deps ->
              list
                ( OpamParser.FullPos.value_from_string
                    (Printf.sprintf {| "ocaml" { >= "%s" } |} p.min_edition)
                    filename
                  :: OpamParser.FullPos.value_from_string
                    (Printf.sprintf {| "dune" { >= "%s" } |}
                       Globals.current_dune_version)
                    filename
                  :: List.map
                    (fun (name, d) -> depend_of_dep name d)
                    (Misc.p_dependencies package)
                  @ List.map
                    (fun (name, d) -> depend_of_dep name d)
                    (Misc.p_tools package) ) )
    ]
  in
  let file_contents =
    [ var_string "opam-version" "2.0";
      var_string "name"
        ( match kind with
          | LibraryPart -> Misc.package_lib package
          | Single
          | ProgramPart ->
              package.name
          | Deps -> package.name );
      var_string "version" (Misc.p_version package);
      var_string "license" (License.name p);
      var_string "synopsis"
        ( match kind with
          | LibraryPart -> Misc.p_synopsis package ^ " (library)"
          | Deps -> Misc.p_synopsis package
          | Single
          | ProgramPart ->
              Misc.p_synopsis package );
      var_string "description" (Misc.p_description package);
      var_list "authors" (List.map string (Misc.p_authors package));
      var_list "maintainer" (List.map string p.authors)
    ]
    @ List.rev !optionals @ build_commands @ depends
  in
  let f = { file_contents; file_name = filename } in
  let s = OpamPrinter.FullPos.opamfile f in
  String.concat "\n"
    ( [ "# This file was generated by `drom` from `drom.toml`.";
        "# Do not modify, or add to the `skip` field of `drom.toml`.";
        s
      ]
      @
      let s = Subst.package_paren ("", package) "opam-trailer" in
      if s = "" then
        []
      else
        [ s ] )

let () = Unix.putenv "OPAMCLI" "2.0"

let exec ?(y = false) cmd args =
  Misc.call
    (Array.of_list
       ( [ "opam" ] @ cmd
       @ ( if y then
           [ "-y" ]
         else
           [] )
       @ args ))

let init ?y ?switch ?edition () =
  let opam_root = Globals.opam_root () in

  if not (Sys.file_exists opam_root) then
    let args =
      match switch with
      | None -> [ "--bare" ]
      | Some switch -> [ "--comp"; switch ]
    in
    exec ?y [ "init" ] args
  else
    match switch with
    | None -> ()
    | Some switch ->
      if Filename.is_relative switch then
        if not (Sys.file_exists (opam_root // switch)) then
          exec ?y [ "switch"; "create" ]
            ( match edition with
            | None -> [ switch ]
            | Some edition -> [ switch; edition ] )

let run ?y ?error ?switch ?edition cmd args =
  init ?y ?switch ?edition ();
  match error with
  | None -> exec ?y cmd args
  | Some error -> ( try exec ?y cmd args with exn -> error := Some exn )
