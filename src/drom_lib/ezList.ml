(**************************************************************************)
(*                                                                        *)
(*   Typerex Libraries                                                    *)
(*                                                                        *)
(*   Copyright 2011-2017 OCamlPro SAS                                     *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

let rec last list =
  match list with [] -> raise Not_found | [ x ] -> x | _ :: tail -> last tail

let _ =
  assert (last [ 1 ] = 1);
  assert (last [ 1; 2; 3; 4 ] = 4);
  ()

(* Fabrice: [drop] and [take] fail when they receive a negative number.
Should they fail too when n is bigger than the list length ? Should we
provide alternatives ? *)

let drop n list =
  let rec aux n list =
    if n > 0 then match list with [] -> [] | _ :: tail -> aux (n - 1) tail
    else list
  in
  if n < 0 then invalid_arg "OcpList.drop";
  aux n list

let _ =
  (*  assert (drop (-1) [1] = [1]); NOW FAILS *)
  assert (drop 0 [ 1 ] = [ 1 ]);
  assert (drop 3 [ 1; 2; 3; 4 ] = [ 4 ]);
  assert (drop 3 [ 1; 2; 3 ] = []);
  ()

let take n l =
  let rec aux accu n l =
    if n = 0 then List.rev accu
    else
      match l with [] -> List.rev accu | h :: t -> aux (h :: accu) (n - 1) t
  in
  if n < 0 then invalid_arg "OcpList.take";
  aux [] n l

let _ =
  assert (take 0 [ 1; 2; 3 ] = []);
  assert (take 1 [ 1; 2; 3 ] = [ 1 ]);
  assert (take 2 [ 1; 2; 3 ] = [ 1; 2 ]);
  assert (take 3 [ 1; 2; 3 ] = [ 1; 2; 3 ]);
  assert (take 4 [ 1; 2; 3 ] = [ 1; 2; 3 ]);
  ()

let make n x =
  let rec aux accu n x = if n > 0 then aux (x :: accu) (n - 1) x else accu in
  if n < 0 then invalid_arg "OcpList.make";
  aux [] n x

let _ =
  assert (make 0 1 = []);
  assert (make 1 1 = [ 1 ]);
  assert (make 2 1 = [ 1; 1 ]);
  assert (make 3 1 = [ 1; 1; 1 ]);
  ()

let remove x l = List.filter (( <> ) x) l

let removeq x l = List.filter (( != ) x) l

let tail_map f list = List.rev (List.rev_map f list)
