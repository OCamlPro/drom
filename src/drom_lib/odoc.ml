(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Types
open EzCompat

let subst ?(more = fun v -> Printf.sprintf "${%s}" v) package s =
  let b = Buffer.create (2 * String.length s) in
  Buffer.add_substitute b
    (function
      | "name" -> package.name
      | "pack" -> String.capitalize (Misc.library_name package)
      | "synopsis" -> Misc.p_synopsis package
      | "description" -> Misc.p_description package
      | "modules" -> String.concat " " (Misc.modules package)
      | v -> more v)
    s;
  Buffer.contents b

let template_src_index_mld p =
  match p.kind with
  | Virtual -> assert false
  | Library ->
      (* TODO: we should check pack-modules: if it is false, we have to
         find all the modules in the directory and generate a link
         for each module. *)
      if Misc.p_pack_modules p then
        Some
          (subst p
             {|
{1 Library ${name}}

${description}

The entry point of this library is the module: {!${pack}}.
|})
      else
        Some
          (subst p
             {|
{1 Library ${name}}

${description}

This library exposes the following toplevel modules: {!modules:${modules}}
|})
  | Program -> Some (subst p {|
{1 Program ${name}}

${description}
|})
