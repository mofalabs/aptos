import 'dart:typed_data';

import 'package:aptos/aptos.dart';
import 'package:test/test.dart';

const addressOne =
    '0x0000000000000000000000000000000000000000000000000000000000000001';
const addressOther =
    '0xca843279e3427144cead5e4d5999a3d0ca843279e3427144cead5e4d5999a3d0';

void main() {
  group('AccountAddress parsing (relaxed)', () {
    test('parses special addresses in SHORT form', () {
      expect(AccountAddress.fromString('0x0').toString(), equals('0x0'));
      expect(AccountAddress.fromString('0x1').toString(), equals('0x1'));
      expect(AccountAddress.fromString('0xf').toString(), equals('0xf'));
      expect(AccountAddress.fromString('1').toString(), equals('0x1'));
    });

    test('parses special addresses in LONG form', () {
      expect(AccountAddress.fromString(addressOne).toString(), equals('0x1'));
      expect(
        AccountAddress.fromString(addressOne.substring(2)).toString(),
        equals('0x1'),
      );
    });

    test('parses non-special addresses in LONG form', () {
      expect(
        AccountAddress.fromString(addressOther).toString(),
        equals(addressOther),
      );
      expect(
        AccountAddress.fromString(addressOther.substring(2)).toString(),
        equals(addressOther),
      );
    });

    test('parses addresses with few missing chars (padding)', () {
      // Drop '0x' plus the leading 2 chars: 2 missing chars is within the
      // default maxMissingChars = 4, so the address is zero-padded.
      final trimmed = addressOther.substring(4);
      expect(
        AccountAddress.fromString(trimmed).toStringLong(),
        equals('0x00$trimmed'),
      );
    });

    test('rejects non-special addresses missing too many chars', () {
      final trimmed = addressOther.substring(12); // 10 missing chars
      expect(
        () => AccountAddress.fromString(trimmed),
        throwsA(isA<ParsingError<AddressInvalidReason>>()),
      );
      // But allowed when maxMissingChars is raised.
      expect(
        AccountAddress.fromString(trimmed, maxMissingChars: 10).toStringLong(),
        equals('0x0000000000$trimmed'),
      );
    });

    test('rejects invalid input', () {
      expect(() => AccountAddress.fromString(''),
          throwsA(isA<ParsingError<AddressInvalidReason>>()));
      expect(() => AccountAddress.fromString('0x'),
          throwsA(isA<ParsingError<AddressInvalidReason>>()));
      expect(() => AccountAddress.fromString('0x${'a' * 65}'),
          throwsA(isA<ParsingError<AddressInvalidReason>>()));
      expect(() => AccountAddress.fromString('0xzz'),
          throwsA(isA<ParsingError<AddressInvalidReason>>()));
    });
  });

  group('AccountAddress parsing (strict)', () {
    test('parses special addresses in SHORT form', () {
      expect(AccountAddress.fromStringStrict('0x0').toString(), equals('0x0'));
      expect(AccountAddress.fromStringStrict('0xf').toString(), equals('0xf'));
    });

    test('parses LONG form addresses', () {
      expect(
        AccountAddress.fromStringStrict(addressOne).toString(),
        equals('0x1'),
      );
      expect(
        AccountAddress.fromStringStrict(addressOther).toString(),
        equals(addressOther),
      );
    });

    test('rejects LONG form without 0x prefix', () {
      expect(
        () => AccountAddress.fromStringStrict(addressOther.substring(2)),
        throwsA(isA<ParsingError<AddressInvalidReason>>()),
      );
    });

    test('rejects SHORT form for non-special addresses', () {
      expect(
        () => AccountAddress.fromStringStrict('0x${'a' * 63}'),
        throwsA(isA<ParsingError<AddressInvalidReason>>()),
      );
    });

    test('rejects padded SHORT form for special addresses', () {
      expect(
        () => AccountAddress.fromStringStrict('0x0f'),
        throwsA(isA<ParsingError<AddressInvalidReason>>()),
      );
      expect(
        () => AccountAddress.fromStringStrict('0x00'),
        throwsA(isA<ParsingError<AddressInvalidReason>>()),
      );
    });
  });

  group('AccountAddress representations', () {
    test('toString / toStringLong / toStringShort', () {
      final special = AccountAddress.fromString('0x1');
      expect(special.toString(), equals('0x1'));
      expect(special.toStringLong(), equals(addressOne));
      expect(
          special.toStringLongWithoutPrefix(), equals(addressOne.substring(2)));
      expect(special.toStringShort(), equals('0x1'));

      final other = AccountAddress.fromString(addressOther);
      expect(other.toString(), equals(addressOther));
      expect(other.toStringShort(), equals(addressOther));

      final zero = AccountAddress.zero;
      expect(zero.toStringShortWithoutPrefix(), equals('0'));

      final padded = AccountAddress.fromString(
          '0x0000ca843279e3427144cead5e4d5999a3d0ca843279e3427144cead5e4d5999');
      expect(
        padded.toStringShort(),
        equals(
            '0xca843279e3427144cead5e4d5999a3d0ca843279e3427144cead5e4d5999'),
      );
    });

    test('static special addresses', () {
      expect(AccountAddress.zero.toString(), equals('0x0'));
      expect(AccountAddress.one.toString(), equals('0x1'));
      expect(AccountAddress.two.toString(), equals('0x2'));
      expect(AccountAddress.three.toString(), equals('0x3'));
      expect(AccountAddress.four.toString(), equals('0x4'));
      expect(AccountAddress.a.toString(), equals('0xa'));
    });

    test('isSpecial', () {
      expect(AccountAddress.fromString('0xf').isSpecial(), isTrue);
      expect(
        AccountAddress.fromString('0x${'10'.padLeft(64, '0')}').isSpecial(),
        isFalse,
      );
      expect(AccountAddress.fromString(addressOther).isSpecial(), isFalse);
    });
  });

  group('AccountAddress from/fromStrict/isValid', () {
    test('from accepts string, bytes, and AccountAddress', () {
      final fromStr = AccountAddress.from('0x1');
      final fromBytes = AccountAddress.from(fromStr.toUint8List());
      final fromAddress = AccountAddress.from(fromStr);
      expect(fromBytes.equals(fromStr), isTrue);
      expect(identical(fromAddress, fromStr), isTrue);
      expect(() => AccountAddress.from(123), throwsArgumentError);
    });

    test('rejects byte arrays of wrong length', () {
      expect(
        () => AccountAddress(Uint8List(31)),
        throwsA(isA<ParsingError<AddressInvalidReason>>()),
      );
    });

    test('isValid', () {
      expect(AccountAddress.isValid(input: '0x1').valid, isTrue);
      expect(
        AccountAddress.isValid(input: '0x0f', strict: true).valid,
        isFalse,
      );
      final result = AccountAddress.isValid(input: '0xzz');
      expect(result.valid, isFalse);
      expect(
          result.invalidReason, equals(AddressInvalidReason.invalidHexChars));
    });
  });

  group('AccountAddress BCS', () {
    test('serializes as 32 fixed bytes', () {
      final address = AccountAddress.fromString('0x1');
      final bytes = address.bcsToBytes();
      expect(bytes.length, equals(32));
      expect(bytes.last, equals(1));

      final deserialized = AccountAddress.deserialize(Deserializer(bytes));
      expect(deserialized.equals(address), isTrue);
    });

    test('serializeForScriptFunction uses Address variant', () {
      final serializer = Serializer();
      AccountAddress.one.serializeForScriptFunction(serializer);
      final bytes = serializer.toUint8List();
      expect(bytes.first, equals(3));
      expect(bytes.length, equals(33));
    });

    test('== and hashCode', () {
      expect(AccountAddress.from('0x1'), equals(AccountAddress.one));
      expect(
        {AccountAddress.from('0x1'), AccountAddress.one}.length,
        equals(1),
      );
    });
  });
}
