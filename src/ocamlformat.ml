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

let skeleton_DOTocamlformat_ignore =
  {|!{ocamlformat:skip}
vendor/*/*
vendor/*/*/*
vendor/*/*/*/*
|}

let skeleton_DOTocamlformat =
  {|!{ocamlformat:skip}!{global-ocamlformat}
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

let find_global () =
  let file = Globals.xdg_config_dir // "ocamlformat" in
  try Some (EzFile.read_file file) with _exn -> None

let project_files =
  [
    (".ocamlformat", skeleton_DOTocamlformat);
    (".ocamlformat-ignore", skeleton_DOTocamlformat_ignore);
  ]
