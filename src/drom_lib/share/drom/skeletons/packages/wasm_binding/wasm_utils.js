//Provides: walloc_u8
function walloc_u8(w, o) {
  var p = w._malloc(o.data.length * o.data.BYTES_PER_ELEMENT);
  w.HEAPU8.set(o.data, p);
  return p;
}

//Provides: wextract_u8
function wextract_u8(w, o, p) {
  var d = new joo_global_object.Uint8Array(w.HEAPU8.buffer, p, o.data.length);
  for (var i = 0; i < o.data.length; i++) { o.data[i] = d[i]; };
  w._free(p);
  return 0;
}

//Provides: walloc_u32
function walloc_u32(w, o) {
  var d = new joo_global_object.Uint32Array(o.data.buffer);
  var p = w._malloc(d.length * d.BYTES_PER_ELEMENT);
  w.HEAPU32.set(d, p >> 2);
  return p;
}

//Provides: wextract_u32
function wextract_u32(w, o, p) {
  o.data = new joo_global_object.Uint8Array(w.HEAPU32.buffer, p, o.data.length);
  w._free(p);
  return 0;
}

//Provides: wfree
function wfree(w, p) {
  w._free(p);
  return 0;
}

//Provides: wu32
//Requires: caml_failwith
function wu32(i32) {
  var u32 = i32 >>> 0;
  if (i32 != u32) caml_failwith("length is not a uint32");
  return u32;
}

//Provides: wu64
//Requires: caml_failwith
function wu64(i32) {
  var u64 = joo_global_object.BigInt(i32 >>> 0);
  if (i32 != u64) caml_failwith("length is not a uint64");
  return u64;
}
