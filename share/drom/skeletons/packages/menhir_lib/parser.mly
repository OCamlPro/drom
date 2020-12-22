%{

!{header-ml}

(* If you delete or rename this file, you should add 'src/!{name}/parser.mly' to the 'skip' field in "drom.toml" *)

open Types

 %}

%token ARROW
%token EOF
%token EQ
%token FUN
%token IN
%token LET
%token LPAR
%token RPAR
%token UNIT
%token<bool> BOOL
%token<float> FLOAT
%token<int> INT
%token<string> STRING
%token<string> VARID

%right LET
%right IN
%left FUN
%left ARROW
%left LPAR
%left DUMMY_APPLY
%left VARID
%left CURRY

%start <Types.e> file

%%
let literal ==
| UNIT; { Unit }
| ~ = BOOL; <Bool>
| ~ = INT; <Int>
| ~ = FLOAT; <Float>
| ~ = STRING; <String>

let var_id ==
| ~ = VARID; <>

let const ==
| ~ = literal; <Literal>
| ~ = var_id; <Var>

let e :=
| LPAR; ~ = e; RPAR; <>
| ~ = const; <Const>
| FUN; ~ = VARID; ARROW; ~ = e; <Abstract>
| LET; var_id = VARID; args = list(VARID); EQ; e1 = e; IN; e2 = e; {
  Bind (
    var_id,
    List.fold_right (fun el acc -> Abstract (el, acc)) args e1,
    e2 )}
| ~ = e; ~ = curry; {
  List.fold_left (fun acc el -> Apply (acc, el)) e curry } %prec DUMMY_APPLY

let curry :=
| ~ = curry; ~ = e; { curry @ [e] } %prec CURRY
| ~ = e; { [e] } %prec CURRY

let file :=
| ~ = terminated(e, EOF); <>
