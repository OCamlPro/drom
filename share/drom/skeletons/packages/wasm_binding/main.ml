!{header-ml}

(* If you delete or rename this file, you should add
   'src/!{name}/main.ml' to the 'skip' field in "drom.toml" *)

(* Example of reversal of a string *)
external ml_reverse : Bigstring.t -> unit = "ml_reverse"

let reverse s =
  let b = Bigstring.of_string s in
  ml_reverse b;
  Bigstring.to_string b
