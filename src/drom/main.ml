(**************************************************************************)
(*                                                                        *)
(*  Copyright (c) 2021 OCamlPro SAS & Origin Labs SAS                     *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  This file is distributed under the terms of the GNU Lesser General    *)
(*  Public License version 2.1, with the special exception on linking     *)
(*  described in the LICENSE.md file in the root directory.               *)
(*                                                                        *)
(*                                                                        *)
(**************************************************************************)


let () =
  let exe = Sys.executable_name in
  match Filename.basename exe |> String.lowercase_ascii with
  | "opam" | "opam.exe" ->
      OpamCliMain.main ()
  | _ -> Drom_lib.Main.main ()
