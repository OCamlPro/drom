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
        else
          None
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
              Printf.printf "  skeleton_toml = None ;\n"
          | Some content ->
              Printf.printf "  skeleton_toml = Some %S ;\n"  content
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
  | _ -> failwith "bad arguments"
