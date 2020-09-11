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

let example =
  {|
[Simple Values]
key=value
spaces in keys=allowed
spaces in values=allowed as well
spaces around the delimiter = obviously
you can also use : to delimit keys from values

[All Values Are Strings]
values like this: 1000000
or this: 3.14159265359
are they treated as numbers? : no
integers, floats and booleans are held as: strings
can use the API to get converted values directly: true

[Multiline Values]
chorus: I'm a lumberjack, and I'm okay
    I sleep all night and I work all day

[No Values]
key_without_value
empty string value here =

[You can use comments]
# like this
; or this

# By default only in an empty line.
# Inline comments can be harmful because they prevent users
# from using the delimiting characters as parts of values.
# That being said, this can be customized.

    [Sections Can Be Indented]
        can_values_be_as_well = True
        does_that_mean_anything_special = False
        purpose = formatting for readability
        multiline_values = are
            handled just fine as
            long as they are indented
            deeper than the first line
            of a value
        # Did I mention we can indent comments, too?
|}

type t = { mutable sections : section StringMap.t }

and section = {
  mutable section_name : string;
  mutable section_options : string StringMap.t;
}

let get t s o = StringMap.find o (StringMap.find s t.sections).section_options

let to_string t =
  let b = Buffer.create 10_000 in
  StringMap.iter
    (fun _ s ->
      Printf.bprintf b "[%s]\n" s.section_name;
      StringMap.iter
        (fun s v ->
          let lines = EzString.split v '\n' in
          let v = String.concat "\t  " lines in
          Printf.bprintf b "\t%s = %s\n" s v)
        s.section_options)
    t.sections;
  Buffer.contents b

let parse_string s =
  let sections = ref StringMap.empty in
  let current_section = ref None in
  let module Logger = struct
    type t = unit

    (*
    let pos_to_lc pos =
      pos.Lexing.pos_lnum,
      pos.Lexing.pos_cnum - pos.Lexing.pos_bol

    let excerpt_to_string tag excerpt =
      let startpos = Configuration_Parser.startpos excerpt in
      let endpos = Configuration_Parser.endpos excerpt in
      let text = Configuration_Parser.text excerpt in
      let startline, startcol =
        pos_to_lc startpos
      in
      let endline, endcol =
        pos_to_lc endpos
      in
      Printf.sprintf "%03d:%03d-%03d:%03d %s(%S)"
        startline startcol
        endline endcol
        tag text
*)

    let comment _exc () = ()

    let section path () =
      let section_name =
        String.concat "." (List.map Configuration_Parser.text path)
      in
      let s =
        match StringMap.find section_name !sections with
        | exception Not_found ->
            let s = { section_name; section_options = StringMap.empty } in
            sections := StringMap.add section_name s !sections;
            s
        | s -> s
      in
      current_section := Some s

    let binding key value () =
      match !current_section with
      | None -> failwith "key outside of section"
      | Some s ->
          s.section_options <-
            StringMap.add
              (Configuration_Parser.text key)
              (Configuration_Parser.text value)
              s.section_options

    let parse_error _errpos _error () = failwith "parse error"
  end in
  let module ConfigurationLogger = Configuration_Parser.Make (Logger) in
  ConfigurationLogger.parse_string s ();

  { sections = !sections }
