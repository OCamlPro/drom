open Toml.Types
open Utils

(* This test file expects official_example4.toml from official toml repo read *)
let toml = Toml.Parser.(from_filename "./official_example4.toml" |> unsafe)

let expected =
  Toml.Min.of_key_values
    [ ( Toml.Min.key "table"
      , TTable
          (Toml.Min.of_key_values
             [ (Toml.Min.key "key", TString "value")
             ; ( Toml.Min.key "subtable"
               , TTable
                   (Toml.Min.of_key_values
                      [ (Toml.Min.key "key", TString "another value") ] ) )
             ; ( Toml.Min.key "inline"
               , TTable
                   (Toml.Min.of_key_values
                      [ ( Toml.Min.key "name"
                        , TTable
                            (Toml.Min.of_key_values
                               [ (Toml.Min.key "first", TString "Tom")
                               ; (Toml.Min.key "last", TString "Preston-Werner")
                               ] ) )
                      ; ( Toml.Min.key "point"
                        , TTable
                            (Toml.Min.of_key_values
                               [ (Toml.Min.key "x", TInt 1)
                               ; (Toml.Min.key "y", TInt 2)
                               ] ) )
                      ] ) )
             ] ) )
    ; ( Toml.Min.key "x"
      , TTable
          (Toml.Min.of_key_values
             [ ( Toml.Min.key "y"
               , TTable
                   (Toml.Min.of_key_values
                      [ ( Toml.Min.key "z"
                        , TTable
                            (Toml.Min.of_key_values
                               [ ( Toml.Min.key "w"
                                 , TTable (Toml.Min.of_key_values []) )
                               ] ) )
                      ] ) )
             ] ) )
    ; ( Toml.Min.key "string"
      , TTable
          (Toml.Min.of_key_values
             [ ( Toml.Min.key "basic"
               , TTable
                   (Toml.Min.of_key_values
                      [ ( Toml.Min.key "basic"
                        , TString
                            "I'm a string. \"You can quote me\". Name\tJosé\n\
                             Location\tSF." )
                      ] ) )
             ; ( Toml.Min.key "multiline"
               , TTable
                   (Toml.Min.of_key_values
                      [ (Toml.Min.key "key1", TString "One\nTwo")
                      ; (Toml.Min.key "key2", TString "One\nTwo")
                      ; (Toml.Min.key "key3", TString "One\nTwo")
                      ; ( Toml.Min.key "continued"
                        , TTable
                            (Toml.Min.of_key_values
                               [ ( Toml.Min.key "key1"
                                 , TString
                                     "The quick brown fox jumps over the lazy \
                                      dog." )
                               ; ( Toml.Min.key "key2"
                                 , TString
                                     "The quick brown fox jumps over the lazy \
                                      dog." )
                               ; ( Toml.Min.key "key3"
                                 , TString
                                     "The quick brown fox jumps over the lazy \
                                      dog." )
                               ] ) )
                      ] ) )
             ; ( Toml.Min.key "literal"
               , TTable
                   (Toml.Min.of_key_values
                      [ ( Toml.Min.key "winpath"
                        , TString "C:\\Users\\nodejs\\templates" )
                      ; ( Toml.Min.key "winpath2"
                        , TString "\\\\ServerX\\admin$\\system32\\" )
                      ; ( Toml.Min.key "quoted"
                        , TString "Tom \"Dubs\" Preston-Werner" )
                      ; (Toml.Min.key "regex", TString "<\\i\\c*\\s*>")
                      ; ( Toml.Min.key "multiline"
                        , TTable
                            (Toml.Min.of_key_values
                               [ ( Toml.Min.key "regex2"
                                 , TString "I [dw]on't need \\d{2} apples" )
                               ; ( Toml.Min.key "lines"
                                 , TString
                                     (String.concat "\n"
                                        [ "The first newline is"
                                        ; "trimmed in raw strings."
                                        ; "   All other whitespace"
                                        ; "   is preserved."
                                        ; ""
                                        ] ) )
                               ] ) )
                      ] ) )
             ] ) )
    ; ( Toml.Min.key "integer"
      , TTable
          (Toml.Min.of_key_values
             [ (Toml.Min.key "key1", TInt 99)
             ; (Toml.Min.key "key2", TInt 42)
             ; (Toml.Min.key "key3", TInt 0)
             ; (Toml.Min.key "key4", TInt (-17))
             ; ( Toml.Min.key "underscores"
               , TTable
                   (Toml.Min.of_key_values
                      [ (Toml.Min.key "key1", TInt 1_000)
                      ; (Toml.Min.key "key2", TInt 5_349_221)
                      ; (Toml.Min.key "key3", TInt 1_2_3_4_5)
                      ] ) )
             ] ) )
    ; ( Toml.Min.key "float"
      , TTable
          (Toml.Min.of_key_values
             [ ( Toml.Min.key "fractional"
               , TTable
                   (Toml.Min.of_key_values
                      [ (Toml.Min.key "key1", TFloat 1.0)
                      ; (Toml.Min.key "key2", TFloat 3.1415)
                      ; (Toml.Min.key "key3", TFloat (-0.01))
                      ] ) )
             ; ( Toml.Min.key "exponent"
               , TTable
                   (Toml.Min.of_key_values
                      [ (Toml.Min.key "key1", TFloat 5e+22)
                      ; (Toml.Min.key "key2", TFloat 1e6)
                      ; (Toml.Min.key "key3", TFloat (-2E-2))
                      ] ) )
             ; ( Toml.Min.key "both"
               , TTable
                   (Toml.Min.of_key_values
                      [ (Toml.Min.key "key", TFloat 6.626e-34) ] ) )
             ; ( Toml.Min.key "underscores"
               , TTable
                   (Toml.Min.of_key_values
                      [ (Toml.Min.key "key1", TFloat 9_224_617.445_991_228_313)
                      ; (Toml.Min.key "key2", TFloat 1e1_000)
                      ] ) )
             ] ) )
    ; ( Toml.Min.key "boolean"
      , TTable
          (Toml.Min.of_key_values
             [ (Toml.Min.key "True", TBool true)
             ; (Toml.Min.key "False", TBool false)
             ] ) )
    ; ( Toml.Min.key "datetime"
      , TTable
          (Toml.Min.of_key_values
             [ (Toml.Min.key "key1", TDate 296611200.)
             ; (Toml.Min.key "key2", TDate 296638320.)
             ; (Toml.Min.key "key3", TDate 296638320.)
             ; (Toml.Min.key "key4", TDate 296638320.999999)
             ] ) )
    ; ( Toml.Min.key "array"
      , TTable
          (Toml.Min.of_key_values
             [ (Toml.Min.key "key1", TArray (NodeInt [ 1; 2; 3 ]))
             ; ( Toml.Min.key "key2"
               , TArray (NodeString [ "red"; "yellow"; "green" ]) )
             ; ( Toml.Min.key "key3"
               , TArray (NodeArray [ NodeInt [ 1; 2 ]; NodeInt [ 3; 4; 5 ] ]) )
             ; ( Toml.Min.key "key4"
               , TArray
                   (NodeArray [ NodeInt [ 1; 2 ]; NodeString [ "a"; "b"; "c" ] ])
               )
             ; (Toml.Min.key "key5", TArray (NodeInt [ 1; 2; 3 ]))
             ; (Toml.Min.key "key6", TArray (NodeInt [ 1; 2 ]))
             ; ( Toml.Min.key "inline"
               , TTable
                   (Toml.Min.of_key_values
                      [ ( Toml.Min.key "points"
                        , TArray
                            (NodeTable
                               [ Toml.Min.of_key_values
                                   [ (Toml.Min.key "x", TInt 1)
                                   ; (Toml.Min.key "y", TInt 2)
                                   ; (Toml.Min.key "z", TInt 3)
                                   ]
                               ; Toml.Min.of_key_values
                                   [ (Toml.Min.key "x", TInt 7)
                                   ; (Toml.Min.key "y", TInt 8)
                                   ; (Toml.Min.key "z", TInt 9)
                                   ]
                               ; Toml.Min.of_key_values
                                   [ (Toml.Min.key "x", TInt 2)
                                   ; (Toml.Min.key "y", TInt 4)
                                   ; (Toml.Min.key "z", TInt 8)
                                   ]
                               ] ) )
                      ] ) )
             ] ) )
    ; ( Toml.Min.key "products"
      , TArray
          (NodeTable
             [ Toml.Min.of_key_values
                 [ (Toml.Min.key "name", TString "Hammer")
                 ; (Toml.Min.key "sku", TInt 738594937)
                 ]
             ; Toml.Min.of_key_values
                 [ (Toml.Min.key "name", TString "Nail")
                 ; (Toml.Min.key "sku", TInt 284758393)
                 ; (Toml.Min.key "color", TString "gray")
                 ]
             ] ) )
    ; ( Toml.Min.key "fruit"
      , TArray
          (NodeTable
             [ Toml.Min.of_key_values
                 [ (Toml.Min.key "name", TString "apple")
                 ; ( Toml.Min.key "physical"
                   , TTable
                       (Toml.Min.of_key_values
                          [ (Toml.Min.key "color", TString "red")
                          ; (Toml.Min.key "shape", TString "round")
                          ] ) )
                 ; ( Toml.Min.key "variety"
                   , TArray
                       (NodeTable
                          [ Toml.Min.of_key_values
                              [ (Toml.Min.key "name", TString "red delicious") ]
                          ; Toml.Min.of_key_values
                              [ (Toml.Min.key "name", TString "granny smith") ]
                          ] ) )
                 ]
             ; Toml.Min.of_key_values
                 [ (Toml.Min.key "name", TString "banana")
                 ; ( Toml.Min.key "variety"
                   , TArray
                       (NodeTable
                          [ Toml.Min.of_key_values
                              [ (Toml.Min.key "name", TString "plantain") ]
                          ] ) )
                 ]
             ] ) )
    ]

let () = assert_table_equal toml expected
