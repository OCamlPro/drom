(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

module TYPES = struct
  type tree = Branch of string * tree list
end

open TYPES

let up_down = "│  "

let up_right_down = "├──"

let up_right = "└──"

let print_tree indent tree =
  let rec iter indent ~last = function
    | Branch (s, branches) ->
      Printf.printf "%s%s %s\n" indent
        ( if last then
          up_right
        else
          up_right_down )
        s;
      iter_branches
        ( indent
        ^
        if last then
          "   "
        else
          up_down )
        branches
  and iter_branches indent = function
    | [] -> ()
    | [ branch ] -> iter (indent ^ " ") ~last:true branch
    | branch :: branches ->
      iter (indent ^ " ") ~last:false branch;
      iter_branches indent branches
  in
  iter indent ~last:true tree

let print_tree ?(indent = "") tree =
  print_tree indent tree
