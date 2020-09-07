(**************************************************************************)
(*                                                                        *)
(*  Copyright (c) 2020 OCamlPro SAS & Origin Labs SAS                     *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  This file is distributed under the terms of the GNU Lesser General    *)
(*  Public License version 2.1, with the special exception on linking     *)
(*  described in the LICENSE.md file in the root directory.               *)
(*                                                                        *)
(**************************************************************************)

(* Perform substitutions in a string.
   * the separator is $ by default
   * $$ is transformed into $
   * ${[^}]} is substituted by calling [f "\1"]
   No other transformation takes place.
   Compared to Buffer.add_substitute, this function provides two improvements:
   * the possibility to change '$' by any separator
   * the guarrantee that f is called from a string ${XXX}, and
       not $(XXX) or $XXX
 *)

let buffer ?(sep = '$') b ~f s =
  let lim = String.length s in
  let rec subst previous i =
    if i < lim then
      let current = s.[i] in
      if current = sep && previous = sep then (
        (* $$ *)
        Buffer.add_char b current;
        subst ' ' (i + 1) )
      else if current = '{' && previous = sep then (
        (* ${... *)
        let j = i + 1 in
        let ident, next_i = find_ident s j j lim in
        Buffer.add_string b
          ( try f ident
            with Not_found ->
              Printf.kprintf failwith
                "EzSubst.buffer: substitution for %S not found in\n%s" ident s
          );
        subst ' ' next_i )
      else if current = sep then subst current (i + 1)
      else (
        if previous = sep then Buffer.add_char b sep;
        Buffer.add_char b current;
        subst current (i + 1) )
    else if previous = sep then Buffer.add_char b sep
  and find_ident s i start lim =
    if i = lim then raise Not_found;
    if s.[i] = '}' then (String.sub s start (i - start), i + 1)
    else find_ident s (i + 1) start lim
  in
  subst ' ' 0

let string ?sep ~f s =
  let b = Buffer.create (String.length s) in
  buffer ?sep b ~f s;
  Buffer.contents b
