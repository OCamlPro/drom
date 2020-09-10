let%expect_test "EzSubst.string" =
  let s = "$hello$hell${hello}$$$hello$" in
  let s =
    Drom_lib.EzSubst.string
      ~f:(function "hello" -> "HELLO" | s -> Printf.sprintf "!{%s}" s)
      s
  in
  Printf.printf "%s\n%!" s;
  [%expect {| $hello$hellHELLO$$hello$ |}]
