import 'dart:math';
import 'dart:typed_data';

import 'package:aptos/hex_string.dart';
import 'package:aptos/utils/hd_key.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;
import 'package:pointycastle/export.dart';
import 'package:bip39/bip39.dart' as bip39;

class AptosAccountObject {
  String? address;
  String? publicKeyHex;
  String? privateKeyHex;

  AptosAccountObject({this.address, this.publicKeyHex, this.privateKeyHex});
}


class AptosAccount {

  late final ed25519.KeyPair signingKey;

  late final HexString accountAddress;

  static AptosAccount fromAptosAccountObject(AptosAccountObject obj) {
    return AptosAccount(HexString.ensure(obj.privateKeyHex!).toUint8Array(), obj.address);
  }

  static bool isValidPath(String path) {
    if (RegExp(r"^m/44'/637'/[0-9]+'/[0-9]+'/[0-9]+'+$").hasMatch(path)) {
      return true;
    }
    return false;
  }

  static bool isValidMnemonics(String mnemonics) {
    return bip39.validateMnemonic(mnemonics);
  }

  static SecureRandom _getRandom() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = <int>[];
    for (int i = 0; i < 32; i++) {
      seeds.add(seedSource.nextInt(255));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  static String generateMnemonic({int strength = 128 }) {
    return bip39.generateMnemonic(strength: strength, randomBytes: _getRandom().nextBytes);
  }

  static AptosAccount generateAccount(String mnemonics, { int addressIndex = 0, int accountIndex = 0 }) {
    String path = "m/44'/637'/$accountIndex'/0'/$addressIndex'";
    return fromDerivePath(path, mnemonics);
  }


  static AptosAccount fromDerivePath(String path, String mnemonics) {
    if (!isValidPath(path)) {
      throw ArgumentError("Invalid derivation path");
    }

    if (!isValidMnemonics(mnemonics)) {
      throw ArgumentError("Invalid mnemonics");
    }

    final normalizeMnemonics = mnemonics
      .trim()
      .split(r"\s+")
      .map((part) => part.toLowerCase())
      .join(" ");
    
    final keys = derivePath(path, bip39.mnemonicToSeedHex(normalizeMnemonics));
    return AptosAccount(keys.key);
  }

  AptosAccount([Uint8List? privateKeyBytes, String? address]) {
    if (privateKeyBytes != null) {
      if (privateKeyBytes.length != 32 && privateKeyBytes.length != 64) {
        throw ArgumentError("Invalid private key");
      }
      final sk = ed25519.newKeyFromSeed(privateKeyBytes.sublist(0, 32));
      final pk = ed25519.public(sk);
      signingKey = ed25519.KeyPair(sk, pk);
    } else {
      signingKey = ed25519.generateKey();
    }
    
    accountAddress = HexString.ensure(address ?? authKey().hex());
  }

  String get address =>  accountAddress.hex();

  HexString authKey() {
    final pkBytes = publicKeyBytes(signingKey);
    final sha3 = SHA3Digest(256);
    sha3.update(pkBytes, 0, pkBytes.lengthInBytes);
    sha3.updateByte(0x00);
    final hash = Uint8List(sha3.digestSize);
    sha3.doFinal(hash, 0);
    return HexString.fromUint8Array(hash);
  }

  HexString pubKey() {
    return HexString.fromUint8Array(publicKeyBytes(signingKey));
  }

  HexString signBuffer(Uint8List buffer) {
    final signature = ed25519.sign(signingKey.privateKey, buffer);
    return HexString.fromUint8Array(signature.sublist(0, 64));
  }

  HexString signHexString(String hexString) {
    final toSign = HexString.ensure(hexString).toUint8Array();
    return signBuffer(toSign);
  }

  AptosAccountObject toPrivateKeyObject() {
    final privateKey = signingKey.privateKey.bytes.sublist(0, 32);
    return AptosAccountObject(
      address: address,
      publicKeyHex: pubKey().hex(),
      privateKeyHex: HexString.fromUint8Array(Uint8List.fromList(privateKey)).hex(),
    );
  }

  Uint8List publicKeyBytes(ed25519.KeyPair keypair) {
    return Uint8List.fromList(keypair.publicKey.bytes);
  }
}
