open Toml.Types

let () =
  let t1 =
    NodeTable
      [ Table.add (Table.Key.of_string "hello") (TString "goodbye") Table.empty
      ]
  in
  let t2 = NodeTable [] in
  assert (Toml.Compare.array t1 t2 = 1);
  assert (Toml.Compare.array t2 t1 = -1);
  let t3 =
    NodeTable
      [ Table.add (Table.Key.of_string "hiya") (TString "seeya") Table.empty ]
  in
  assert (Toml.Compare.array t1 t3 = -1)
