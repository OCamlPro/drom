%{
open Types

type op =
  | OpInit of value   (* ==, only set if not already set *)
  | OpEqual of value  (* =, set for the first time *)
  | OpSet of value    (* :=, always set *)
  | OpUnset           (* -=, remove value if exists *)

type t = Value of value
       | Table of (Table.Key.t, t) Hashtbl.t
       | Tables of ((Table.Key.t, t) Hashtbl.t) list

(* Indicate if the given table is a [Regular] table (i.e. its name
 * is its real name), or if it is a [ArrayElement] (i.e. its name
 * is the name of the array containing the table). *)
type table_tag = Regular | ArrayElement

(* [lookup_table root keys]
 * For a given path [keys], look over [root] and fetch a table.
 * Creates empty subtables all along the way if needed. *)
let lookup_table root keys =
  List.fold_left
    (fun t k ->
       try match Hashtbl.find t k with
         | Table t   -> t
         | Value _   -> failwith ("lookup_table.")
         | Tables [] -> let sub = Hashtbl.create 0 in
           Hashtbl.replace t k (Tables [sub]) ;
           sub
         (* Return the last table defined *)
         | Tables t -> List.hd (List.rev t)
       with Not_found -> let sub = Hashtbl.create 0 in
         Hashtbl.add t k (Table sub) ;
         sub)
    root keys

(* [add_value t k v] add to the value [v], at the key [k],
 * in the table [t]. Fails if a value is already binded to [k]. *)
let add_value t k v =
  match v with
  | OpEqual v ->
     if Hashtbl.mem t k then
       if !Types.override then
         Hashtbl.remove t k
       else
         Printf.ksprintf failwith "add_value failed: key %S already exists"
           (Table.Key.to_string k) ;

     Hashtbl.add t k (Value v)
  | OpInit v ->
     if not ( Hashtbl.mem t k ) then Hashtbl.add t k (Value v)
  | OpSet v ->
     if Hashtbl.mem t k then Hashtbl.remove t k ;
     Hashtbl.add t k (Value v)
  | OpUnset ->
     if Hashtbl.mem t k then Hashtbl.remove t k

(* [add_to_table root ks kvs] add [kvs] to table found following path
 * [ks] from [root] table.
 * Use it for a table not in array of tables. *)
let add_to_table root ks kvs =
  let t = lookup_table root ks in
  List.iter (fun (k, v) -> add_value t k v) kvs

(* [add_to_nested_table root ks kvs] add [kvs] to nested
 * table found following path [ks] from [root].
 * Use it for a table which is in an array of tables.  *)
let add_to_nested_table root ks kvs =

  (* [ts] are intermediate tables key,
   * [k] is the value key. *)
  let (ts, k) = let rec aux acc = function
      | [ x ]  -> (List.rev acc, x)
      | h :: q -> aux (h :: acc) q
      | []     -> assert false
    in aux [] ks in

  let t = lookup_table root ts in

  (* [insert_in_new_table ts kvs] create a new table, insert
   * [kvs], a (key * value) list into it, and pakc it with
   * tables [ts] into an array of table. *)
  let insert_table ts kvs =
    let t = Hashtbl.create 0 in
    List.iter(fun (k, v) -> add_value t k v) kvs ;
    Tables (ts @ [ t ]) in

  try match Hashtbl.find t k with
    | Tables ts -> Hashtbl.replace t k (insert_table ts kvs);
    | Table _   -> failwith (Printf.sprintf "%s is a table, not an array of tables" (Table.Key.to_string k))
    | Value _   -> failwith ("add_to_nested_table")
  with Not_found  -> Hashtbl.add t k (insert_table [] kvs)

(* Convert a value of local type [t] into a [Value.value]  *)
let rec convert = function
  | Table t   -> TTable (htbl_to_map t)
  | Value v   -> v
  | Tables ts ->
    TArray (NodeTable (List.filter (fun t -> Hashtbl.length t > 0) ts
                       |> List.map htbl_to_map))

and htbl_to_map h =
  Hashtbl.fold (fun k v map -> Table.add k (convert v) map)
    h Table.empty

let to_table key_values key_value_groups =
  let t = Hashtbl.create 0 in
  List.iter (fun ((tag, ks), kvs) ->
      match tag with
      | Regular      -> add_to_table t ks kvs
      | ArrayElement -> add_to_nested_table t ks kvs)
    (* Create a dummy table with empty key for values
     * which are direct children of root table.  *)
    (((Regular, []), key_values) :: key_value_groups) ;
  match convert (Table t) with TTable t -> t | _ -> assert false

let to_table2 key_values key_value_groups =
  let t = Hashtbl.create 0 in

  let add_to_table t ks v =
    match List.rev ks with
    | [] -> assert false
    | k :: rks ->
       add_to_table t (List.rev rks) [k, v]
  in

  List.iter (fun ((tag, ks), kvs) ->
      match tag with
      | Regular      ->
         List.iter (fun (k, v) -> add_to_table t ( ks @  k ) v) kvs
      | ArrayElement ->
         add_to_nested_table t ks (List.map (function
                                       | [x], v -> x,v
                                       | _ -> assert false) kvs)
    )
    ( ((Regular, []), key_values) :: key_value_groups );
  match convert (Table t) with TTable t -> t | _ -> assert false
%}

