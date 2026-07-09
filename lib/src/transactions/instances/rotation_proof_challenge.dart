import '../../bcs/serializable/move_primitives.dart';
import '../../bcs/serializable/move_structs.dart';
import '../../bcs/serializer.dart';
import '../../core/account_address.dart';
import '../../core/crypto/public_key.dart';

/// Represents a challenge required for the account owner to sign in order to
/// rotate the authentication key.
class RotationProofChallenge extends Serializable {
  /// Resource account address.
  final AccountAddress accountAddress = AccountAddress.one;

  /// Module name, i.e: 0x1::account.
  final MoveString moduleName = MoveString('account');

  /// The rotation proof challenge struct name that lives under the module.
  final MoveString structName = MoveString('RotationProofChallenge');

  /// Signer's address.
  final AccountAddress originator;

  /// Signer's current authentication key.
  final AccountAddress currentAuthKey;

  /// New public key to rotate to.
  final MoveVector<U8> newPublicKey;

  /// Sequence number of the account.
  final U64 sequenceNumber;

  /// Initializes a new instance of the class with the specified parameters.
  /// This constructor sets up the necessary attributes for managing account
  /// keys.
  ///
  /// [sequenceNumber] - The sequence number associated with the transaction.
  /// [originator] - The account address of the originator.
  /// [currentAuthKey] - The current authentication key of the account.
  /// [newPublicKey] - The new public key to be set for the account.
  RotationProofChallenge({
    required BigInt sequenceNumber,
    required this.originator,
    required this.currentAuthKey,
    required PublicKey newPublicKey,
  })  : sequenceNumber = U64(sequenceNumber),
        newPublicKey = MoveVector.u8(newPublicKey.toUint8Array());

  /// Serializes the properties of the current instance for transmission or
  /// storage.
  @override
  void serialize(Serializer serializer) {
    serializer.serialize(accountAddress);
    serializer.serialize(moduleName);
    serializer.serialize(structName);
    serializer.serialize(sequenceNumber);
    serializer.serialize(originator);
    serializer.serialize(currentAuthKey);
    serializer.serialize(newPublicKey);
  }
}
