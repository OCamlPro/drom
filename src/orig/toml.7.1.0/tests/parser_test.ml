open Toml.Types
open Utils
open OUnit

let find k = Toml.Types.Table.find (Toml.Min.key k)

let unsafe_from_string s = Toml.Parser.(from_string s |> unsafe)

let () =
  let str = "key = \"VaLUe42\"" in
  let toml = unsafe_from_string str in
  test_string "VaLUe42" (get_string "key" toml)

let () =
  let str = "key = \"VaLUe42\"\nkey2=42" in
  let toml = unsafe_from_string str in
  test_string "VaLUe42" (get_string "key" toml);
  test_int 42 (get_int "key2" toml)

let () =
  let str = "key = 42\nkey2=-42 \n key3 = +42 \n key4 = 1_2_3_4_5 \n key5=0" in
  let toml = unsafe_from_string str in
  test_int 42 (get_int "key" toml);
  test_int (-42) (get_int "key2" toml);
  test_int 42 (get_int "key3" toml);
  test_int 12345 (get_int "key4" toml);
  test_int 0 (get_int "key5" toml)

let () =
  let test str =
    let toml = unsafe_from_string ("key=" ^ str) in
    test_float (float_of_string str) (get_float "key" toml)
  in
  test "+1.0";
  test "3.1415";
  test "-0.01";
  test "5e+22";
  test "1e6";
  test "-2E-2";
  test "6.626e-34"

let () =
  let get_float_value toml_string =
    unsafe_from_string toml_string |> get_float "key"
  in
  assert_equal (-1023.03) (get_float_value "key=-1_023.0_3");
  assert_equal 142.301e10 (get_float_value "key=14_2.3_01e1_0")

let () =
  let str = "key = true\nkey2=false" in
  let toml = unsafe_from_string str in
  test_bool true (get_bool "key" toml);
  test_bool false (get_bool "key2" toml)

let () =
  let test str input =
    let toml = unsafe_from_string ("key=\"" ^ input ^ "\"") in
    test_string str (get_string "key" toml)
  in
  test "\b" "\\b";
  test "\t" "\\t";
  test "\n" "\\n";
  test "\r" "\\r";
  test "\\" "\\\\";
  test "\"" "\\\"";
  assert_raises
    (Toml.Parser.Error
       ( "Error in <string> at line 1 at column 6 (position 6): "
         ^ "Forbidden escaped char"
       , { Toml.Parser.source = "<string>"; line = 1; column = 6; position = 6 }
       ) )
    (fun () -> unsafe_from_string "key=\"\\j\"");
  assert_raises
    (Toml.Parser.Error
       ( "Error in <string> at line 1 at column 30 (position 30): "
         ^ "Unterminated string"
       , { Toml.Parser.source = "<string>"
         ; line = 1
         ; column = 30
         ; position = 30
         } ) )
    (fun () -> unsafe_from_string "key=\"This string is not termin")

let () =
  let str = "key1 = \"\"\"\nRoses are red\nViolets are blue\"\"\"" in
  let toml = unsafe_from_string str in
  test_string "Roses are red\nViolets are blue" (get_string "key1" toml)

let () =
  let test input =
    let toml = unsafe_from_string ("key = '" ^ input ^ "'") in
    test_string input (get_string "key" toml)
  in
  test "C:\\Users\\nodejs\\templates";
  test "\\\\ServerX\\admin$\\system32\\";
  test "Tom \"Dubs\" Preston-Werner";
  test "<\\i\\c*\\s*>"

(* TODO: "Multiline literal strings" >:: (fun () -> ...) *)

let () =
  let str = "key = [true, true, false, true]" in
  let toml = unsafe_from_string str in
  assert_equal [ true; true; false; true ] (get_bool_array "key" toml);
  let str = "key = []" in
  let toml = unsafe_from_string str in
  assert_equal [] (get_bool_array "key" toml);
  let str = "key = [true, true,]" in
  let toml = unsafe_from_string str in
  assert_equal [ true; true ] (get_bool_array "key" toml)

let () =
  let str = "key=[ [1,2],[\"a\",\"b\",\"c\",\"d\"]\n,[] ]" in
  let toml = unsafe_from_string str in
  assert_bool ""
    ( match find "key" toml with
    | TArray
        (NodeArray
          [ NodeInt [ 1; 2 ]; NodeString [ "a"; "b"; "c"; "d" ]; NodeEmpty ] )
      ->
      true
    | _ -> false )

