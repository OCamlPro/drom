(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ez_file.V1
open EzCompat

let call ?(stdout = Unix.stdout) args =
  if Globals.verbose 1 then
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

let hook ?(args = []) script =
  if Sys.file_exists script then call (Array.of_list (script :: args))

let before_hook ?args command =
  hook ?args (Printf.sprintf "./scripts/before-%s.sh" command)

let after_hook ?args command =
  hook ?args (Printf.sprintf "./scripts/after-%s.sh" command)
