open Types

let maybe_escape_char formatter ch =
  match ch with
  | '"' -> Format.pp_print_string formatter "\\\""
  | '\\' -> Format.pp_print_string formatter "\\\\"
  | '\n' -> Format.pp_print_string formatter "\\n"
  | '\t' -> Format.pp_print_string formatter "\\t"
  | _ ->
    let code = Char.code ch in
    if code <= 31 then
      Format.fprintf formatter "\\u%04x" code
    else
      Format.pp_print_char formatter ch

let print_bool formatter value = Format.pp_print_bool formatter value

let print_int formatter value = Format.pp_print_int formatter value

let print_float formatter value =
  let fractional = abs_float (value -. floor value) in
  (* Even 1.'s fractional value is not equal to 0. *)
  if fractional <= epsilon_float then
    Format.fprintf formatter "%.1f" value
  else
    Format.pp_print_float formatter value

let print_string formatter value =
  let has_newline = ref false in
  let has_quote = ref false in
  let has_doublequote = ref false in
  String.iter
    (function
      | '\n' -> has_newline := true
      | '\'' -> has_quote := true
      | '"' -> has_doublequote := true
      | _ -> () )
    value;
  match (!has_newline, !has_doublequote, !has_quote) with
  | true, false, _ ->
    Format.pp_print_string formatter {|"""|};
    String.iter
      (function
        | '\n' -> Format.pp_print_newline formatter ()
        | c -> maybe_escape_char formatter c )
      value;
    Format.pp_print_string formatter {|"""|}
  | true, true, false ->
    Format.pp_print_string formatter "'''\n";
    Format.pp_print_string formatter value;
    Format.pp_print_string formatter "'''"
  | _ ->
    Format.pp_print_char formatter '"';
    String.iter (maybe_escape_char formatter) value;
    Format.pp_print_char formatter '"'

let print_date fmt d = ISO8601.Permissive.pp_datetimezone fmt (d, 0.)

(* This function is a shim for [Format.pp_print_list] from ocaml 4.02 *)
let pp_print_list ~pp_sep print_item_func formatter values =
  match values with
  | [] -> ()
  | [ e ] -> print_item_func formatter e
  | e :: l ->
    print_item_func formatter e;
    List.iter
      (fun v ->
        pp_sep formatter ();
        print_item_func formatter v )
      l

let is_table _ = function
  | TTable _ -> true
  | TArray (NodeTable _) -> true
  | _ -> false

let is_array_of_table _ = function
  | TArray (NodeTable _) -> true
  | _ -> false

let rec print_array formatter toml_array sections =
  let print_list values ~f:print_item_func =
    let pp_sep formatter () = Format.pp_print_string formatter ", " in
    Format.pp_print_char formatter '[';
    pp_print_list ~pp_sep print_item_func formatter values;
    Format.pp_print_char formatter ']'
  in
  match toml_array with
  | NodeBool values -> print_list values ~f:print_bool
  | NodeInt values -> print_list values ~f:print_int
  | NodeFloat values -> print_list values ~f:print_float
  | NodeString values -> print_list values ~f:print_string
  | NodeDate values -> print_list values ~f:print_date
  | NodeArray values ->
    print_list values ~f:(fun formatter arr ->
        print_array formatter arr sections )
  | NodeTable values ->
    List.iter
      (fun tbl ->
        (*
         * Don't print the intermediate sections, if all values are arrays of tables,
         * print [[x.y.z]] as appropriate instead of [[x]][[y]][[z]]
         *)
        if not (Types.Table.for_all is_array_of_table tbl) then
          Format.fprintf formatter "[[%s]]\n"
            (sections |> List.map Types.Table.Key.to_string |> String.concat ".");
        print_table formatter tbl sections )
      values
  | NodeEmpty -> Format.pp_print_string formatter "[]"

and print_table formatter toml_table sections =
  (*
   * We need to print non-table values first, otherwise we risk including
   * top-level values in a section by accident
   *)
  let table_with_table_values, table_with_non_table_values =
    Types.Table.partition is_table toml_table
  in
  let print_key_value key value =
    print_value_with_key formatter key value sections
  in
  (* iter() guarantees that keys are returned in ascending order *)
  Types.Table.iter print_key_value table_with_non_table_values;
  Types.Table.iter print_key_value table_with_table_values

and print_value formatter toml_value sections =
  match toml_value with
  | TBool value -> print_bool formatter value
  | TInt value -> print_int formatter value
  | TFloat value -> print_float formatter value
  | TString value -> print_string formatter value
  | TDate value -> print_date formatter value
  | TArray value -> print_array formatter value sections
  | TTable value -> print_table formatter value sections

and print_value_with_key formatter key toml_value sections =
  let sections', add_linebreak =
    match toml_value with
    | TTable value ->
      let sections_with_key = sections @ [ key ] in
      (*
       * Don't print the intermediate sections, if all values are tables,
       * print [x.y.z] as appropriate instead of [x][y][z]
       *)
      if not (Types.Table.for_all is_table value) then
        Format.fprintf formatter "[%s]\n"
          ( sections_with_key
          |> List.map Types.Table.Key.to_string
          |> String.concat "." );
      (sections_with_key, false)
    | TArray (NodeTable _tables) ->
      let sections_with_key = sections @ [ key ] in
      (sections_with_key, false)
    | _ ->
      Format.fprintf formatter "%s = " (Types.Table.Key.to_string key);
      (sections, true)
  in
  print_value formatter toml_value sections';
  if add_linebreak then Format.pp_print_char formatter '\n'

let value formatter toml_value =
  print_value formatter toml_value [];
  Format.pp_print_flush formatter ()

let array formatter toml_array =
  match toml_array with
  | NodeTable _t ->
    (* We need the parent section for printing an array of table correctly,
       otheriwise the header contains [[]] *)
    invalid_arg "Cannot format array of tables, use Toml.Printer.table"
  | _ ->
    print_array formatter toml_array [];
    Format.pp_print_flush formatter ()

let table formatter toml_table =
  print_table formatter toml_table [];
  Format.pp_print_flush formatter ()

let mk_printer fn x =
  let b = Buffer.create 100 in
  let fmt = Format.formatter_of_buffer b in
  fn fmt x;
  Buffer.contents b

let string_of_table = mk_printer table

let string_of_value = mk_printer value

let string_of_array = mk_printer array
