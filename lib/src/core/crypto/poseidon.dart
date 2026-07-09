import 'dart:convert';
import 'dart:typed_data';

import 'poseidon_constants.dart';

/// The BN254 scalar field prime, i.e. the modulus of the field over which the
/// Poseidon permutation operates.
final BigInt _fieldPrime = BigInt.parse(
  '21888242871839275222246405745257275088548364400416034343698204186575808495617',
);

const int _bytesPackedPerScalar = 31;
const int _maxNumInputScalars = 16;
const int _maxNumInputBytes = (_maxNumInputScalars - 1) * _bytesPackedPerScalar;

/// Hashes a string to a field element via Poseidon hashing.
/// This function is useful for converting a string into a fixed-size hash that
/// can be used in cryptographic applications.
///
/// [str] is the string to be hashed and [maxSizeBytes] the maximum size in
/// bytes for the resulting hash.
BigInt hashStrToField(String str, int maxSizeBytes) {
  final strBytes = Uint8List.fromList(utf8.encode(str));
  return _hashBytesWithLen(strBytes, maxSizeBytes);
}

/// Computes a Poseidon hash of the provided byte array, ensuring that the byte
/// array does not exceed the specified maximum size.
///
/// Throws an [ArgumentError] if the length of the inputted bytes exceeds the
/// specified maximum size.
BigInt _hashBytesWithLen(Uint8List bytes, int maxSizeBytes) {
  if (bytes.length > maxSizeBytes) {
    throw ArgumentError(
      'Input bytes of length ${bytes.length} is longer than $maxSizeBytes',
    );
  }
  final packed = padAndPackBytesWithLen(bytes, maxSizeBytes);
  return poseidonHash(packed);
}

/// Pads the input byte array with zeros to a specified maximum size and then
/// packs the bytes into field-element scalars.
///
/// Throws an [ArgumentError] if the input byte array exceeds the specified
/// maximum size.
List<BigInt> _padAndPackBytesNoLen(Uint8List bytes, int maxSizeBytes) {
  if (bytes.length > maxSizeBytes) {
    throw ArgumentError(
      'Input bytes of length ${bytes.length} is longer than $maxSizeBytes',
    );
  }
  final paddedStrBytes = _padUint8ArrayWithZeros(bytes, maxSizeBytes);
  return _packBytes(paddedStrBytes);
}

/// Pads and packs the given byte array to a specified maximum size and appends
/// its length.
///
/// Throws an [ArgumentError] if the length of the input bytes exceeds the
/// maximum size.
List<BigInt> padAndPackBytesWithLen(Uint8List bytes, int maxSizeBytes) {
  if (bytes.length > maxSizeBytes) {
    throw ArgumentError(
      'Input bytes of length ${bytes.length} is longer than $maxSizeBytes',
    );
  }
  return _padAndPackBytesNoLen(bytes, maxSizeBytes)
    ..add(BigInt.from(bytes.length));
}

/// Packs a byte array into a list of [BigInt] scalars, ensuring the input does
/// not exceed the maximum allowed bytes.
///
/// Throws an [ArgumentError] if the input exceeds the maximum number of bytes
/// allowed.
List<BigInt> _packBytes(Uint8List bytes) {
  if (bytes.length > _maxNumInputBytes) {
    throw ArgumentError(
      "Can't pack more than $_maxNumInputBytes.  Was given ${bytes.length} bytes",
    );
  }
  return _chunkUint8Array(bytes, _bytesPackedPerScalar)
      .map(bytesToBigIntLE)
      .toList();
}

/// Splits a byte array into smaller chunks of the specified size.
List<Uint8List> _chunkUint8Array(Uint8List array, int chunkSize) {
  final result = <Uint8List>[];
  for (var i = 0; i < array.length; i += chunkSize) {
    final end = i + chunkSize < array.length ? i + chunkSize : array.length;
    result.add(Uint8List.sublistView(array, i, end));
  }
  return result;
}

