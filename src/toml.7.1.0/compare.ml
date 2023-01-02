let rec list_compare ~f l1 l2 =
  match (l1, l2) with
  | head1 :: tail1, head2 :: tail2 ->
    let comp_result = f head1 head2 in
    if comp_result != 0 then
      comp_result
    else
      list_compare ~f tail1 tail2
  | [], _head2 :: _tail2 -> -1
  | _head1 :: _tail1, [] -> 1
  | [], [] -> 0

let rec value (x : Types.value) (y : Types.value) =
  match (x, y) with
  | TArray x, TArray y -> array x y
  | TTable x, TTable y -> table x y
  | _, _ -> compare x y

and array (x : Types.array) (y : Types.array) =
  match (x, y) with
  | NodeTable nt1, NodeTable nt2 -> list_compare ~f:table nt1 nt2
  | _ -> compare x y

and table (x : Types.table) (y : Types.table) = Types.Table.compare value x y
