!{header-ml}

(* If you delete or rename this file, you should add
   'src/!{name}/main.ml' to the 'skip' field in "drom.toml" *)

external hello_world: unit -> string = "hello_world"

let main () =
  print_endline @@ hello_world ()
