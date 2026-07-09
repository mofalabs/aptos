import '../../bcs/serializer.dart';

/// An abstract representation of a cryptographic proof associated with specific
/// zero-knowledge proof schemes, such as Groth16 and PLONK.
abstract class Proof extends Serializable {}
