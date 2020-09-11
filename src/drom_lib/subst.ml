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

let verbose_subst = try
    ignore ( Sys.getenv "DROM_VERBOSE_SUBST" ); true
  with Not_found -> false

let project_brace (_,p) v =
  match v with
  | "name" -> p.package.name
  | "synopsis" -> p.synopsis
  | "description" -> p.description
  | "version" -> p.version
  | "edition" -> p.edition
  | "min-edition" -> p.min_edition
  | "copyright" -> (
      match p.copyright with
      | Some copyright -> copyright
      | None -> String.concat ", " p.authors )
  | "license" -> License.license p
  | "authors-ampersand" -> String.concat " & " p.authors
  (* general *)
  | "year" -> (Misc.date ()).Unix.tm_year |> string_of_int
  | "month" -> (Misc.date ()).Unix.tm_mon |> Printf.sprintf "%02d"
  | "day" -> (Misc.date ()).Unix.tm_mday |> Printf.sprintf "%02d"
  (* for github *)
  | "comment-if-not-windows-ci" -> if p.windows_ci then "" else "#"
  | "include-for-min-edition" ->
      if p.edition = p.min_edition then ""
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
      Random.int 1_000_000_000 |> string_of_int |> Digest.string
      |> Digest.to_hex
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
<li><a href="%s">General Documentation</a></li>|}
            link )
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
      match p.sphinx_target with Some dir -> dir | None -> "docs/sphinx" )
  | "make-copy-programs" ->
      List.filter (fun package -> package.kind = Program) p.packages
      |> List.map (fun package ->
          Printf.sprintf "\n\tcp -f _build/default/%s/main.exe %s"
            package.dir package.name)
      |> String.concat ""
  | "badge-ci" -> (
      match p.github_organization with
      | None -> ""
      | Some github_organization ->
          Printf.sprintf
            "[![Actions \
             Status](https://github.com/%s/%s/workflows/Main%%20Workflow/badge.svg)](https://github.com/%s/%s/actions)"
            github_organization p.package.name github_organization
            p.package.name )
  | "badge-release" -> (
      match p.github_organization with
      | None -> ""
      | Some github_organization ->
          Printf.sprintf
            "[![Release](https://img.shields.io/github/release/%s/%s.svg)](https://github.com/%s/%s/releases)"
            github_organization p.package.name github_organization
            p.package.name )
  | "homepage" -> (
      match Misc.homepage p with
      | Some homepage -> homepage
      | None -> "Not yet specified" )
  | "doc-gen" -> (
      match Misc.doc_gen p with Some url -> url | None -> "Not yet specified" )
  | "doc-api" -> (
      match Misc.doc_api p with Some url -> url | None -> "Not yet specified" )
  | "dev-repo" -> (
      match Misc.dev_repo p with Some url -> url | None -> "Not yet specified" )
  (* for dune *)
  | "gitignore-programs" ->
      List.filter (fun package -> package.kind = Program) p.packages
      |> List.map (fun p -> "/" ^ p.name)
      |> String.concat "\n"
  (* for git *)
  | "packages" ->
      p.packages
      |> List.map (fun p -> p.name)
      |> String.concat " "
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
      match Ocamlformat.find_global () with
      | None -> ""
      | Some content -> raise (ReplaceContent content) )
  (* for ocpindent *)
  | "global-ocpindent" -> (
      match Ocpindent.find_global () with
      | None -> ""
      | Some content -> raise (ReplaceContent content) )
  | s ->
      Printf.eprintf "Error: no project substitution for %S\n%!" s;
      raise Not_found

let project_paren (_,p) name =
  match StringMap.find name p.fields with
  | exception Not_found ->
      if verbose_subst then
        Printf.eprintf "Warning: no project field %S\n%!" name;
      ""
  | s -> s

let package_brace (context,p) v =
  match v with
  | "name" | "package-name" -> p.name
  | "dir" | "package-dir" -> p.dir
  | "package-dune" -> Dune.package_dune p
  | "package-dune-files" -> Dune.package_dune_files p
  | _ -> (
      match Misc.EzString.chop_prefix v ~prefix:"project-" with
      | Some v -> project_brace ( context, p.project ) v
      | None -> project_brace ( context, p.project ) v )

let package_paren (context,package) name =
  match Misc.EzString.chop_prefix ~prefix:"project-" name with
  | Some name -> project_paren (context,package.project) name
  | None ->
      match StringMap.find name package.p_fields with
      | s -> s
      | exception Not_found ->
          match Misc.EzString.chop_prefix ~prefix:"package-" name with
          | None -> project_paren (context,package.project) name
          | Some name ->
              match StringMap.find name package.p_fields with
              | s -> s
              | exception Not_found ->
                  if verbose_subst then
                    Printf.eprintf "Warning: no package field %S\n%!" name;
                  ""

let subst_encode p_subst escape p s =
  match EzString.split s ':' with
  | [] ->
      Printf.eprintf "Warning: empty expression\n%!";
      raise Not_found
  | [ "escape" ; "true" ] -> escape := true; ""
  | [ "escape" ; "false" ] -> escape := true; ""
  | var :: encodings ->
      let var = p_subst p var in
      let rec iter encodings var =
        match encodings with
        | [] -> var
        | encoding :: encodings ->
            let var = match encoding with
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
    Ez_subst.string ~sep:'!'
      ~escape
      ~brace:(subst_encode project_brace escape)
      ~paren:(subst_encode project_paren (ref true))
      ?bracket
      (context,p)
      s
  with ReplaceContent content -> content

let package context ?bracket p s =
  try
    let escape = ref false in
    Ez_subst.string ~sep:'!'
      ~escape
      ~brace:(subst_encode package_brace escape)
      ~paren:(subst_encode package_paren (ref true))
      ?bracket
      (context,p)
      s
  with ReplaceContent content -> content
