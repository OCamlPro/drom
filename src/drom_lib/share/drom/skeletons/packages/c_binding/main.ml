!{header-ml}

(* If you delete or rename this file, you should add
   'src/!{name}/main.ml' to the 'skip' field in "drom.toml" *)

(* Example of creation of abstract chebyshev series and evaluation *)
type t
type gsl_fun = float -> float

external _alloc : int -> t = "ml_gsl_cheb_alloc"
external _free :  t -> unit = "ml_gsl_cheb_free"
external _init : t -> gsl_fun -> float -> float -> unit = "ml_gsl_cheb_init"

let make ~a ~b f n =
  let cs = _alloc n in
  Gc.finalise _free cs;
  _init cs f a b;
  cs

external eval : t -> float -> float = "ml_gsl_cheb_eval"

let main () =
  let order = 10 in
  let f x = if x < 0.5 then 0. else 1. in
  let cs = make ~a:0. ~b:1. f order in
  let x = 0.3 in
  let y = eval cs x in
  Printf.printf "Evaluation of Chebishev series at order %d for x = %.1f -> %.4f\n"
    order x y
