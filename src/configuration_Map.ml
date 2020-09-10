(* Configuration_Map -- Generic configuration facility

   Author: Michael Grünewald
   Date: Wed Oct 24 07:48:50 CEST 2012

   Copyright © 2012–2015 Michael Grünewald

   This file must be used under the terms of the CeCILL-B.
   This source file is licensed as described in the file COPYING, which
   you should have received as part of this distribution. The terms
   are also available at
   http://www.cecill.info/licences/Licence_CeCILL-B_V1-en.txt *)

open Printf

let path_to_string p k = String.concat "." (p @ [ k ])

let path_of_string s =
  let n = String.length s in
  let rec loop acc i =
    match String.index_from s i '.' with
    | j -> loop (String.sub s i (j - i) :: acc) (j + 1)
    | exception Not_found -> String.sub s i (n - i) :: acc
  in
  match loop [] 0 with
  | [] -> ksprintf failwith "%s.path_of_string: %S" __MODULE__ s
  | hd :: tl -> (List.rev tl, hd)

(* Finite automatons recognising globbing patterns. *)
module Glob = struct
  let rec list_match pattern text =
    match (pattern, text) with
    | [], [] -> true
    | '*' :: pattern_tl, [] -> list_match pattern_tl []
    | '*' :: pattern_tl, _text_hd :: text_tl ->
        list_match pattern_tl text || list_match pattern text_tl
    | '?' :: pattern_tl, _ :: text_tl -> list_match pattern_tl text_tl
    | pattern_hd :: pattern_tl, text_hd :: text_tl ->
        pattern_hd = text_hd && list_match pattern_tl text_tl
    | _ -> false

  let string_chars s =
    let rec loop ax i = if i < 0 then ax else loop (s.[i] :: ax) (i - 1) in
    loop [] (String.length s - 1)

  let string_match pattern text =
    list_match (string_chars pattern) (string_chars text)
end

(* We implement configuration sets as a functor parametrised by
   messages emitted on the occurence of various events. *)

module type MESSAGE = sig
  val value_error :
    string list -> string -> Lexing.position -> string -> string -> unit

  val uncaught_exn :
    string list -> string -> Lexing.position -> string -> exn -> unit

  val default : string list -> string -> unit

  val parse_error : Lexing.position -> string -> unit
end

module type S = sig
  type t

  type 'a key = {
    of_string : string -> 'a;
    path : string list;
    name : string;
    default : 'a;
    description : string;
  }

  val key : (string -> 'a) -> string list -> string -> 'a -> string -> 'a key

  val get : t -> 'a key -> 'a

  val value : 'a key -> string -> 'a

  type 'b editor

  val xmap : ('a -> 'b) -> ('b -> 'a -> 'a) -> 'b editor -> 'a editor

  val editor : 'a key -> ('a -> 'b -> 'b) -> 'b editor

  val apply : t -> 'b editor -> 'b -> 'b

  val empty : t

  val add : string list * string -> string -> t -> t

  val merge : t -> t -> t

  val override : t -> t -> t

  val from_file : string -> t

  val from_string : string -> t

  val from_alist : ((string list * string) * string) list -> t

  val to_alist : t -> ((string list * string) * string) list
end

(* We provide a simple implementation of the required associative
   structure based on alists.

   An implementation based on finite automatons could be interesting in
   the case where there is a large number of keys, because it would speed
   up the retrieval.

   It is not possible to use an hashtable because keys could be patterns. *)
module Make (M : MESSAGE) = struct
  type t = (string * (string * Lexing.position)) list

  type 'a key = {
    of_string : string -> 'a;
    path : string list;
    name : string;
    default : 'a;
    description : string;
  }

  type 'b editor = {
    editor_path : string list;
    editor_name : string;
    editor_description : string;
    editor_f : t -> 'b -> 'b;
  }

  let xmap get set editor =
    let editor_f conf x = set (editor.editor_f conf (get x)) x in
    { editor with editor_f }

  let key c p k def des =
    { of_string = c; path = p; name = k; default = def; description = des }

  let assoc key conf =
    let path_as_string = path_to_string key.path key.name in
    let string_match (glob, _data) = Glob.string_match glob path_as_string in
    snd (List.find string_match conf)

  let use_default key =
    M.default key.path key.name;
    key.default

  let positioned_value pos key text =
    try key.of_string text with
    | Failure mesg ->
        M.value_error key.path key.name pos text mesg;
        use_default key
    | exn ->
        M.uncaught_exn key.path key.name pos text exn;
        use_default key

  let value key text = positioned_value Lexing.dummy_pos key text

  let get a key =
    try
      let text, pos = assoc key a in
      positioned_value pos key text
    with Not_found -> use_default key

  let editor key edit =
    let editor_f conf = edit (get conf key) in
    {
      editor_path = key.path;
      editor_name = key.name;
      editor_description = key.description;
      editor_f;
    }

  let apply conf editor = editor.editor_f conf

  let empty = []

  let add (p, k) v a = (path_to_string p k, (v, Lexing.dummy_pos)) :: a

  let merge a b = a @ b

  let rec override_loop a b ax =
    match a with
    | [] -> List.rev ax
    | (k, v) :: t ->
        if List.mem_assoc k b then override_loop t b ((k, List.assoc k b) :: ax)
        else override_loop t b ((k, v) :: ax)

  let override a b = override_loop a b []

  (* Definition of our configuration parser *)
  module Parser_definition = struct
    type configuration = t

    type t = { path : string list; conf : configuration }

    let comment _ state = state

    let section l state =
      { state with path = List.map Configuration_Parser.text l }

    let binding k v state =
      let path = path_to_string state.path (Configuration_Parser.text k) in
      let text = Configuration_Parser.text v in
      let pos = Configuration_Parser.startpos v in
      { state with conf = (path, (text, pos)) :: state.conf }

    let parse_error pos error state =
      M.parse_error pos (Configuration_Parser.error_to_string error);
      state
  end

  module Parser = Configuration_Parser.Make (Parser_definition)

  let from_anything f x =
    let p = { Parser_definition.path = []; conf = [] } in
    List.rev (f x p).Parser_definition.conf

  let from_file = from_anything Parser.parse_file

  let from_string = from_anything Parser.parse_string

  let from_alist a =
    let loop c (k, v) = add k v c in
    List.fold_left loop empty a

  let to_alist a = List.map (fun (k, (v, _)) -> (path_of_string k, v)) a
