import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha512.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/key_derivators/api.dart' show Pbkdf2Parameters;
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/pointycastle.dart' show KeyParameter;

/// Contains a derived cryptographic key and chain code.
class DerivedKeys {
  final Uint8List key;
  final Uint8List chainCode;

  const DerivedKeys({required this.key, required this.chainCode});
}

/// Aptos derive path is 637.
final RegExp aptosHardenedRegex =
    RegExp(r"^m\/44'\/637'\/[0-9]+'\/[0-9]+'\/[0-9]+'?$");

final RegExp aptosBip44Regex = RegExp(r"^m\/44'\/637'\/[0-9]+'\/[0-9]+\/[0-9]+$");

/// Supported key types and their associated seeds.
enum KeyType {
  ed25519('ed25519 seed');

  const KeyType(this.value);

  final String value;
}

const int hardenedOffset = 0x80000000;

/// Validate a BIP-44 derivation path string to ensure it meets the required
/// format. This function checks if the provided path adheres to the BIP-44
/// standard for Secp256k1, in form
/// m/44'/637'/{account_index}'/{change_index}/{address_index}.
///
/// Note that for Secp256k1, the last two components must be non-hardened.
bool isValidBIP44Path(String path) => aptosBip44Regex.hasMatch(path);

/// Aptos derive path is 637.
///
/// Parse and validate a path that is compliant to SLIP-0010 and BIP-44 in
/// form m/44'/637'/{account_index}'/{change_index}'/{address_index}'.
/// See SLIP-0010 https://github.com/satoshilabs/slips/blob/master/slip-0044.md
/// See BIP-44 https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki
///
/// Note that for Ed25519, all components must be hardened.
/// This is because non-hardened [PK] derivation would not work due to
/// Ed25519's lack of a key homomorphism. Specifically, you cannot derive the
/// PK associated with derivation path a/b/c given the PK of a/b.
bool isValidHardenedPath(String path) => aptosHardenedRegex.hasMatch(path);

Uint8List _toBytes(Object input) {
  if (input is Uint8List) return input;
  if (input is String) return Uint8List.fromList(utf8.encode(input));
  throw ArgumentError(
    'Input must be a String or Uint8List, got ${input.runtimeType}',
  );
}

Uint8List _hmacSha512(Uint8List key, Uint8List data) {
  final hmac = HMac(SHA512Digest(), 128)..init(KeyParameter(key));
  return hmac.process(data);
}

/// Derives a key and chain code from a hash seed and data using HMAC-SHA512.
/// [hashSeed] and [data] may each be a UTF-8 [String] or a [Uint8List].
DerivedKeys deriveKey(Object hashSeed, Object data) {
  final digest = _hmacSha512(_toBytes(hashSeed), _toBytes(data));
  return DerivedKeys(
    key: Uint8List.sublistView(digest, 0, 32),
    chainCode: Uint8List.sublistView(digest, 32),
  );
}

/// Derive a child key from the private key (SLIP-0010 hardened derivation).
DerivedKeys ckdPriv(DerivedKeys parent, int index) {
  final data = Uint8List(1 + parent.key.length + 4);
  data.setRange(1, 1 + parent.key.length, parent.key);
  final byteData = ByteData.sublistView(data);
  byteData.setUint32(1 + parent.key.length, index);
  return deriveKey(parent.chainCode, data);
}

/// Splits a derive path into segments, removing apostrophes.
List<String> splitPath(String path) =>
    path.split('/').sublist(1).map((el) => el.replaceAll("'", '')).toList();

/// Normalizes the mnemonic by removing extra whitespace and making it
/// lowercase, then derives the BIP-39 seed.
///
/// The seed is `PBKDF2(HMAC-SHA512, password = mnemonic, salt = "mnemonic",
/// c = 2048, dkLen = 64)`, per the BIP-39 specification.
Uint8List mnemonicToSeed(String mnemonic) {
  final normalizedMnemonic = mnemonic
      .trim()
      .split(RegExp(r'\s+'))
      .map((part) => part.toLowerCase())
      .join(' ');
  final derivator = PBKDF2KeyDerivator(HMac(SHA512Digest(), 128))
    ..init(Pbkdf2Parameters(
      Uint8List.fromList(utf8.encode('mnemonic')),
      2048,
      64,
    ));
  return derivator.process(Uint8List.fromList(utf8.encode(normalizedMnemonic)));
}

// ===
// BIP32 secp256k1 hierarchical-deterministic key derivation: derives a child
// private key from a master seed and a derivation path, used by
// Secp256k1PrivateKey.
// ===

final RegExp _bip32PathRegex = RegExp(r"^[mM](\/\d+'?)*$");

BigInt _bytesToBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}

Uint8List _bigIntTo32Bytes(BigInt value) {
  final bytes = Uint8List(32);
  var v = value;
  for (var i = 31; i >= 0; i -= 1) {
    bytes[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  return bytes;
}

/// Derives a secp256k1 private key from a master [seed] following BIP32,
/// using a derivation [path] such as `m/44'/637'/0'/0/0`.
Uint8List bip32DerivePrivateKey(Uint8List seed, String path) {
  if (!_bip32PathRegex.hasMatch(path)) {
    throw ArgumentError('Invalid BIP32 derivation path: $path');
  }

  final domain = ECCurve_secp256k1();
  final n = domain.n;

  final master = deriveKey('Bitcoin seed', seed);
  var key = _bytesToBigInt(master.key);
  var chainCode = master.chainCode;
  if (key == BigInt.zero || key >= n) {
    throw StateError('Invalid BIP32 master key derived from seed');
  }

  final segments = path.split('/').sublist(1);
  for (final segment in segments) {
    final hardened = segment.endsWith("'");
    final index =
        int.parse(hardened ? segment.substring(0, segment.length - 1) : segment);
    final childIndex = hardened ? index + hardenedOffset : index;

    final Uint8List data;
    if (childIndex >= hardenedOffset) {
      // Hardened child: 0x00 || ser256(k_par) || ser32(i)
      data = Uint8List(37);
      data.setRange(1, 33, _bigIntTo32Bytes(key));
    } else {
      // Normal child: serP(point(k_par)) || ser32(i)
      final publicPoint = (domain.G * key)!;
      data = Uint8List(37);
      data.setRange(0, 33, publicPoint.getEncoded(true));
    }
    ByteData.sublistView(data).setUint32(33, childIndex);

    final i = _hmacSha512(chainCode, data);
    final il = _bytesToBigInt(Uint8List.sublistView(i, 0, 32));
    final childKey = (il + key) % n;
    if (il >= n || childKey == BigInt.zero) {
      // Probability < 2^-127; BIP32 says to proceed with the next index, but
      // like most implementations we simply reject.
      throw StateError('Invalid BIP32 child key at segment $segment');
    }
    key = childKey;
    chainCode = Uint8List.sublistView(i, 32);
  }

  return _bigIntTo32Bytes(key);
}
