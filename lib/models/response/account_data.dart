class AccountData {

  AccountData(this.sequenceNumber, this.authenticationKey);

  final String sequenceNumber;
  final String authenticationKey;

  factory AccountData.fromJson(Map<String, dynamic> data) {
    return AccountData(
      data["sequence_number"], 
      data["authentication_key"]
    );
  }

  Map<String, String> toJson() {
    return {
      "sequence_number": sequenceNumber,
      "authentication_key": authenticationKey
    };
  }
}