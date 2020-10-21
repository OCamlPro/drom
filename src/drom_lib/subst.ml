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
open EzCompat

exception ReplaceContent of string

let verbose_subst =
  try
    ignore (Sys.getenv "DROM_VERBOSE_SUBST");
    true
  with Not_found -> false

let maybe_string = function
  | None -> ""
  | Some s -> s

let project_brace (_, p) v =
  match v with
  | "name" -> p.package.name
  | "synopsis" -> p.synopsis
  | "description" -> p.description
  | "version" -> p.version
  | "edition" -> p.edition
  | "min-edition" -> p.min_edition
  | "github-organization" -> maybe_string p.github_organization
  | "authors-as-strings" ->
    String.concat " " (List.map (Printf.sprintf "%S") p.authors)
  | "copyright" -> (
    match p.copyright with
    | Some copyright -> copyright
    | None -> String.concat ", " p.authors )
  | "license" -> License.license p
  | "license-name" -> p.license
  | "header-ml" -> License.header_ml p
  | "header-mll" -> License.header_mll p
  | "header-mly" -> License.header_mly p
  | "authors-ampersand" -> String.concat " & " p.authors
  (* general *)
  | "year" -> (Misc.date ()).Unix.tm_year |> string_of_int
  | "month" -> (Misc.date ()).Unix.tm_mon |> Printf.sprintf "%02d"
  | "day" -> (Misc.date ()).Unix.tm_mday |> Printf.sprintf "%02d"
  (* for github *)
  | "comment-if-not-windows-ci" ->
    if p.windows_ci then
      ""
    else
      "#"
  | "include-for-min-edition" ->
    if p.edition = p.min_edition then
      ""
    else
      Printf.sprintf
        {|
        include:
          - os: ubuntu-latest
            ocaml-version: %s
            skip_test: true
|}
        p.min_edition
  (* for sphinx *)
  | "sphinx-authors-list" -> String.concat "\n* " p.authors
  | "sphinx-copyright" -> (
    match p.copyright with
    | None -> "unspecified"
    | Some copyright -> copyright )
  | "random" ->
    Random.int 1_000_000_000 |> string_of_int |> Digest.string |> Digest.to_hex
  | "li-authors" ->
    String.concat "\n"
      (List.map
         (fun s -> Printf.sprintf "  <li><p>%s</p></li>" s)
         (List.map EzHtml.string p.authors))
  | "li-github" -> (
    match p.github_organization with
    | None -> ""
    | Some github_organization ->
      let link =
        Printf.sprintf "https://github.com/%s/%s" github_organization
          p.package.name
      in
      Printf.sprintf {|
<li><a href="%s">Project on Github</a></li>|} link )
  | "li-doc-gen" -> (
    match Misc.doc_gen p with
    | None -> ""
    | Some link ->
      Printf.sprintf {|
<li><a href="%s">General Documentation</a></li>|} link )
  | "li-doc-api" -> (
    match Misc.doc_api p with
    | None -> ""
    | Some link ->
      Printf.sprintf {|
<li><a href="%s">API Documentation</a></li>|} link )
  | "li-bug-reports" -> (
    match Misc.bug_reports p with
    | None -> ""
    | Some link ->
      Printf.sprintf {|
<li><a href="%s">Bug reports</a></li>|} link )
  | "sphinx-index-home" -> (
    match Misc.homepage p with
    | None -> ""
    | Some link -> Printf.sprintf "   Home <%s>\n" link )
  | "sphinx-index-api" -> (
    match Misc.doc_api p with
    | None -> ""
    | Some link -> Printf.sprintf "   API doc <%s>\n" link )
  | "sphinx-index-github" -> (
    match p.github_organization with
    | None -> ""
    | Some github_organization ->
      Printf.sprintf
        {|
   Devel and Issues on Github <https://github.com/%s/%s>
|}
        github_organization p.package.name )
  | "sphinx-target" -> (
    match p.sphinx_target with
    | Some dir -> dir
    | None -> "docs/sphinx" )
  | "make-copy-programs" ->
    List.filter (fun package -> package.kind = Program) p.packages
    |> List.map (fun package ->
           Printf.sprintf "\n\tcp -f _build/default/%s/main.exe %s" package.dir
             package.name)
    |> String.concat ""
  | "badge-ci" -> (
    match p.github_organization with
    | None -> ""
    | Some github_organization ->
      Printf.sprintf
        "[![Actions \
         Status](https://github.com/%s/%s/workflows/Main%%20Workflow/badge.svg)](https://github.com/%s/%s/actions)"
        github_organization p.package.name github_organization p.package.name )
  | "badge-release" -> (
    match p.github_organization with
    | None -> ""
    | Some github_organization ->
      Printf.sprintf
        "[![Release](https://img.shields.io/github/release/%s/%s.svg)](https://github.com/%s/%s/releases)"
        github_organization p.package.name github_organization p.package.name )
  | "homepage" -> (
    match Misc.homepage p with
    | Some homepage -> homepage
    | None -> "Not yet specified" )
  | "doc-gen" -> (
    match Misc.doc_gen p with
    | Some url -> url
    | None -> "Not yet specified" )
  | "doc-api" -> (
    match Misc.doc_api p with
    | Some url -> url
    | None -> "Not yet specified" )
  | "dev-repo" -> (
    match Misc.dev_repo p with
    | Some url -> url
    | None -> "Not yet specified" )
  (* for dune *)
  | "gitignore-programs" ->
    List.filter (fun package -> package.kind = Program) p.packages
    |> List.map (fun p -> "/" ^ p.name)
    |> String.concat "\n"
  (* for git *)
  | "packages" -> p.packages |> List.map (fun p -> p.name) |> String.concat " "
  | "opams" ->
    p.packages
    |> List.map (fun p -> Printf.sprintf "./%s.opam" p.name)
    |> String.concat " "
  | "libraries" ->
    List.filter (fun package -> package.kind = Library) p.packages
    |> List.map (fun p -> p.name)
    |> String.concat " "
  (* for ocamlformat *)
  | "global-ocamlformat" -> (
    let open EzFile.OP in
    match EzFile.read_file (Globals.xdg_config_dir // "ocamlformat") with
    | exception _e -> ""
    | content -> raise (ReplaceContent content) )
  (* for ocpindent *)
  | "global-ocpindent" -> (
    let open EzFile.OP in
    match
      EzFile.read_file (Globals.xdg_config_dir // "ocp" // "ocp-indent.conf")
    with
    | exception _e -> (
      match
        EzFile.read_file (Globals.home_dir // ".ocp" // "ocp-indent.conf")
      with
      | exception _e -> ""
      | content -> raise (ReplaceContent content) )
    | content -> raise (ReplaceContent content) )
  | "dune-profiles" ->
    let b = Buffer.create 1000 in
    StringMap.iter
      (fun name profile ->
        Printf.bprintf b "  (%s\n" name;
        StringMap.iter
          (fun name value ->
            Printf.bprintf b "    (%s %s%s)\n"
              ( match name with
              | "ocaml" -> "flags (:standard"
              | "odoc" -> "odoc"
              | "coq" -> "coq ("
              | tool -> tool ^ "_flags" )
              value
              ( match name with
              | "coq" -> ")" (* (coq (flags XXX)) *)
              | "ocaml" -> ")"
              | _ -> "" ))
          profile.flags;
        Printf.bprintf b "  )\n")
      p.profiles;
    Buffer.contents b
  | s ->
    Printf.eprintf "Error: no project substitution for %S\n%!" s;
    raise Not_found

let project_paren (_, p) name =
  match StringMap.find name p.fields with
  | exception Not_found ->
    if verbose_subst then Printf.eprintf "Warning: no project field %S\n%!" name;
    ""
  | s -> s

let package_brace (context, package) v =
  match v with
  | "name"
  | "package-name" ->
    package.name
  | "library-name" -> Misc.library_name package
  | "dir"
  | "package-dir" ->
    package.dir
  | "pack-modules" -> string_of_bool (Misc.p_pack_modules package)
  | "dune-libraries" ->
    let dependencies =
      List.map
        (fun (name, d) ->
          match d.depname with
          | None -> name
          | Some name -> name)
        (Misc.p_dependencies package)
    in
    let p_mode = Misc.p_mode package in
    let dependencies =
      match p_mode with
      | Binary -> dependencies
      | Javascript ->
        if List.mem "js_of_ocaml" dependencies then
          dependencies
        else
          "js_of_ocaml" :: dependencies
    in
    String.concat " " dependencies
  | "dune-stanzas" ->
    String.concat "\n"
      ( match Misc.p_mode package with
      | Binary -> []
      | Javascript ->
        [ ( match package.kind with
          | Library
          | Virtual ->
            ""
          | Program -> "(modes exe js)" );
          "   (preprocess (pps js_of_ocaml-ppx))"
        ] )
  | "package-dune-files" -> Dune.package_dune_files package
  | "package-dune-installs" -> (
    match (Misc.p_mode package, package.kind) with
    | Javascript, Program ->
      (* We need to create a specific installation rule to force
         build of the Javascript files when `dune build
         @install` is called by `drom build` *)
      String.concat "\n"
        [ "(install";
          Printf.sprintf " (files (main.bc.js as www/js/%s.js))" package.name;
          " (section share)";
          Printf.sprintf " (package %s))" package.name
        ]
    | _ -> "" )
  | _ -> (
    match Misc.EzString.chop_prefix v ~prefix:"project-" with
    | Some v -> project_brace (context, package.project) v
    | None -> project_brace (context, package.project) v )

let package_paren (context, package) name =
  match Misc.EzString.chop_prefix ~prefix:"project-" name with
  | Some name -> project_paren (context, package.project) name
  | None -> (
    match StringMap.find name package.p_fields with
    | s -> s
    | exception Not_found -> (
      match Misc.EzString.chop_prefix ~prefix:"package-" name with
      | None -> project_paren (context, package.project) name
      | Some name -> (
        match StringMap.find name package.p_fields with
        | s -> s
        | exception Not_found ->
          if verbose_subst then
            Printf.eprintf "Warning: no package field %S\n%!" name;
          "" ) ) )

let subst_encode p_subst escape p s =
  match EzString.split s ':' with
  | [] ->
    Printf.eprintf "Warning: empty expression\n%!";
    raise Not_found
  | [ "escape"; "true" ] ->
    escape := true;
    ""
  | [ "escape"; "false" ] ->
    escape := true;
    ""
  | var :: encodings ->
    let var = p_subst p var in
    let rec iter encodings var =
      match encodings with
      | [] -> var
      | encoding :: encodings ->
        let var =
          match encoding with
          | "html" -> EzHtml.string var
          | "cap" -> String.capitalize var
          | "uncap" -> String.uncapitalize var
          | "low" -> String.lowercase var
          | "up" -> String.uppercase var
          | "alpha" -> Misc.underscorify var
          | _ ->
            Printf.eprintf "Error: unknown encoding %S\n%!" encoding;
            raise Not_found
        in
        iter encodings var
    in
    iter encodings var

let project context ?bracket p s =
  try
    let escape = ref false in
    Ez_subst.string ~sep:'!' ~escape
      ~brace:(subst_encode project_brace escape)
      ~paren:(subst_encode project_paren (ref true))
      ?bracket (context, p) s
  with ReplaceContent content -> content

let package context ?bracket p s =
  try
    let escape = ref false in
    Ez_subst.string ~sep:'!' ~escape
      ~brace:(subst_encode package_brace escape)
      ~paren:(subst_encode package_paren (ref true))
      ?bracket (context, p) s
  with ReplaceContent content -> content
