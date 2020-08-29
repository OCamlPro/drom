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

let template_main_main_ml p =
  Printf.sprintf {|let () = %s.Main.main ()
|} ( library_module p )

let template_src_main_ml p =
  match Misc.p_kind p with
  | Both ->
    Printf.sprintf
      {|
(* If you delete or rename this file, you should add '%s/main.ml' to the 'skip' field in "drom.toml" *)

let main () = Printf.printf "Hello world!\n%!"
|} p.dir
  | Program ->
    Printf.sprintf
      {|
(* If you rename this file, you should add '%s/main.ml' to the 'skip' field in "drom.toml" *)

let () = Printf.printf "Hello world!\n%!"
|}
      p.dir
  | Library -> assert false

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
  (match Misc.p_kind p.package with
   | Library -> ""
   | Program ->
     Printf.sprintf {|
	cp -f _build/default/%s/main.exe %s
|} p.package.dir p.package.name
   | Both ->
     Printf.sprintf {|
	cp -f _build/default/main/main.exe %s
|} p.package.name
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



let semantic_version version =
  match EzString.split version '.' with
    [ major ; minor ; fix ] ->
    begin try
        Some ( int_of_string major, int_of_string minor, int_of_string fix )
      with
        Not_found -> None
    end
  | _ -> None

let dev_repo p =
  match p.dev_repo with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "git+https://github.com/%s/%s.git"
               organization p.package.name )
    | None -> None

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
      Printf.eprintf "Loading .drom\n%!";
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
  let write_file ?(force=false) filename content =
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
      end else begin
        let filename = "_drom" // "skipped" // filename in
        EzFile.make_dir ~p:true ( Filename.dirname filename ) ;
        EzFile.write_file filename content
      end
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
    | Some kind -> { p with kind }, true
  in
  let p, changed = match mode with
    | None -> p, changed
    | Some mode ->
      let js_dep = ( "js_of_ocaml", { depversion = "3.6" ; depname = None } ) in
      let js_tool = ( "js_of_ocaml", "3.6") in
      let ppx_tool = ( "js_of_ocaml-ppx", "3.6" ) in
      let add_dep dep deps changed  =
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
  (*   write_file "dune-workspace" ""; *)
  write_file "README.md" ( template_readme_md p ) ;
  write_file ( p.package.dir // "dune" ) ( Dune.template_src_dune p.package ) ;
  if Misc.p_kind p.package = Both then begin
    write_file "main/dune" ( Dune.template_main_dune p.package ) ;
    write_file "main/main.ml" ( template_main_main_ml p.package ) ;
  end else begin
    remove_file "main/dune" ;
    remove_file "main/main.ml" ;
  end ;
  begin
    match Misc.p_kind p.package with
    | Library -> ()
    | Program | Both ->
      write_file ( p.package.dir // "main.ml" ) ( template_src_main_ml
                                                    p.package ) ;
  end ;

  write_file "CHANGES.md" ( template_CHANGES_md p ) ;
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
  write_file ".ocamlformat" "" ;

  if not_skipped "workflows" then begin

    let workflows_dir = ".github/workflows" in

    write_file ( workflows_dir // "ci.ml" )
      ( Github.template_DOTgithub_workflows_ci_ml p ) ;
    write_file ( workflows_dir // "workflow.yml" )
      ( Github.template_DOTgithub_workflows_workflow_yml p ) ;

  end;

  let opam_filename, kind =
    match p.kind with
    | Both ->
      ( p.package.name ^ "_lib.opam", LibraryPart )
    | Library | Program ->
      ( p.package.name ^ ".opam", Single )
  in
  write_file opam_filename ( Opam.opam_of_project kind p.package ) ;
  begin
    match p.kind with
    | Library | Program ->
      remove_file ( p.package.name ^ "_lib.opam" )
    | Both ->
      write_file ( p.package.name ^ ".opam" )
        ( Opam.opam_of_project ProgramPart p.package )
  end;

  EzFile.make_dir ~p:true Globals.drom_dir ;
  EzFile.write_file ( Globals.drom_dir // "known-licences.txt" )
    ( License.known_licenses () );

  if not_skipped "license" then
    write_file "LICENSE.md" ( License.license p ) ;

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

  if upgrade || changed ||  not ( Sys.file_exists "drom.toml" ) then
    write_file ~force:upgrade "drom.toml" ( Project.toml_of_project p ) ;

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
