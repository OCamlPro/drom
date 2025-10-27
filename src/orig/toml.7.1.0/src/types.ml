(** {2 Toml tables} *)

module Table = struct
  module Key : sig
    type t

    val compare : t -> t -> int

    val of_string : string -> t

    val to_string : t -> string
  end = struct
    type t = string

    (** Bare keys only allow [A-Za-z0-9_-]. *)
    let is_bare t =
      let valid_so_far = ref true in
      let i = ref 0 in
      while !valid_so_far && !i < String.length t do
        match String.unsafe_get t !i with
        | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '-' -> incr i
        | _c -> valid_so_far := false
      done;
      !valid_so_far

    let of_string t = t

    (* This function needs to go to more effort to escape non-bare strings. The
       current implementation does not conform to the spec as it will not
       escape, e.g., question marks. *)
    let to_string t = if is_bare t then t else "\"" ^ t ^ "\""

    let compare = String.compare
  end

  include Map.Make (Key)

  let of_key_values key_values =
    List.fold_left (fun tbl (key, value) -> add key value tbl) empty key_values
end

type array =
  | NodeEmpty
  | NodeBool of bool list
  | NodeInt of int list
  | NodeFloat of float list
  | NodeString of string list
  | NodeDate of float list
  | NodeArray of array list (* this can have any type *)
  | NodeTable of table list

and value =
  | TBool of bool
  | TInt of int
  | TFloat of float
  | TString of string
  | TDate of float
  | TArray of array
  | TTable of table

and table = value Table.t
