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

let cmd_name = "opam-plugin"

let action ~remove () =
  let root = Globals.opam_root () in
  let plugins_dir = root // "plugins" in
  let plugins_bin_dir = plugins_dir // "bin" in
  let plugins_bin_exe = plugins_bin_dir // "opam-drom" in
  let plugins_drom_dir = plugins_dir // "opam-drom" in
  if remove then begin
    Misc.call [| "rm" ; "-f" ; plugins_bin_exe |];
    Misc.call [| "rm" ; "-rf" ; plugins_drom_dir |];
  end else
    match Config.find_share_dir ~for_copy:true () with
    | None ->
        Printf.eprintf
          "Error: share dir not specified. Aborting\n%!";
        exit 2
    | Some share_dir ->
        if Sys.file_exists share_dir then begin
          EzFile.make_dir ~p:true plugins_bin_dir;
          Misc.call [| "cp"; "-f"; Sys.executable_name;
                       plugins_bin_exe |];
          Misc.call [| "rm" ; "-rf" ; plugins_drom_dir |];
          Misc.call [| "cp"; "-r"; share_dir ; plugins_drom_dir |];
          Printf.printf "drom has been installed as an opam plugin:\n";
          Printf.printf "  You can now call it with 'opam drom COMMAND'\n%!";
        end else begin
          Printf.eprintf
            "Error: share dir %s does not exist. Aborting\n%!" share_dir;
          exit 2
        end

let cmd =
  let remove = ref false in
  EZCMD.sub cmd_name
    (fun () -> action ~remove:!remove ())
    ~args: [
      [ "remove" ] , Arg.Set remove,
      EZCMD.info "Remove drom as an opam plugin";
    ]
    ~doc: "Install drom as an opam plugin (called by 'opam drom')"
    ~version: "0.2.1"
    ~man: [
      `S "DESCRIPTION";
      `Blocks [
        `P "This command performs the following actions:";
        `I ("1.", "Install drom executable in $(b,$OPAMROOT/plugins/bin/opam-drom)");
        `I ("2.", "Install drom share files in $(b,$OPAMROOT/plugins/opam-drom), removing former files");
      ]
    ]
