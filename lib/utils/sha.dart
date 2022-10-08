
import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha3.dart';

final sha3Hash = SHA3Digest(256);

Uint8List sha3256(Uint8List data) {
  sha3Hash.reset();
  return sha3Hash.process(data);
}

Uint8List sha3256FromString(String str) {
  sha3Hash.reset();
  final data = Uint8List.fromList(utf8.encode(str));
  return sha3Hash.process(data);
}