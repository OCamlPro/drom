let safe_find key table =
  try
    let value = Types.Table.find (Types.Table.Key.of_string key) table in
    Some value
  with Not_found -> None

type ('a, 'b) lens =
  { get : 'a -> 'b option
  ; set : 'b -> 'a -> 'a option
  }

let key k =
  { get = (fun value -> safe_find k value)
  ; set =
      (fun new_value value ->
        Some (Types.Table.add (Types.Table.Key.of_string k) new_value value) )
  }

let bool =
  { get =
      (fun (value : Types.value) ->
        match value with Types.TBool v -> Some v | _ -> None )
  ; set = (fun new_value _value -> Some (Types.TBool new_value))
  }

let int =
  { get =
      (fun (value : Types.value) ->
        match value with Types.TInt v -> Some v | _ -> None )
  ; set = (fun new_value _value -> Some (Types.TInt new_value))
  }

let float =
  { get =
      (fun (value : Types.value) ->
        match value with Types.TFloat v -> Some v | _ -> None )
  ; set = (fun new_value _value -> Some (Types.TFloat new_value))
  }

let string =
  { get =
      (fun (value : Types.value) ->
        match value with Types.TString v -> Some v | _ -> None )
  ; set = (fun new_value _value -> Some (Types.TString new_value))
  }

let date =
  { get =
      (fun (value : Types.value) ->
        match value with Types.TDate v -> Some v | _ -> None )
  ; set = (fun new_value _value -> Some (Types.TDate new_value))
  }

let array =
  { get =
      (fun (value : Types.value) ->
        match value with Types.TArray v -> Some v | _ -> None )
  ; set = (fun new_value _value -> Some (Types.TArray new_value))
  }

let table =
  { get =
      (fun (value : Types.value) ->
        match value with Types.TTable v -> Some v | _ -> None )
  ; set = (fun new_value _value -> Some (Types.TTable new_value))
  }

let strings =
  { get =
      (fun (value : Types.array) ->
        match value with
        | Types.NodeString v -> Some v
        | Types.NodeEmpty -> Some []
        | _ -> None )
  ; set = (fun new_value _value -> Some (Types.NodeString new_value))
  }

let bools =
  { get =
      (fun (value : Types.array) ->
        match value with
        | Types.NodeBool v -> Some v
        | Types.NodeEmpty -> Some []
        | _ -> None )
  ; set = (fun new_value _value -> Some (Types.NodeBool new_value))
  }

let ints =
  { get =
      (fun (value : Types.array) ->
        match value with
        | Types.NodeInt v -> Some v
        | Types.NodeEmpty -> Some []
        | _ -> None )
  ; set = (fun new_value _value -> Some (Types.NodeInt new_value))
  }

let floats =
  { get =
      (fun (value : Types.array) ->
        match value with
        | Types.NodeFloat v -> Some v
        | Types.NodeEmpty -> Some []
        | _ -> None )
  ; set = (fun new_value _value -> Some (Types.NodeFloat new_value))
  }

let dates =
  { get =
      (fun (value : Types.array) ->
        match value with
        | Types.NodeDate v -> Some v
        | Types.NodeEmpty -> Some []
        | _ -> None )
  ; set = (fun new_value _value -> Some (Types.NodeDate new_value))
  }

let arrays =
  { get =
      (fun (value : Types.array) ->
        match value with
        | Types.NodeArray v -> Some v
        | Types.NodeEmpty -> Some []
        | _ -> None )
  ; set = (fun new_value _value -> Some (Types.NodeArray new_value))
  }

let tables =
  { get =
      (fun (value : Types.array) ->
        match value with
        | Types.NodeTable v -> Some v
        | Types.NodeEmpty -> Some []
        | _ -> None )
  ; set = (fun new_value _value -> Some (Types.NodeTable new_value))
  }

let ( |- ) (f : 'a -> 'b option) (g : 'b -> 'c option) (x : 'a) =
  match f x with Some r -> g r | None -> None

let modify (l : ('a, 'b) lens) (f : 'b -> 'b option) (a : 'a) =
  match l.get a with
  | Some old_value -> (
    match f old_value with Some new_value -> l.set new_value a | None -> None )
  | None -> None

let update f value lens = modify lens f value

let compose (l1 : ('a, 'b) lens) (l2 : ('c, 'a) lens) =
  { get = l2.get |- l1.get; set = (fun v -> modify l2 (l1.set v)) }

let ( |-- ) l1 l2 = compose l2 l1

let field k = key k |-- table

let get record lens = lens.get record

let set value record lens = lens.set value record