(* OcamlYacc definitions *)
%token <bool> BOOL
%token <string> INTEGER
%token <string> FLOAT
%token <string> STRING
%token <float> DATE
%token <string> KEY
%token LBRACK RBRACK LBRACE RBRACE EOF COMMA DOT
%token EQUAL INIT SET CLEAR

%start toml

%type <Types.table> toml
%type <Table.Key.t * op> keyValue
%type <Types.array> array_start

%%
(* Grammar rules *)
toml:
 | keysValue* pair( group_header, keysValue* )* EOF
   { to_table2 $1 $2 }

group_header:
 | LBRACK LBRACK key_path RBRACK RBRACK { ArrayElement, $3 }
 | LBRACK key_path RBRACK               { Regular, $2 }

key:
 | STRING { Table.Key.of_string $1 }
 | KEY    { Table.Key.of_string $1 }
 | INTEGER    { Table.Key.of_string $1 }

key_path: k = separated_nonempty_list (DOT, key) { k }

keysValue:
 | key_path EQUAL value { ($1, OpEqual $3) }
 | key_path INIT value { ($1, OpInit $3) }
 | key_path SET value { ($1, OpSet $3) }
 | key_path CLEAR { ($1, OpUnset) }

keyValue:
 | key EQUAL value { ($1, OpEqual $3) }
 | key INIT value { ($1, OpInit $3) }
 | key SET value { ($1, OpSet $3) }
 | key CLEAR { ($1, OpUnset) }

value:
    BOOL { TBool($1) }
  | INTEGER { TInt(int_of_string $1) }
  | FLOAT { TFloat(float_of_string $1) }
  | STRING { TString($1) }
  | DATE { TDate $1 }
  | LBRACK array_start { TArray($2) }
  | inline_table { TTable($1) }

inline_table:
  LBRACE; key_values = inline_table_key_values; RBRACE {
  to_table key_values [] }

inline_table_key_values:
  key_values = separated_list(COMMA, keyValue) { key_values }

array_start:
    RBRACK { NodeEmpty }
  | BOOL array_end(BOOL) { NodeBool($1 :: $2) }
  | INTEGER array_end(INTEGER) { NodeInt(List.map int_of_string ($1 :: $2)) }
  | FLOAT array_end(FLOAT) { NodeFloat(List.map float_of_string ( $1 :: $2)) }
  | STRING array_end(STRING) { NodeString($1 :: $2) }
  | DATE array_end(DATE) { NodeDate($1 :: $2) }
  | LBRACK array_start nested_array_end { NodeArray($2 :: $3) }
  | inline_table array_end(inline_table) { NodeTable($1 :: $2) }

array_end(param):
    COMMA param array_end(param) { $2 :: $3 }
  | COMMA? RBRACK { [] }

nested_array_end:
    COMMA LBRACK array_start nested_array_end { $3 :: $4 }
  | COMMA? RBRACK { [] }

%%
