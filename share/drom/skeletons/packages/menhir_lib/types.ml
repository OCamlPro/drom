!{header-ml}

(* If you delete or rename this file, you should add 'src/!{name}/types.ml' to the 'skip' field in "drom.toml" *)

type literal =
  | Unit
  | Bool of Bool.t
  | Int of Int.t
  | Float of Float.t
  | String of String.t

type const =
  | Literal of literal
  | Var of String.t

type e =
  | Const of const
  | Bind of String.t * e * e
  | Abstract of String.t * e
  | Apply of e * e
