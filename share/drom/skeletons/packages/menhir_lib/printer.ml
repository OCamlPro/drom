!{header-ml}

(* If you delete or rename this file, you should add 'src/!{name}/printer.ml' to the 'skip' field in "drom.toml" *)

open Types

let pp_literal fmt = function
  | Unit -> Format.fprintf fmt "()"
  | Bool b -> Format.fprintf fmt "%B" b
  | Int i -> Format.fprintf fmt "%d" i
  | Float f -> Format.fprintf fmt "%f" f
  | String s -> Format.fprintf fmt "%S" s

let pp_const fmt = function
  | Literal l -> Format.fprintf fmt "%a" pp_literal l
  | Var x -> Format.fprintf fmt "%s" x

let rec pp_e fmt = function
  | Const c -> Format.fprintf fmt "%a" pp_const c
  | Bind (x, e1, e2) -> Format.fprintf fmt "let %s = %a in@.%a" x pp_e e1 pp_e e2
  | Abstract (x, e) -> Format.fprintf fmt "fun %s ->@.%a" x pp_e e
  | Apply (e1, e2) -> Format.fprintf fmt "(%a) (%a)" pp_e e1 pp_e e2
