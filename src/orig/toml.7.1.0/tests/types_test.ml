let () =
  let key = Toml.Types.Table.Key.of_string "a-b-c" in
  assert (String.compare "a-b-c" (Toml.Types.Table.Key.to_string key) = 0)
