!{header-ml}

module C = Configurator.V1

let () =
  C.main ~name:"gsl" (fun c ->
    let default : C.Pkg_config.package_conf =
      { libs = [ "-lgsl"; "-lgslcblas"; "-lm" ]; cflags = [] }
    in
    let conf =
      match C.Pkg_config.get c with
      | None -> default
      | Some pc ->
          match C.Pkg_config.query pc ~package:"gsl" with
          | None -> default
          | Some deps -> deps
    in
    C.Flags.write_sexp "ccopt.sexp" conf.cflags;
    C.Flags.write_sexp "cclib.sexp" conf.libs)
