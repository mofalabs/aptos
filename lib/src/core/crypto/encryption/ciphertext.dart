import 'dart:typed_data';

import '../../../bcs/deserializer.dart';
import '../../../bcs/serializer.dart';
import '../ed25519.dart';
import 'bls12381.dart';
import 'symmetric.dart';

/// ed25519 verification key length in bytes.
const int _vkLength = 32;

/// ed25519 signature length in bytes.
const int _signatureLength = 64;

/// Number of compressed G2 elements in a BIBE ciphertext.
const int _ctG2Count = 3;

/// Compressed BLS12-381 G2 element length in bytes.
const int _g2Size = 96;

/// Hashes a G2 element to a G1 point using the batch-encryption domain
/// separation tag. Used to derive the BIBE one-time-pad source.
G1Point hashG2Element(G2Point g2Element) =>
    hashToCurveG1(g2Element.toCompressedBytes(), hashG2ElementDst);

/// BIBE (identity-based) ciphertext.
///
/// Corresponds to the Rust type
/// `aptos_batch_encryption::shared::ciphertext::BIBECiphertext`. The curve
/// points and symmetric primitives are held as their raw byte representations
/// so the BCS wire layout is byte-exact.
///
/// BCS: `id` bytes | `ct_g2` bytes (a single length prefix for all 3 G2
/// elements) | padded key fixed 16 bytes | GCM nonce fixed 12 bytes |
/// ciphertext body bytes.
class BIBECiphertext extends Serializable {
  /// Little-endian Fr scalar bytes (length-prefixed on the wire).
  final Uint8List idBytes;

  /// Concatenated compressed G2 points (length-prefixed on the wire).
  final Uint8List ctG2Bytes;

  /// Padded symmetric key, fixed 16 bytes.
  final Uint8List paddedKey;

  /// AES-GCM nonce, fixed 12 bytes.
  final Uint8List gcmNonce;

  /// Symmetric ciphertext body (length-prefixed on the wire).
  final Uint8List ctBody;

  BIBECiphertext({
    required this.idBytes,
    required this.ctG2Bytes,
    required this.paddedKey,
    required this.gcmNonce,
    required this.ctBody,
  }) {
    if (paddedKey.length != symmetricKeyLength) {
      throw ArgumentError('paddedKey must be $symmetricKeyLength bytes');
    }
    if (gcmNonce.length != gcmNonceLength) {
      throw ArgumentError('gcmNonce must be $gcmNonceLength bytes');
    }
  }

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(idBytes);
    // BCS: a single length prefix covers all 3 G2 elements (matches the
    // arkworks-serde wrapper in Rust).
    serializer.serializeBytes(ctG2Bytes);
    serializer.serializeFixedBytes(paddedKey);
    serializer.serializeFixedBytes(gcmNonce);
    serializer.serializeBytes(ctBody);
  }

  static BIBECiphertext deserialize(Deserializer deserializer) {
    final idBytes = deserializer.deserializeBytes();
    final ctG2Bytes = deserializer.deserializeBytes();
    final paddedKey = deserializer.deserializeFixedBytes(symmetricKeyLength);
    final gcmNonce = deserializer.deserializeFixedBytes(gcmNonceLength);
    final ctBody = deserializer.deserializeBytes();
    return BIBECiphertext(
      idBytes: idBytes,
      ctG2Bytes: ctG2Bytes,
      paddedKey: paddedKey,
      gcmNonce: gcmNonce,
      ctBody: ctBody,
    );
  }
}

/// A batch-encryption ciphertext.
///
/// Corresponds to the Rust type
/// `aptos_batch_encryption::shared::ciphertext::Ciphertext`.
class Ciphertext extends Serializable {
  /// ed25519 verification key, 32 bytes (length-prefixed on the wire).
  final Uint8List vk;

  final BIBECiphertext bibeCt;

  final Uint8List associatedDataBytes;

  /// ed25519 signature, fixed 64 bytes.
  final Uint8List signature;

  Ciphertext(this.vk, this.bibeCt, this.associatedDataBytes, this.signature) {
    if (vk.length != _vkLength) {
      throw ArgumentError(
        'ed25519 public key must be $_vkLength bytes, got ${vk.length}',
      );
    }
    if (signature.length != _signatureLength) {
      throw ArgumentError(
        'ed25519 signature must be $_signatureLength bytes, '
        'got ${signature.length}',
      );
    }
  }

  @override
  void serialize(Serializer serializer) {
    // Rust: ed25519 VKs serialized as variable bytes.
    serializer.serializeBytes(vk);
    bibeCt.serialize(serializer);
    serializer.serializeBytes(associatedDataBytes);
    // Rust: signatures serialized as fixed bytes.
    serializer.serializeFixedBytes(signature);
  }

