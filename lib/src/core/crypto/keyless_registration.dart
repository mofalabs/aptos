/// Registers the keyless `AnyPublicKey`/`AnySignature` variants into the
/// any-key registry.
///
/// Dart has no side-effect imports, so the registry calls
/// [registerKeylessCrypto] lazily before variant lookups. This ensures the
/// keyless variants are always available whenever a lookup occurs.
library;

import '../../types/types.dart';
import 'any_key_registry.dart';
import 'federated_keyless.dart';
import 'keyless.dart';

bool _registered = false;

/// Idempotently registers the Keyless and FederatedKeyless variants for
/// `AnyPublicKey` and the Keyless variant for `AnySignature`.
void registerKeylessCrypto() {
  if (_registered) return;
  _registered = true;

  registerAnyPublicKeyVariant(
    AnyPublicKeyVariant.keyless,
    KeylessPublicKey.deserialize,
    (key) => key is KeylessPublicKey ? AnyPublicKeyVariant.keyless : null,
  );
  registerAnyPublicKeyVariant(
    AnyPublicKeyVariant.federatedKeyless,
    FederatedKeylessPublicKey.deserialize,
    (key) => key is FederatedKeylessPublicKey
        ? AnyPublicKeyVariant.federatedKeyless
        : null,
  );
  registerAnySignatureVariant(
    AnySignatureVariant.keyless,
    KeylessSignature.deserialize,
    (signature) =>
        signature is KeylessSignature ? AnySignatureVariant.keyless : null,
  );
}
