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

let ignore _p = {|
vendor/*/*
vendor/*/*/*
vendor/*/*/*/*
|}

let template = {|
# profile=conventional
# margin=80
# parens-ite=true
# if-then-else=k-r
# parens-tuple=always
# type-decl=sparse
# space-around-collection-expressions=false
# break-cases=toplevel
# cases-exp-indent=2
# leading-nested-match-parens=true
# module-item-spacing=preserve
# doc-comments=after
# break-separators=after-and-docked
|}


let template _p =
  let file = Globals.xdg_config_dir // "ocamlformat" in
  try EzFile.read_file file with
  | _exn ->
      template
