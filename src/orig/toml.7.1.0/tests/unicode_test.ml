let () =
  ( try
      (* this is expected to fail, if it does we exit cleanly, otherwise we fail *)
      let s = Toml.Unicode.to_utf8 "FFFF1" in
      if String.equal s "this is juste to type check" then () else ()
    with Failure _ -> exit 0 );
  assert false
