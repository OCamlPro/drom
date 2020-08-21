(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open DromTypes
open EzFile.OP

(*
`opam-new create project` will generate the tree:
* project/
    drom.toml
    .git/
    .gitignore
    dune-workspace
    dune-project     [do not edit]
    project.opam     [do not edit]
    src/
       dune          [do not edit]
       main.ml

drom.toml looks like:
```
[package]
authors = ["Fabrice Le Fessant <fabrice.le_fessant@origin-labs.com>"]
edition = "4.10.0"
library = false
name = "project"
version = "0.1.0"

[dependencies]

[tools]
dune = "2.6.0"
```

*)


let cmd_name = "new"

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

let ocaml_gitignore p =
  Printf.sprintf {|
/%s
*~
_build
.merlin
/_drom
/_opam
/_build
|} p.name

let ocaml_helloworld = {|

let () =
  Printf.printf "Hello world!\n%!"

|}

let ocaml_library = {|

let f () =
  Printf.printf "Hello world!\n%!"

|}

let application_dune =
  (
    {|

(executable
 (name main)
 (public_name %s)
 (libraries %s)
)

|}
    : ('a -> 'b -> 'c, unit, string) format  )

let makefile_template p =
  Printf.sprintf
  {|
all:
	dune build
	cp -f _build/default/src/main.exe %s

build-deps:
	opam install --deps-only ./opam

init:
	git submodule init
	git submodule update

doc: html
	markdown docs/index.md > docs/index.html

html:
	sphinx-build sphinx docs/doc

view:
	xdg-open file://$$(pwd)/docs/doc/index.html
|}
  p.name

let semantic_version version =
  match EzString.split version '.' with
    [ major ; minor ; fix ] ->
    begin try
        Some ( int_of_string major, int_of_string minor, int_of_string fix )
      with
        Not_found -> None
    end
  | _ -> None

let homepage p =
  match p.homepage with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "https://%s.github.com/%s" organization p.name )
    | None -> None

let documentation p =
  match p.documentation with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "https://%s.github.com/%s" organization p.name )
    | None -> None

let bug_reports p =
  match p.bug_reports with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "https://github.com/%s/%s/issues"
               organization p.name )
    | None -> None

let dev_repo p =
  match p.dev_repo with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "git+https://github.com/%s/%s.git"
               organization p.name )
    | None -> None

let opam_of_project p =
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
  add_optional_string "homepage" ( homepage p );
  add_optional_string "doc" ( documentation p );
  add_optional_string "license" p.license ;
  add_optional_string "bug-reports" ( bug_reports p );
  add_optional_string "dev-repo" (dev_repo p );

  let file_contents = [
    var_string "opam-version" "2.0";
    var_string "name" p.name ;
    var_string "version" p.version ;
    var_string "synopsis" p.synopsis ;
    var_string "description" p.description ;
    var_list "authors" ( List.map string p.authors ) ;
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
                List (pos,
                      OpamParser.value_from_string
                        ( Printf.sprintf {| "ocaml" { = "%s" } |}
                            p.edition
                        )
                        file_name
                      ::
                      List.map (fun (name, version) ->
                          OpamParser.value_from_string (
                            match semantic_version version with
                            | Some (major, minor, fix) ->
                              Printf.sprintf
                                {| "%s" { >= "%d.%d.%d" & < "%d.0.0" }|}
                                name major minor fix (major+1)
                            | None ->
                              Printf.sprintf
                                {| "%s" {= "%s" } |} name version
                          )
                            file_name
                        )
                        ( p.dependencies @ p.tools )
                     ))
    ]
  in
  let f =
    {
      file_contents ;
      file_name
    }
  in
  OpamPrinter.opamfile f

