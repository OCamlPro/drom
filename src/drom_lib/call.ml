(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ez_file.V1
open EzCompat

let call
    ?(exec=false)
    ?(stdout = Unix.stdout)
    ?(stderr = Unix.stderr)
    ?print_args
    args =
  if Globals.verbose 1 then
    Printf.eprintf "Calling %s\n%!"
      (String.concat " "
         (match print_args with
          | None -> args
          | Some args -> args));
  let targs = Array.of_list args in
  if exec then begin
    (* TODO : redirect stdout and stderr *)
    Unix.execvp targs.(0) targs
  end else
    let pid = Unix.create_process targs.(0) targs
        Unix.stdin stdout stderr in
    let rec iter () =
      match Unix.waitpid [] pid with
      | exception Unix.Unix_error (EINTR, _, _) -> iter ()
      | _pid, status -> (
          match status with
          | WEXITED 0 -> ()
          | _ ->
              Error.raise "Command '%s' exited with error code %s"
                (String.concat " " args)
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
    [ "curl";
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
    ]

let hook ?(args = []) script =
  if Sys.file_exists script then call (script :: args)

let before_hook ?args ~command () =
  hook ?args (Printf.sprintf "./scripts/before-%s.sh" command)

let after_hook ?args ~command () =
  hook ?args (Printf.sprintf "./scripts/after-%s.sh" command)

let tmpfile () =
  Filename.temp_file "tmpfile" ".tmp"

(* Does not print anything, except in case of error. Exception on error *)
let silent ?print_args args =
  let out_file = tmpfile () in
  let fd = Unix.openfile out_file
      [ Unix.O_CREAT ; Unix.O_WRONLY ; Unix.O_TRUNC ] 0o644 in
  match call ?print_args args ~stdout:fd ~stderr:fd with
  | () ->
      Unix.close fd;
      Sys.remove out_file
  | exception exn ->
      Unix.close fd;
      let output = EzFile.read_file out_file in
      Sys.remove out_file;
      Printf.eprintf "%s\n%!" output;
      raise exn
