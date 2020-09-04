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
open EzFile.OP

open EzCompat

let template_DOTgitignore p =
  Printf.sprintf {|
/%s
*~
_build
.merlin
/_drom
/_opam
/_build
|} p.package.name

let library_name p =
  match p.p_pack with
  | Some name ->
    String.uncapitalize_ascii name
  | None ->
    let s = Bytes.of_string p.name in
    for i = 1 to String.length p.name - 2 do
      let c = p.name.[i] in
      match c with
      | 'a'..'z' | '0'..'9' -> ()
      | _ -> Bytes.set s i '_'
    done;
    Bytes.to_string s

let library_module p =
  match p.p_pack with
  | Some name -> name
  | None ->
    let s = Bytes.of_string p.name in
    Bytes.set s 0 ( Char.uppercase p.name.[0] );
    for i = 1 to String.length p.name - 2 do
      let c = p.name.[i] in
      match c with
      | 'a'..'z' | '0'..'9' -> ()
      | _ -> Bytes.set s i '_'
    done;
    Bytes.to_string s

let template_src_main_ml ~header_ml p =
  match p.kind with
  | Library ->
    Printf.sprintf
      {|%s
(* If you delete or rename this file, you should add '%s/main.ml' to the 'skip' field in "drom.toml" *)

let main () = Printf.printf "Hello world!\n%!"
|}
      header_ml p.dir
  | Program ->
    match p.p_driver_only with
    | Some library_module ->
      Printf.sprintf {|%s
let () = %s ()
|}
        header_ml library_module

    | _ ->
    Printf.sprintf
      {|%s

(* If you rename this file, you should add '%s/main.ml' to the 'skip' field in "drom.toml" *)

let () = Printf.printf "Hello world!\n%!"
|}
      header_ml p.dir

