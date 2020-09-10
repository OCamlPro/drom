(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzFile.OP

let config =
  lazy
    (Configparser.parse_string
       (EzFile.read_file (Globals.home_dir // ".gitconfig")))

let user () = Configparser.get (Lazy.force config) "user" "name"

let email () = Configparser.get (Lazy.force config) "user" "email"

let template_DOTgitignore =
  {|
!{gitignore-programs}
*~
_build
.merlin
.vscode
/_drom
/_opam
/_build
|}

let project_files =
  Misc.add_skip "git" [ (".gitignore", template_DOTgitignore) ]
