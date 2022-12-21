#!/bin/bash

path=src
output=dist/main.js
optimize="-O3"

while getopts o:p:O: flag; do
    case $flag in
        o) output=${OPTARG};;
        p) path=${OPTARG};;
        O) optimize="-O"${OPTARG};;
    esac
done

src=( !(c-names-dot-c) )

src=(${src[@]/#/$path/})

emcc \
    $optimize \
    -o $output \
    ${src[@]} \
    -DKRML_NOUINT128 \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s MODULARIZE=1 \
    -s EXPORT_NAME=wasm_loader \
    -s WASM_BIGINT=1 \
    -s EXPORTED_FUNCTIONS='[ "_malloc", "_free", "_reverse"]'

sed -i '1s/^/\/\/Provides: wasm_loader const/' $output
sed -i '3i\
  var ArrayBuffer = joo_global_object.ArrayBuffer;\
  var Browser = joo_global_object.Browser;\
  var Buffer = joo_global_object.Buffer;\
  var Float32Array = joo_global_object.Float32Array;\
  var Float64Array = joo_global_object.Float64Array;\
  var Int16Array = joo_global_object.Int16Array;\
  var Int32Array = joo_global_object.Int32Array;\
  var Int8Array = joo_global_object.Int8Array;\
  var Promise = joo_global_object.Promise;\
  var TextDecoder = joo_global_object.TextDecoder;\
  var Uint16Array = joo_global_object.Uint16Array;\
  var Uint32Array = joo_global_object.Uint32Array;\
  var Uint8Array = joo_global_object.Uint8Array;\
  var WebAssembly = joo_global_object.WebAssembly;\
  var __dirname = joo_global_object.__dirname;\
  var __filename = joo_global_object.__filename;\
  var clearInterval = joo_global_object.clearInterval;\
  var console = joo_global_object.console;\
  var crypto = joo_global_object.crypto;\
  var fetch = joo_global_object.fetch;\
  var importScripts = joo_global_object.importScripts;\
  var print = joo_global_object.print;\
  var printErr = joo_global_object.printErr;\
  var process = joo_global_object.process;\
  var quit = joo_global_object.quit;\
  var read = joo_global_object.read;\
  var readbuffer = joo_global_object.readbuffer;\
  var readline = joo_global_object.readline;\
  var scriptArgs = joo_global_object.scriptArgs;\
  var setTimeout = joo_global_object.setTimeout;' $output
sed -e :a -e '$d;N;2,7ba' -e 'P;D' -i $output
echo "
//Provides: wasm_ready
//Requires: caml_failwith
function wasm_ready() {
  caml_failwith('wasm not yet loaded');
}

//Provides: wasm
//Requires: wasm_loader, wasm_ready
var wasm = wasm_loader().then(function(r) {
  wasm = r;
  wasm_ready = function() { return true; };
})" >> $output
