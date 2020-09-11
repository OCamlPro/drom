let%expect_test "EzSubst.string" =
  let s = "$hello$hell${hello}$\\$hello$" in
  let s =
    Drom_lib.Ez_subst.string
      ~brace:(fun _ s ->
          match s with
            "hello" -> "HELLO" | s ->
              Printf.sprintf "!{%s}" s)
      ()
      s
  in
  Printf.printf "%s\n%!" s;
  [%expect {| $hello$hellHELLO$$hello$ |}]
