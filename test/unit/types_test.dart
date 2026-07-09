import 'dart:convert';

import 'package:aptos/src/types/ledger.dart';
import 'package:aptos/src/types/move_types.dart';
import 'package:aptos/src/types/pagination.dart';
import 'package:aptos/src/types/transaction_responses.dart';
import 'package:aptos/src/types/types.dart';
import 'package:test/test.dart';

/// Runs a fixture through a JSON encode/decode cycle so it has the exact
/// runtime types (`Map<String, dynamic>`, `List<dynamic>`) that a real API
/// response would have after `jsonDecode`.
Map<String, dynamic> normalize(Map<String, dynamic> fixture) =>
    jsonDecode(jsonEncode(fixture)) as Map<String, dynamic>;

void main() {
  group('LedgerInfo', () {
    test('round-trips getLedgerInfo JSON', () {
      final fixture = normalize({
        'chain_id': 1,
        'epoch': '9331',
        'ledger_version': '1962588495',
        'oldest_ledger_version': '0',
        'ledger_timestamp': '1719522395048723',
        'node_role': 'full_node',
        'oldest_block_height': '0',
        'block_height': '244134793',
        'git_hash': '48e42a171b1d0a1a1d18c6f81b6b0f45c8a45742',
      });

      final info = LedgerInfo.fromJson(fixture);
      expect(info.chainId, 1);
      expect(info.nodeRole, RoleType.fullNode);
      expect(info.ledgerVersion, '1962588495');
      expect(info.encryptionKey, isNull);
      expect(info.toJson(), equals(fixture));
    });
  });

  group('AccountData', () {
    test('round-trips account JSON', () {
      final fixture = normalize({
        'sequence_number': '27',
        'authentication_key':
            '0x0d2b54ffd7b1c73f2fd8d192ee92e97d43838f2ecec322a0acbf3d8ab4fed163',
      });

      final account = AccountData.fromJson(fixture);
      expect(account.sequenceNumber, '27');
      expect(account.toJson(), equals(fixture));
    });
  });

  group('GasEstimation', () {
    test('round-trips full gas estimation JSON', () {
      final fixture = normalize({
        'deprioritized_gas_estimate': 100,
        'gas_estimate': 100,
        'prioritized_gas_estimate': 150,
      });

      final estimation = GasEstimation.fromJson(fixture);
      expect(estimation.gasEstimate, 100);
      expect(estimation.toJson(), equals(fixture));
    });

    test('round-trips gas estimation without optional fields', () {
      final fixture = normalize({'gas_estimate': 100});

      final estimation = GasEstimation.fromJson(fixture);
      expect(estimation.deprioritizedGasEstimate, isNull);
      expect(estimation.prioritizedGasEstimate, isNull);
      expect(estimation.toJson(), equals(fixture));
    });
  });

  group('MoveResource', () {
    test('round-trips a coin store resource', () {
      final fixture = normalize({
        'type': '0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>',
        'data': {
          'coin': {'value': '13629'},
          'deposit_events': {
            'counter': '5',
            'guid': {
              'id': {'addr': '0xabde", "creation_num": "2', 'creation_num': '2'}
            },
          },
          'frozen': false,
        },
      });

      final resource = MoveResource.fromJson(fixture);
      expect(resource.type, '0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>');
      expect((resource.data['coin'] as Map)['value'], '13629');
      expect(resource.toJson(), equals(fixture));
    });
  });

  group('MoveModuleBytecode', () {
    test('round-trips a module with ABI', () {
      final fixture = normalize({
        'bytecode': '0xa11ceb0b060000000901',
        'abi': {
          'address': '0x1',
          'name': 'aptos_account',
          'friends': ['0x1::genesis', '0x1::resource_account'],
          'exposed_functions': [
            {
              'name': 'transfer',
              'visibility': 'public',
              'is_entry': true,
              'is_view': false,
              'generic_type_params': [],
              'params': ['&signer', 'address', 'u64'],
              'return': [],
            },
            {
              'name': 'balance',
              'visibility': 'public',
              'is_entry': false,
              'is_view': true,
              'generic_type_params': [
                {
                  'constraints': ['key'],
                },
              ],
              'params': ['address'],
              'return': ['u64'],
            },
          ],
          'structs': [
            {
              'name': 'DirectTransferConfig',
              'is_native': false,
              'is_event': false,
              'is_enum': false,
              'abilities': ['key'],
              'generic_type_params': [],
              'fields': [
                {'name': 'allow_arbitrary_coin_transfers', 'type': 'bool'},
                {
                  'name': 'update_coin_transfer_events',
                  'type': '0x1::event::EventHandle<0x1::account::UpdateEvent>',
                },
              ],
            },
          ],
        },
      });

      final module = MoveModuleBytecode.fromJson(fixture);
      final abi = module.abi!;
      expect(abi.name, 'aptos_account');
      expect(
          abi.exposedFunctions.first.visibility, MoveFunctionVisibility.public);
      expect(abi.exposedFunctions.first.isEntry, isTrue);
      expect(abi.exposedFunctions[1].genericTypeParams.first.constraints,
          [MoveAbility.key]);
      expect(abi.structs.first.abilities, [MoveAbility.key]);
      expect(abi.structs.first.fields, hasLength(2));
      expect(module.toJson(), equals(fixture));
    });

    test('round-trips a module without ABI', () {
      final fixture = normalize({'bytecode': '0xa11ceb0b'});
      final module = MoveModuleBytecode.fromJson(fixture);
      expect(module.abi, isNull);
      expect(module.toJson(), equals(fixture));
    });
  });

  group('PendingTransactionResponse', () {
    test('round-trips entry function payload + ed25519 signature', () {
      final fixture = normalize({
        'type': 'pending_transaction',
        'hash':
            '0xb5b3e9b0d1a09b2d8b2b321fd07f3cbbe0cbcc2ba0cbb2f2f1e2b8b8f8f8b8b8',
        'sender':
            '0x9125e4054d884fdc7296b66e12c0d63a7baa0d88c77e8e784987c0a967c670ac',
        'sequence_number': '13',
        'max_gas_amount': '200000',
        'gas_unit_price': '100',
        'expiration_timestamp_secs': '1719524425',
        'payload': {
          'type': 'entry_function_payload',
          'function': '0x1::aptos_account::transfer',
          'type_arguments': [],
          'arguments': [
            '0x517d055b21ba1ab8ba4f0e93d5f5a2f9f9f0e9e0e9e0e9e0e9e0e9e0e9e0e9e0',
            '10000',
          ],
        },
        'signature': {
          'type': 'ed25519_signature',
          'public_key':
              '0x5f2d63e26eb4d2f4e0e2c2e00e2ee2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2',
          'signature':
              '0xd2c2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2'
                  'd2c2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2',
        },
      });

      final response = TransactionResponse.fromJson(fixture);
      expect(response, isA<PendingTransactionResponse>());
      final pending = response as PendingTransactionResponse;
      expect(pending.type, TransactionResponseType.pending);
      expect(pending.sequenceNumber, '13');

      final payload = pending.payload as EntryFunctionPayloadResponse;
      expect(payload.function, '0x1::aptos_account::transfer');
      expect(payload.arguments, hasLength(2));

      final signature = pending.signature as TransactionEd25519Signature;
      expect(signature.type, 'ed25519_signature');

      expect(pending.toJson(), equals(fixture));
    });

    test('round-trips without a signature', () {
      final fixture = normalize({
        'type': 'pending_transaction',
        'hash': '0x1111',
        'sender': '0x1',
        'sequence_number': '0',
        'max_gas_amount': '2000',
        'gas_unit_price': '100',
        'expiration_timestamp_secs': '1719524425',
        'payload': {
          'type': 'entry_function_payload',
          'function': '0x1::code::publish_package_txn',
          'type_arguments': [],
          'arguments': [],
        },
      });

      final pending =
          TransactionResponse.fromJson(fixture) as PendingTransactionResponse;
      expect(pending.signature, isNull);
      expect(pending.toJson(), equals(fixture));
    });
  });

  group('UserTransactionResponse', () {
    final fixture = normalize({
      'type': 'user_transaction',
      'version': '1962588100',
      'hash':
          '0x1f6dc06e11a20724882b6f9b6d6ee32cd1c1a4b0d0e94e3d2c8a9c3a0dbbbf1c',
      'state_change_hash':
          '0x8f2c5e6b0c1d1d1e1f202122232425262728292a2b2c2d2e2f30313233343536',
      'event_root_hash':
          '0x414343554d554c41544f525f504c414345484f4c4445525f4841534800000000',
      'state_checkpoint_hash': null,
      'gas_used': '545',
      'success': true,
      'vm_status': 'Executed successfully',
      'accumulator_root_hash':
          '0x1f2e3d4c5b6a798897a6b5c4d3e2f10112233445566778899aabbccddeeff00',
      'changes': [
        {
          'type': 'write_resource',
          'address': '0x9125e4054d884fdc7296b66e12c0d63a7baa0d88c77e8e78',
          'state_key_hash':
              '0x6e4b28d40f98a106a65163530924c0dcb40c1349d3aa915d108b4d6cfc1ddb19',
          'data': {
            'type': '0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>',
            'data': {
              'coin': {'value': '976180'},
              'frozen': false,
            },
          },
        },
        {
          'type': 'write_table_item',
          'state_key_hash':
              '0x6e4b28d40f98a106a65163530924c0dcb40c1349d3aa915d108b4d6cfc1ddb19',
          'handle':
              '0x1b854694ae746cdbd8d44186ca4929b2b337df21d1c74633be19b2710552fdca',
          'key':
              '0x0619dc29a0aac8fa146714058e8dd6d2d0f3bdf5f6331907bf91f3acd81e6935',
          'value': '0x712d69a4c9d51d9e28e9c00000000000',
          'data': {
            'key':
                '0x619dc29a0aac8fa146714058e8dd6d2d0f3bdf5f6331907bf91f3acd81e6935',
            'key_type': 'address',
            'value': '58389060450029130914457',
            'value_type': 'u128',
          },
        },
        {
          'type': 'delete_resource',
          'address': '0x9125e4054d884fdc7296b66e12c0d63a7baa0d88c77e8e78',
          'state_key_hash':
              '0x23851af2e1e402fbf9dbcb7fef1d4cf74a2b5e9f65f04cbf7f74f4a4c9f2b0f6',
          'resource': '0x1::account::CapabilityOffer',
        },
      ],
      'sender': '0x9125e4054d884fdc7296b66e12c0d63a7baa0d88c77e8e78',
      'sequence_number': '27',
      'max_gas_amount': '200000',
      'gas_unit_price': '100',
      'expiration_timestamp_secs': '1719524425',
      'payload': {
        'type': 'entry_function_payload',
        'function': '0x1::coin::transfer',
        'type_arguments': ['0x1::aptos_coin::AptosCoin'],
        'arguments': [
          '0x517d055b21ba1ab8ba4f0e93d5f5a2f9f9f0e9e0e9e0e9e0',
          '10000',
        ],
      },
      'signature': {
        'type': 'single_sender',
        'public_key': {
          'type': 'ed25519',
          'value':
              '0x5f2d63e26eb4d2f4e0e2c2e00e2ee2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2',
        },
        'signature': {
          'type': 'ed25519',
          'value':
              '0xd2c2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2e2b2',
        },
      },
      'events': [
        {
          'guid': {
            'creation_number': '0',
            'account_address': '0x0',
          },
          'sequence_number': '0',
          'type': '0x1::coin::CoinWithdraw',
          'data': {
            'account': '0x9125e4054d884fdc7296b66e12c0d63a7baa0d88c77e8e78',
            'amount': '10000',
            'coin_type': '0x1::aptos_coin::AptosCoin',
          },
        },
        {
          'guid': {
            'creation_number': '0',
            'account_address': '0x0',
          },
          'sequence_number': '0',
          'type': '0x1::transaction_fee::FeeStatement',
          'data': {
            'execution_gas_units': '4',
            'io_gas_units': '2',
            'storage_fee_octas': '0',
            'storage_fee_refund_octas': '0',
            'total_charge_gas_units': '545',
          },
        },
      ],
      'timestamp': '1719522395048723',
    });

    test('round-trips with writeset changes, events and single sender', () {
      final response = TransactionResponse.fromJson(fixture);
      expect(response, isA<UserTransactionResponse>());
      final user = response as UserTransactionResponse;
      expect(user.type, TransactionResponseType.user);
      expect(user.version, '1962588100');
      expect(user.stateCheckpointHash, isNull);
      expect(user.replayProtectionNonce, isNull);
      expect(user.success, isTrue);
      expect(user.events, hasLength(2));
      expect(user.events.first.type, '0x1::coin::CoinWithdraw');
      expect(user.changes, hasLength(3));

      final writeResource = user.changes[0] as WriteSetChangeWriteResource;
      expect(writeResource.data.type,
          '0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>');

      final writeTableItem = user.changes[1] as WriteSetChangeWriteTableItem;
      expect(writeTableItem.data!.keyType, 'address');
      expect(writeTableItem.data!.valueType, 'u128');

      final deleteResource = user.changes[2] as WriteSetChangeDeleteResource;
      expect(deleteResource.resource, '0x1::account::CapabilityOffer');

      final signature = user.signature as TransactionSingleSenderSignature;
      expect(signature.publicKey.type, 'ed25519');

      expect(user.toJson(), equals(fixture));
    });

    test('round-trips a fee payer signature', () {
      final signatureFixture = normalize({
        'type': 'fee_payer_signature',
        'sender': {
          'type': 'ed25519_signature',
          'public_key': '0x11',
          'signature': '0x22',
        },
        'secondary_signer_addresses': ['0x2', '0x3'],
        'secondary_signers': [
          {
            'type': 'ed25519_signature',
            'public_key': '0x33',
            'signature': '0x44',
          },
          {
            'type': 'multi_ed25519_signature',
            'public_keys': ['0x55', '0x66'],
            'signatures': ['0x77'],
            'threshold': 1,
            'bitmap': '0x80000000',
          },
        ],
        'fee_payer_address': '0x4',
        'fee_payer_signer': {
          'type': 'secp256k1_ecdsa_signature',
          'public_key': '0x88',
          'signature': '0x99',
        },
      });

      final signature = TransactionSignature.fromJson(signatureFixture)
          as TransactionFeePayerSignature;
      expect(signature.sender, isA<TransactionEd25519Signature>());
      expect(signature.secondarySigners[1],
          isA<TransactionMultiEd25519Signature>());
      expect(signature.feePayerSigner, isA<TransactionSecp256k1Signature>());
      expect(signature.feePayerAddress, '0x4');
      expect(signature.toJson(), equals(signatureFixture));
    });

    test('round-trips a multi agent signature', () {
      final signatureFixture = normalize({
        'type': 'multi_agent_signature',
        'sender': {
          'type': 'ed25519_signature',
          'public_key': '0x11',
          'signature': '0x22',
        },
        'secondary_signer_addresses': ['0x2'],
        'secondary_signers': [
          {
            'type': 'ed25519_signature',
            'public_key': '0x33',
            'signature': '0x44',
          },
        ],
      });

      final signature = TransactionSignature.fromJson(signatureFixture)
          as TransactionMultiAgentSignature;
      expect(signature.secondarySignerAddresses, ['0x2']);
      expect(signature.toJson(), equals(signatureFixture));
    });
  });

  group('GenesisTransactionResponse', () {
    test('round-trips a direct write set payload', () {
      final fixture = normalize({
        'type': 'genesis_transaction',
        'version': '0',
        'hash':
            '0x958e4e5208fbd7c7350ae5f0130d772827b8b0e5be1ada84fa1fb60cdb585d1b',
        'state_change_hash': '0xaa11',
        'event_root_hash': '0xbb22',
        'state_checkpoint_hash': null,
        'gas_used': '0',
        'success': true,
        'vm_status': 'Executed successfully',
        'accumulator_root_hash': '0xcc33',
        'changes': [
          {
            'type': 'write_module',
            'address': '0x1',
            'state_key_hash': '0xdd44',
            'data': {
              'bytecode': '0xa11ceb0b',
              'abi': {
                'address': '0x1',
                'name': 'acl',
                'friends': [],
                'exposed_functions': [],
                'structs': [],
              },
            },
          },
        ],
        'payload': {
          'type': 'write_set_payload',
          'write_set': {
            'type': 'direct_write_set',
            'changes': [
              {
                'type': 'write_resource',
                'address': '0x1',
                'state_key_hash': '0xee55',
                'data': {
                  'type': '0x1::chain_id::ChainId',
                  'data': {'id': 1},
                },
              },
            ],
            'events': [
              {
                'guid': {
                  'creation_number': '0',
                  'account_address': '0x1',
                },
                'sequence_number': '0',
                'type': '0x1::reconfiguration::NewEpochEvent',
                'data': {'epoch': '1'},
              },
            ],
          },
        },
        'events': [
          {
            'guid': {
              'creation_number': '2',
              'account_address': '0x1',
            },
            'sequence_number': '0',
            'type': '0x1::reconfiguration::NewEpochEvent',
            'data': {'epoch': '1'},
          },
        ],
      });

      final genesis =
          TransactionResponse.fromJson(fixture) as GenesisTransactionResponse;
      expect(genesis.type, TransactionResponseType.genesis);

      final writeSet = genesis.payload.writeSet as DirectWriteSet;
      expect(writeSet.changes.single, isA<WriteSetChangeWriteResource>());
      expect(
          writeSet.events.single.type, '0x1::reconfiguration::NewEpochEvent');

      final writeModule = genesis.changes.single as WriteSetChangeWriteModule;
      expect(writeModule.data.abi!.name, 'acl');

      expect(genesis.toJson(), equals(fixture));
    });
  });

  group('BlockMetadataTransactionResponse', () {
    final fixture = normalize({
      'type': 'block_metadata_transaction',
      'version': '1962588099',
      'hash': '0x8a44',
      'state_change_hash': '0x8b55',
      'event_root_hash': '0x8c66',
      'state_checkpoint_hash': null,
      'gas_used': '0',
      'success': true,
      'vm_status': 'Executed successfully',
      'accumulator_root_hash': '0x8d77',
      'changes': [],
      'id': '0x8e88',
      'epoch': '9331',
      'round': '3183',
      'events': [
        {
          'guid': {
            'creation_number': '0',
            'account_address': '0x0',
          },
          'sequence_number': '0',
          'type': '0x1::block::NewBlock',
          'data': {'height': '244134793'},
        },
      ],
      'previous_block_votes_bitvec': [255, 223, 255, 190],
      'proposer':
          '0xdb5247f859ce63dbe8940cf8773be722a60dcc594a8be9aca4b76abceb251b8e',
      'failed_proposer_indices': [83],
      'timestamp': '1719522395048723',
    });

    test('round-trips block metadata JSON', () {
      final response = TransactionResponse.fromJson(fixture)
          as BlockMetadataTransactionResponse;
      expect(response.type, TransactionResponseType.blockMetadata);
      expect(response.round, '3183');
      expect(response.previousBlockVotesBitvec, [255, 223, 255, 190]);
      expect(response.failedProposerIndices, [83]);
      expect(response.toJson(), equals(fixture));
    });

    test('round-trips inside a Block', () {
      final blockFixture = normalize({
        'block_height': '244134793',
        'block_hash':
            '0x97f7d372ef99ba1c6f5b21d1f0ec722fe1e4e6a04e442dbaa8161e34ec6dabab',
        'block_timestamp': '1719522395048723',
        'first_version': '1962588099',
        'last_version': '1962588103',
        'transactions': [fixture],
      });

      final block = Block.fromJson(blockFixture);
      expect(block.blockHeight, '244134793');
      expect(
          block.transactions!.single, isA<BlockMetadataTransactionResponse>());
      expect(block.toJson(), equals(blockFixture));
    });

    test('round-trips a Block without transactions', () {
      final blockFixture = normalize({
        'block_height': '10',
        'block_hash': '0xaa',
        'block_timestamp': '1719522395048723',
        'first_version': '100',
        'last_version': '105',
      });

      final block = Block.fromJson(blockFixture);
      expect(block.transactions, isNull);
      expect(block.toJson(), equals(blockFixture));
    });
  });

  group('StateCheckpointTransactionResponse', () {
    test('round-trips state checkpoint JSON', () {
      final fixture = normalize({
        'type': 'state_checkpoint_transaction',
        'version': '1962588103',
        'hash': '0x11aa',
        'state_change_hash': '0x22bb',
        'event_root_hash': '0x33cc',
        'state_checkpoint_hash': '0x44dd',
        'gas_used': '0',
        'success': true,
        'vm_status': 'Executed successfully',
        'accumulator_root_hash': '0x55ee',
        'changes': [],
        'timestamp': '1719522395048723',
      });

      final response = TransactionResponse.fromJson(fixture)
          as StateCheckpointTransactionResponse;
      expect(response.type, TransactionResponseType.stateCheckpoint);
      expect(response.stateCheckpointHash, '0x44dd');
      expect(response.toJson(), equals(fixture));
    });
  });

  group('ValidatorTransactionResponse', () {
    test('round-trips validator transaction JSON', () {
      final fixture = normalize({
        'type': 'validator_transaction',
        'version': '1962588098',
        'hash': '0x66ff',
        'state_change_hash': '0x7700',
        'event_root_hash': '0x8811',
        'state_checkpoint_hash': null,
        'gas_used': '0',
        'success': true,
        'vm_status': 'Executed successfully',
        'accumulator_root_hash': '0x9922',
        'changes': [],
        'events': [
          {
            'guid': {
              'creation_number': '0',
              'account_address': '0x0',
            },
            'sequence_number': '0',
            'type': '0x1::jwks::ObservedJWKsUpdated',
            'data': {'epoch': '9331'},
          },
        ],
        'timestamp': '1719522395048723',
      });

      final response =
          TransactionResponse.fromJson(fixture) as ValidatorTransactionResponse;
      expect(response.type, TransactionResponseType.validator);
      expect(response.events.single.type, '0x1::jwks::ObservedJWKsUpdated');
      expect(response.toJson(), equals(fixture));
    });
  });

  group('BlockEpilogueTransactionResponse', () {
    test('round-trips with block end info', () {
      final fixture = normalize({
        'type': 'block_epilogue_transaction',
        'version': '1962588104',
        'hash': '0xaa33',
        'state_change_hash': '0xbb44',
        'event_root_hash': '0xcc55',
        'state_checkpoint_hash': '0xdd66',
        'gas_used': '0',
        'success': true,
        'vm_status': 'Executed successfully',
        'accumulator_root_hash': '0xee77',
        'changes': [],
        'timestamp': '1719522395048723',
        'block_end_info': {
          'block_gas_limit_reached': false,
          'block_output_limit_reached': false,
          'block_effective_block_gas_units': 296,
          'block_approx_output_size': 8500,
        },
      });

      final response = TransactionResponse.fromJson(fixture)
          as BlockEpilogueTransactionResponse;
      expect(response.type, TransactionResponseType.blockEpilogue);
      expect(response.blockEndInfo!.blockGasLimitReached, isFalse);
      expect(response.blockEndInfo!.blockApproxOutputSize, 8500);
      expect(response.toJson(), equals(fixture));
    });

    test('round-trips with null block end info', () {
      final fixture = normalize({
        'type': 'block_epilogue_transaction',
        'version': '1',
        'hash': '0xaa33',
        'state_change_hash': '0xbb44',
        'event_root_hash': '0xcc55',
        'state_checkpoint_hash': null,
        'gas_used': '0',
        'success': true,
        'vm_status': 'Executed successfully',
        'accumulator_root_hash': '0xee77',
        'changes': [],
        'timestamp': '1719522395048723',
        'block_end_info': null,
      });

      final response = TransactionResponse.fromJson(fixture)
          as BlockEpilogueTransactionResponse;
      expect(response.blockEndInfo, isNull);
      expect(response.toJson(), equals(fixture));
    });
  });

  group('Transaction payloads', () {
    test('round-trips a script payload', () {
      final fixture = normalize({
        'type': 'script_payload',
        'code': {'bytecode': '0xa11ceb0b060000000701'},
        'type_arguments': ['0x1::aptos_coin::AptosCoin'],
        'arguments': ['100', true],
      });

      final payload =
          TransactionPayloadResponse.fromJson(fixture) as ScriptPayloadResponse;
      expect(payload.code.bytecode, '0xa11ceb0b060000000701');
      expect(payload.code.abi, isNull);
      expect(payload.toJson(), equals(fixture));
    });

    test('round-trips a multisig payload', () {
      final fixture = normalize({
        'type': 'multisig_payload',
        'multisig_address':
            '0x57478da34d655c8bd7de6c8d95d0bbfd54accd2ecda21c1e28f9a8b18f4a449c',
        'transaction_payload': {
          'type': 'entry_function_payload',
          'function': '0x1::aptos_account::transfer',
          'type_arguments': [],
          'arguments': ['0x1', '1'],
        },
      });

      final payload = TransactionPayloadResponse.fromJson(fixture)
          as MultisigPayloadResponse;
      expect(
          payload.transactionPayload!.function, '0x1::aptos_account::transfer');
      expect(payload.toJson(), equals(fixture));
    });

    test('round-trips an encrypted (not yet decrypted) payload', () {
      final fixture = normalize({
        'type': 'encrypted_payload',
        'encrypted_state': 'encrypted',
        'payload_hash': '0x1234',
        'ciphertext': '0xdeadbeef',
        'claimed_entry_fun': {
          'module': '0x1::aptos_account',
          'name': 'transfer',
        },
        'encryption_epoch': '9331',
      });

      final payload = TransactionPayloadResponse.fromJson(fixture)
          as EncryptedEncryptedTransactionPayloadResponse;
      expect(payload.encryptedState, 'encrypted');
      expect(payload.claimedEntryFun!.name, 'transfer');
      expect(payload.toJson(), equals(fixture));
    });

    test('round-trips a decrypted encrypted payload', () {
      final fixture = normalize({
        'type': 'encrypted_payload',
        'encrypted_state': 'decrypted',
        'payload_hash': '0x1234',
        'ciphertext': '0xdeadbeef',
        'claimed_entry_fun': null,
        'decrypted_payload': {
          'type': 'entry_function_payload',
          'function': '0x1::aptos_account::transfer',
          'type_arguments': [],
          'arguments': ['0x1', '1'],
        },
        'decryption_nonce': '42',
      });

      final payload = TransactionPayloadResponse.fromJson(fixture)
          as DecryptedEncryptedTransactionPayloadResponse;
      expect(payload.claimedEntryFun, isNull);
      expect(payload.decryptedPayload, isA<EntryFunctionPayloadResponse>());
      expect(payload.decryptionNonce, '42');
      expect(payload.toJson(), equals(fixture));
    });
  });

  group('Request types', () {
    test('TableItemRequest round-trips', () {
      final fixture = normalize({
        'key_type': 'address',
        'value_type': 'u128',
        'key':
            '0x619dc29a0aac8fa146714058e8dd6d2d0f3bdf5f6331907bf91f3acd81e6935',
      });

      final request = TableItemRequest.fromJson(fixture);
      expect(request.keyType, 'address');
      expect(request.toJson(), equals(fixture));
    });

    test('ViewFunctionJsonPayload serializes with wire keys', () {
      const payload = ViewFunctionJsonPayload(
        function: '0x1::coin::balance',
        typeArguments: ['0x1::aptos_coin::AptosCoin'],
        functionArguments: ['0x1'],
      );

      expect(
        payload.toJson(),
        equals({
          'function': '0x1::coin::balance',
          'type_arguments': ['0x1::aptos_coin::AptosCoin'],
          'arguments': ['0x1'],
        }),
      );
      expect(
        ViewFunctionJsonPayload.fromJson(normalize(payload.toJson())).function,
        '0x1::coin::balance',
      );
    });

    test('pagination and option types hold their inputs', () {
      const pagination = PaginationArgs(offset: 10, limit: 25);
      expect(pagination.offset, 10);
      expect(pagination.limit, 25);

      final ledgerVersion = LedgerVersionArg(ledgerVersion: BigInt.two);
      expect(ledgerVersion.ledgerVersion, BigInt.two);

      const cursor = CursorPaginationArgs(cursor: 'abc', limit: 10);
      expect(cursor.cursor, 'abc');

      const wait = WaitForTransactionOptions(
        timeoutSecs: 20,
        checkSuccess: true,
        waitForIndexer: false,
      );
      expect(wait.timeoutSecs, 20);
      expect(wait.checkSuccess, isTrue);
      expect(wait.waitForIndexer, isFalse);
    });
  });

  group('Dispatch errors', () {
    test('unknown transaction response type throws', () {
      expect(
        () => TransactionResponse.fromJson({'type': 'unknown_transaction'}),
        throwsArgumentError,
      );
    });

    test('unknown write set change type throws', () {
      expect(
        () => WriteSetChange.fromJson({'type': 'unknown_change'}),
        throwsArgumentError,
      );
    });

    test('unknown payload type throws', () {
      expect(
        () => TransactionPayloadResponse.fromJson({'type': 'unknown_payload'}),
        throwsArgumentError,
      );
    });

    test('unknown signature type throws', () {
      expect(
        () => TransactionSignature.fromJson({'type': 'unknown_signature'}),
        throwsArgumentError,
      );
      expect(
        () => AccountSignature.fromJson({'type': 'single_sender'}),
        throwsArgumentError,
      );
    });
  });
}
