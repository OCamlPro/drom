#define CAML_NAME_SPACE
#include "caml/mlvalues.h"
#include "caml/alloc.h"
#include "caml/memory.h"
#include "caml/callback.h"

// example with gsl chebyshev
#include "gsl/gsl_chebyshev.h"

double gslfun_callback_indir(double x, void *params) {
  value res;
  value v_x = caml_copy_double(x);
  value *closure = params;
  res=caml_callback(*closure, v_x);
  return Double_val(res);
}

CAMLprim value ml_gsl_cheb_alloc(value arg) {
  CAMLparam1(arg);
  CAMLlocal1(res);
  res=caml_alloc_small(1, Abstract_tag);
  Field(res, 0)=Val_bp(gsl_cheb_alloc(Int_val(arg)));
  CAMLreturn(res);
}

CAMLprim value ml_gsl_cheb_free(value arg) {
  CAMLparam1(arg);
  gsl_cheb_free((gsl_cheb_series *)Field((arg), 0));
  CAMLreturn(Val_unit);
}

CAMLprim value ml_gsl_cheb_init(value cs, value f, value a, value b)
{
  CAMLparam2(cs, f);
  gsl_function gf = { &gslfun_callback_indir, &f };
  gsl_cheb_init((gsl_cheb_series *)Field((cs), 0), &gf, Double_val(a), Double_val(b));
  CAMLreturn(Val_unit);
}

CAMLprim value ml_gsl_cheb_eval(value arg1, value arg2) {
  CAMLparam2(arg1, arg2);
  CAMLreturn(caml_copy_double(gsl_cheb_eval((gsl_cheb_series *)Field((arg1), 0), Double_val(arg2))));
}
