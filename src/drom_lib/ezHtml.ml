(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let buffer b s =
  let add = Printf.bprintf b in
  for i = 0 to String.length s - 1 do
    match s.[i] with
    | '&' -> add "&amp;"
    | '<' -> add "&lt;"
    | '>' -> add "&gt;"
    | '\'' -> add "&apos;"
    | '\"' -> add "&quot;"
    | '@' -> add "&commat;"
    | c ->
        Buffer.add_char b c
  done

let string s =
  let b = Buffer.create (String.length s + 11) in
  buffer b s;
  Buffer.contents b
