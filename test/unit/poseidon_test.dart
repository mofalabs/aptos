import 'package:aptos/src/core/crypto/poseidon.dart';
import 'package:aptos/src/core/hex.dart';
import 'package:test/test.dart';

void main() {
  group('Poseidon', () {
    // Known-answer vectors.
    test('should hash correctly', () {
      final input = [
        [1, 2],
        [1],
      ];
      final expected = [
        BigInt.parse(
            '7853200120776062878684798364095072458815029376092732009249414926327459813530'),
        BigInt.parse(
            '18586133768512220936620570745912940619677854269274689475585506675881198879027'),
      ];
      for (var i = 0; i < input.length; i += 1) {
        expect(poseidonHash(input[i]), expected[i]);
      }
    });

    test('should hash strings correctly', () {
      final input = ['hello', 'google'];
      final expected = [
        BigInt.parse(
            '19131502131677697582824316262023599653223229634739282128274922348992854400539'),
        BigInt.parse(
            '10420754430899002178577798392930147671924237248238291825718956074978332229675'),
      ];
      for (var i = 0; i < input.length; i += 1) {
        expect(hashStrToField(input[i], 31), expected[i]);
      }
    });

    test('should convert bigint to array and back correctly', () {
      final input = [BigInt.from(123), BigInt.from(321)];
      final intermediateResult = [
        '7b000000000000000000000000000000000000000000000000000000000000',
        '41010000000000000000000000000000000000000000000000000000000000',
      ];
      for (var i = 0; i < input.length; i += 1) {
        expect(
          bigIntToBytesLE(input[i], 31),
          Hex.fromHexInput(intermediateResult[i]).toUint8List(),
        );
        expect(bytesToBigIntLE(bigIntToBytesLE(input[i], 31)), input[i]);
      }
    });

    test('should error if too many inputs', () {
      expect(
        () => poseidonHash(List<Object>.filled(17, 0)),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('between 1 and 16'),
        )),
      );
    });

    test('should error with a descriptive message on empty input', () {
      expect(
        () => poseidonHash(<Object>[]),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('between 1 and 16'),
        )),
      );
    });

    // Cross-implementation vectors: poseidonN([1, 2, ..., n]) as known-answer
    // values, covering every supported arity 1..16.
    test('matches poseidon-lite for all arities 1..16', () {
      const expected = [
        '18586133768512220936620570745912940619677854269274689475585506675881198879027',
        '7853200120776062878684798364095072458815029376092732009249414926327459813530',
        '6542985608222806190361240322586112750744169038454362455181422643027100751666',
        '18821383157269793795438455681495246036402687001665670618754263018637548127333',
        '6183221330272524995739186171720101788151706631170188140075976616310159254464',
        '20400040500897583745843009878988256314335038853985262692600694741116813247201',
        '12748163991115452309045839028154629052133952896122405799815156419278439301912',
        '18604317144381847857886385684060986177838410221561136253933256952257712543953',
        '13589767895268936107593642967621470491511464502761040466226072462545218539640',
        '3657500514307717306974218405144578736633140001277925127187636780142269815841',
        '3572015662710076994097916907865950486270383304442561406230608893458731714472',
        '2501997477381648492950318384533644783248002172679259592360114615426357826485',
        '7041832639553862712666971417715061873827921493498355005117622707743491651590',
        '8354478399926161176778659061636406690034081872658507739535256090879947077494',
        '4203130618016961831408770638653325366880478848856764494148034853759773445968',
        '9989051620750914585850546081941653841776809718687451684622678807385399211877',
      ];
      for (var n = 1; n <= 16; n += 1) {
        final inputs = List<Object>.generate(n, (i) => BigInt.from(i + 1));
        expect(
          poseidonHash(inputs),
          BigInt.parse(expected[n - 1]),
          reason: 'arity $n',
        );
      }
    });

    test('accepts int, BigInt, and decimal String inputs interchangeably', () {
      final expected = poseidonHash([BigInt.one, BigInt.two]);
      expect(poseidonHash([1, 2]), expected);
      expect(poseidonHash(['1', '2']), expected);
    });

    test('padAndPackBytesWithLen packs bytes little-endian with length', () {
      // 'hello' padded to 31 bytes packs into one scalar, plus the length.
      final packed = padAndPackBytesWithLen(
        Hex.fromHexInput('68656c6c6f').toUint8List(),
        31,
      );
      expect(packed.length, 2);
      expect(packed[0], BigInt.parse('478560413032')); // 'hello' LE
      expect(packed[1], BigInt.from(5));
    });
  });
}