let () =
  let str = "[group1]\nkey = true\nkey2 = 1337" in
  let toml = unsafe_from_string str in
  assert_raises Not_found (fun () -> find "key" toml);
  let group1 = get_table "group1" toml in
  test_value (TBool true) (find "key" group1);
  test_value (TInt 1337) (find "key2" group1)

let () =
  let str = "[group1]\nkey = true # this is comment" in
  let toml = unsafe_from_string str in
  let group1 = get_table "group1" toml in
  test_value (TBool true) (find "key" group1)

let () =
  let str = "[group1]\nkey = 1979-05-27T07:32:00Z" in
  let toml = unsafe_from_string str in
  let group1 = get_table "group1" toml in
  test_value (TDate 296638320.) (find "key" group1)

let () =
  let str =
    [ "[[a.b.c]]"
    ; "field1 = 1"
    ; "field2 = 2"
    ; "[[a.b.c]]"
    ; "field1 = 10"
    ; "field2 = 20"
    ]
    |> String.concat "\n"
  in
  let toml = unsafe_from_string str in
  let c =
    TArray
      (NodeTable
         [ Toml.Min.of_key_values
             [ (Toml.Min.key "field1", TInt 1)
             ; (Toml.Min.key "field2", TInt 2)
             ]
         ; Toml.Min.of_key_values
             [ (Toml.Min.key "field1", TInt 10)
             ; (Toml.Min.key "field2", TInt 20)
             ]
         ] )
  in
  let b = TTable (Toml.Min.of_key_values [ (Toml.Min.key "c", c) ]) in
  let a = TTable (Toml.Min.of_key_values [ (Toml.Min.key "b", b) ]) in
  let expected = Toml.Min.of_key_values [ (Toml.Min.key "a", a) ] in
  assert_table_equal expected toml

let () =
  let str =
    "[[fruit]]\n\
     name = \"apple\"\n\
     [fruit.physical]\n\
     color = \"red\"\n\
     shape = \"round\"\n\
     [[fruit.variety]]\n\
     name = \"red delicious\"\n\
     [[fruit.variety]]\n\
     name = \"granny smith\"\n\
     [[fruit]]\n\
     name = \"banana\"\n\
     [[fruit.variety]]\n\
     name = \"plantain\""
  in
  let toml = unsafe_from_string str in
  assert_equal 1 (Toml.Types.Table.cardinal toml);
  assert_bool "" (Toml.Types.Table.mem (Toml.Min.key "fruit") toml);
  let fruits = get_table_array "fruit" toml in
  assert_equal 2 (List.length fruits);
  let apple = List.hd fruits in
  assert_equal 3 (Toml.Types.Table.cardinal apple);
  assert_equal "apple" (get_string "name" apple);
  let physical = get_table "physical" apple in
  let expected_physical =
    Toml.Min.of_key_values
      [ (Toml.Min.key "color", TString "red")
      ; (Toml.Min.key "shape", TString "round")
      ]
  in
  assert_table_equal expected_physical physical;
  let apple_varieties = get_table_array "variety" apple in
  assert_equal 2 (List.length apple_varieties);
  let expected_red_delicious =
    Toml.Min.of_key_values [ (Toml.Min.key "name", TString "red delicious") ]
  in
  assert_table_equal expected_red_delicious (List.hd apple_varieties);
  let expected_granny_smith =
    Toml.Min.of_key_values [ (Toml.Min.key "name", TString "granny smith") ]
  in
  assert_table_equal expected_granny_smith (List.rev apple_varieties |> List.hd);
  let banana = List.rev fruits |> List.hd in
  assert_equal 2 (Toml.Types.Table.cardinal banana);
  assert_equal "banana" (get_string "name" banana);
  let banana_varieties = get_table_array "variety" banana in
  assert_equal 1 (List.length banana_varieties);
  let expected_plantain =
    Toml.Min.of_key_values [ (Toml.Min.key "name", TString "plantain") ]
  in
  assert_equal expected_plantain (List.hd banana_varieties)

