open OUnit
open Toml.Types

let test fn expected testing =
  assert_equal
    ~printer:(fun x -> x)
    expected
    (Toml.Printer.string_of_value (fn testing))

let test_string = test (fun v -> TString v)

let test_bool = test (fun v -> TBool v)

let test_int = test (fun v -> TInt v)

let test_float = test (fun v -> TFloat v)

let test_date = test (fun v -> TDate v)

let test_int_array = test (fun v -> TArray (NodeInt v))

let test_bool_array = test (fun v -> TArray (NodeBool v))

let test_float_array = test (fun v -> TArray (NodeFloat v))

let test_string_array = test (fun v -> TArray (NodeString v))

let test_date_array = test (fun v -> TArray (NodeDate v))

let test_array_array = test (fun v -> TArray (NodeArray v))

let test_table expected key_values =
  assert_equal
    ~printer:(fun x -> x)
    (String.concat "\n" expected ^ "\n")
    (TTable (Toml.Min.of_key_values key_values) |> Toml.Printer.string_of_value)

let () =
  test_string "\"string value\"" "string value";
  test_string "'''\nstr\\ing\t\n\002\"'''" "str\\ing\t\n\002\"";
  test_string "\"\195\169\"" "\195\169"

let () =
  test_bool "true" true;
  test_bool "false" false

let () =
  test_int "42" 42;
  test_int "-42" (-42)

let () =
  test_float "42.24" 42.24;
  test_float "-42.24" (-42.24);
  test_float "1.0" 1.;
  test_float "-1.0" (-1.)

let () =
  test_date "1979-05-27T07:32:00+00:00" 296638320.;
  test_date "1970-01-01T00:00:00+00:00" 0.

let () =
  test_int_array "[]" [];
  test_int_array "[4, 5]" [ 4; 5 ]

let () =
  test_bool_array "[]" [];
  test_bool_array "[true, false]" [ true; false ]

let () =
  test_float_array "[]" [];
  test_float_array "[4.2, 3.14]" [ 4.2; 3.14 ]

let () =
  test_string_array "[]" [];
  test_string_array "[\"a\", \"b\"]" [ "a"; "b" ]

let () =
  test_date_array "[]" [];
  test_date_array "[1979-05-27T07:32:00+00:00, 1979-05-27T08:38:40+00:00]"
    [ 296638320.; 296642320. ];
  test_table
    [ "[dog]"; "type = \"golden retriever\"" ]
    [ ( Toml.Min.key "dog"
      , TTable
          (Toml.Min.of_key_values
             [ (Toml.Min.key "type", TString "golden retriever") ] ) )
    ]

let () =
  test_table
    [ "[dog.tater]"; "type = \"pug\"" ]
    [ ( Toml.Min.key "dog"
      , TTable
          (Toml.Min.of_key_values
             [ ( Toml.Min.key "tater"
               , TTable
                   (Toml.Min.of_key_values
                      [ (Toml.Min.key "type", TString "pug") ] ) )
             ] ) )
    ];
  assert_equal
    ~printer:(fun x -> x)
    ""
    (Toml.Printer.string_of_table
       (Toml.Min.of_key_values [ (Toml.Min.key "dog", TArray (NodeTable [])) ]) );
  test_table
    [ "[[dog]]"; "[dog.tater]"; "type = \"pug\"" ]
    [ ( Toml.Min.key "dog"
      , TArray
          (NodeTable
             [ Toml.Min.of_key_values
                 [ ( Toml.Min.key "tater"
                   , TTable
                       (Toml.Min.of_key_values
                          [ (Toml.Min.key "type", TString "pug") ] ) )
                 ]
             ] ) )
    ];
  test_table
    [ "[[dog]]"
    ; "[dog.tater]"
    ; "type = \"pug\""
    ; "[[dog.dalmatian]]"
    ; "number = 1"
    ; "[[dog.dalmatian]]"
    ; "number = 2"
    ]
    [ ( Toml.Min.key "dog"
      , TArray
          (NodeTable
             [ Toml.Min.of_key_values
                 [ ( Toml.Min.key "tater"
                   , TTable
                       (Toml.Min.of_key_values
                          [ (Toml.Min.key "type", TString "pug") ] ) )
                 ]
             ; Toml.Min.of_key_values
                 [ ( Toml.Min.key "dalmatian"
                   , TArray
                       (NodeTable
                          [ Toml.Min.of_key_values
                              [ (Toml.Min.key "number", TInt 1) ]
                          ; Toml.Min.of_key_values
                              [ (Toml.Min.key "number", TInt 2) ]
                          ] ) )
                 ]
             ] ) )
    ]

let () =
  test_array_array "[]" [];
  test_array_array "[[]]" [ NodeInt [] ];
  test_array_array "[[2341, 2242], [true]]"
    [ NodeInt [ 2341; 2242 ]; NodeBool [ true ] ]

let () =
  assert_raises
    (Invalid_argument "Cannot format array of tables, use Toml.Printer.table")
    (fun () -> ignore (Toml.Printer.string_of_array (NodeTable [])));
  assert_raises
    (Invalid_argument "Cannot format array of tables, use Toml.Printer.table")
    (fun () ->
      ignore
        (Toml.Printer.string_of_array
           (NodeTable
              [ Toml.Min.of_key_values [ (Toml.Min.key "number", TInt 1) ]
              ; Toml.Min.of_key_values [ (Toml.Min.key "number", TInt 2) ]
              ] ) ) )

let () =
  let level3_table =
    Toml.Min.of_key_values
      [ (Toml.Min.key "is_deep", TBool true)
      ; (Toml.Min.key "location", TString "basement")
      ]
  in
  let level2_1_table =
    Toml.Min.of_key_values [ (Toml.Min.key "level3", TTable level3_table) ]
  in
  let level2_2_table =
    Toml.Min.of_key_values [ (Toml.Min.key "is_less_deep", TBool true) ]
  in
  let level1_table =
    Toml.Min.of_key_values
      [ (Toml.Min.key "level2_1", TTable level2_1_table)
      ; (Toml.Min.key "level2_2", TTable level2_2_table)
      ]
  in
  let top_level_table =
    Toml.Min.of_key_values
      [ (Toml.Min.key "toplevel", TString "ocaml")
      ; (Toml.Min.key "level1", TTable level1_table)
      ]
  in
  assert_equal
    ~printer:(fun x -> x)
    ( String.concat "\n"
        [ "toplevel = \"ocaml\""
        ; "[level1.level2_1.level3]"
        ; "is_deep = true"
        ; "location = \"basement\""
        ; "[level1.level2_2]"
        ; "is_less_deep = true"
        ]
    ^ "\n" )
    (top_level_table |> Toml.Printer.string_of_table)

let () =
  let s_out =
    Format.asprintf "%a" Toml.Printer.value
      (Toml.Types.TString (String.make 1 (Char.chr 30)))
  in
  assert (String.equal s_out {|"\u001e"|})

let () =
  let s_out = Format.asprintf "%a" Toml.Printer.array Toml.Types.NodeEmpty in
  assert (String.equal s_out "[]")
