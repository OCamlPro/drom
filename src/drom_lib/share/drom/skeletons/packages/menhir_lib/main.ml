!{header-ml}

(* If you delete or rename this file, you should add 'src/!{name}/main.ml' to the 'skip' field in "drom.toml" *)

let main () =

  if Array.length Sys.argv <> 2 then begin
    Format.eprintf "usage: %s <file>@." Sys.argv.(0);
    exit 1
  end;

  let file = Sys.argv.(1) in

  if not @@ Sys.file_exists file then begin
    Format.eprintf "file `%s` doesn't exist@." file;
    exit 1
  end;

  if Sys.is_directory file then begin
    Format.eprintf "file `%s` is a directory@." file;
    exit 1
  end;

  let channel = open_in file in

  let buf = Lexing.from_channel channel in

  let e =
    try Parser.file Lexer.token buf
    with _e -> begin
      Format.eprintf "error while parsing file `%s`@." file;
      exit 1
    end
  in

  close_in channel;

  Format.printf "%a@." Printer.pp_e e
