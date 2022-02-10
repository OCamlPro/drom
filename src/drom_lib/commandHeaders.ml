(**************************************************************************)
(*                                                                        *)
(*   Typerex Tools                                                        *)
(*                                                                        *)
(*   Copyright 2011-2017 OCamlPro SAS                                     *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU General Public License version 3 described in the file       *)
(*   LICENSE.                                                             *)
(*                                                                        *)
(**************************************************************************)

open EzCompat

open Ezcmd.V2
open EZCMD.TYPES

type header_sep = {
  sep_name : string;
  sep_regexp : Str.regexp;
  sep_add_line : int; (* add the header at this line by default *)
  mutable sep_headers : header list;
}

and header = {
  header_id : string;
  header_lines : string list;
  header_sep : header_sep;
  mutable header_files : (int * file) list;
}

and file = {
  file_name : string;
  file_headers : (int * header) list; (* position x header *)
}

type config = {
  ignore_headers : StringSet.t;
  ignore_files : StringSet.t;
  ignore_extensions : StringSet.t;
}

type env = {
  config : config;
  headers : (string, header) Hashtbl.t;
  mutable files : (string, file) Hashtbl.t;
  mutable save_to_ignore : StringSet.t;
}


let ignore_files_filename = ".drom-check-headers-ignore-files"
let ignore_files_more_filename = "drom-check-headers-ignore-files"
let ignore_headers_filename = ".drom-check-headers-ignore-headers"

let homedir = try
    Sys.getenv "HOME"
  with Not_found -> "/"
let config_dir = Filename.concat homedir ".config/drom/check-headers"

let max_header_lines = ref 30
let min_char_repetition = ref 50

let stars = String.concat "" (
    Array.to_list (Array.init !min_char_repetition (fun _ -> "\\*")))
let spaces = "[\t ]*"
let new_header_sep ?(sep_add_line=0) sep_name sep_regexp =
  { sep_name;
    sep_regexp = Str.regexp sep_regexp;
    sep_headers = [];
    sep_add_line;
  }

(* Morally, these structures should be in [env], as they are modified
   during the scan. Instead, we reset them at the beginning of
   [scan_dirs].
*)
let ml_header = new_header_sep  "ML Header" (spaces ^ "(" ^ stars)
let cc_header = new_header_sep "C header" (spaces ^ "/" ^ stars)
let sh_header = new_header_sep ~sep_add_line:2 "Shell header"
    (spaces ^ String.make !min_char_repetition '#')

let reset_headers env =
  List.iter (fun sep ->
    List.iter (fun h ->
      h.header_files <- []
    )
      sep.sep_headers) [
    ml_header; cc_header; sh_header
  ];
  Hashtbl.clear env.files

let is_header_sep line header_sep =
  Str.string_match header_sep.sep_regexp line 0

let new_header_id s = Digest.to_hex (Digest.string s)

let new_header env header_sep header_pos header_lines  =
  let header = String.concat " " header_lines in
  let header_id = new_header_id header in
  if StringSet.mem header_id env.config.ignore_headers then
    []
  else
    let h =
      try
        Hashtbl.find env.headers header_id
      with Not_found ->
        let h = {
          header_sep;
          header_id;
          header_lines;
          header_files = [];
        } in
        Hashtbl.add env.headers header_id h;
        header_sep.sep_headers <- h :: header_sep.sep_headers;
        h
    in
    [header_pos, h]

let read_headers env lines header_sep =
  let rec iter_out pos lines headers =
    match lines with
    | [] -> List.rev headers
    | line :: lines ->
      if is_header_sep line header_sep then
        iter_in (pos+1) lines pos [line] headers
      else
        iter_out (pos+1) lines headers
  and iter_in pos lines header_pos header_lines headers =
    match lines with
    | [] -> (* abort header *)
      List.rev headers
    | line :: lines ->
      if is_header_sep line header_sep then
        let header_lines = List.rev (line :: header_lines) in
        let header = new_header env header_sep header_pos header_lines in
        iter_out (pos+1) lines (header @ headers)
      else
      if pos - header_pos > !max_header_lines then (* not a header *)
        iter_out (pos+1) lines headers
      else
        iter_in (pos+1) lines header_pos (line :: header_lines) headers
  in
  iter_out 0 lines []

