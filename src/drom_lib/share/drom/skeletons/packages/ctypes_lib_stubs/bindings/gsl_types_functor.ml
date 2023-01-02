module Apply (T : Cstubs.Types.TYPE) = struct
  open Ctypes
  open T

  module Gsl_function = struct
    type gsl_function

    type t = gsl_function structure

    let t : t typ = typedef (structure "gsl_function_struct") "gsl_function"

    let function_type = double @-> ptr void @-> returning double

    let function_ = field t "function" (static_funptr function_type)

    let params = field t "params" (ptr void)

    let () = seal t
  end

  module Gsl_cheb_series = struct
    type gsl_cheb_series

    type t = gsl_cheb_series structure

    let t : t typ =
      typedef (structure "gsl_cheb_series_struct") "gsl_cheb_series"
  end
end
