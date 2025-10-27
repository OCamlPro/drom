open OUnit

let assert_table_equal expected testing =
  OUnit.assert_equal
    ~cmp:(fun x y -> Toml.Compare.table x y == 0)
    ~printer:(fun x ->
      let buf = Buffer.create 42 in
      Toml.Printer.table (Format.formatter_of_buffer buf) x;
      Buffer.contents buf )
    expected testing

let force_opt opt =
  match opt with Some value -> value | None -> failwith "No value"

let get_string k toml_table =
  Toml.Lenses.(get toml_table (key k |-- string)) |> force_opt

let get_int k toml_table =
  Toml.Lenses.(get toml_table (key k |-- int)) |> force_opt

let get_float k toml_table =
  Toml.Lenses.(get toml_table (key k |-- float)) |> force_opt

let get_bool k toml_table =
  Toml.Lenses.(get toml_table (key k |-- bool)) |> force_opt

let get_bool_array k toml_table =
  Toml.Lenses.(get toml_table (key k |-- array |-- bools)) |> force_opt

let get_table k toml_table =
  Toml.Lenses.(get toml_table (key k |-- table)) |> force_opt

let get_table_array k toml_table =
  Toml.Lenses.(get toml_table (key k |-- array |-- tables)) |> force_opt

let test_value = assert_equal ~printer:Toml.Printer.string_of_value

let test_string = assert_equal ~printer:(fun x -> x)

let test_int = assert_equal ~printer:string_of_int

let test_float = assert_equal ~printer:string_of_float

let test_bool = assert_equal ~printer:string_of_bool

let unsafe_from_string s = Toml.Parser.from_string s |> Toml.Parser.unsafe
