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
        Error.printf "Command '%s' exited with error code %s"
          (String.concat " " (Array.to_list args))
          (match status with
           | WEXITED n -> string_of_int n
           | WSIGNALED n -> Printf.sprintf "SIGNAL %d" n
           | WSTOPPED n -> Printf.sprintf "STOPPED %d" n
          )
  in
  iter ()

(* Return a tm with correct year *)
let date () =
  let time= Unix.gettimeofday () in
  let tm = Unix.gmtime time in
  { tm with tm_year = 1900 + tm.tm_year }

open Types

let homepage p =
  match p.homepage with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "https://%s.github.com/%s" organization p.name )
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
        Some ( Printf.sprintf "https://%s.github.com/%s/doc" organization p.name )
      | None -> None

let doc_gen p =
  match p.doc_gen with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "https://%s.github.com/%s/sphinx" organization p.name )
    | None -> None
