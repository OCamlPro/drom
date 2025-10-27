(* For more informations about unicode to utf-8 converting method used see:
 * http://www.ietf.org/rfc/rfc3629.txt (Page3, section "3. UTF-8 definition")
 *)

(* decimal conversions of binary used:
 * 10000000 -> 128; 11000000 -> 192; 11100000 -> 224 *)

(* This function convert Unicode escaped XXXX to utf-8 encoded string *)

let to_utf8 u =
  let dec = int_of_string @@ "0x" ^ u in
  let update_byte s i mask shift =
    Char.chr
    @@ (Char.code (Bytes.get s i) + ((dec lsr shift) land int_of_string mask))
    |> Bytes.set s i
  in
  if dec > 0xFFFF then failwith ("Invalid escaped unicode \\u" ^ u)
  else if dec > 0x7FF then (
    let s = Bytes.of_string "\224\128\128" in
    update_byte s 2 "0b00111111" 0;
    update_byte s 1 "0b00111111" 6;
    update_byte s 0 "0b00001111" 12;
    Bytes.to_string s )
  else if dec > 0x7F then (
    let s = Bytes.of_string "\192\128" in
    update_byte s 1 "0b00111111" 0;
    update_byte s 0 "0b00011111" 6;
    Bytes.to_string s )
  else
    let s = Bytes.of_string "\000" in
    update_byte s 0 "0b01111111" 0;
    Bytes.to_string s
