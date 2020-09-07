(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type tree =
  | Branch of string * tree list

let last_indent = "\226\148\148\226\148\128\226\148\128"
let middle_indent = "\226\148\160\226\148\128\226\148\128"

let print_tree indent tree =
  let rec iter indent ~last = function
    | Branch ( s , branches ) ->
        match branches with
        | [] ->
            Printf.printf "%s%s%s\n"
              indent
              (if last then
                 last_indent
               else
                 middle_indent
              )
              s
        | branches ->
            Printf.printf "%s%s%s\n"
              indent
              (if last then
                 last_indent
               else
                 middle_indent
              )
              s ;
            let indent = indent ^ (if last then "   " else
                                     "\226\148\160  " ) in
            iter_branches indent branches

  and iter_branches indent = function
    | [] -> assert false
    | [ branch ] ->
        iter indent ~last:true branch
    | branch :: (  ( _ :: _ ) as branches ) ->
        iter indent ~last:true branch ;
        iter_branches indent branches
  in
  iter indent ~last:true tree
