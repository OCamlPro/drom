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
open EzFile.OP

let config =
  lazy
    (Configparser.parse_string
       (EzFile.read_file (Globals.home_dir // ".gitconfig")))

let user () = Configparser.get (Lazy.force config) "user" "name"

let email () = Configparser.get (Lazy.force config) "user" "email"


let call args =
  Misc.call ( Array.of_list ( "git" :: args ))

let run args =
  try call args  with _ -> ()

open Configparser

let update_submodules () =

  if Sys.file_exists ".gitmodules" then
    let gitmodules =
      Configparser.parse_string
        (EzFile.read_file ".gitmodules")
    in
    let inited = ref false in
    let init () =
      if not !inited then begin
        run [ "submodule" ; "init" ];
        inited := true
      end
    in
    StringMap.iter (fun _section_name section ->
        match StringMap.find "path" section.section_options with
        | exception Not_found -> ()
        | path ->
            if not ( Sys.file_exists path ) then begin
              init () ;
              run [ "submodule" ; "update" ; path ]
            end
      ) gitmodules.sections

let remove dir =
  Misc.call [| "rm" ; "-rf" ; dir |];
  run [ "rm" ; "-rf" ; dir ]

let rename old_dir new_dir =
  Misc.call [| "mv" ; old_dir ; new_dir |];
  run [ "rm" ; "-rf" ; old_dir ] ;
  run [ "add" ; new_dir ]
