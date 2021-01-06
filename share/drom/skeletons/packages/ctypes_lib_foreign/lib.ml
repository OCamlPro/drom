!{header-ml}

(* If you delete or rename this file, you should add
   'src/!{dir}/!{name}.ml' to the 'skip' field in "drom.toml" *)

open Ctypes
open Foreign

(* To force the external library to be linked *)
external _dummy : unit -> unit = "gsl_cheb_eval"

module Types = struct

  module Gsl_function = struct

    type gsl_function
    type t = gsl_function structure

    let t : t typ =
      typedef (structure "gsl_function_struct") "gsl_function"

    let function_ =
      field t "function" (funptr (double @-> ptr void @-> returning double))

    let params =
      field t "params" (ptr void)

    let () =
      seal t

    let make f =
      let gf = Ctypes.make t in
      Ctypes.setf gf function_ (fun x (_p : unit ptr) -> f x);
      Ctypes.setf gf params Ctypes.null;
      gf

  end

end

module Functions = struct

  open Types

  module Gsl_cheb = struct

    type gsl_cheb_series
    type t = gsl_cheb_series structure

    let t : t typ =
      typedef (structure "gsl_cheb_series_struct") "gsl_cheb_series"

    let alloc =
      foreign "gsl_cheb_alloc" (size_t @-> returning (ptr t))

    let free =
      foreign "gsl_cheb_free" (ptr t @-> returning void)

    let init =
      foreign "gsl_cheb_init"
        (ptr t @-> ptr Gsl_function.t @-> double @-> double @-> returning int)

    let eval =
      foreign "gsl_cheb_eval" (ptr t @-> double @-> returning double)

    let make ~a ~b (f : float -> float) (n : int) =
      let cs = alloc (Unsigned.Size_t.of_int n) in
      Gc.finalise free cs;
      let _ = init cs (Ctypes.addr (Gsl_function.make f)) a b in
      cs

  end

end