let update_files ~create ~build p =

  let to_add = ref [] in
  let write_file filename content =
    EzFile.write_file filename content ;
    to_add := filename :: !to_add
  in

  let config = Lazy.force DromConfig.config in
  EzFile.make_dir ~p:true "src";
  EzFile.make_dir ~p:true "_drom";

  let former_project = p in
  let p =
    match p.license, config.config_license with
    | None, Some s -> { p with license = Some s }
    | _ -> p
  in
  let p =
    match p.github_organization, config.config_github_organization with
    | None, Some s -> { p with github_organization = Some s }
    | _ -> p
  in
  let p =
    match p.authors, config.config_author with
    | [], Some s -> { p with authors = [ s ] }
    | _ -> p
  in

  let save_drom_toml =
    if p <> former_project then begin
      Printf.eprintf "Updating 'drom.toml' from config\n%!";
      true
    end else
    if not ( Sys.file_exists "drom.toml" ) then begin
      Printf.eprintf "Creating 'drom.toml'\n%!";
      true
    end
    else
      false
  in
  if save_drom_toml then
    write_file "drom.toml" ( DromToml.toml_of_project p ) ;

  if not ( Sys.file_exists ".gitignore" ) then
    write_file ".gitignore" ( ocaml_gitignore p ) ;

  if not ( Sys.file_exists "Makefile" ) then
    write_file "Makefile" ( makefile_template p ) ;

  if create then begin
    write_file "dune-workspace" "";
    write_file (p.name ^ ".opam") "";
    if p.library then begin
      write_file "src/lib.ml" ocaml_library ;
    end else begin
      write_file "src/main.ml" ocaml_helloworld ;
    end ;
    write_file "README.md"
      ( Printf.sprintf "# %s\n" p.name );
    if not ( Sys.file_exists ".git" ) then begin
      DromMisc.call [| "git"; "init" |];
      match config.config_github_organization with
      | None -> ()
      | Some organization ->
        DromMisc.call [| "git"; "remote" ; "add" ; "origin" ;
                            Printf.sprintf
                              "git@github.com:%s/%s"
                              organization
                              p.name |];
        DromMisc.call [| "git"; "add" ; "README.md" |];
        DromMisc.call [| "git"; "commit" ; "-m" ; "Initial commit" |];
    end
  end ;

  if not ( Sys.file_exists "docs" ) then begin
    EzFile.make_dir ~p:true "docs" ;
    write_file "docs/index.md"
      ( Printf.sprintf "# %s\n" p.name );
    write_file "docs/index.html"
      ( Printf.sprintf "<h1>%s</h1>" p.name );
    EzFile.make_dir ~p:true "docs/doc";
    write_file "docs/.nojekyll" "";
    write_file "docs/doc/index.html"
      ( Printf.sprintf "<h1>Sphinx doc for %s</h1>\n" p.name )
  end;

  if not ( Sys.file_exists "sphinx" ) then begin
    EzFile.make_dir ~p:true "sphinx" ;
    write_file "sphinx/conf.py" ( DromSphinx.conf_py p ) ;
    write_file "sphinx/index.rst" ( DromSphinx.index_rst p ) ;
    write_file "sphinx/usage.rst" ( DromSphinx.usage_rst p ) ;
    write_file "sphinx/about.rst" ( DromSphinx.about_rst p ) ;
    EzFile.make_dir ~p:true "sphinx/_static/css" ;
    write_file "sphinx/_static/css/fixes.css" "";
  end;



  let dune_project =
    let b = Buffer.create 100000 in
    Printf.bprintf b
      {|(lang dune 2.0)
; This file is maintained by drom, using drom.toml
(name %s)
(allow_approximate_merlin)
(generate_opam_files true)
|}
      p.name ;

    Printf.bprintf b {|
(package
 (name %s)
|}
      p.name ;
    Printf.bprintf b {|
 (synopsis %S)
|}
      p.synopsis ;
    Printf.bprintf b {|
 (description %S)
|} p.description ;
    Printf.bprintf b " (depends\n";
    Printf.bprintf b "   (ocaml (= %s))\n" p.edition ;
    List.iter (fun (name, version) ->
        match semantic_version version with
        | Some (major, minor, fix) ->
          Printf.bprintf b "   (%s (and (>= %d.%d.%d) (< %d.0.0)))\n"
            name major minor fix (major+1)
        | None ->
          Printf.bprintf b "   (%s (= %s))\n" name version
      ) ( p.dependencies @ p.tools );
    Printf.bprintf b " )\n";
    Printf.bprintf b ")\n";
    Buffer.contents b
  in
  write_file "dune-project" dune_project ;

  let s = Printf.sprintf application_dune
      p.name
      ( String.concat " " ( List.map fst p.dependencies ) )
  in
  write_file "src/dune" s ;

  write_file ".ocamlformat" "" ;

  if build then
    begin
      let opam_filename = "_drom/opam" in
      let former_opam_file =
        if Sys.file_exists opam_filename then
          Some ( EzFile.read_file opam_filename )
        else None
      in
      let new_opam_file =
        let s = opam_of_project p in
        Printf.sprintf
          "# This file was generated by `drom` from `drom.toml`. Do not modify.\n%s"
          s
      in
      if former_opam_file <> Some new_opam_file ||
         not ( Sys.file_exists "_opam" ) then begin
        Printf.eprintf "Updating %s\n%!" opam_filename ;

        let ocaml_nv = "ocaml." ^ p.edition in
        if Sys.file_exists "_opam" &&
           not ( Sys.file_exists ( "_opam" // ".opam-switch" // "packages"
                                   // ocaml_nv )) then begin
          error "Wrong ocaml version in _opam. Expecting %s. Remove '_opam/' or change the project edition" ocaml_nv
        end;

        if not ( Sys.file_exists "_opam" ) then begin
          DromMisc.call [| "opam" ; "switch" ; "create"; "." ; "--empty" |];
          let packages = [
            ocaml_nv ;
            "ocamlformat" ;
            "user-setup" ;
            "merlin" ;
            "odoc" ;
          ] in
          DromMisc.call ( Array.of_list
                               ( "opam" :: "install" :: "-y" :: packages ) );
        end ;

        let tmp_opam_filename = "_drom/tmp.opam" in
        EzFile.write_file tmp_opam_filename new_opam_file ;

        DromMisc.call [| "opam" ; "install" ; "-y" ; "--deps-only";
                            tmp_opam_filename |];

        Sys.remove tmp_opam_filename ;
        EzFile.write_file opam_filename new_opam_file;

      end

    end;

  match !to_add with
  | [] -> ()
  | files ->
    DromMisc.call
      ( Array.of_list
          ( "git" :: "add" :: files ))
