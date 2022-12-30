let () =
  Ctypes_stubgen.make_functions_stubs
    [ "stddef.h"; "gsl/gsl_math.h"; "gsl/gsl_chebyshev.h" ]
    (module Gsl_functions_functor.Apply)
