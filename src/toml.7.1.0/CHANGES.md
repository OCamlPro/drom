This library is a modified version of toml.7.1.0 with the following changes:

* Additionnal syntax operators:
  * `x == y` : set variable `x` to value `y` only if `x` was not set before;
  * `x := y` : always set variable `x` to value `y`, even if already existing;
  * `x -=` : remove variable `x`;

* Changed syntax operators:
  * `x = y` : set variable `x` to variable `y`, but complains if `x` was already
  defined, unless the new `Types.override` is set to `true`;

* Misc changed parsing behavior:
  * Accept 0x hexa notation for integers
  * Allow setting variables by path: `x.y.z = v`

* Fixes:
  * Printer correctly prints multi-line strings (with delimiters and escape
  sequences)

* The current implementation is wrong. It cannot support nested groups within
  arrays.
