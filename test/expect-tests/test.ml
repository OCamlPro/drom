let%expect_test "EzSubst.V1.EZSUBST.string" =
  let s = "$hello$hell${hello}$\\$hello$" in
  let s =
    Ez_subst.V1.EZ_SUBST.string
      ~brace:(fun _ s ->
        match s with
        | "hello" -> "HELLO"
        | s -> Printf.sprintf "!{%s}" s )
      ~ctxt:() s
  in
  Printf.printf "%s\n%!" s;
  [%expect {| $hello$hellHELLO$$hello$ |}]
