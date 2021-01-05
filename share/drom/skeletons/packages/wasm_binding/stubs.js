
//Provides: ml_reverse
//Requires: wasm, wasm_ready, walloc_u8, wextract_u8, wu64
function ml_reverse(b) {
  wasm_ready();
  var n = wu64(b.data.length);
  var p = walloc_u8(wasm, b);
  wasm._reverse(p, n);
  wextract_u8(wasm, b, p);
  return 0
}