let () =
  let str =
    "[a.b.c]\nfield1 = 1\nfield2 = 2\n[[a.b.c]]\nfield1 = 10\nfield2 = 20"
  in
  assert_raises
    (Toml.Parser.Error
       ( "Error in <string> at line 6 at column 11 (position 63): c is a \
          table, not an array of tables"
       , { Toml.Parser.source = "<string>"
         ; line = 6
         ; column = 11
         ; position = 63
         } ) )
    (fun () -> ignore (unsafe_from_string str))

let () =
  let str =
    [ "[[fruit]]"
    ; "[vegetable]"
    ; "name=\"lettuce\""
    ; "[[fruit]]"
    ; "name=\"apple\""
    ]
    |> String.concat "\n"
  in
  let toml = unsafe_from_string str in
  assert_equal 2 (Toml.Types.Table.cardinal toml);
  let expected_vegetable =
    Toml.Min.of_key_values [ (Toml.Min.key "name", TString "lettuce") ]
  in
  let vegetable = get_table "vegetable" toml in
  assert_equal expected_vegetable vegetable;
  let fruits = get_table_array "fruit" toml in
  assert_equal 1 (List.length fruits);
  let expected_fruit =
    Toml.Min.of_key_values [ (Toml.Min.key "name", TString "apple") ]
  in
  assert_equal expected_fruit (List.hd fruits)

let () =
  let str = "key=1[group]\nkey = 2" in
  let toml = unsafe_from_string str in
  assert_equal 1 (get_int "key" toml);
  assert_equal 2 (get_table "group" toml |> get_int "key")

let () =
  let str = "key=\"\\u03C9\"\nkey2=\"\\u4E2D\\u56FD\\u0021\"" in
  let toml = unsafe_from_string str in
  assert_equal "ω" (get_string "key" toml);
  assert_equal "中国!" (get_string "key2" toml)

let () =
  let str = "key = { it_key1 = 1, it_key2 = '2' }" in
  let toml = unsafe_from_string str in
  let expected =
    Toml.Min.of_key_values
      [ ( Toml.Min.key "key"
        , TTable
            (Toml.Min.of_key_values
               [ (Toml.Min.key "it_key1", TInt 1)
               ; (Toml.Min.key "it_key2", TString "2")
               ] ) )
      ]
  in
  assert_table_equal expected toml

let () =
  let str = "key = {}" in
  let toml = unsafe_from_string str in
  let expected =
    Toml.Min.of_key_values
      [ (Toml.Min.key "key", TTable (Toml.Min.of_key_values [])) ]
  in
  assert_table_equal expected toml

let () =
  let str =
    "key = { it_key1 = 1, it_key2 = '2', it_key3 = { nested_it_key = 'nested \
     value' } }"
  in
  let toml = unsafe_from_string str in
  let expected =
    Toml.Min.of_key_values
      [ ( Toml.Min.key "key"
        , TTable
            (Toml.Min.of_key_values
               [ (Toml.Min.key "it_key1", TInt 1)
               ; (Toml.Min.key "it_key2", TString "2")
               ; ( Toml.Min.key "it_key3"
                 , TTable
                     (Toml.Min.of_key_values
                        [ (Toml.Min.key "nested_it_key", TString "nested value")
                        ] ) )
               ] ) )
      ]
  in
  assert_table_equal expected toml

let () =
  let str =
    "\na = [\"b\"]\nb = \"error here\n\nc = \"should not be reached\""
  in
  assert_raises
    (Toml.Parser.Error
       ( "Error in <string> at line 3 at column 16 (position 27): Control \
          characters (U+0000 to U+001F) must be escaped"
       , { Toml.Parser.source = "<string>"
         ; line = 3
         ; column = 16
         ; position = 27
         } ) )
    (fun () -> ignore (unsafe_from_string str))

let () =
  let file = "ImafileandIshouldntexistifIdopleasedeletemetohavethetesttopass" in
  let oc = open_out file in
  Format.fprintf (Format.formatter_of_out_channel oc) "goodbye=3@.";
  close_out oc;
  let ic = open_in file in
  let res = Toml.Parser.from_channel ic in
  close_in ic;
  match res with
  | `Ok t ->
    let res = Format.asprintf "%a" Toml.Printer.table t in
    assert (String.equal res "goodbye = 3\n")
  | `Error (_msg, _loc) -> assert false

(*
let () =

  let toml = unsafe_from_string {|key = "hello"|} in
  test_string "hello" (get_string "key" toml)
  let str = ""*)
