(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let (//) = Filename.concat

let () =
  Printf.printf "(* pwd:%s\nDeps:\n%s\n *)\n"
    ( Sys.getcwd () )
    ( String.concat
        " "
        ( Sys.argv |> Array.to_list ))


let chop_prefix s ~prefix =
  if EzString.starts_with s ~prefix then
    let prefix_len = String.length prefix in
    let len = String.length s in
    Some (String.sub s prefix_len (len - prefix_len))
  else None

let () =
  match Sys.argv |> Array.to_list with
  | _exe ::
    name ::
    skeleton_dir ::
    _deps ->
      if not (Sys.file_exists skeleton_dir) then
        Printf.kprintf failwith
          "Warning: skeleton %s/ not found. Skipping skeleton files.\n%!"
          skeleton_dir;

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
                      Array.map (fun file ->
                          (dir // file,
                           dirname //
(*                             match chop_prefix ~prefix:"dot_" file with
                             | Some file -> "DOT_" ^ file
                             | None ->
                                 (
                                   match chop_prefix ~prefix:"under_" file with
                                   | Some file -> "UNDER_" ^ file
                                   | None ->
*)
                           file
                           )
                          ) files
                    in
                    let files = Array.to_list files in
                    iter (todo @ files) ret
                | _ ->
                    (* warning *)
                    iter todo ret ) )
      in

      let project_files = iter [ (skeleton_dir // "project", "") ] [] in
      let package_files = iter [ (skeleton_dir // "package", "") ] [] in

      Printf.printf "open Types\n" ;
      Printf.printf "let name = %S\n" name;
      Printf.printf "let skeleton = {\n" ;

      let print_files name files =
        Printf.printf "  %s_files = [\n%s ] ;\n"
          name
          (String.concat "\n"
             ( List.map (fun ( name, content ) ->
                   Printf.sprintf "     %S, %S ;" name content
                 ) files ))
      in
      print_files "project" project_files ;
      print_files "package" package_files ;


      Printf.printf "  }\n"
  | _ -> failwith "bad arguments"
