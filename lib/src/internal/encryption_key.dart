import '../api/aptos_config.dart';
import '../bcs/deserializer.dart';
import '../core/hex.dart';
import '../transactions/instances/encrypted_payload.dart';
import 'general.dart';

/// A cached encryption key together with the epoch it was fetched for.
class _CachedEncryptionKey {
  final String epoch;
  final EncryptionKey key;
  const _CachedEncryptionKey(this.epoch, this.key);
}

final Map<String, _CachedEncryptionKey> _encryptionKeyCache = {};

/// Fetches the node's per-epoch batch-encryption key from the fullnode ledger
/// info, deserializes it, and caches it by fullnode URL (or network) and
/// epoch.
///
/// Returns null when the node does not advertise an encryption key (i.e. it
/// does not support encrypted transaction submission).
Future<({EncryptionKey key, BigInt epoch})?> fetchAndCacheEncryptionKey({
  required AptosConfig aptosConfig,
}) async {
  final cacheKey =
      'encryption-key-${aptosConfig.fullnode ?? aptosConfig.network}';

  final ledgerInfo = await getLedgerInfo(aptosConfig: aptosConfig);

  final cached = _encryptionKeyCache[cacheKey];
  if (cached != null && cached.epoch == ledgerInfo.epoch) {
    return (key: cached.key, epoch: BigInt.parse(cached.epoch));
  }

  final hexKey = ledgerInfo.encryptionKey;
  if (hexKey == null) {
    return null;
  }

  final keyBytes = Hex.fromHexInput(hexKey).toUint8List();
  final key = EncryptionKey.deserialize(Deserializer(keyBytes));

  _encryptionKeyCache[cacheKey] = _CachedEncryptionKey(ledgerInfo.epoch, key);
  return (key: key, epoch: BigInt.parse(ledgerInfo.epoch));
}
