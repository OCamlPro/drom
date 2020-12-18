(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzFile.OP
open EzCompat

module EzString = struct
  include EzString

  let chop_prefix s ~prefix =
    if EzString.starts_with s ~prefix then
      let prefix_len = String.length prefix in
      let len = String.length s in
      Some (String.sub s prefix_len (len - prefix_len))
    else
      None

  let chop_suffix s ~suffix =
    if EzString.ends_with s ~suffix then
      let suffix_len = String.length suffix in
      let len = String.length s in
      Some (String.sub s 0 (len - suffix_len))
    else
      None
end

let option_value o ~default =
  match o with
  | None -> default
  | Some v -> v

let verbose i = !Globals.verbosity >= i

let call ?(stdout = Unix.stdout) args =
  if verbose 1 then
    Printf.eprintf "Calling %s\n%!" (String.concat " " (Array.to_list args));
  let pid = Unix.create_process args.(0) args Unix.stdin stdout Unix.stderr in
  let rec iter () =
    match Unix.waitpid [] pid with
    | exception Unix.Unix_error (EINTR, _, _) -> iter ()
    | _pid, status -> (
      match status with
      | WEXITED 0 -> ()
      | _ ->
        Error.raise "Command '%s' exited with error code %s"
          (String.concat " " (Array.to_list args))
          ( match status with
          | WEXITED n -> string_of_int n
          | WSIGNALED n -> Printf.sprintf "SIGNAL %d" n
          | WSTOPPED n -> Printf.sprintf "STOPPED %d" n ) )
  in
  iter ()

(** run a cmd and return the first line of output *)
let call_get_fst_line cmd =
  let chan = Unix.open_process_in cmd in
  try
    let output = input_line chan in
    match Unix.close_process_in chan with
    | WEXITED 0 -> Some output
    | _err ->
      Error.raise "Command '%s' exited with error code %s" cmd
        ( match _err with
        | WEXITED n -> string_of_int n
        | WSIGNALED n -> Printf.sprintf "SIGNAL %d" n
        | WSTOPPED n -> Printf.sprintf "STOPPED %d" n )
  with
  | End_of_file -> None
  | e -> raise e

(* Return a tm with correct year and month *)
let date () =
  let time = Unix.gettimeofday () in
  let tm = Unix.gmtime time in
  { tm with tm_year = 1900 + tm.tm_year; tm_mon = tm.tm_mon + 1 }

open Types

let homepage p =
  match p.homepage with
  | Some s -> Some s
  | None -> (
    match p.github_organization with
    | Some organization ->
      Some
        (Printf.sprintf "https://%s.github.io/%s" organization p.package.name)
    | None -> None )

let sphinx_target p =
  option_value p.sphinx_target ~default:"sphinx"

let odoc_target p =
  option_value p.odoc_target ~default:"doc"

let doc_api p =
  match p.doc_api with
  | Some s -> Some s
  | None -> (
    match p.github_organization with
    | Some organization ->
      Some
        (Printf.sprintf "https://%s.github.io/%s/%s" organization
           p.package.name (odoc_target p))
    | None -> None )

let doc_gen p =
  match p.doc_gen with
  | Some s -> Some s
  | None ->
      match p.github_organization with
      | Some organization ->
          Some
            (Printf.sprintf "https://%s.github.io/%s/%s" organization
               p.package.name (sphinx_target p))
      | None -> None

let p_dependencies package =
  package.p_dependencies @ package.project.dependencies

let p_mode package =
  match package.p_mode with
  | Some deps -> deps
  | None -> Binary

let p_pack_modules package =
  match package.p_pack_modules with
  | Some deps -> deps
  | None -> true

let p_version package =
  match package.p_version with
  | Some deps -> deps
  | None -> package.project.version

let p_tools package = package.p_tools @ package.project.tools

let p_synopsis package =
  match package.p_synopsis with
  | Some deps -> deps
  | None -> package.project.synopsis

let p_description package =
  match package.p_description with
  | Some deps -> deps
  | None -> package.project.description

let p_authors package =
  match package.p_authors with
  | Some deps -> deps
  | None -> package.project.authors

let wget ~url ~output =
  let dirname = Filename.dirname output in
  if not (Sys.file_exists dirname) then EzFile.make_dir ~p:true dirname;
  call
    [| "curl";
       "-f";
       "--write-out";
       "%{http_code}\\n";
       "--retry";
       "3";
       "--retry-delay";
       "2";
       "--user-agent";
       "drom/0.1.0";
       "-L";
       "-o";
       output;
       url
    |]

let bug_reports p =
  match p.bug_reports with
  | Some s -> Some s
  | None -> (
    match p.github_organization with
    | Some organization ->
      Some
        (Printf.sprintf "https://github.com/%s/%s/issues" organization
           p.package.name)
    | None -> None )

let subst s f =
  let b = Buffer.create (2 * String.length s) in
  Buffer.add_substitute b f s;
  Buffer.contents b

let list_opam_packages dir =
  let packages = ref [] in
  let files =
    match Sys.readdir dir with
    | exception _ -> [||]
    | files -> files
  in
  Array.iter
    (fun file ->
      if Filename.check_suffix file ".opam" then
        let package = Filename.chop_suffix file ".opam" in
        packages := package :: !packages)
    files;
  !packages

let semantic_version version =
  match EzString.split version '.' with
  | [ major; minor; fix ] -> (
    try Some (int_of_string major, int_of_string minor, int_of_string fix)
    with Failure _ -> None )
  | _ -> None

let underscorify s =
  let b = Bytes.of_string s in
  for i = 1 to String.length s - 2 do
    let c = s.[i] in
    match c with
    | 'a' .. 'z'
    | 'A' .. 'Z'
    | '0' .. '9' ->
      ()
    | _ -> Bytes.set b i '_'
  done;
  Bytes.to_string b

let library_name p =
  match p.p_pack with
  | Some name -> String.uncapitalize name
  | None -> underscorify p.name

let package_lib package = underscorify package.name ^ "_lib"

let deps_package p =
  let packages = ref StringSet.empty in
  List.iter
    (fun package -> packages := StringSet.add package.name !packages)
    p.packages;
  let p_dependencies =
    List.flatten (List.map (fun pk -> pk.p_dependencies) p.packages)
  in
  let p_tools = List.flatten (List.map (fun pk -> pk.p_tools) p.packages) in
  let p_dependencies =
    List.filter
      (fun (name, _d) -> not (StringSet.mem name !packages))
      p_dependencies
  in
  let p_tools =
    List.filter (fun (name, _d) -> not (StringSet.mem name !packages)) p_tools
  in
  { p.package with
    name = p.package.name ^ "-deps";
    p_synopsis = Some (p.synopsis ^ " (all deps)");
    p_dependencies;
    p_tools
  }

let modules package =
  let files = try Sys.readdir package.dir with _ -> [||] in
  let set = ref StringSet.empty in
  let add_module file =
    let m = String.capitalize file in
    set := StringSet.add m !set
  in
  Array.iter
    (fun file ->
      match EzString.chop_suffix file ~suffix:".ml" with
      | Some file -> add_module file
      | None -> (
        match EzString.chop_suffix file ~suffix:".mll" with
        | Some file -> add_module file
        | None -> (
          match EzString.chop_suffix file ~suffix:".mly" with
          | Some file -> add_module file
          | None -> () ) ))
    files;
  StringSet.to_list !set

let add_skip name list =
  List.map
    (fun (file, content) -> (file, Printf.sprintf "!{%s:skip}%s" name content))
    list

let dev_repo p =
  match p.dev_repo with
  | Some s -> Some s
  | None -> (
    match p.github_organization with
    | Some organization ->
      Some
        (Printf.sprintf "https://github.com/%s/%s" organization p.package.name)
    | None -> None )

let vendor_packages () =
  let vendors_dir = "vendors" in
  (try Sys.readdir vendors_dir with _ -> [||])
  |> Array.map (fun dir ->
         let dir = vendors_dir // dir in
         (try Sys.readdir dir with Not_found -> [||])
         |> Array.map (fun file ->
                if Filename.check_suffix file ".opam" then
                  Some (dir // file)
                else
                  None)
         |> Array.to_list
         |> List.filter (function
              | None -> false
              | Some _file -> true)
         |> List.map (function
              | None -> assert false
              | Some file -> file))
  |> Array.to_list |> List.flatten

let library_module p =
  match p.p_pack with
  | Some name -> name
  | None -> String.capitalize (underscorify p.name)

let string_of_kind = function
  | Program -> "program"
  | Library -> "library"
  | Virtual -> "virtual"

let project_skeleton = function
  | None -> "program"
  | Some skeleton -> skeleton

let package_skeleton package =
  match package.p_skeleton with
  | Some skeleton -> skeleton
  | None -> string_of_kind package.kind

let hook ?(args=[]) script =
  if Sys.file_exists script then
    call ( Array.of_list (script :: args) )

let before_hook ?args command =
  hook ?args (Printf.sprintf "./scripts/before-%s.sh" command)

let after_hook ?args command =
  hook ?args (Printf.sprintf "./scripts/after-%s.sh" command)

let default_ci_systems =
  [ "ubuntu-latest" ; "macos-latest" ; "windows-latest" ]

let editor () =
  match Sys.getenv "EDITOR" with
  | exception Not_found -> "emacs"
  | editor -> editor
