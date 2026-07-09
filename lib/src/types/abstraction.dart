/// Account abstraction (AA) enum variants.
library;

/// The variant for the AbstractAuthenticationData enum.
enum AbstractAuthenticationDataVariant {
  v1(0),
  derivableV1(1);

  const AbstractAuthenticationDataVariant(this.value);

  final int value;
}

/// The variant for the AASigningData enum.
enum AASigningDataVariant {
  v1(0);

  const AASigningDataVariant(this.value);

  final int value;
}