let record_header ?(config=false) env file_name header_sep =
  let lines = EzFile.read_lines_to_list file_name in
  let file_headers = read_headers env lines header_sep in
  let file = {
    file_name;
    file_headers;
  } in
  Hashtbl.add env.files file_name file;
  let file_headers = match file_headers with
    | [] ->
      (* We create a specific header for no-header. This specific header has
             its id generated from the name of the header_sep, because we want
             each header_sep to have a different set of no-header files. *)
      new_header env header_sep 0 [ header_sep.sep_name ]
    | _ -> file_headers in
  if not config then
    List.iter (fun (header_pos, header) ->
      header.header_files <- (header_pos, file) :: header.header_files
    ) file_headers

let list_ignore_files env list =
  List.fold_left (fun env file ->
      if file = "" then env else
      if file.[0] = '.' then
        { env with
          ignore_extensions = StringSet.add file env.ignore_extensions }
      else
        { env with
          ignore_files = StringSet.add file env.ignore_files
        }) env list


let list_ignore_headers env list =
  List.fold_left (fun env line ->
      { env with
        ignore_headers = StringSet.add line env.ignore_headers }
    ) env list


let add_default_ignored config =
  list_ignore_files config [
    ignore_files_more_filename;
    ignore_files_filename;
    ignore_headers_filename;
    "opam";
    "url";
    "descr";
    "_tags"; "_oasis";
    "meta";
    "readme"; "todo";
    "license";
    "authors";  "copying"; "changes";
    "check-headers.undo";

    ".cmo" ; ".cmi" ; ".cmxs" ; ".cmxa" ; ".cma"
    ; ".cmt" ; ".cmti" ; ".cmx" ; ".annot"

    ; ".mlmods" ; ".mlimods" ; ".mlpp" ; ".mlipp"
    ; ".asm" ; ".byte" ; ".native" ; ".out"

    ; ".mllib" ; ".mldylib" ; ".odocl"

    ; ".so" ; ".o" ; ".a"
    ; ".exe" ; ".dll"

    ; ".log" ; ".status"
    ; ".md" ; ".txt" ; ".tex" ; ".plot"
  ; ".html" ; ".css" ; ".xml" ; ".dtd" ; ".sgml"
        ; ".el"
          ; ".png" ; ".jpg" ; ".jpeg" ; ".git"
        ; ".old"
          ; ".gz" ; ".pdf"

          ; ".rst" ; ".opam"; ".toml"
  ]


let rec scan_dir env dir =
  let files = Sys.readdir dir in
  let config = env.config in
  let config =
    let dirfile = Filename.concat dir ignore_files_filename in
    if Sys.file_exists dirfile then
      list_ignore_files config (EzFile.read_lines_to_list dirfile)
    else config in

  let config =
    let dirfile = Filename.concat dir ignore_headers_filename in
    if Sys.file_exists dirfile then
      list_ignore_headers config (EzFile.read_lines_to_list dirfile)
    else config
  in
  let env = if config == env.config then env else
      { env with config }
  in

  Array.iter (fun file ->
      let lfile = String.lowercase file in
      match lfile.[0] with
        '.' | '_' -> ()
      | _ ->
          let dirfile = Filename.concat dir file in
          match try Some ( Sys.is_directory dirfile ) with
            | _ -> None
          with
          | None -> ()
          | Some false ->
              check_file env file dirfile
          | Some true ->
              if Sys.file_exists
                  (Filename.concat dirfile ".ocp-check-headers-stop") then
                ()
              else
                scan_dir env dirfile
    ) files

and check_file env lfile dirfile =
  let len = String.length lfile in
  if lfile.[len-1] <> '~' && lfile.[0] <> '.' then
    let ext = try
        let pos = String.rindex lfile '.' in
        String.sub lfile pos (len-pos)
      with _ -> ""
    in
    match ext with
    | ".ml" | ".mli" | ".mll" | ".ocp" | ".ocp2" | ".mlp" | ".ml4" ->
        record_header env dirfile ml_header
    | ".c" | ".h" | ".cpp" | ".mly" | ".js" ->
        record_header env dirfile cc_header
    | ".sh" | ".ac" | ".in" | ".m4" ->
        record_header env dirfile sh_header

    | _ ->
        if not (StringSet.mem ext env.config.ignore_extensions) then
          match lfile with
          | "configure" | "makefile" ->
              record_header env dirfile sh_header
          | _ ->
              if not (StringSet.mem lfile env.config.ignore_files ||
                      StringSet.mem lfile env.save_to_ignore
                     ) then begin
                env.save_to_ignore <- StringSet.add lfile env.save_to_ignore;
                Printf.eprintf "Warning: unknown extension for file %S\n%!"
                  dirfile;
              end