let template_readme_md p =
  match p.github_organization with
  | None ->
    Printf.sprintf "# %s\n" p.package.name
  | Some github_organization ->
  Printf.sprintf {|
[![Actions Status](https://github.com/%s/%s/workflows/Main%%20Workflow/badge.svg)](https://github.com/%s/%s/actions)
[![Release](https://img.shields.io/github/release/%s/%s.svg)](https://github.com/%s/%s/releases)

# %s

%s

* Website: https://%s.github.io/%s
* General Documentation: https://%s.github.io/%s/sphinx
* API Documentation: https://%s.github.io/%s/doc
* Sources: https://github.com/%s/%s
|}
github_organization p.package.name
github_organization p.package.name
github_organization p.package.name
github_organization p.package.name
p.package.name
p.description
github_organization p.package.name
github_organization p.package.name
github_organization p.package.name
github_organization p.package.name

let template_Makefile p =
  Printf.sprintf
  {|
.PHONY: all build-deps doc sphinx odoc view fmt fmt-check install dev-deps test
DEV_DEPS := merlin ocamlformat odoc

all: build

build:
	dune build%s

build-deps:
	opam install --deps-only ./%s.opam

sphinx:
	sphinx-build sphinx %s

doc:
	dune build @doc
	rsync -auv --delete _build/default/_doc/_html/. docs/doc

view:
	xdg-open file://$$(pwd)/docs/index.html

fmt:
	dune build @fmt --auto-promote

fmt-check:
	dune build @fmt

install:
	dune install

opam:
	opam pin -k path .

uninstall:
	dune uninstall

dev-deps:
	opam install -y ${DEV_DEPS}

test:
	dune build @runtest
|}
  (match p.package.kind with
   | Library -> ""
   | Program ->
     Printf.sprintf {|
	cp -f _build/default/%s/main.exe %s
|} p.package.dir p.package.name
  )
  p.package.name
  ( match p.sphinx_target with
    | Some dir -> dir
    | None -> "docs/sphinx" )

let template_CHANGES_md _p =
  let tm = Misc.date () in
  Printf.sprintf {|
## v0.1.0 ( %04d-%02d-%02d )

* Initial commit
|}
    tm.Unix.tm_year
    tm.Unix.tm_mon
    tm.Unix.tm_mday


let dev_repo p =
  match p.dev_repo with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "git+https://github.com/%s/%s.git"
               organization p.package.name )
    | None -> None

exception Skip

let update_files
    ?kind ?mode
    ?(upgrade=false) ?(git=false) ?(create=false)
    ?(promote_skip=false)
    p =

  let can_skip = ref [] in
  let not_skipped s =
    can_skip := s :: !can_skip;
    not ( List.mem s p.skip ) in
  let save_hashes = ref false in
  let hashes =
    if Sys.file_exists ".drom" then
      let map = ref StringMap.empty in
      (* Printf.eprintf "Loading .drom\n%!"; *)
      Array.iter (fun line ->
          if line <> "" && line.[0] <> '#' then
            let ( digest, filename ) = EzString.cut_at line ' ' in
            let digest = Digest.from_hex digest in
            map := StringMap.add filename digest !map
        )
        ( EzFile.read_lines ".drom")  ;
      !map
    else StringMap.empty
  in
  let hashes = ref hashes in
  let to_add = ref [] in
  let to_remove = ref [] in
  let skipped = ref [] in
  let write_file filename content =
    let dirname = Filename.dirname filename in
    EzFile.make_dir ~p:true dirname ;
    EzFile.write_file filename content ;
    hashes := StringMap.add filename ( Digest.string content ) !hashes ;
    save_hashes := true ;
    to_add := filename :: !to_add ;
  in
  let can_update ~filename content =
    let old_content = EzFile.read_file filename in
    if content = old_content then begin
      false
    end else
      let hash = Digest.string old_content in
      try
        let former_hash = StringMap.find filename !hashes in
        let not_modified = former_hash = hash in
        if not not_modified then begin
          skipped := filename :: !skipped ;
          Printf.eprintf "Skipping modified file %s\n%!" filename ;
        end ;
        not_modified
      with Not_found ->
        skipped := filename :: !skipped ;
        Printf.eprintf "Skipping existing file %s\n%!" filename ;
        false
  in
  (*
  let remove_file filename =
    if Sys.file_exists filename then
      let old_content = EzFile.read_file filename in
      let hash = Digest.string old_content in
      try
        let former_hash = StringMap.find filename !hashes in
        if former_hash <> hash then
          Printf.eprintf "Keeping modified file %s\n%!" filename
        else begin
          hashes := StringMap.remove filename !hashes ;
          save_hashes := true ;
          to_remove := filename ::!to_remove
        end
      with Not_found -> ()
  in
*)
  let write_file ?(skip=false) ?(force=false) filename content =
    try
      if skip then raise Skip;
      if force then begin
        Printf.eprintf "Updating file %s\n%!" filename;
        write_file filename content
      end else
      if not_skipped filename then
        if not ( Sys.file_exists filename ) then begin
          Printf.eprintf "Creating file %s\n%!" filename;
          write_file filename content
        end else
        if can_update ~filename content then begin
          Printf.eprintf "Updating file %s\n%!" filename;
          write_file filename content
        end
        else raise Skip
      else
        raise Skip
    with Skip ->
      let filename = "_drom" // "skipped" // filename in
      EzFile.make_dir ~p:true ( Filename.dirname filename ) ;
      EzFile.write_file filename content
  in

  let config = Lazy.force Config.config in

  let changed = false in
  let p, changed =
    if upgrade then
      let p, changed =
        match p.github_organization, config.config_github_organization with
        | None, Some s -> { p with github_organization = Some s }, true
        | _ -> p, changed
      in
      let p, changed =
        match p.authors, config.config_author with
        | [], Some s -> { p with authors = [ s ] }, true
        | _ -> p, changed
      in
      let p, changed =
        match p.copyright, config.config_copyright with
        | None, Some s -> { p with copyright = Some s }, true
        | _ -> p, changed
      in
      ( p, changed )
    else
      ( p, changed )
  in
  let p, changed = match kind with
    | None -> p, changed
    | Some kind ->
      p.package.kind <- kind ;
      p , true
  in
  let p, changed = match mode with
    | None -> p, changed
    | Some mode ->
      let js_dep = ( "js_of_ocaml", [ Semantic (3,6,0) ] ) in
      let js_tool = ( "js_of_ocaml", [ Semantic (3,6,0) ] ) in
      let ppx_tool = ( "js_of_ocaml-ppx", [ Semantic (3,6,0) ] ) in
      let add_dep ( name, depversions ) deps changed  =
        let dep = ( name, { depversions ; depname = None } ) in
        match mode with
        | Binary ->
          if List.mem dep deps then
            EzList.remove dep deps, true
          else
            deps, changed
        | Javascript ->
          if not ( List.mem_assoc (fst dep) deps ) then
            dep :: deps, true
          else
            deps, changed
      in
      let dependencies, changed = add_dep js_dep p.dependencies changed in
      let tools, changed = add_dep js_tool p.tools changed in
      let tools, changed = add_dep ppx_tool tools changed in
      { p with mode ; dependencies ; tools }, changed
  in

  write_file ".gitignore" ( template_DOTgitignore p ) ;
  write_file "Makefile" ( template_Makefile p ) ;
  write_file "README.md" ( template_readme_md p ) ;

  write_file "dune" ( Dune.template_dune p ) ;

  let header_ml = License.header_ml p in

  List.iter (fun package ->

      write_file ( package.dir // "dune" ) ( Dune.template_src_dune package ) ;
      begin
        match package.p_gen_version with
        | None -> ()
        | Some file ->
          (* TODO : we should put info in this file *)
          write_file ( package.dir // file )
            ( Printf.sprintf "let version = \"%s\"\n"
                ( Misc.p_version package ) );
      end;

      let file = package.dir // "main.ml" in
      write_file file ( template_src_main_ml ~header_ml package ) ;

      begin
        match Odoc.template_src_index_mld package with
        | None -> ()
        | Some content ->
            write_file ( package.dir // "index.mld" ) content
      end;
    ) p.packages ;

  write_file "CHANGES.md" ( template_CHANGES_md p ) ;

  if not_skipped "docs" then begin

    write_file "docs/index.html"
      ( Sphinx.docs_index_html p ) ;

    write_file "docs/style.css"
      ( Sphinx.docs_style_css p ) ;

    if not ( Sys.file_exists  "docs/doc/index.html" ) then
      write_file "docs/doc/index.html"
        ( Printf.sprintf {|
<h1>API documentation for %s</h1>
<p>You need to run the following commands in the project to generate this doc:
<pre>
make doc
</pre>
or
<pre>
drom doc
</pre>
and then:
<pre>
git add docs/doc
</pre>
</p>
|} p.package.name ) ;

    if not ( Sys.file_exists "docs/sphinx/index.html" ) then
      write_file "docs/sphinx/index.html"
        ( Printf.sprintf {|
<h1>Sphinx doc for %s</h1>
<p>You need to run the following commands in the project to generate this doc:
<pre>
make sphinx
</pre>
or
<pre>
drom sphinx
</pre>
and then:
<pre>
git add docs/sphinx
</pre>
</p>
|} p.package.name ) ;
  end;

  if not_skipped "sphinx" then begin
    write_file "docs/.nojekyll" "";
    write_file "sphinx/conf.py" ( Sphinx.conf_py p ) ;
    write_file "sphinx/index.rst" ( Sphinx.index_rst p ) ;
    write_file "sphinx/install.rst" ( Sphinx.install_rst p ) ;
    write_file "sphinx/license.rst" ( Sphinx.license_rst p ) ;
    write_file "sphinx/about.rst" ( Sphinx.about_rst p ) ;
    write_file "sphinx/_static/css/fixes.css" "";
  end;

  write_file "dune-project" ( Dune.template_dune_project p ) ;
  write_file ".ocamlformat" ( Ocamlformat.template p );
  write_file ".ocamlformat-ignore" ( Ocamlformat.ignore p );
  write_file ".ocp-indent" ( Ocpindent.template p );

  if not_skipped "workflows" then begin

    let workflows_dir = ".github/workflows" in

    write_file ( workflows_dir // "ci.ml" )
      ( Github.template_DOTgithub_workflows_ci_ml p ) ;
    write_file ( workflows_dir // "workflow.yml" )
      ( Github.template_DOTgithub_workflows_workflow_yml p ) ;

  end;

  List.iter (fun package ->
      let opam_filename = package.name ^ ".opam" in
      write_file opam_filename ( Opam.opam_of_project Single package )
    ) p.packages ;

  let opam_filename = Globals.drom_dir // p.package.name ^ "-deps.opam" in
  let deps_package = Misc.deps_package p in
  EzFile.write_file opam_filename ( Opam.opam_of_project Deps deps_package ) ;

  EzFile.make_dir ~p:true Globals.drom_dir ;
  EzFile.write_file ( Globals.drom_dir // "known-licences.txt" )
    ( License.known_licenses () );

  write_file "LICENSE.md" ( License.license p ) ;
  EzFile.write_file ( Globals.drom_dir // "header.ml" )
    ( License.header_ml p ) ;
  EzFile.write_file ( Globals.drom_dir // "header.mll" )
    ( License.header_mll p ) ;
  EzFile.write_file ( Globals.drom_dir // "header.mly" )
    ( License.header_mly p ) ;


  EzFile.write_file ( Globals.drom_dir // "maximum-skip-field.txt" )
    ( Printf.sprintf "skip = \"%s\"\n"
        ( String.concat " " !can_skip )) ;

  let p, changed =
    if promote_skip && !skipped <> [] then
      let skip = p.skip @ !skipped in
      Printf.eprintf "skip field promotion: %s\n%!"
        ( String.concat " " !skipped );
      { p with skip }, true
    else
      ( p, changed )
  in

  let skip = not (
      upgrade || changed ||  not ( Sys.file_exists "drom.toml" )
    ) in
  write_file ~skip ~force:upgrade "drom.toml" ( Project.toml_of_project p ) ;


  if create then begin
    if git && not ( Sys.file_exists ".git" ) then begin
      Misc.call [| "git"; "init" |];
      match config.config_github_organization with
      | None -> ()
      | Some organization ->
        Misc.call [| "git"; "remote" ; "add" ; "origin" ;
                     Printf.sprintf
                       "git@github.com:%s/%s"
                       organization
                       p.package.name |];
        Misc.call [| "git"; "add" ; "README.md" |];
        Misc.call [| "git"; "commit" ; "-m" ; "Initial commit" |];
    end
  end ;


  if !save_hashes then
    let b = Buffer.create 1000 in
    Printf.bprintf b
      "# Keep this file in your GIT repo to help drom track generated files\n";
    StringMap.iter (fun filename hash ->
        Printf.bprintf b "%s %s\n"
          ( Digest.to_hex hash ) filename ) !hashes ;
    EzFile.write_file ".drom" ( Buffer.contents b ) ;
    if git then begin
      Misc.call
        ( Array.of_list
            ( "git" :: "add" :: ".drom" :: !to_add ));
      match !to_remove with
      | [] -> ()
      | files ->
        Misc.call
          ( Array.of_list
              ( "git" :: "rm" :: files ))
    end
