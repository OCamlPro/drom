let fmt = Format.std_formatter

let print_headers fmt = List.iter (Format.fprintf fmt "#include <%s>@\n")

let make_types_stubs (c_headers : string list)
    (types_functor : (module Cstubs.Types.BINDINGS)) =
  print_headers fmt c_headers;
  Cstubs_structs.write_c fmt types_functor;
  Format.pp_print_flush fmt ()

let make_functions_stubs (c_headers : string list)
    (functions_functor : (module Cstubs.BINDINGS)) =
  begin
    match Sys.argv.(1) with
    | "c" ->
      print_headers fmt c_headers;
      Cstubs.write_c ~prefix:"gsl_stub" fmt functions_functor
    | "ml" -> Cstubs.write_ml ~prefix:"gsl_stub" fmt functions_functor
    | s -> failwith ("unknown functions " ^ s)
  end;
  Format.pp_print_flush fmt ()
