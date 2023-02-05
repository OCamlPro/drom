(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ez_subst (* .V1 *)
open Types
open EzCompat
open Ez_file.V1
open EzFile.OP

exception Postpone

type ('context, 'p) state = {
  context : 'context;
  p : 'p; (* Types.project or Types.package *)
  share : Types.share ; (* used mostly for licenses *)
  postpone : bool ; (* some operations can be postponed (`raise
                       Postpone`), for example if they depend on
                       another file that has to be generated
                       before. *)
  hashes : Hashes.t option; (* When reading files, files may not exist
                               yet until `Hashes.save` has been
                               called, so we need a way to read them
                               before they are committed to disk *)
}

let state ?(postpone=false) ?hashes context share p =
  { context ; p ; share ; postpone ; hashes }

exception ReplaceContent of string

let rec find_top_dir dir =
  match Filename.dirname dir with
  | ""
  | "." ->
    dir
  | dirname -> find_top_dir dirname

let verbose_subst =
  try
    ignore (Sys.getenv "DROM_VERBOSE_SUBST");
    true
  with
  | Not_found -> false

let maybe_string = function
  | None -> ""
  | Some s -> s

let with_buffer f =
  let b = Buffer.create 100 in
  f b;
  Buffer.contents b

let project_brace ({ p; _ }  as state ) v =
  match v with
  | "name" -> p.package.name
  | "synopsis" -> p.synopsis
  | "description" -> p.description
  | "skeleton" -> Misc.project_skeleton p.skeleton
  | "version" -> p.version
  | "edition" -> p.edition
  | "min-edition" -> p.min_edition
  | "github-organization" -> maybe_string p.github_organization
  | "authors-as-strings" ->
    String.concat ", " (List.map (Printf.sprintf "%S") p.authors)
  | "authors-for-toml" ->
    String.concat ", " (List.map (Printf.sprintf "\"%s\"") p.authors)
  | "copyright" -> (
    match p.copyright with
    | Some copyright -> copyright
    | None -> String.concat ", " p.authors )
  | "license" -> License.license state.share p
  | "license-name" -> p.license
  | "header-ml" -> License.header_ml state.share p
  | "header-c" -> License.header_c state.share p
  | "header-mly" -> License.header_mly state.share p
  | "header-mll" -> License.header_mll state.share p
  | "authors-ampersand" -> String.concat " & " p.authors
  (* general *)
  | "start_year" -> string_of_int p.year
  | "years" ->
    let current_year = (Misc.date ()).Unix.tm_year in
    if current_year = p.year then
      string_of_int p.year
    else
      Printf.sprintf "%d-%d" p.year current_year
  | "year" -> (Misc.date ()).Unix.tm_year |> string_of_int
  | "month" -> (Misc.date ()).Unix.tm_mon |> Printf.sprintf "%02d"
  | "day" -> (Misc.date ()).Unix.tm_mday |> Printf.sprintf "%02d"
  (* for github *)
  | "ci-first-system" -> List.hd p.ci_systems
  | "ci-systems" -> String.concat "\n          - " p.ci_systems
  | "comment-if-not-windows-ci" ->
    if List.mem "windows-latest" p.ci_systems then
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
          - os: %s
            ocaml-version: %s
            skip_test: true
|}
        (List.hd p.ci_systems) p.min_edition
  (* for sphinx *)
  | "sphinx-authors-list" -> String.concat "\n* " p.authors
  | "sphinx-copyright" -> (
    match p.copyright with
    | None -> "unspecified"
    | Some copyright -> copyright )
  | "random" ->
      (* TODO:deprecate as it is not determinist *)
    Random.int 1_000_000_000 |> string_of_int |> Digest.string |> Digest.to_hex
  | "li-authors" ->
    String.concat "\n"
      (List.map
         (fun s -> Printf.sprintf "  <li><p>%s</p></li>" s)
         (List.map EzHtml.string p.authors) )
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
  | "sphinx-target" -> Misc.sphinx_target p
  | "odoc-target" -> Misc.odoc_target p
  | "badge-ci" -> begin
    match p.github_organization with
    | None -> ""
    | Some github_organization ->
      with_buffer (fun b ->
          List.iter
            (fun workflow ->
              Printf.bprintf b
                "[![Actions \
                 Status](https://github.com/%s/%s/workflows/%s/badge.svg)](https://github.com/%s/%s/actions)"
                github_organization p.package.name workflow github_organization
                p.package.name )
            [ "Main%20Workflow" ] )
  end
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
  | "gitignore-programs" ->
    List.filter (fun package -> package.kind = Program) p.packages
    |> List.map (fun p -> "/" ^ p.name)
    |> String.concat "\n"
  (* for git *)
  | "packages" ->
    List.filter (fun package -> package.kind <> Virtual) p.packages
    |> List.map (fun p -> p.name)
    |> String.concat " "
  | "opams" ->
    List.filter (fun package -> package.kind <> Virtual) p.packages
    |> List.map (fun p -> Printf.sprintf "./%s.opam" p.name)
    |> String.concat " "
  | "virtuals" ->
    List.filter (fun package -> package.kind = Virtual) p.packages
    |> List.map (fun p -> p.name)
    |> String.concat " "
  | "libraries" ->
    List.filter (fun package -> package.kind = Library) p.packages
    |> List.map (fun p -> p.name)
    |> String.concat " "
  | "programs" ->
    List.filter (fun package -> package.kind = Library) p.packages
    |> List.map (fun p -> p.name)
    |> String.concat " "
  (* for ocamlformat *)
  | "global-ocamlformat" -> (
    match Globals.Base_dirs.config_dir with
    | None -> ""
    | Some config_dir ->
      let open EzFile.OP in
      begin
        match EzFile.read_file (config_dir // "ocamlformat") with
        | exception _e -> ""
        | content -> raise (ReplaceContent content)
      end )
  (* for ocpindent *)
  | "global-ocpindent" -> (
    match Globals.Base_dirs.config_dir with
    | None -> ""
    | Some config_dir ->
      let open EzFile.OP in
      begin
        match EzFile.read_file (config_dir // "ocp" // "ocp-indent.conf") with
        | exception _e -> ""
        | content -> raise (ReplaceContent content)
      end )
  (* for dune *)
  | "dune-version" -> p.dune_version
  | "dune-lang" ->
    String.sub p.dune_version 0 (String.rindex p.dune_version '.')
  | "dune-cram" ->
    if VersionCompare.compare p.dune_version "2.7.0" >= 0 then
      "(cram enable)"
    else
      ""
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
              | _ -> "" ) )
          profile.flags;
        Printf.bprintf b "  )\n" )
      p.profiles;
    Buffer.contents b
  | "dune-dirs" -> begin
    let set = StringSet.of_list [ "src"; "test"; "vendors"; "share" ] in
    let set =
      List.fold_left
        (fun set package ->
          let dir = find_top_dir package.dir in
          StringSet.add dir set )
        set p.packages
    in
    String.concat " " (StringSet.to_list set)
  end
  | "dune-installs" ->
    let b = Buffer.create 1000 in
    List.iter
      (fun share_dir ->
        List.iter
          (fun package ->
            let share_files = ref [] in
            let share_dir = share_dir // package.name in
            if Sys.file_exists share_dir then begin
              EzFile.make_select EzFile.iter_dir ~deep:true share_dir
                ~kinds:[ S_REG; S_LNK ] ~f:(fun path ->
                  if not (Filename.check_suffix path "~") then
                    share_files := (share_dir // path, path) :: !share_files )
            end;
            match !share_files with
            | [] -> ()
            | files ->
              let files = List.sort compare files in
              Buffer.add_string b
                (String.concat "\n"
                   ( [ ""; "(install"; Printf.sprintf " (files" ]
                   @ List.flatten
                       (List.map
                          (fun (file, path) ->
                            [ Printf.sprintf "   ( %S" file;
                              Printf.sprintf "    as %S)" path
                            ] )
                          files )
                   @ [ " )";
                       " (section share)";
                       Printf.sprintf " (package %s))" package.name
                     ] ) ) )
          p.packages )
      p.share_dirs;
    Buffer.contents b
  | "dune-packages" -> Dune.packages p
  | "build-profile" -> (
    match p.profile with
    | None -> ""
    | Some s -> " --profile " ^ s )
  | "ocamlformat-ignore-share" ->
      String.concat "\n"
        (List.map (fun s ->
             Filename.concat s "**"
           ) p.share_dirs)
  | s ->
    Printf.eprintf "Error: no project substitution for %S\n%!" s;
    raise Not_found

let project_paren state name =
  let name, default =
    if String.contains name ':' then
      let name, default = EzString.cut_at name ':' in
      name, Some default
    else
      name, None
  in
  match StringMap.find name state.p.fields with
  | s -> s
  | exception Not_found ->
      match default with
      | None ->
          if verbose_subst then
            Printf.eprintf "Warning: no project field %S\n%!" name;
          ""
      | Some default -> default

let package_brace state v =
  let package = state.p in
  match v with
  | "name"
  | "package-name" ->
    package.name
  | "program-name" -> begin
    match StringMap.find "program-name" package.p_fields with
    | exception Not_found -> package.name
    | name -> name
  end
  | "skeleton" -> Misc.package_skeleton package
  | "library-name" -> Misc.library_name package
  | "pack" -> Misc.library_module package
  | "kind" -> Misc.string_of_kind package.kind
  | "modules" -> String.concat " " (Misc.modules package)
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
          | Some name -> name )
        (List.filter
           (fun (_name, d) -> not d.depopt)
           (Misc.p_dependencies package) )
    in
    String.concat " " dependencies
  | "dune-stanzas" ->
    let b = ref [] in
    if package.p_optional = Some true then b := "(optional)" :: !b;
    begin
      match package.p_preprocess with
      | None -> ()
      | Some s -> b := Printf.sprintf "(preprocess (%s))" s :: !b
    end;
    String.concat "\n  " !b
  | "package-dune-files" -> Dune.package_dune_files package
  | "package-dune-installs" -> (
    let share_files = ref [] in
    (*
      begin
        match (Misc.p_mode package, package.kind) with
        | Javascript, Program ->
            (* We need to create a specific installation rule to force
               build of the Javascript files when `dune build
               @install` is called by `drom build` *)
            share_files := Printf.sprintf "(main.bc.js as %s.js)" package.name :: !share_files
        | _ -> ()
      end;
*)
    match !share_files with
    | [] -> ""
    | files ->
      String.concat "\n"
        [ "(install";
          Printf.sprintf " (files %s)" (String.concat " " files);
          " (section share)";
          Printf.sprintf " (package %s))" package.name
        ] )
  | _ -> (
    match Misc.EzString.chop_prefix v ~prefix:"project-" with
    | Some v -> project_brace { state with p = package.project } v
    | None -> project_brace { state with p = package.project } v )

let package_paren state name =
  let package = state.p in
  match Misc.EzString.chop_prefix ~prefix:"project-" name with
  | Some name -> project_paren { state with p = package.project } name
  | None -> (
    match StringMap.find name package.p_fields with
    | s -> s
    | exception Not_found -> (
      match Misc.EzString.chop_prefix ~prefix:"package-" name with
      | None -> project_paren { state with p = package.project } name
      | Some name -> (
        match StringMap.find name package.p_fields with
        | s -> s
        | exception Not_found ->
          if verbose_subst then
            Printf.eprintf "Warning: no package field %S\n%!" name;
          "" ) ) )

let subst_encode p_subst escape state s =
  match EzString.split s ':' with
  | [] ->
      Printf.eprintf "Warning: empty expression\n%!";
      raise Not_found
  | [ "escape"; "true" ] ->
      escape := true;
      ""
  | [ "escape"; "false" ] ->
      escape := false;
      ""
  | list ->
      let s, encodings = match list with
        | [] -> assert false
        | s :: ">" :: encodings ->
            s, encodings
        | var :: encodings ->
            let s = p_subst state var in
            s, encodings
      in
      let rec iter encodings var =
        match encodings with
        | [] -> var
        | "default" :: default ->
            if var = "" then
              String.concat ":" default
            else
              var
        | encoding :: encodings ->
            let var =
              match encoding with
              | "read" ->
                  begin
                    if state.postpone then
                      raise Postpone
                    else
                      match state.hashes with
                      | None ->
                          EzFile.read_file var
                      | Some hashes ->
                          Hashes.read hashes ~file:var
                  end
              | "md5" -> Digest.string var |> Digest.to_hex
              | "html" -> EzHtml.string var
              | "cap" -> String.capitalize var
              | "uncap" -> String.uncapitalize var
              | "low" -> String.lowercase var
              | "up"
              | "upp" ->
                  String.uppercase var
              | "alpha" -> Misc.underscorify var
              | "md-to-html" ->
                  Omd.of_string var |> Omd.to_html
              | _ ->
                  Printf.eprintf "Error: unknown encoding %S\n%!" encoding;
                  raise Not_found
            in
            iter encodings var
      in
      iter encodings s

let project ?bracket ?skipper state s =
  try
    let escape = ref false in
    EZ_SUBST.string ~sep:'!' ~escape
      ~brace:(subst_encode project_brace escape)
      ~paren:(subst_encode project_paren (ref true))
      ?bracket ?skipper ~ctxt:state s
  with
  | ReplaceContent content -> content

let package ?bracket ?skipper state s =
  try
    let escape = ref false in
    EZ_SUBST.string ~sep:'!' ~escape
      ~brace:(subst_encode package_brace escape)
      ~paren:(subst_encode package_paren (ref true))
      ?bracket ?skipper ~ctxt:state s
  with
  | ReplaceContent content -> content
