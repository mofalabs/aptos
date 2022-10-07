
import 'dart:typed_data';

import 'package:aptos/aptos.dart';

class RotationProofChallenge with Serializable {
  
  RotationProofChallenge(
   this.accountAddress,
   this.moduleName,
   this.structName,
   this.sequenceNumber,
   this.originator,
   this.currentAuthKey,
   this.newPublicKey
  );

  final AccountAddress accountAddress;
  final String moduleName;
  final String structName;
  final BigInt sequenceNumber;
  final AccountAddress originator;
  final AccountAddress currentAuthKey;
  final Uint8List newPublicKey;

  @override
  void serialize(Serializer serializer) {
    accountAddress.serialize(serializer);
    serializer.serializeStr(moduleName);
    serializer.serializeStr(structName);
    serializer.serializeU64(sequenceNumber);
    originator.serialize(serializer);
    currentAuthKey.serialize(serializer);
    serializer.serializeBytes(newPublicKey);
  }
}
