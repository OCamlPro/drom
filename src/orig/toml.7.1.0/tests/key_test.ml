open Utils
open Toml.Types.Table.Key

let test_must_quote key =
  let quoted = to_string @@ of_string key in
  assert (not @@ String.equal key quoted)

let () =
  test_string "\"my_good_unicodé_key\""
    (to_string (of_string "my_good_unicodé_key"));
  test_must_quote "key with spaces";
  test_must_quote "with\ttab";
  test_must_quote "with\nlinefeed";
  test_must_quote "with\rcr";
  test_must_quote "with.dot";
  test_must_quote "with[bracket";
  test_must_quote "with]bracket";
  test_must_quote "with\"quote";
  test_must_quote "with#pound"
