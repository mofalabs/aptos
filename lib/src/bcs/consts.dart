// Upper bound values for uint8, uint16, uint64 etc. These are all derived as
// 2^N - 1, where N is the number of bits in the type.

const int maxU8Number = 255;
const int maxU16Number = 65535;
const int maxU32Number = 4294967295;
final BigInt maxU64BigInt = BigInt.parse('18446744073709551615');
final BigInt maxU128BigInt =
    BigInt.parse('340282366920938463463374607431768211455');
final BigInt maxU256BigInt = BigInt.parse(
  '115792089237316195423570985008687907853269984665640564039457584007913129639935',
);

// Signed integer bounds.

const int minI8Number = -128;
const int maxI8Number = 127;
const int minI16Number = -32768;
const int maxI16Number = 32767;
const int minI32Number = -2147483648;
const int maxI32Number = 2147483647;
final BigInt minI64BigInt = BigInt.parse('-9223372036854775808');
final BigInt maxI64BigInt = BigInt.parse('9223372036854775807');
final BigInt minI128BigInt =
    BigInt.parse('-170141183460469231731687303715884105728');
final BigInt maxI128BigInt =
    BigInt.parse('170141183460469231731687303715884105727');
final BigInt minI256BigInt = BigInt.parse(
  '-57896044618658097711785492504343953926634992332820282019728792003956564819968',
);
final BigInt maxI256BigInt = BigInt.parse(
  '57896044618658097711785492504343953926634992332820282019728792003956564819967',
);
