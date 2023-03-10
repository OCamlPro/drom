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
    Call.call [ "rm"; "-f"; plugins_bin_exe ];
    Call.call [ "rm"; "-rf"; plugins_drom_dir ]
  end else begin
    EzFile.make_dir ~p:true plugins_bin_dir;
    Call.call [ "cp"; "-f"; Sys.executable_name; plugins_bin_exe ];
    Printf.printf "drom has been installed as an opam plugin:\n";
    Printf.printf "  You can now call it with 'opam drom COMMAND'\n%!"
  end

let cmd =
  let remove = ref false in
  EZCMD.sub cmd_name
    (fun () -> action ~remove:!remove ())
    ~args:
      [ ( [ "remove" ],
          Arg.Set remove,
          EZCMD.info "Remove drom as an opam plugin" )
      ]
    ~doc:"Install drom as an opam plugin (called by 'opam drom')"
    ~version:"0.2.1"
    ~man:
      [ `S "DESCRIPTION";
        `Blocks
          [ `P "This command performs the following actions:";
            `I
              ( "1.",
                "Install drom executable in \
                 $(b,$OPAMROOT/plugins/bin/opam-drom)" );
            `I
              ( "2.",
                "Install drom share files in $(b,$OPAMROOT/plugins/opam-drom), \
                 removing former files" )
          ]
      ]
