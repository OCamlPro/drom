(**************************************************************************)
(*                                                                        *)
(*  Copyright (c) 2020 OCamlPro                                           *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  This file is distributed under the terms of the GNU Lesser General    *)
(*  Public License version 2.1, with the special exception on linking     *)
(*  described in the LICENSE.md file in the root directory.               *)
(*                                                                        *)
(**************************************************************************)

module EZ_SUBST = struct
  (* TODO: add '\\' as escape character *)

  type 'context t = 'context -> string -> string

  exception UnclosedExpression of string

  let escape = ref true

  let check = function
    | [] -> false
    | p :: _ -> not p

  let buffer ?(sep = '$') ?(sym = false) ?(fail = true) ?(escape = escape)
      ?skipper ?brace ?paren ?bracket ?var ~ctxt b s =
    let len = String.length s in

    let rec iter b skip stack i =
      (* default state *)
      if i = len then
        match stack with
        | [] -> ()
        | (_eoi, f, b1, skip1) :: stack ->
          if fail then
            raise (UnclosedExpression (Buffer.contents b))
          else
            replace b1 skip1 f b stack i
      else
        let c = s.[i] in
        if c = sep then
          iter1 b skip stack (i + 1)
        else if c = '\\' && !escape then
          iter3 b skip stack (i + 1)
        else
          match stack with
          | [] ->
            if check skip then Buffer.add_char b c;
            iter b skip stack (i + 1)
          | (eoi, f, b1, skip1) :: stack1 ->
            if c = eoi then
              if sym then
                iter2 b skip stack eoi (i + 1)
              else
                replace b1 skip1 f b stack1 (i + 1)
            else (
              if check skip then Buffer.add_char b c;
              iter b skip stack (i + 1)
            )
    and iter1 b skip stack i =
      (* found '$' *)
      if i = len then (
        if check skip then Buffer.add_char b sep;
        iter b skip stack i
      ) else
        let c = s.[i] in
        match (c, brace, paren, bracket, var) with
        | '{', Some f, _, _, _ ->
          iter (Buffer.create 16) [ false ] (('}', f, b, skip) :: stack) (i + 1)
        | '(', _, Some f, _, _ ->
          iter (Buffer.create 16) [ false ] ((')', f, b, skip) :: stack) (i + 1)
        | '[', _, _, Some f, _ ->
          iter (Buffer.create 16) [ false ] ((']', f, b, skip) :: stack) (i + 1)
        | ('a' .. 'z' | 'A' .. 'Z'), _, _, _, Some f ->
          let b1 = Buffer.create 16 in
          Buffer.add_char b1 c;
          iter4 b1 [ false ] (('_', f, b, skip) :: stack) (i + 1)
        | _ ->
          if check skip then Buffer.add_char b sep;
          iter b skip stack i
    and iter2 b skip stack eoi i =
      (* stack<>[] & found '}', need '$' *)
      if i = len then
        if fail then
          raise (UnclosedExpression (Buffer.contents b))
        else
          match stack with
          | [] -> assert false
          | (_eoi, f, b1, skip1) :: stack -> replace b1 skip1 f b stack i
      else
        let c = s.[i] in
        if c = sep then
          match stack with
          | [] -> assert false
          | (_eoi, f, b1, skip1) :: stack -> replace b1 skip1 f b stack (i + 1)
        else (
          if check skip then Buffer.add_char b eoi;
          iter b skip stack i
        )
    and iter3 b skip stack i =
      (* found '\\' *)
      if i = len then (
        if check skip then Buffer.add_char b '\\';
        iter b skip stack i
      ) else (
        if check skip then Buffer.add_char b s.[i];
        iter b skip stack (i + 1)
      )
    and iter4 b skip stack i =
      (* default state *)
      if i = len then
        match stack with
        | [] -> assert false
        | (_eoi, f, b1, skip1) :: stack -> replace b1 skip1 f b stack i
      else
        let c = s.[i] in
        match c with
        | 'A' .. 'Z'
        | 'a' .. 'z'
        | '_'
        | '0' .. '9' ->
          if check skip then Buffer.add_char b c;
          iter4 b skip stack (i + 1)
        | _ -> (
          match stack with
          | [] -> assert false
          | (_eoi, f, b1, skip1) :: stack -> replace b1 skip1 f b stack i )
    and replace b1 skip1 f b stack i =
      let ident = Buffer.contents b in
      ( match skipper with
      | None -> ()
      | Some skipper -> skipper := skip1 );
      let replacement = f ctxt ident in
      let skip1 =
        match skipper with
        | None -> skip1
        | Some skipper -> !skipper
      in
      if check skip1 then Buffer.add_string b1 replacement;
      iter b1 skip1 stack i
    in

    iter b [ false ] [] 0

  let string ?sep ?sym ?fail ?escape ?skipper ?brace ?paren ?bracket ?var ~ctxt
      s =
    let b = Buffer.create (String.length s) in
    buffer ?sep ?sym ?escape ?skipper ?fail ?brace ?paren ?bracket ?var b ~ctxt
      s;
    Buffer.contents b

  exception UnknownExpression of string

  let string_from_list ?sep ?sym ?(fail = true) ?(brace = true) ?(paren = true)
      ?(bracket = true) ?(var = true) ?default list s =
    let ctxt = default in
    let subst default s =
      match List.assoc s list with
      | s -> s
      | exception Not_found -> (
        match default with
        | Some s -> s
        | None ->
          if fail then
            raise (UnknownExpression s)
          else
            s )
    in
    let subst flag =
      if flag then
        Some subst
      else
        None
    in
    let brace = subst brace in
    let paren = subst paren in
    let bracket = subst bracket in
    let var = subst var in
    string ?sep ?sym ~fail ?brace ?paren ?bracket ?var ~ctxt s
end
