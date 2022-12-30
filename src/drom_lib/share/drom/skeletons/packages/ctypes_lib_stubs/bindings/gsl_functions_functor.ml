module Apply (F : Cstubs.FOREIGN) = struct
  open Ctypes
  open F
  open Gsl_types

  module Gsl_cheb = struct
    let alloc =
      foreign "gsl_cheb_alloc" (size_t @-> returning (ptr Gsl_cheb_series.t))

    let free = foreign "gsl_cheb_free" (ptr Gsl_cheb_series.t @-> returning void)

    let init =
      foreign "gsl_cheb_init"
        ( ptr Gsl_cheb_series.t @-> ptr Gsl_function.t @-> double @-> double
        @-> returning int )

    let order =
      foreign "gsl_cheb_order" (ptr Gsl_cheb_series.t @-> returning size_t)

    let size =
      foreign "gsl_cheb_size" (ptr Gsl_cheb_series.t @-> returning size_t)

    let coeffs =
      foreign "gsl_cheb_coeffs"
        (ptr Gsl_cheb_series.t @-> returning (ptr double))

    let eval =
      foreign "gsl_cheb_eval"
        (ptr Gsl_cheb_series.t @-> double @-> returning double)

    let eval_n =
      foreign "gsl_cheb_eval_n"
        (ptr Gsl_cheb_series.t @-> size_t @-> double @-> returning double)
  end
end
