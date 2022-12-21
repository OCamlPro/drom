#define CAML_NAME_SPACE
#include "caml/mlvalues.h"
#include "caml/bigarray.h"
#include "main.h"

CAMLprim value ml_reverse(value buf) {
  reverse(Caml_ba_data_val(buf), Caml_ba_array_val(buf)->dim[0]);
  return Val_unit;
}
