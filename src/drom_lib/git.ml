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

let call args = Call.call (Array.of_list ("git" :: args))

let run args =
  try call args with
  | _ -> ()

let update_submodules () =
  if Sys.file_exists ".gitmodules" then
    run [ "submodule"; "update"; "--init"; "--recursive" ]

let remove dir =
  Call.call [| "rm"; "-rf"; dir |];
  run [ "rm"; "-rf"; dir ]

let rename old_dir new_dir =
  Call.call [| "mv"; old_dir; new_dir |];
  run [ "rm"; "-rf"; old_dir ];
  run [ "add"; new_dir ]
