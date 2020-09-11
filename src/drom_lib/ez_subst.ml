(**************************************************************************)
(*                                                                        *)
(*  Copyright (c) 2020 OCamlPro & Origin Labs                             *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  This file is distributed under the terms of the GNU Lesser General    *)
(*  Public License version 2.1, with the special exception on linking     *)
(*  described in the LICENSE.md file in the root directory.               *)
(*                                                                        *)
(**************************************************************************)

(* TODO: add '\\' as escape character *)

type 'context t = ('context -> string -> string)

exception UnclosedExpression of string

let escape = ref true

let buffer ?(sep = '$') ?(sym=false) ?(escape=escape)
    ?brace ?paren ?bracket ?var b context s =
  let len = String.length s in

  let rec iter b stack i = (* default state *)
    if i = len then
      match stack with
      | [] -> ()
      | _b :: _ ->
          raise (UnclosedExpression ( Buffer.contents b ))
    else
      let c = s.[i] in
      if c = sep then
        iter1 b stack (i+1)
      else
      if c = '\\' && !escape then
        iter3 b stack (i+1)
      else
        match stack with
        | [] ->
            Buffer.add_char b c ;
            iter b stack (i+1)
        | (eoi, f, b1) :: stack1 ->
            if c = eoi then begin
              if sym then
                iter2 b stack eoi (i+1)
              else
                replace b1 f b stack1 (i+1)
            end
            else begin
              Buffer.add_char b c ;
              iter b stack (i+1)
            end

  and iter1 b stack i = (* found '$' *)
    if i = len then begin
      Buffer.add_char b sep;
      iter b stack i
    end
    else
      let c = s.[i] in
      match c, brace, paren, bracket, var with
      | '{', Some f, _, _, _ ->
          iter (Buffer.create 16) ( ('}', f, b) :: stack) (i+1)
      | '(', _, Some f, _, _ ->
          iter (Buffer.create 16) ( (')', f, b) :: stack) (i+1)
      | '[', _, _, Some f, _ ->
          iter (Buffer.create 16) ( (']', f, b) :: stack) (i+1)
      | ( 'a'..'z' |  'A'..'Z' ), _, _, _, Some f ->
          let b1 = Buffer.create 16 in
          Buffer.add_char b1 c;
          iter4 b1 ( ('_', f, b) :: stack) (i+1)
      | _ ->
          Buffer.add_char b sep;
          iter b stack i

  and iter2 b stack eoi i = (* stack<>[] & found '}', need '$' *)
    if i = len then
      raise (UnclosedExpression (Buffer.contents b))
    else
      let c = s.[i] in
      if c = sep then begin
        match stack with
        | [] -> assert false
        | ( _eoi, f, b1 ) :: stack ->
            replace b1 f b stack (i+1)
      end
      else begin
        Buffer.add_char b eoi;
        iter b stack i
      end

  and iter3 b stack i = (* found '\\' *)
    if i = len then begin
      Buffer.add_char b '\\';
      iter b stack i
    end
    else begin
      Buffer.add_char b s.[i];
      iter b stack (i+1)
    end

  and iter4 b stack i = (* default state *)
    if i = len then
      match stack with
      | [] -> assert false
      | ( _eoi, f, b1 ) :: stack ->
          replace b1 f b stack i
    else
      let c = s.[i] in
      match c with
      | 'A'..'Z' | 'a'..'z' | '_' | '0'..'9' ->
          Buffer.add_char b c;
          iter4 b stack (i+1)
      | _ ->
          match stack with
          | [] -> assert false
          | ( _eoi, f, b1 ) :: stack ->
              replace b1 f b stack i

  and replace b1 f b stack i =
    let ident = Buffer.contents b in
    let replacement = f context ident in
    Buffer.add_string b1 replacement;
    iter b1 stack i

  in
  iter b [] 0

let string ?sep ?sym ?escape ?brace ?paren ?bracket ?var context s =
  let b = Buffer.create ( String.length s ) in
  buffer ?sep ?sym ?escape ?brace ?paren ?bracket ?var b context s;
  Buffer.contents b