/// Converts a little-endian byte array into a [BigInt].
BigInt bytesToBigIntLE(Uint8List bytes) {
  var result = BigInt.zero;
  for (var i = bytes.length - 1; i >= 0; i -= 1) {
    result = (result << 8) | BigInt.from(bytes[i]);
  }
  return result;
}

/// Converts a [BigInt] or [int] value into a little-endian byte array of a
/// specified length.
Uint8List bigIntToBytesLE(Object value, int length) {
  var val = _toBigInt(value);
  final bytes = Uint8List(length);
  final mask = BigInt.from(0xff);
  for (var i = 0; i < length; i += 1) {
    bytes[i] = (val & mask).toInt();
    val >>= 8;
  }
  return bytes;
}

/// Pads the input byte array with zeros to achieve the specified size.
///
/// Throws an [ArgumentError] if [paddedSize] is less than the length of
/// [inputArray].
Uint8List _padUint8ArrayWithZeros(Uint8List inputArray, int paddedSize) {
  if (paddedSize < inputArray.length) {
    throw ArgumentError(
      'Padded size must be greater than or equal to the input array size.',
    );
  }
  final paddedArray = Uint8List(paddedSize);
  paddedArray.setRange(0, inputArray.length, inputArray);
  return paddedArray;
}

/// Hashes up to 16 scalar elements via the Poseidon hashing algorithm.
/// Each element must be a scalar field element of the BN254 elliptic curve
/// group.
///
/// [inputs] is a list of elements to be hashed, each of which can be an
/// [int], [BigInt], or decimal [String].
///
/// Throws an [ArgumentError] if the input length is zero or exceeds the
/// maximum allowed.
BigInt poseidonHash(List<Object> inputs) {
  if (inputs.isEmpty || inputs.length > _maxNumInputScalars) {
    throw ArgumentError(
      'poseidonHash requires between 1 and $_maxNumInputScalars inputs, '
      'got ${inputs.length}',
    );
  }
  return _poseidon(inputs.map(_toBigInt).toList());
}

BigInt _toBigInt(Object value) {
  if (value is BigInt) return value;
  if (value is int) return BigInt.from(value);
  if (value is String) return BigInt.parse(value);
  throw ArgumentError(
    'Poseidon inputs must be int, BigInt, or String, got ${value.runtimeType}',
  );
}

/// Raises [v] to the fifth power modulo the BN254 scalar field prime.
BigInt _pow5(BigInt v) {
  final o = (v * v) % _fieldPrime;
  return (v * o % _fieldPrime * o) % _fieldPrime;
}

/// Multiplies the state vector by the MDS matrix modulo the field prime.
List<BigInt> _mix(List<BigInt> state, List<List<BigInt>> m) {
  final out = <BigInt>[];
  for (var x = 0; x < state.length; x += 1) {
    var o = BigInt.zero;
    for (var y = 0; y < state.length; y += 1) {
      o += m[x][y] * state[y];
    }
    out.add(o % _fieldPrime);
  }
  return out;
}

/// The Poseidon permutation over the BN254 scalar field.
BigInt _poseidon(List<BigInt> inputs) {
  final t = inputs.length + 1;
  final constants = poseidonConstants(inputs.length);
  final nRoundsF = poseidonNRoundsF;
  final nRoundsP = poseidonNRoundsP[t - 2];
  final c = constants.c;
  final m = constants.m;

  var state = <BigInt>[BigInt.zero, ...inputs.map((i) => i % _fieldPrime)];
  for (var x = 0; x < nRoundsF + nRoundsP; x += 1) {
    for (var y = 0; y < state.length; y += 1) {
      state[y] = (state[y] + c[x * t + y]) % _fieldPrime;
      if (x < nRoundsF ~/ 2 || x >= nRoundsF ~/ 2 + nRoundsP) {
        state[y] = _pow5(state[y]);
      } else if (y == 0) {
        state[y] = _pow5(state[y]);
      }
    }
    state = _mix(state, m);
  }
  return state[0];
}
