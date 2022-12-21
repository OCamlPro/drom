!{header-ml}

(* If you delete or rename this file, you should add
   'src/!{dir}/!{name}.ml' to the 'skip' field in "drom.toml" *)

module Types = struct

  let funptr ft f =
    Ctypes.coerce (Foreign.funptr ft) (Ctypes.static_funptr ft) f

  module Gsl_function = struct

    include Gsl_types.Gsl_function

    let make f =
      let gf = Ctypes.make t in
      Ctypes.setf gf function_ (funptr function_type (fun x _p -> f x));
      Ctypes.setf gf params Ctypes.null;
      gf

  end

  module Gsl_cheb_series = struct

    include Gsl_types.Gsl_cheb_series

  end

end

module Functions = struct

  module Gsl_cheb = struct

    include Gsl_functions.Gsl_cheb

    open Types

    let make ~a ~b (f : float -> float) (n : int) =
      let cs = alloc (Unsigned.Size_t.of_int n) in
      Gc.finalise free cs;
      let _ = init cs (Ctypes.addr (Gsl_function.make f)) a b in
      cs

  end

end
