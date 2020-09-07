(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let template_test_expect_dune =
  {|; if you modify this file, add 'test' to the 'skip' field in drom.toml

(library
 (name lib_expect_tests)
 (preprocess
  (pps ppx_expect))
 (inline_tests
  (modes best)) ; add js for testing with nodejs
 (libraries !{libraries}) ; add your project libraries here
 )
|}

let template_test_expect_test_ml =
  "let%expect_test \"addition\" =\n\
  \  Printf.printf \"%d\\n%!\" (1 + 2);\n\
  \  [%expect {| 3 |}]\n"

let template_test_inline_dune =
  {|; if you modify this file, add 'test' to the 'skip' field in drom.toml

(library
 (name lib_inline_tests)
 (preprocess
  (pps ppx_inline_test))
 (inline_tests
  (modes best)) ; add js for testing with nodejs
 (libraries !{libraries}))
|}

let template_test_inline_test_ml =
  {|let%test "must-return-true" = true

let%test_unit "must-return-unit" = ()

let%test_module "module" =
  ( module struct
    let%test "must-return-true" = true
  end )
|}

let template_test_output_dune =
  {|; if you modify this file, add 'test' to the 'skip' field in drom.toml

; a first example where we would test the behavior of one of the executables
; that we generate else-where

(rule
 (with-stdout-to
  test1.output
  (run cat test1.expected)))

(rule
 (alias runtest)
 (action
  (diff test1.expected test1.output)))

; a second example where we generate a file and test its output

(executable
 (name test2)
 (libraries !{libraries}) ; add your own library here
 )

(alias
 (name buildtest)
 (deps test2.exe))

(rule
 (with-stdout-to
  test2.output
  (run %{exe:test2.exe})))

(rule
 (alias runtest)
 (action
  (diff test2.expected test2.output)))
|}

let template_test_output_test2_ml =
  {|let () =
  Printf.printf "Bonjour\n%!";
  exit 0
|}

let template_test_output_test1_expected = "Hello world\n"

let template_test_output_test2_expected = "Bonjour\n"

let project_files =
  Misc.add_skip "test"
    [
      ("test/expect-tests/dune", template_test_expect_dune);
      ("test/expect-tests/test.ml", template_test_expect_test_ml);
      ("test/inline-tests/dune", template_test_inline_dune);
      ("test/inline-tests/test.ml", template_test_inline_test_ml);
      ("test/output-tests/dune", template_test_output_dune);
      ("test/output-tests/test1.expected", template_test_output_test1_expected);
      ("test/output-tests/test2.ml", template_test_output_test2_ml);
      ("test/output-tests/test2.expected", template_test_output_test2_expected);
    ]
