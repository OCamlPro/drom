(lang dune 2.0)
; This file is maintained by drom, using drom.toml
(name drom)
(allow_approximate_merlin)
(generate_opam_files true)

(package
 (name drom)

 (synopsis "The drom project")

 (description "The drom OCaml project")
 (depends
   (ocaml (= 4.10.0))
   (dune (and (>= 2.6.0) (< 3.0.0)))
 )
)
