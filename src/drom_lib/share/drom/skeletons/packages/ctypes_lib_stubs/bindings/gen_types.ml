let () =
  Ctypes_stubgen.make_types_stubs
    [ "stddef.h"; "gsl/gsl_math.h"; "gsl/gsl_chebyshev.h" ]
    (module Gsl_types_functor.Apply)
