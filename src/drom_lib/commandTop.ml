(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.V2
open EZCMD.TYPES
open Ez_file.V1
open EzFile.OP

let cmd_name = "top"

let action ~args cmd =
  let args =
    match Project.find ~display:false () with
    | None -> "ocaml" :: cmd
    | Some _ ->
      let (_p : Types.project) =
        Build.build ~dev_deps:true ~extra_packages:[ "utop" ] ~args ()
      in
      let init_file = Filename.temp_file "ocaml" ".init" in
      let stdout =
        Unix.openfile init_file [ Unix.O_CREAT; Unix.O_WRONLY ] 0o644
      in
      Call.call ~stdout [ "opam"; "exec"; "--"; "dune"; "top" ];
      Unix.close stdout;
      "utop" :: "-init" :: init_file :: cmd
  in
  let utop_history = Globals.home_dir // ".utop-history" in
  if not (Sys.file_exists utop_history) then begin
    let oc = open_out utop_history in
    close_out oc
  end;
  Call.call ("opam" :: "exec" :: "--" :: args)

let cmd =
  let cmd = ref [] in
  let args, specs = Build.build_args () in
  EZCMD.sub cmd_name
    (fun () -> action ~args !cmd)
    ~args:
      ( [ ( [],
            Arg.Anons (fun list -> cmd := list),
            EZCMD.info "Provide arguments for the ocaml toplevel" )
        ]
      @ specs )
    ~doc:"Run the ocaml toplevel"
