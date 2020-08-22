(lang dune 2.0)

(name drom)
(allow_approximate_merlin)
(generate_opam_files true)

(version 0.1.0)

(package
 (name drom-lib)
 (synopsis "drom is a tool to easily generate OCaml projects on Github")
 (description "drom is a tool to easily generate OCaml projects on Github
 this can be very long
 ")
 (depends
   (ocaml (>= 4.07.1))
   (toml (and (>= 5.0.0) (< 6.0.0)))
   (opam-file-format (and (>= 2.0.0) (< 3.0.0)))
   (ez-file (and (>= 0.1.0) (< 1.0.0)))
   (ez-config (and (>= 0.1.0) (< 1.0.0)))
   (ez-cmdliner (and (>= 0.1.0) (< 1.0.0)))
   (dune (and (>= 2.6.0) (< 3.0.0)))
 )
)

(package
 (name drom)
 (synopsis "drom is a tool to easily generate OCaml projects on Github")
 (description "drom is a tool to easily generate OCaml projects on Github")
 (depends (drom-lib (= 0.1.0)))
 )

