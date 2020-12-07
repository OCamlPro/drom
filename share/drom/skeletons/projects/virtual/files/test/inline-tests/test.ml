let%test "must-return-true" = true

let%test_unit "must-return-unit" = ()

let%test_module "module" =
  ( module struct
    let%test "must-return-true" = true
  end )
