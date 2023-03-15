(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let user () =
  match Call.call_get_fst_line "git config --get user.name" with
  | Some user -> user
  | None -> raise Not_found

let email () =
  match Call.call_get_fst_line "git config --get user.email" with
  | Some email -> email
  | None -> raise Not_found

let call ?cd cmd args =
  match cd with
  | Some cd ->
      let print_args = "git" :: cmd :: args in
      let args = "git" :: "-C" :: cd :: cmd :: args in
      Call.call ~print_args args
  | None -> Call.call ("git" :: cmd :: args)

let silent ?cd cmd args =
  match cd with
  | Some cd ->
      let print_args = "git" :: cmd :: args in
      let args = "git" :: "-C" :: cd :: cmd :: args in
      Call.silent ~print_args args
  | None -> Call.silent ("git" :: cmd :: args)

let silent_fail cmd args =
  try call cmd args with | _ -> ()

let update_submodules () =
  if Sys.file_exists ".gitmodules" then
    silent_fail "submodule" [ "update"; "--init"; "--recursive" ]

let add ?(silent=false) files =
  let config = Config.get () in
  match config.config_git_stage with
  | Some false -> ()
  | None | Some true ->
      if silent then
        silent_fail "add" files
      else
        call "add" files

let remove ?(silent=false) files =
  Call.call ("rm" :: "-rf" :: files );
  let config = Config.get () in
  match config.config_git_stage with
  | Some false -> ()
  | None | Some true ->
      if silent then
        silent_fail "rm" ("-rf" :: files)
      else
        call "rm" ("-rf" :: files)

let rename old_dir new_dir =
  Call.call [ "mv"; old_dir; new_dir ];
  let config = Config.get () in
  match config.config_git_stage with
  | Some false -> ()
  | None | Some true ->
      remove ~silent:true [ old_dir ];
      add ~silent:true [ new_dir ]
