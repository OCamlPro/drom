open Toml.Types
open Utils

(* This test file expects official_example.toml from official toml repo read *)
let toml = Toml.Parser.(from_filename "./official_example.toml" |> unsafe)

let expected =
  Toml.Min.of_key_values
    [ (Toml.Min.key "title", TString "TOML Example")
    ; ( Toml.Min.key "owner"
      , TTable
          (Toml.Min.of_key_values
             [ (Toml.Min.key "name", TString "Tom Preston-Werner")
             ; (Toml.Min.key "organization", TString "GitHub")
             ; ( Toml.Min.key "bio"
               , TString "GitHub Cofounder & CEO\nLikes tater tots and beer." )
             ; (Toml.Min.key "dob", TDate 296638320.) (* 1979-05-27T07:32:00 *)
             ] ) )
    ; ( Toml.Min.key "database"
      , TTable
          (Toml.Min.of_key_values
             [ (Toml.Min.key "server", TString "192.168.1.1")
             ; (Toml.Min.key "ports", TArray (NodeInt [ 8001; 8001; 8002 ]))
             ; (Toml.Min.key "connection_max", TInt 5000)
             ; (Toml.Min.key "enabled", TBool true)
             ] ) )
    ; ( Toml.Min.key "servers"
      , TTable
          (Toml.Min.of_key_values
             [ ( Toml.Min.key "alpha"
               , TTable
                   (Toml.Min.of_key_values
                      [ (Toml.Min.key "ip", TString "10.0.0.1")
                      ; (Toml.Min.key "dc", TString "eqdc10")
                      ] ) )
             ; ( Toml.Min.key "beta"
               , TTable
                   (Toml.Min.of_key_values
                      [ (Toml.Min.key "ip", TString "10.0.0.2")
                      ; (Toml.Min.key "dc", TString "eqdc10")
                      ; (Toml.Min.key "country", TString "中国")
                      ] ) )
             ] ) )
    ; ( Toml.Min.key "clients"
      , TTable
          (Toml.Min.of_key_values
             [ ( Toml.Min.key "data"
               , TArray
                   (NodeArray
                      [ NodeString [ "gamma"; "delta" ]; NodeInt [ 1; 2 ] ] ) )
             ; (Toml.Min.key "hosts", TArray (NodeString [ "alpha"; "omega" ]))
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
    ]

let () = assert_table_equal toml expected
