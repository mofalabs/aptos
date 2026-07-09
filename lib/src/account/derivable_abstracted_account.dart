import 'dart:typed_data';

import 'package:pointycastle/digests/sha3.dart';

import '../bcs/serializer.dart';
import '../core/account_address.dart';
import '../core/hex.dart';
import '../transactions/authenticator/account.dart';
import '../types/move_types.dart';
import '../types/types.dart';
import '../utils/helpers.dart';
import 'abstracted_account.dart';

/// Signer implementation for the Derivable Account Abstraction (DAA)
/// authentication scheme, where the account address is derived from the
/// authentication function and an abstract public key.
class DerivableAbstractedAccount extends AbstractedAccount {
  /// The abstract public key that is used to identify the account.
  /// Depending on the use case, most of the time it is the public key of the
  /// source wallet.
  final Uint8List abstractPublicKey;

  /// The domain separator used to calculate the DAA account address.
  static const int addressDomainSeparator = 5;

  /// Creates a DerivableAbstractedAccount.
  ///
  /// [signer] is the function that signs the SHA3-256 digest of the
  /// transaction signing message and returns the `authenticator` bytes used
  /// in the `AbstractionAuthData`. [authenticationFunction] is the Move
  /// function used to verify the signature. [abstractPublicKey] is the
  /// abstract public key that identifies the account.
  DerivableAbstractedAccount({
    required super.signer,
    required super.authenticationFunction,
    required this.abstractPublicKey,
  }) : super(
          accountAddress: AccountAddress(
            DerivableAbstractedAccount.computeAccountAddress(
              authenticationFunction,
              abstractPublicKey,
            ),
          ),
        );

  /// Compute the account address of the DAA.
  ///
  /// The DAA account address is computed by hashing the function info and
  /// the account identity and appending the domain separator (5).
  ///
  /// [functionInfo] is the authentication function; [accountIdentifier] is
  /// the account identity.
  ///
  /// Throws a [StateError] if [functionInfo] is not a valid fully-qualified
  /// Move function name.
  static Uint8List computeAccountAddress(
    MoveFunctionId functionInfo,
    Uint8List accountIdentifier,
  ) {
    if (!isValidFunctionInfo(functionInfo)) {
      throw StateError(
        'Invalid authentication function $functionInfo passed into '
        'DerivableAbstractedAccount',
      );
    }
    final parts = functionInfo.split('::');

    final hash = SHA3Digest(256);

    // Serialize and append the function info.
    final serializer = Serializer();
    AccountAddress.fromString(parts[0]).serialize(serializer);
    serializer.serializeStr(parts[1]);
    serializer.serializeStr(parts[2]);
    final functionInfoBytes = serializer.toUint8List();
    hash.update(functionInfoBytes, 0, functionInfoBytes.length);

    // Serialize and append the account identity.
    final s2 = Serializer();
    s2.serializeBytes(accountIdentifier);
    final accountIdentityBytes = s2.toUint8List();
    hash.update(accountIdentityBytes, 0, accountIdentityBytes.length);

    // Append the domain separator.
    hash.updateByte(DerivableAbstractedAccount.addressDomainSeparator);

    final digest = Uint8List(hash.digestSize);
    hash.doFinal(digest, 0);
    return digest;
  }

  @override
  AccountAuthenticatorAbstraction signWithAuthenticator(HexInput message) {
    final messageBytes = Hex.fromHexInput(message).toUint8List();
    final digest = SHA3Digest(256).process(messageBytes);
    return AccountAuthenticatorAbstraction(
      authenticationFunction,
      digest,
      sign(digest).value,
      abstractPublicKey,
    );
  }
}