end

(*
module Quiet =
struct
  let value_error _path _name _pos _text _mesg =
    ()

  let uncaught_exn _path _name _pos _text _exn =
    ()

  let default _path _name _value =
    ()

  let parse_error _pos _message =
    ()
end
*)

(*
module Verbose =
struct
  let value_error path name pos text mesg =
    eprintf "Configuration_Map.value_error: '%s' for '%s' in %s'"
      text (path_to_string path name) pos.Lexing.pos_fname

  let uncaught_exn path name pos text exn =
    eprintf "Configuration_Map.uncaught_exn: %s: %s\n"
      (path_to_string path name) (Printexc.to_string exn)

  let default path name =
    eprintf "Configuration_Map.default: %s\n"
      (path_to_string path name)

  let parse_error pos message =
    eprintf "Configuration_Map.parse_error: \
             syntax error in configuration file '%s' on line %d."
      pos.Lexing.pos_fname pos.Lexing.pos_lnum
end
*)

module Brittle = struct
  type location = Undefined | File of string * int

  let location pos =
    if pos.Lexing.pos_fname = "" then Undefined
    else File (pos.Lexing.pos_fname, pos.Lexing.pos_lnum)

  let failprintf fmt = ksprintf (fun s -> raise (Failure s)) fmt

  let value_error path name pos text mesg =
    match location pos with
    | File (filename, line) ->
        failprintf "Bad %s value '%s' for '%s' in '%s' line %d." mesg text
          (path_to_string path name) filename line
    | Undefined ->
        failprintf "Bad %s value '%s' for '%s'." mesg text
          (path_to_string path name)

  let uncaught_exn path name _pos _text exn =
    eprintf "Configuration_Map.uncaught_exn: %s: %s\n"
      (path_to_string path name) (Printexc.to_string exn)

  let default _path _name = ()

  let parse_error pos _message =
    match location pos with
    | File (filename, line) ->
        failprintf "Syntax error in configuration file '%s' on line %d."
          filename line
    | Undefined ->
        failprintf "Syntax error in configuration text on line %d."
          pos.Lexing.pos_lnum
end

module Internal : S = Make (Brittle)

include Internal