let scan_dirs env dirs =

  (* do not clear headers, clear their positions instead *)
  reset_headers env;

  List.iter (fun (file, header_sep) ->
    let dirfile = Filename.concat config_dir file in
    if Sys.file_exists dirfile then
      record_header ~config:true env dirfile header_sep
  ) [ "headers.ml", ml_header;
      "headers.cc", cc_header;
      "headers.sh", sh_header];

  List.iter (fun dir ->
    if Sys.is_directory dir then
      scan_dir env dir
    else
      let lfile = String.lowercase (Filename.basename dir) in
      check_file env lfile dir
  ) dirs;
  ()

let fprintf_loc oc file_name line_pos =
  Printf.fprintf oc "File %S, line %d, characters 0-1:\n" file_name line_pos


let print_headers skip_headers sep file_name =
  if sep.sep_headers <> [] then begin
    let oc = open_out file_name in
    Printf.fprintf oc "Report on %s\n" sep.sep_name;

    if sep.sep_headers <> [] then begin

      Printf.fprintf oc "\nExtracted headers\n";

      List.iter (fun header ->
        if not (StringSet.mem header.header_id skip_headers) then begin
          Printf.fprintf oc "\nHeader id: %s\n" header.header_id;
          if header.header_lines = [ header.header_sep.sep_name ] then begin
            Printf.fprintf oc "\n\n\n\n         EMPTY HEADER\n\n\n\n\n";
          end else begin
            Printf.fprintf oc "<<<\n";
            List.iter (fun line ->
                Printf.fprintf oc "   %s\n" line;
              ) header.header_lines;
            Printf.fprintf oc ">>>\n";
          end;
          List.iter (fun (line_pos, file) ->
              fprintf_loc oc file.file_name line_pos;
              Printf.fprintf oc "Warning: file with %d headers\n%!"
                (List.length file.file_headers)
          ) header.header_files;
        end
        ) sep.sep_headers;

    end;
    close_out oc;
    Printf.printf "File %S generated\n%!" file_name;
  end



let save_ignored env =
  if env.save_to_ignore <> StringSet.empty then begin
    let oc = open_out ignore_files_more_filename in
    StringSet.iter (fun line ->
      Printf.fprintf oc "%s\n" line) env.save_to_ignore;
    close_out oc;
    Printf.eprintf "Ignored files saved to %s\n%!" ignore_files_more_filename;
    Printf.eprintf "You can add it to your %s\n%!" ignore_files_filename

  end

let rec remove_empty_lines lines =
  match lines with
    "" :: lines -> remove_empty_lines lines
  | lines -> lines

let replace_header src_header dst_header line_pos file =
  Printf.printf "Replacing %s by %s on %s\n%!" src_header.header_id
    dst_header.header_id file.file_name;
  let lines = EzFile.read_lines_to_list file.file_name in
  let rec insert_header pos lines rev_lines =
    if pos = line_pos then
      check_src_header lines src_header.header_lines rev_lines
    else
      match lines with
      | [] ->
        Printf.eprintf "Error: header %s not found in %S (EOF before pos)\n%!"
          src_header.header_id file.file_name;
        raise Not_found
      | line :: lines ->
        insert_header (pos+1) lines (line :: rev_lines)

  and check_src_header lines header_lines rev_lines =
    match lines, header_lines with
    | _, [] -> (List.rev rev_lines) @ dst_header.header_lines @
      ("" :: remove_empty_lines lines)
    | [], _ ->
      Printf.eprintf "Error: header %s not found in %S (truncated header)\n%!"
        src_header.header_id file.file_name;
      raise Not_found
    | left :: lines, right :: header_lines ->
      if left <> right then begin
        Printf.eprintf "Error: header %s not found in %S (line mismatch)\n%!"
          src_header.header_id file.file_name;
        raise Not_found
      end;
      check_src_header lines header_lines rev_lines
  in
  try
    let lines = insert_header 0 lines [] in
    EzFile.write_lines_of_list file.file_name lines;
    true
  with Not_found -> false

