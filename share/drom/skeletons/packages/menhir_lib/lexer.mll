{
  !{header-ml}

(* If you delete or rename this file, you should add 'src/!{name}/lexer.mll' to the 'skip' field in "drom.toml" *)

open Parser
}

let ws = ['\n' '\r' '\t' ' ']*
let var_id = ['a'-'z' 'A'-'Z' '_' '-']*

rule token = parse
  | ws { token lexbuf }
  | var_id as v { VARID v }
  | "fun" { FUN }
  | "let" { LET }
  | "->" { ARROW }
  | "()" { UNIT }
  | "=" { EQ }
  | "(" { LPAR }
  | ")" { RPAR }
  | eof { EOF }
  | _ { failwith "unexpected char" }
