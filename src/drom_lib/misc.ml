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
    else None

  let chop_suffix s ~suffix =
    if EzString.ends_with s ~suffix then
      let suffix_len = String.length suffix in
      let len = String.length s in
      Some (String.sub s 0 (len - suffix_len))
    else None
end

let call ?(stdout = Unix.stdout) args =
  if !Globals.verbose then
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
            (Printf.sprintf "https://%s.github.io/%s" organization
               p.package.name)
      | None -> None )

let doc_api p =
  match p.doc_api with
  | Some s -> Some s
  | None -> (
      match p.github_organization with
      | Some organization ->
          Some
            (Printf.sprintf "https://%s.github.io/%s/doc" organization
               p.package.name)
      | None -> None )

let doc_gen p =
  match p.doc_gen with
  | Some s -> Some s
  | None -> (
      match
        match p.sphinx_target with
        | Some dir -> EzString.chop_prefix dir ~prefix:"docs"
        | None -> Some "/sphinx"
      with
      | None -> None
      | Some subdir -> (
          match p.github_organization with
          | Some organization ->
              Some
                (Printf.sprintf "https://%s.github.io/%s%s" organization
                   p.package.name subdir)
          | None -> None ) )

let p_dependencies package =
  package.p_dependencies @ package.project.dependencies

let p_mode package =
  match package.p_mode with Some deps -> deps | None -> package.project.mode

let p_pack_modules package =
  match package.p_pack_modules with
  | Some deps -> deps
  | None -> package.project.pack_modules

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
    [|
      "curl";
      "--write-out";
      "%{http_code}\\n";
      "--retry";
      "3";
      "--retry-delay";
      "2";
      "--user-agent";
      "opam-bin/2.0.5";
      "-L";
      "-o";
      output;
      url;
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
    match Sys.readdir dir with exception _ -> [||] | files -> files
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
      with Not_found -> None )
  | _ -> None

let underscorify s =
  let b = Bytes.of_string s in
  for i = 1 to String.length s - 2 do
    let c = s.[i] in
    match c with
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' -> ()
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
  {
    p.package with
    name = p.package.name ^ "-deps";
    p_synopsis = Some (p.synopsis ^ " (all deps)");
    p_dependencies;
    p_tools;
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
            (Printf.sprintf "https://github.com/%s/%s" organization
               p.package.name)
      | None -> None )

let vendor_packages () =
  let vendors_dir = "vendors" in
  ( try Sys.readdir vendors_dir with _ -> [||] )
  |> Array.map (fun dir ->
      let dir = vendors_dir // dir in
      ( try Sys.readdir dir with Not_found -> [||] )
      |> Array.map (fun file ->
          if Filename.check_suffix file ".opam" then
            Some ( dir // file )
          else None
        )
      |> Array.to_list
      |> List.filter (function
          | None -> false
          | Some _file -> true)
      |> List.map (function
            None -> assert false
          | Some file -> file)
    )
  |> Array.to_list
  |> List.flatten
