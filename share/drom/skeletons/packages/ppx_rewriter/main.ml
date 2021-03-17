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

let expand_ext ~loc ~path:_ expr = match expr.pexp_desc with
  | Pexp_record (l, _) ->
    let e = pexp_tuple ~loc (List.map snd l) in
    dprintf "%s\nchanged in\n%s\n"
      (Pprintast.string_of_expression expr)
      (Pprintast.string_of_expression e);
    e
  | _ -> expr

let extension_ext =
  Extension.declare "ext"
    Extension.Context.expression
    Ast_pattern.(single_expr_payload __)
    expand_ext

let rule_ext = Context_free.Rule.extension extension_ext

let () =
  Driver.register_transformation "ppx_ext" ~rules:[rule_ext]
