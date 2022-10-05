
class Signature {
  Signature(this.type, this.publicKey, this.signature);

  final String type;
  final String publicKey;
  final String signature;

  Map<String, String> toJson() {
    return <String, String>{
      "type": type,
      "public_key": publicKey,
      "signature": signature
    };
  }
}