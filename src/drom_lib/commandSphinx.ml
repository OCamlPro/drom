(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.V2
open EZCMD.TYPES

let cmd_name = "sphinx"

let make_sphinx p =
  let dir = Misc.sphinx_target p in
  let sphinx_target = Format.sprintf "_drom/docs/%s" dir in
  Call.before_hook ~command:"sphinx" ~args:[ sphinx_target ] ();
  Call.call [ "sphinx-build"; "sphinx"; sphinx_target ];
  Call.after_hook ~command:"sphinx" ~args:[ sphinx_target ] ();
  sphinx_target

let action ~args ~open_www () =
  let (p : Types.project) = Build.build ~dev_deps:true ~args () in
  let sphinx_target = make_sphinx p in
  if !open_www then
    Call.call [ "xdg-open"; Filename.concat sphinx_target "index.html" ]

let cmd =
  let args, specs = Build.build_args () in
  let open_www = ref false in
  EZCMD.sub cmd_name
    (fun () -> action ~args ~open_www ())
    ~args:
      ( [ ( [ "view" ],
            Arg.Set open_www,
            EZCMD.info "Open a browser on the sphinx documentation" )
        ]
      @ specs )
    ~doc:"Generate documentation using sphinx"
    ~man:
      [ `S "DESCRIPTION";
        `Blocks
          [ `P "This command performs the following actions:";
            `I
              ( "1.",
                "Build the project, installing dev dependencies if not done \
                 yet (see $(b,drom build) and $(b,drom dev-deps) for more \
                 info)." );
            `I ("2.", "If a file $(i,scripts/before-sphinx.sh) exists, run it");
            `I
              ( "3.",
                "Build Sphinx documentation using the command $(b,sphinx-build \
                 sphinx _drom/docs/${sphinx-target}), where \
                 $(b,${sphinx-target}) is the $(b,sphinx-target) field in the \
                 project description, or $(b,sphinx) by default. Documentation \
                 source files are expected to be found in the top $(b,sphinx/) \
                 directory." );
            `I
              ( "4.",
                "If the argument $(b,--view) was specified, open a browser on \
                 the newly generated documentation" )
          ]
      ]