  static Ciphertext deserialize(Deserializer deserializer) {
    final vk = deserializer.deserializeBytes();
    final bibeCt = BIBECiphertext.deserialize(deserializer);
    final associatedDataBytes = deserializer.deserializeBytes();
    final signature = deserializer.deserializeFixedBytes(_signatureLength);
    return Ciphertext(vk, bibeCt, associatedDataBytes, signature);
  }
}

/// The node's per-epoch batch-encryption public key.
///
/// Corresponds to the Rust type
/// `aptos_batch_encryption::shared::encryption_key::EncryptionKey`. Fetch it
/// from the fullnode ledger info, deserialize from BCS, then [encrypt] a
/// payload against it.
class EncryptionKey extends Serializable {
  /// The signer master public key, a G2 element.
  final G2Point sigMpkG2;

  /// The tau element, a G2 element.
  final G2Point tauG2;

  EncryptionKey(this.sigMpkG2, this.tauG2);

  @override
  void serialize(Serializer serializer) {
    serializer.serializeBytes(sigMpkG2.toCompressedBytes());
    serializer.serializeBytes(tauG2.toCompressedBytes());
  }

  static EncryptionKey deserialize(Deserializer deserializer) {
    final sigMpkG2 =
        G2Point.fromCompressedBytes(deserializer.deserializeBytes());
    final tauG2 = G2Point.fromCompressedBytes(deserializer.deserializeBytes());
    return EncryptionKey(sigMpkG2, tauG2);
  }

  /// Encrypts [plaintext] with [associatedData], producing a [Ciphertext].
  ///
  /// Mirrors the Rust flow: derive `Id = hash(vk || BCS(associatedData))` with
  /// the identity domain separator, BIBE-encrypt under that id, then sign the
  /// `(bibeCiphertext, associatedData)` tuple with a fresh ed25519 key so the
  /// node can authenticate the ciphertext without decrypting it.
  Ciphertext encrypt(Serializable plaintext, Serializable associatedData) {
    final secretKey = Ed25519PrivateKey.generate();
    final publicKey = secretKey.publicKey().toUint8Array();

    final associatedDataBytes = associatedData.bcsToBytes();

    final preimage = Uint8List(publicKey.length + associatedDataBytes.length)
      ..setRange(0, publicKey.length, publicKey)
      ..setRange(publicKey.length,
          publicKey.length + associatedDataBytes.length, associatedDataBytes);
    final id = hashToFr(preimage, idHashDst);

    final bibeCt = bibeEncrypt(plaintext, id);

    // to_sign = (bibeCt, associatedDataBytes) as a BCS tuple.
    final toSignSerializer = Serializer();
    bibeCt.serialize(toSignSerializer);
    toSignSerializer.serializeBytes(associatedDataBytes);
    final toSign = toSignSerializer.toUint8List();

    final signature = secretKey.signBytes(toSign).toUint8Array();

    return Ciphertext(publicKey, bibeCt, associatedDataBytes, signature);
  }

  /// BIBE-encrypts [plaintext] against identity [id].
  ///
  /// The blinding scalars [r0]/[r1] and the symmetric [symmetricKey]/[nonce]
  /// are sampled at random when omitted; they may be supplied to make the
  /// output deterministic (used only for testing).
  BIBECiphertext bibeEncrypt(
    Serializable plaintext,
    BigInt id, {
    BigInt? r0,
    BigInt? r1,
    Uint8List? symmetricKey,
    Uint8List? nonce,
  }) {
    final blind0 = r0 ?? getRandomFr();
    final blind1 = r1 ?? getRandomFr();

    final ctG2Points = <G2Point>[
      G2Point.base.multiply(blind0).add(sigMpkG2.multiply(blind1)),
      G2Point.base.multiply(id).subtract(tauG2).multiply(blind0),
      G2Point.base.negate().multiply(blind1),
    ];
    final ctG2Bytes = Uint8List(_g2Size * _ctG2Count);
    for (var i = 0; i < _ctG2Count; i += 1) {
      ctG2Bytes.setRange(
        i * _g2Size,
        (i + 1) * _g2Size,
        ctG2Points[i].toCompressedBytes(),
      );
    }

    final hashedEncryptionKey = hashG2Element(sigMpkG2);
    final g1Point = hashedEncryptionKey.multiply(blind1);
    // Target-group element: invert the pairing output before deriving the pad.
    final otpSource = blsPairing(g1Point, sigMpkG2).inverse().toLEBytes();
    final otp = deriveOneTimePad(otpSource);

    final symKey = symmetricKey ?? randomBytes(symmetricKeyLength);
    final paddedKey = padKey(symKey, otp);

    final gcmNonce = nonce ?? randomBytes(gcmNonceLength);
    final ctBody = aesGcmEncrypt(symKey, gcmNonce, plaintext.bcsToBytes());

    return BIBECiphertext(
      idBytes: frToLEBytes(id),
      ctG2Bytes: ctG2Bytes,
      paddedKey: paddedKey,
      gcmNonce: gcmNonce,
      ctBody: ctBody,
    );
  }
}
