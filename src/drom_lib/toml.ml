(* We have fixes in Toml, so, for now, we use a local package drom_toml *)
include Drom_toml

let with_override f =
  (*  Types.override := true;*)
  match f () with
  | exception exn ->
    Types.override := false;
    raise exn
  | v ->
    Types.override := false;
    v
