!{header-ml}

open Ppxlib
open Ast_builder.Default

let verbose = match Sys.getenv_opt "!{name:upp}_DEBUG" with
  | None | Some "0" | Some "false" | Some "no" -> 0
  | Some s ->
    match s with
    | "true" -> 1
    | s -> match int_of_string_opt s with
      | Some i -> i
      | None -> 0

let dprintf ?(v=1) ?(force=false) fmt =
  if force || verbose >= v then Format.ksprintf (fun s -> Format.eprintf "%s@." s) fmt
  else Printf.ifprintf () fmt

let str_of_structure e = Pprintast.string_of_structure e
let str_of_signature e =
  Pprintast.signature Format.str_formatter e;
  Format.flush_str_formatter ()




let str_gen ~loc ~path:_ (rec_flag, l) debug name =
  let s = List.map (fun ( _t : type_declaration ) ->
      pstr_value ~loc rec_flag
        [value_binding ~loc
           ~pat:(pvar ~loc "x" )
             ~expr:(pexp_construct ~loc {loc; txt=Longident.parse "None"} None)
        ]) l in
  dprintf ~force:debug "%s: %s\n"
    (match name with
     | None -> "any"
     | Some name -> name) (str_of_structure s);
  s

let sig_gen ~loc ~path:_ (_rec_flag, l) debug =
  let s = List.map (fun ( _t : type_declaration ) ->
      psig_value ~loc (
        value_description ~loc ~name:{txt="x"; loc}
          ~type_:
            (ptyp_constr ~loc {txt= Longident.parse "int";loc} []) ~prim:[]
      )
    ) l
  in
  dprintf ~force:debug "%s\n" (str_of_signature s);
  s

let () =

  let args_str = Deriving.Args.(
      empty
      +> flag "debug"
      +> arg "name" (estring __)
    ) in
  let str_type_decl = Deriving.Generator.make args_str str_gen in

  let args_sig = Deriving.Args.(
      empty
      +> flag "debug"
    ) in
  let sig_type_decl = Deriving.Generator.make args_sig sig_gen in

  Deriving.ignore @@ Deriving.add "!{name}" ~str_type_decl ~sig_type_decl
