open Utils
open Toml.Lenses

let () =
  let tbl = Toml.Types.Table.empty in
  let out = get tbl (key "I'm a key" |-- int) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=4" in
  let out = set 8 tbl (key "imatable" |-- table |-- key "imakey" |-- int) in
  match out with
  | None -> assert false
  | Some tbl ->
    let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- int) in
    assert (out = Some 8)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=true" in
  let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- int) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=false" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- bool) in
  assert (out = Some false)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=4" in
  let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- bool) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=true" in
  let out =
    set false tbl (key "imatable" |-- table |-- key "imakey" |-- bool)
  in
  match out with
  | None -> assert false
  | Some tbl ->
    let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- bool) in
    assert (out = Some false)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=0.1" in
  let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- float) in
  match out with None -> assert false | Some f -> assert (Float.equal 0.1 f)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=true" in
  let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- float) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=0.1" in
  let out =
    set 42.31 tbl (key "imatable" |-- table |-- key "imakey" |-- float)
  in
  match out with
  | None -> assert false
  | Some tbl -> (
    let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- float) in
    match out with
    | None -> assert false
    | Some f -> assert (Float.equal 42.31 f) )

let () =
  let tbl = unsafe_from_string {|[imatable] imakey="hello"|} in
  let out =
    set "goodbye" tbl (key "imatable" |-- table |-- key "imakey" |-- string)
  in
  match out with
  | None -> assert false
  | Some tbl ->
    let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- string) in
    assert (out = Some "goodbye")

let () =
  let tbl = unsafe_from_string "[imatable] imakey=true" in
  let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- string) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string {|[imatable] imakey=1995-09-06|} in
  let out = set 0.1 tbl (key "imatable" |-- table |-- key "imakey" |-- date) in
  match out with
  | None -> assert false
  | Some tbl ->
    let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- date) in
    assert (out = Some 0.1)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=true" in
  let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- date) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=true" in
  let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- array) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string {|[imatable] imakey=["hi"]|} in
  let out =
    set Toml.Types.NodeEmpty tbl
      (key "imatable" |-- table |-- key "imakey" |-- array)
  in
  match out with
  | None -> assert false
  | Some tbl ->
    let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- array) in
    assert (out = Some Toml.Types.NodeEmpty)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=true" in
  let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- table) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=false" in
  let out =
    update
      (fun b -> Some (not b))
      tbl
      (key "imatable" |-- table |-- key "imakey" |-- bool)
  in
  match out with
  | None -> assert false
  | Some tbl ->
    let out = get tbl (key "imatable" |-- table |-- key "imakey" |-- bool) in
    assert (out = Some true)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=false" in
  let out =
    update
      (fun _b -> None)
      tbl
      (key "imatable" |-- table |-- key "imakey" |-- bool)
  in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=4" in
  let out =
    update (fun _b -> None) tbl (field "imatable" |-- key "imakey" |-- bool)
  in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- strings) in
  assert (out = Some [])

let () =
  let tbl = unsafe_from_string {|[imatable] imakey=["hello"]|} in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- strings) in
  assert (out = Some [ "hello" ])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[true]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- strings) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[]" in
  let out =
    update
      (fun _v -> Some [ "hello" ])
      tbl
      (field "imatable" |-- key "imakey" |-- array |-- strings)
  in
  match out with
  | None -> assert false
  | Some tbl ->
    let out =
      get tbl (field "imatable" |-- key "imakey" |-- array |-- strings)
    in
    assert (out = Some [ "hello" ])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- bools) in
  assert (out = Some [])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[true]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- bools) in
  assert (out = Some [ true ])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[3]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- bools) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[true]" in
  let out =
    update
      (fun _v -> Some [ false ])
      tbl
      (field "imatable" |-- key "imakey" |-- array |-- bools)
  in
  match out with
  | None -> assert false
  | Some tbl ->
    let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- bools) in
    assert (out = Some [ false ])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- ints) in
  assert (out = Some [])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[77]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- ints) in
  assert (out = Some [ 77 ])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[true]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- ints) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[98]" in
  let out =
    update
      (fun _v -> Some [ 95 ])
      tbl
      (field "imatable" |-- key "imakey" |-- array |-- ints)
  in
  match out with
  | None -> assert false
  | Some tbl ->
    let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- ints) in
    assert (out = Some [ 95 ])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- floats) in
  assert (out = Some [])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[77.0]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- floats) in
  assert (out = Some [ 77. ])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[true]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- floats) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[98.0]" in
  let out =
    update
      (fun _v -> Some [ 95. ])
      tbl
      (field "imatable" |-- key "imakey" |-- array |-- floats)
  in
  match out with
  | None -> assert false
  | Some tbl ->
    let out =
      get tbl (field "imatable" |-- key "imakey" |-- array |-- floats)
    in
    assert (out = Some [ 95. ])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- dates) in
  assert (out = Some [])

let () =
  (* ISO8601 currently doesn't support dates < 1970 ; by chance it works on Unix so we only enable this test in that case *)
  if Sys.os_type = "Unix" then
    let tbl = unsafe_from_string "[imatable] imakey=[1956-11-23]" in
    let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- dates) in
    assert (out = Some [ -413596800. ])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[8]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- dates) in
  assert (out = None)

let () =
  (* ISO8601 currently doesn't support dates < 1970 ; by chance it works on Unix so we only enable this test in that case *)
  if Sys.os_type = "Unix" then
    let tbl = unsafe_from_string "[imatable] imakey=[1969-07-23]" in
    let out =
      update
        (fun _v -> Some [ 95. ])
        tbl
        (field "imatable" |-- key "imakey" |-- array |-- dates)
    in
    match out with
    | None -> assert false
    | Some tbl ->
      let out =
        get tbl (field "imatable" |-- key "imakey" |-- array |-- dates)
      in
      assert (out = Some [ 95. ])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- arrays) in
  assert (out = Some [])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[[]]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- arrays) in
  assert (out = Some [ NodeEmpty ])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[8]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- arrays) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[[4]]" in
  let out =
    update
      (fun _v -> Some [ Toml.Types.NodeEmpty ])
      tbl
      (field "imatable" |-- key "imakey" |-- array |-- arrays)
  in
  match out with
  | None -> assert false
  | Some tbl ->
    let out =
      get tbl (field "imatable" |-- key "imakey" |-- array |-- arrays)
    in
    assert (out = Some [ Toml.Types.NodeEmpty ])

(* tables *)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- tables) in
  assert (out = Some [])

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[true]" in
  let out = get tbl (field "imatable" |-- key "imakey" |-- array |-- tables) in
  assert (out = None)

let () =
  let tbl = unsafe_from_string "[imatable] imakey=[]" in
  let out =
    update
      (fun _v -> Some [ Toml.Types.Table.empty ])
      tbl
      (field "imatable" |-- key "imakey" |-- array |-- tables)
  in
  match out with
  | None -> assert false
  | Some tbl ->
    let out =
      get tbl (field "imatable" |-- key "imakey" |-- array |-- tables)
    in
    assert (out = Some [ Toml.Types.Table.empty ])
