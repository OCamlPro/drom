(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzCompat

let call ?(stdout = Unix.stdout) args =
  Printf.eprintf "Calling %s\n%!"
    (String.concat " " ( Array.to_list args ) );
  let pid = Unix.create_process args.(0) args
      Unix.stdin stdout Unix.stderr in
  let rec iter () =
    match Unix.waitpid [ ] pid with
    | exception (Unix.Unix_error (EINTR, _, _)) -> iter ()
    | _pid, status ->
      match status with
      | WEXITED 0 -> ()
      | _ ->
        Error.raise "Command '%s' exited with error code %s"
          (String.concat " " (Array.to_list args))
          (match status with
           | WEXITED n -> string_of_int n
           | WSIGNALED n -> Printf.sprintf "SIGNAL %d" n
           | WSTOPPED n -> Printf.sprintf "STOPPED %d" n
          )
  in
  iter ()

(* Return a tm with correct year and month *)
let date () =
  let time= Unix.gettimeofday () in
  let tm = Unix.gmtime time in
  { tm with
    tm_year = 1900 + tm.tm_year ;
    tm_mon = tm.tm_mon + 1 ;
  }

open Types

let homepage p =
  match p.homepage with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "https://%s.github.io/%s"
               organization p.package.name )
    | None -> None

let doc_api p =
  match p.doc_api with
  | Some s -> Some s
  | None ->
    match p.kind with
    | Program -> None
    | Library | Both ->
      match p.github_organization with
      | Some organization ->
        Some ( Printf.sprintf "https://%s.github.io/%s/doc"
                 organization p.package.name )
      | None -> None

let doc_gen p =
  match p.doc_gen with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "https://%s.github.io/%s/sphinx"
               organization p.package.name )
    | None -> None

let opam ?(y=false) cmd args =
  call
    (Array.of_list
       (
         [ "opam" ] @
         cmd @
         ( if y then [ "-y" ] else [] )
         @
         args ))

let string_of_dependency d =
  match d.depname with
  | None -> d.depversion
  | Some depname -> Printf.sprintf "%s %s" d.depversion depname

let dependency_of_string ~name s =
  match EzString.split s ' ' with
  | [] -> Error.raise "dependency %S: no version" name
  | _ :: _ :: _ :: _ ->
    Error.raise "dependency %S: unparsable version %S" name s
  | [ depversion ] -> { depversion ; depname = None }
  | [ depversion ; depname ] -> { depversion ; depname = Some depname }

let p_dependencies package =
  match package.p_dependencies with
  | Some deps -> deps
  | None -> package.project.dependencies

let p_mode package =
  match package.p_mode with
  | Some deps -> deps
  | None -> package.project.mode

let p_kind package =
  match package.p_kind with
  | Some deps -> deps
  | None -> package.project.kind

let p_pack_modules package =
  match package.p_pack_modules with
  | Some deps -> deps
  | None -> package.project.pack_modules

let p_version package =
  match package.p_version with
  | Some deps -> deps
  | None -> package.project.version

let p_tools package =
  match package.p_tools with
  | Some deps -> deps
  | None -> package.project.tools

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
  if not ( Sys.file_exists dirname ) then
    EzFile.make_dir ~p:true dirname;
  call [| "curl" ;
          "--write-out" ; "%{http_code}\\n" ;
          "--retry" ; "3" ;
          "--retry-delay" ; "2" ;
          "--user-agent" ; "opam-bin/2.0.5" ;
          "-L" ;
          "-o" ; output ;
          url
       |]


let bug_reports p =
  match p.bug_reports with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "https://github.com/%s/%s/issues"
               organization p.package.name )
    | None -> None


let subst s f =
  let b = Buffer.create ( 2 * String.length s ) in
  Buffer.add_substitute b f s;
  Buffer.contents b

let list_opam_packages dir =
  let packages = ref [] in
  let files = match Sys.readdir dir with
    | exception _ -> [||]
    | files -> files
  in
  Array.iter (fun file ->
      if Filename.check_suffix file ".opam" then
        let package = Filename.chop_suffix file ".opam" in
        packages := package :: !packages
    ) files ;
  !packages

let semantic_version version =
  match EzString.split version '.' with
    [ major ; minor ; fix ] ->
    begin try
        Some ( int_of_string major, int_of_string minor, int_of_string fix )
      with
        Not_found -> None
    end
  | _ -> None


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