let add_default_header header file =
  Printf.printf "Adding header %s on %s\n%!" header.header_id file.file_name;
  (* This is the easiest one *)
  let sep = header.header_sep in
  let lines = EzFile.read_lines_to_list file.file_name in
  let rec insert_header pos lines rev_lines =
    if pos = sep.sep_add_line then
      (List.rev rev_lines) @ header.header_lines @ (
        "" :: remove_empty_lines lines)
    else
      match lines with
      | [] -> (List.rev rev_lines) @ header.header_lines @ [""]
      | line :: lines ->
        insert_header (pos+1) lines (line :: rev_lines)
  in
  let lines = insert_header 0 lines [] in
  EzFile.write_lines_of_list file.file_name lines;
  true

type args = {
  mutable arg_add_default : string list;
  mutable arg_dirs : string list; (* reverse order *)
  mutable arg_replace : string list;
  mutable arg_replace_by : string option ;
  mutable arg_skip_headers : StringSet.t ;
}

let undo_oc = ref None

let get_undo_oc () =
  match !undo_oc with
  | None ->
    let oc = open_out "check-headers.undo" in
    undo_oc := Some oc;
    oc
  | Some oc -> oc

let init_action args env =

  let dirs = List.rev args.arg_dirs in

  scan_dirs env dirs;
  save_ignored env;
  ()



let do_actions args env =

    if args.arg_add_default <> [] then
      List.iter (fun header_id ->
        try
          let header = Hashtbl.find env.headers header_id in
          let sep = header.header_sep in
          let empty_header_id = new_header_id sep.sep_name in
          try
            let empty_header = Hashtbl.find env.headers empty_header_id in
            let updates = ref 0 in
            List.iter (fun (_, file) ->
              if add_default_header header file then begin
                Printf.fprintf (get_undo_oc ())
                  "add:%s:%s\n" header_id file.file_name;
                incr updates
              end
            ) empty_header.header_files;
            Printf.printf "add_default %s: %d files changed\n%!"
              header_id !updates;
            if !updates > 0 then begin
              Printf.printf
                "Scanning again after %d changes for %s\n%!" !updates
                header_id;
              let dirs = List.rev args.arg_dirs in
              scan_dirs env dirs
            end
          with Not_found ->
            Printf.printf "add-default %s: no file with no header\n%!"
              header_id
        with Not_found ->
          Printf.eprintf "Error: default header %s not found\n%!" header_id
      ) (List.rev args.arg_add_default);

  if args.arg_replace <> [] then
    List.iter (fun header_pair ->
      let src_id, dst_id = try
                             let pos = String.index header_pair ':' in
                             let len = String.length header_pair in
                             String.sub header_pair 0 pos,
                             String.sub header_pair (pos+1) (len-pos-1)
        with Not_found ->
          Printf.eprintf "Error: cannot parse pair %S\n%!" header_pair;
          exit 2
      in
      let src_header = try
                         Hashtbl.find env.headers src_id
        with Not_found ->
          Printf.eprintf "Error: source header of %S not found\n%!" header_pair;
          exit 2
      in
      let src_sep = src_header.header_sep in
      let dst_header = try
                         Hashtbl.find env.headers dst_id
        with Not_found ->
          Printf.eprintf "Error: destination header of %S not found\n%!" header_pair;
          exit 2
      in
      let dst_sep = dst_header.header_sep in

      if dst_sep != src_sep then begin
        Printf.eprintf "Error: %s and %s of different kind\n%!"
          src_id dst_id;
        exit 2
      end;
      let updates = ref 0 in
      List.iter (fun (line_pos, file) ->
        if replace_header src_header dst_header line_pos file then begin
          incr updates;
          Printf.fprintf (get_undo_oc ())
            "replace:%s:%d:%s:%s\n" src_id line_pos dst_id file.file_name;
        end
      ) src_header.header_files;
      Printf.printf "replace %s: %d files changed\n%!"
        src_id !updates;
      if !updates > 0 then begin
        Printf.printf
          "Scanning again after %d changes for %s\n%!" !updates
          src_id;
        let dirs = List.rev args.arg_dirs in
        scan_dirs env dirs
      end
    ) (List.rev args.arg_replace)

