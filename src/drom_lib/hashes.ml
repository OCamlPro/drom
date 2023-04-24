(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ez_file.V1
open EzCompat

(* Management of .drom file of hashes *)

module HASH : sig

  type hash

  val digest_content : ?perm:int -> file:string -> content:string -> unit ->
    hash
  val digest_file : string -> hash

  val from_hex : string -> hash
  val to_hex : hash -> string
  val to_string : hash -> string
  val old_string_hash : string -> hash

end = struct

  include Digest

  type hash = string

  let digest_content ?(perm = 0o644) ~file ~content () =
    let content =
      if Filename.check_suffix file ".sh" then
        String.concat "" (EzString.split content '\r')
      else
        content
    in
    let perm = (perm lsr 6) land 7 in
    Digest.string (Printf.sprintf "%s.%d" content perm)

  let digest_file file =
    let content = EzFile.read_file file in
    let perm = (Unix.lstat file).Unix.st_perm in
    digest_content ~perm ~content ~file ()

  let to_string s = s
  let old_string_hash = Digest.string

end

include HASH

type t =
  { mutable hashes : hash list StringMap.t;
    mutable modified : bool;
    mutable files : (bool * string * int) StringMap.t;
    (* for git *)
    mutable to_add : StringSet.t;
    mutable to_remove : StringSet.t;
    mutable skel_version : string option
  }

let load () =
  let version = ref None in
  let hashes =
    if Sys.file_exists ".drom" then (
      let map = ref StringMap.empty in
      (* Printf.eprintf "Loading .drom\n%!"; *)
      Array.iteri
        (fun i line ->
           try
             let len = String.length line in
             if len > 2 && match line.[0] with
               | '#'
               | '=' | '<' | '>' (* git conflict ! *)
                 -> false
               | _ -> true then
               let digest, filename =
                 if String.contains line ':' then
                   EzString.cut_at line ':'
                 else
                   EzString.cut_at line ' '
                   (* only for backward compat *)
               in
               if digest = "version" then
                 version := Some filename
               else
                 let digest = HASH.from_hex digest in
                 let hashes =
                   match StringMap.find filename !map with
                   | exception Not_found -> []
                   | hashes -> hashes
                 in
                 map := StringMap.add filename (digest :: hashes) !map
           with
           | exn ->
               Printf.eprintf "Error loading .drom at line %d: %s\n%!" (i + 1)
                 (Printexc.to_string exn);
               Printf.eprintf " on line: %s\n%!" line;
               exit 2 )
        (EzFile.read_lines ".drom");
      !map
    ) else
      StringMap.empty
  in
  { hashes;
    files = StringMap.empty;
    modified = false;
    to_add = StringSet.empty;
    to_remove = StringSet.empty;
    skel_version = !version
  }

let write t ~record ~perm ~file ~content =
  t.files <- StringMap.add file (record, content, perm) t.files;
  t.modified <- true

let read t ~file =
  match StringMap.find file t.files with
  | exception Not_found -> EzFile.read_file file
  | (_record, content, _perm) -> content

let get t file = StringMap.find file t.hashes

let update ?(git = true) t file hashes =
  t.hashes <- StringMap.add file hashes t.hashes;
  if git then t.to_add <- StringSet.add file t.to_add;
  t.modified <- true

let remove t file =
  t.hashes <- StringMap.remove file t.hashes;
  t.to_remove <- StringSet.add file t.to_remove;
  t.modified <- true

let rename t ~src ~dst =
  match get t src with
  | exception Not_found -> ()
  | digest ->
    remove t src;
    update t dst digest

(* only compare the 3 user permissions. Does it work on Windows ? *)
let perm_equal p1 p2 = (p1 lsr 6) land 7 = (p2 lsr 6) land 7

let save ?(git = true) t =
  if t.modified then begin
    StringMap.iter
      (fun file (record, content, perm) ->
        let dirname = Filename.dirname file in
        if not (Sys.file_exists dirname) then EzFile.make_dir ~p:true dirname;
        EzFile.write_file file content;
        Unix.chmod file perm;
        if record then update t file [digest_content ~file ~perm ~content ()] )
      t.files;

    let b = Buffer.create 1000 in
    Printf.bprintf b
      "# Keep this file in your GIT repo to help drom track generated files\n";
    Printf.bprintf b "# begin version\n%!";
    Printf.bprintf b "version:%s\n%!" (match t.skel_version with
        | None -> assert false
        | Some version -> version);
    Printf.bprintf b "# end version\n%!";
    StringMap.iter
      (fun filename hashes ->
        if Sys.file_exists filename then begin
          if filename = "." then begin
            Printf.bprintf b "\n# hash of toml configuration files\n";
            Printf.bprintf b "# used for generation of all files\n"
          end else begin
            Printf.bprintf b "\n# begin context for %s\n" filename;
            Printf.bprintf b "# file %s\n" filename
          end;
          List.iter (fun hash ->
              Printf.bprintf b "%s:%s\n" (HASH.to_hex hash) filename
            ) (List.rev hashes);
          Printf.bprintf b "# end context for %s\n" filename
        end )
      t.hashes;
    EzFile.write_file ".drom" (Buffer.contents b);

    if git && Sys.file_exists ".git" then begin
      let to_remove = ref [] in
      StringSet.iter
        (fun file ->
           if Sys.file_exists file then
             to_remove := file :: !to_remove
        )
        t.to_remove;
      if !to_remove <> [] then begin
        Git.remove ~silent:true ("-f" :: !to_remove);
      end;
      let to_add = ref [] in
      StringSet.iter
        (fun file -> if Sys.file_exists file then to_add := file :: !to_add)
        t.to_add;
      Git.add ~silent:true (".drom" :: !to_add)
    end;
    t.to_add <- StringSet.empty;
    t.to_remove <- StringSet.empty;
    t.modified <- false
  end

let with_ctxt ?git f =
  let t = load () in
  begin
    match t.skel_version with
    | Some "0.8.0"
    | Some "0.9.0" -> ()
    | _ -> t.skel_version <- Some "0.9.0"
  end;
  match f t with
  | res ->
    save ?git t;
    res
  | exception exn ->
    let bt = Printexc.get_raw_backtrace () in
    save t;
    Printexc.raise_with_backtrace exn bt

let set_version t v =
  if t.skel_version <> Some v then begin
    t.modified <- true ;
    t.skel_version <- Some v
  end
