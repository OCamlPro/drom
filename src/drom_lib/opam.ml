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
open Ez_opam_file.V1
open Types
open Ez_file.V1
open EzFile.OP

module OpamParser = struct
  module FullPos = struct
    let value_from_string s f =
      try OpamParser.FullPos.value_from_string s f with
      | exn ->
        Printf.eprintf "Error with [%s]:\n" s;
        raise exn
  end
end

let dev_repo p =
  match Misc.dev_repo p with
  | Some s -> Some (Printf.sprintf "git+%s.git" s)
  | None -> None

let opam_of_package ?cross kind share package =
  let p = package.project in
  let open OpamParserTypes.FullPos in
  let filename = "opam" in
  let pos = { filename; start = (0, 0); stop = (0, 0) } in
  let elem pelem = { pelem; pos } in
  let string s = elem (String s) in
  let list v = elem (List (elem v)) in
  let var s v = elem (Variable (elem s, v)) in
  let var_string s v = var s (string v) in
  let var_list s v = var s (list v) in
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

  let pin_depends = ref [] in

  let build_commands =
    match (kind, package.kind) with
    | Deps, _
    | _, Virtual ->
        []
    | _ ->
        [ var "build"
            (OpamParser.FullPos.value_from_string
               (Printf.sprintf "%s%s%s%s"
                  (Printf.sprintf {|
[
  ["dune" "subst"] {dev}
  ["sh" "-c" "./scripts/before.sh build '%%{name}%%'" ]
  ["dune" "build" "-p" %s "-j" jobs "@install"
|}
                     (match cross with
                      | None -> "name"
                      | Some cross ->
                          Printf.sprintf "\"%s\" \"-x\" \"%s\"" package.name cross
                     ))
                  ( if
                    match StringMap.find "no-opam-test" package.p_fields with
                    | exception Not_found -> false
                    | "false"
                    | "no" ->
                        false
                    | _ -> true
                    then
                      ""
                    else
                      {|"@runtest" {with-test}|} )
                  ( if
                    match StringMap.find "no-opam-doc" package.p_fields with
                    | exception Not_found -> false
                    | "false"
                    | "no" ->
                        false
                    | _ -> true
                    then
                      ""
                    else
                      {|"@doc" {with-doc}|} )
                  {|
  ]
  ["sh" "-c" "./scripts/after.sh build '%{name}%'" ]
]
|} )
               filename );
          var "install"
            (OpamParser.FullPos.value_from_string
               {|
[
  ["sh" "-c" "./scripts/before.sh install '%{name}%'" ]
]
|}
               filename )
        ]
  in
  let depend_of_dep (name, d, is_library) =
    let b = Buffer.create 100 in
    Printf.bprintf b {| "%s" { |}
      (if is_library then
         match cross with
         | None -> name
         | Some cross ->  name ^ "-" ^ cross
       else name);
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
         | Gt version -> Printf.bprintf b {| > "%s" |} version )
      d.depversions;
    if d.deptest then Printf.bprintf b " with-test ";
    if d.depdoc then Printf.bprintf b " with-doc ";
    Printf.bprintf b "}\n";
    (*  Printf.eprintf "parse: %s\n%!" s; *)

    begin match d.dep_pin, d.depversions with
      | None, _ -> ()
      | Some url, [ Eq v ] ->
          pin_depends := (name, Some v, url) :: !pin_depends ;
      | Some url, _ ->
          pin_depends := (name, None, url) :: !pin_depends ;
    end;
    OpamParser.FullPos.value_from_string (Buffer.contents b) filename
  in
  let depends =
    match kind with
    | ProgramPart ->
        [ var_list "depends"
            [ OpamParser.FullPos.value_from_string
                (Printf.sprintf
                   {|
                                "%s" { = version }
|}
                   (Misc.package_lib package) )
                filename
            ]
        ]
    | Single
    | LibraryPart
    | Deps -> (
        let initial_deps =
          match package.kind with
          | Virtual -> begin
              match StringMap.find "gen-opam" package.p_fields with
              | exception _ -> []
              | s ->
                  match String.lowercase s with
                  | "all" ->
                      List.map
                        (fun pp ->
                           OpamParser.FullPos.value_from_string
                             ( if package.p_version = pp.p_version then
                                 Printf.sprintf {| "%s" { = version } |} pp.name
                               else
                                 Printf.sprintf {| "%s" { = %S } |} pp.name
                                   (Misc.p_version pp) )
                             filename )
                        (List.filter (fun pp -> package != pp) p.packages)
                  | "some" -> []
                  | _ -> []
            end
          | _ ->
              [ OpamParser.FullPos.value_from_string
                  (Printf.sprintf {| "ocaml" { >= "%s" } |} p.min_edition)
                  filename;
                OpamParser.FullPos.value_from_string
                  (Printf.sprintf {| "dune" { >= "%s" } |}
                     (* We insert here the infimum version computed internally instead of copying
                        the user given specification, if any. This is not a problem since the infimum
                        meets the given criterias by definition. It also helps opam by giving him
                        less constraints so it can be seen as optimization. *)
                     package.project.dune_version )
                  filename
              ]
        in
        let alldeps =
          ( List.map (fun (n,d) -> (n,d,true)) @@ Misc.p_dependencies package )
          @
          ( List.map (fun (n,d) -> (n,d,false)) @@ Misc.p_tools package ) in
        let depends, depopts =
          List.partition (fun (_, d,_) -> not d.depopt) alldeps
        in
        let depends = List.map depend_of_dep depends in
        let depopts = List.map depend_of_dep depopts in
        [ var_list "depends" (initial_deps @ depends) ]
        @
        match depopts with
        | [] -> []
        | _ -> [ var_list "depopts" depopts ] )
  in
  let pin_depends = match !pin_depends with
    | [] -> []
    | pin_depends ->
        [ var_list "pin-depends"
            (List.map (fun (name, version, url) ->
                 list [
                   string (match version with
                       | None -> name
                       | Some version ->
                           Printf.sprintf "%s.%s" name version) ;
                   string url ;
                 ]
               ) pin_depends)]
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
      var_string "license" (License.name share p);
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
    @ List.rev !optionals
    @ build_commands
    @ depends
    @ pin_depends
  in
  let f = { file_contents; file_name = filename } in
  let s = OpamPrinter.FullPos.opamfile f in
  String.concat "\n"
    ( [ "# This file was generated by `drom` from `drom.toml`.";
        "# Do not modify, or add to the `skip` field of `drom.toml`.";
        s
      ]
      @
      let s = Subst.package_paren
          (Subst.state "" share package) "opam-trailer" in
      let s =
        if s = "" then
          []
        else
          [ s ]
      in
      match p.project_share_repo with
      | None -> s (* compatibility with 0.8.0 *)
      | Some _ ->
          "# Content of `opam-trailer` field:" :: s
    )

let call ?exec ?stdout ?(y = false) cmd args =
  Call.call ?exec ?stdout
    ( [ "opam" ; "--cli=2.1" ] @ cmd
      @ ( if y then
            [ "-y" ]
          else
            [] )
      @ args )

let init ?y ?switch ?edition () =
  let opam_root = Globals.opam_root () in

  if not (Sys.file_exists opam_root) then
    let args =
      match switch with
      | None -> [ "--bare" ]
      | Some switch -> [ "--comp"; switch ]
    in
    call ?y [ "init" ] args
  else
    match switch with
    | None -> ()
    | Some switch ->
      if Filename.is_relative switch then
        if not (Sys.file_exists (opam_root // switch)) then
          call ?y [ "switch"; "create" ]
            ( match edition with
            | None -> [ switch ]
            | Some edition -> [ switch; edition ] )

let run ?y ?error ?switch ?edition cmd args =
  init ?y ?switch ?edition ();
  match error with
  | None -> call ?y cmd args
  | Some error -> (
    try call ?y cmd args with
    | exn -> error := Some exn )

let exec ?exec ?stdout args =
  call ?exec ?stdout [ "exec" ] ( "--" :: args )