let new_args () = {
  arg_add_default = [];
  arg_replace = [];
  arg_dirs = [];
  arg_replace_by = None ;
  arg_skip_headers = StringSet.empty ;
}

let action args =
  if args.arg_dirs = [] then args.arg_dirs <- ["."];

    let config = {
    ignore_headers = StringSet.empty;
    ignore_files = StringSet.empty;
    ignore_extensions = StringSet.empty;
  }
  in
  let config = add_default_ignored config in

  let env = {
    headers = Hashtbl.create 113;
    files = Hashtbl.create 113;
    config;
    save_to_ignore = StringSet.empty;
  } in

  (*
  if !arg_typerex then begin

    FileString.write_file "LICENSE"
      (List.assoc "typerex/LICENSE" CheckHeadersFiles.files);

    List.iter (fun (dir, license) ->
      let args = new_args () in
      args.arg_dirs <- [dir];
      init_action args env;

      List.iter (fun (ext, header_sep) ->

        let to_replace = ref [] in
        List.iter (fun h ->
          to_replace := h.header_id :: !to_replace
        ) header_sep.sep_headers;

        let header_name = Printf.sprintf "typerex/header-%s.%s" license ext in
        let header = List.assoc header_name CheckHeadersFiles.files in
        let header_lines = OcpString.split header '\n' in
        let header_lines =
          match List.rev header_lines with
          | "" :: "" :: "" :: header_lines
          | "" :: "" :: header_lines
          | "" :: header_lines -> List.rev header_lines
          | _ -> header_lines
        in
        match new_header env header_sep 0 header_lines with
        | [] -> assert false
        | (_, h) :: _ ->
          Printf.eprintf "Header %s for %s\n%!" h.header_id header_name;
          args.arg_add_default <- h.header_id :: args.arg_add_default;

          List.iter (fun h_id ->
            if h_id <> h.header_id then
              args.arg_replace <- (Printf.sprintf "%s:%s" h_id h.header_id)
                :: args.arg_replace
          ) !to_replace
      ) [ "ml", ml_header; "c", cc_header ];

      do_actions args env;

    ) [
      "libs", "LGPL";
      "tools", "GPL";
    ]

  end
  else *)
    begin
      init_action args env;
      do_actions args env;
    end;

  begin match !undo_oc with
  | None -> ()
  | Some oc -> close_out oc
  end;

  print_headers args.arg_skip_headers ml_header "headers-ml.txt";
  print_headers args.arg_skip_headers cc_header "headers-cc.txt";
  print_headers args.arg_skip_headers sh_header "headers-sh.txt";
  ()

let cmd_name = "headers"
let cmd =

  let args = new_args () in
  EZCMD.sub cmd_name
    (fun () -> action args)
    ~args: (
      [
        [ "add-default" ], Arg.String (fun s ->
            args.arg_add_default <- s :: args.arg_add_default),
        EZCMD.info ~docv:"HEADER_ID"
          "Add this header as the default for these files";

        [ "replace"], Arg.String (fun s ->
            args.arg_replace <- s :: args.arg_replace),
        EZCMD.info ~docv:"SRC:DST" "Replace header SRC by header DST";

        ["replace-by"], Arg.String (fun s ->
            args.arg_replace_by <- Some s),
        EZCMD.info ~docv:"HEADER_ID" "Replace by this header";

        ["from"], Arg.String (fun src_id ->
            match args.arg_replace_by with
            | None ->
                Printf.eprintf
                  "Error: --from should come after --replace-by\n%!";
                exit 2
            | Some dst_id ->
                List.iter (fun id ->
                    args.arg_replace <-
                      (Printf.sprintf "%s:%s" id dst_id) :: args.arg_replace
                  ) (EzString.split src_id ':')
          ),
        EZCMD.info ~docv:"HEADER_ID" "Replace this header";

        ["skip"], Arg.String (fun id ->
            args.arg_skip_headers <- StringSet.add id args.arg_skip_headers),
        EZCMD.info ~docv:"HEADER_ID" "skip this header when printing headers";
      ]
    )
    ~doc: "Check all headers in project"
