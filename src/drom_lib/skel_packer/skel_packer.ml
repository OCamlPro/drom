(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let ( // ) = Filename.concat

let () =
  Printf.printf "(* pwd:%s\nDeps:\n%s\n *)\n" (Sys.getcwd ())
    (String.concat " " (Sys.argv |> Array.to_list))

let chop_prefix s ~prefix =
  if EzString.starts_with s ~prefix then
    let prefix_len = String.length prefix in
    let len = String.length s in
    Some (String.sub s prefix_len (len - prefix_len))
  else None

let () =
  match Sys.argv |> Array.to_list with
  | _exe :: kind :: name :: super :: skeleton_dir :: _deps ->
      let rec iter todo ret =
        match todo with
        | [] -> ret
        | (dir, dirname) :: todo -> (
            match Unix.stat dir with
            | exception _exn ->
                (* warning ? *)
                iter todo ret
            | st -> (
                match st.Unix.st_kind with
                | S_REG ->
                    let content = EzFile.read_file dir in
                    iter todo ((dirname, content) :: ret)
                | S_DIR ->
                    let files = Sys.readdir dir in
                    let files =
                      Array.map
                        (fun file -> ( dir // file, dirname // file ))
                        files
                    in
                    let files = Array.to_list files in
                    iter (todo @ files) ret
                | _ ->
                    (* warning *)
                    iter todo ret ) )
      in

      let toml =
        let file = skeleton_dir ^ ".toml" in
        if Sys.file_exists file then
          Some (EzFile.read_file file)
        else begin
          Printf.eprintf "%S does not exist\n%!" file;
          None
        end
      in
      let files =
        if Sys.file_exists skeleton_dir then
          iter [ (skeleton_dir, "") ] []
        else
          []
      in

      Printf.printf "open Types\n";
      Printf.printf "let name = %S\n" name;
      Printf.printf "let %s_skeleton = {\n" kind;

      let print_files files =
        begin
          if super = "None" then
            Printf.printf "  skeleton_inherits = None ;\n"
          else
            Printf.printf "  skeleton_inherits = Some %S ;\n" super
        end;
        begin match toml with
          | None ->
              Printf.printf "  skeleton_toml = [] ;\n"
          | Some content ->
              Printf.printf
                "  skeleton_toml = [ %S ] ;\n"
                content
        end;
        Printf.printf "  skeleton_files = [\n%s ] ;\n"
          (String.concat "\n"
             (List.map
                (fun (name, content) ->
                   Printf.sprintf "     %S, %S ;" name content)
                (List.sort compare files)))
      in
      print_files files;
      Printf.printf "  }\n"
  | _exe :: "licenses" :: [] ->
      let licenses_dir =  "licenses" in
      let dirs = Sys.readdir licenses_dir in
      Printf.printf "let licenses = []\n";
      Array.iter (fun dir ->
          let dirname = licenses_dir // dir in
          Printf.printf "module %s = struct\n" dir;
          Printf.printf "  let key = \"%s\"\n" dir;
          Printf.printf "  let name = \"%s\"\n"
            ( String.trim ( EzFile.read_file ( dirname // "NAME" ) ));
          Printf.printf "  let header = [ %s ]\n"
            ( String.concat
                "; \n"
                (List.map (fun line ->
                     Printf.sprintf "  %S" line
                   )
                    ( EzFile.read_lines ( dirname // "HEADER" )
                      |> Array.to_list )));
          Printf.printf "  let license = {|%s|}\n"
            ( EzFile.read_file ( dirname // "LICENSE" ));
          Printf.printf "end\n";
          Printf.printf
            "let licenses = (%s.key, (module %s : Types.LICENSE)) :: licenses\n"
            dir dir
        ) dirs

  | _ -> failwith "bad arguments"
