!{header-ml}

module Gsl = !(lib-name:alpha:cap)

let () =
  let order = 10 in
  let f x = if x < 0.5 then 0. else 1. in
  let cs = Gsl.Functions.Gsl_cheb.make ~a:0. ~b:1. f order in
  let x = 0.3 in
  let y = Gsl.Functions.Gsl_cheb.eval cs x in
  Printf.printf
    "Evaluation of Chebishev series at order %d for x = %.1f -> %.4f\n"
    order x y
