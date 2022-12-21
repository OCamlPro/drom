let%expect_test "addition" =
  Printf.printf "%d\n%!" (1 + 2);
  [%expect {| 3 |}]
