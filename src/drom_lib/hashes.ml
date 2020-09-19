(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzCompat

(* Management of .drom file of hashes *)

type t = {
  mutable hashes : string StringMap.t ;
  mutable modified : bool ;
}

let load () =
  let hashes =
    if Sys.file_exists ".drom" then (
      let map = ref StringMap.empty in
      (* Printf.eprintf "Loading .drom\n%!"; *)
      Array.iter
        (fun line ->
           if line <> "" && line.[0] <> '#' then
             let digest, filename = EzString.cut_at line ' ' in
             let digest = Digest.from_hex digest in
             map := StringMap.add filename digest !map)
        (EzFile.read_lines ".drom");
      !map )
    else StringMap.empty
  in
  { hashes ; modified = false }

let save t =
  let { hashes ; modified } = t in
  if modified then begin
    let b = Buffer.create 1000 in
    Printf.bprintf b
      "# Keep this file in your GIT repo to help drom track generated files\n";
    StringMap.iter
      (fun filename hash ->
         Printf.bprintf b "%s %s\n" (Digest.to_hex hash) filename)
      hashes;
    EzFile.write_file ".drom" (Buffer.contents b);
    t.modified <- false
  end

let update t file hash =
  t.hashes <- StringMap.add file hash t.hashes;
  t.modified <- true

let remove t file =
  t.hashes <- StringMap.remove file t.hashes;
  t.modified <- true

let get t file =
  StringMap.find file t.hashes

let digest_file file = Digest.file file
let digest_string file = Digest.string file

let with_ctxt f =
  let t = load () in
  f t;
  save t
