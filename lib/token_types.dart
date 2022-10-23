
import 'package:aptos/bcs/consts.dart';

class TokenData {
  /// Unique name within this creator's account for this Token's collection
  String collection;

  /// Description of Token
  String description;

  /// Name of Token
  String name;

  /// Optional maximum number of this Token
  int? maximum;

  /// Total number of this type of Token
  int supply;

  /// URL for additional information / media
  String uri;

  TokenData(this.collection, this.description, this.name, this.maximum, this.supply, this.uri);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "collection": collection,
      "description": description,
      "name": name,
      "maximum": maximum ?? MAX_U32_NUMBER,
      "supply": supply,
      "uri": uri
    };
  }
}

class TokenDataId {
  /// Token creator address
  String creator;

  /// Unique name within this creator's account for this Token's collection
  String collection;

  /// Name of Token
  String name;

  TokenDataId(this.creator, this.collection, this.name);

  factory TokenDataId.fromJson(Map<String, dynamic> json) {
    return TokenDataId(json["creator"], json["collection"], json["name"]);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "creator": creator,
      "collection": collection,
      "name": name
    };
  }
}

class TokenId {
  TokenDataId tokenDataId;

  /// version number of the property map
  String propertyVersion;

  TokenId(this.tokenDataId, this.propertyVersion);

  factory TokenId.fromJson(Map<String, dynamic> json) {
    return TokenId(TokenDataId.fromJson(json["token_data_id"]), json["property_version"]);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "token_data_id": tokenDataId.toJson(),
      "property_version": propertyVersion
    };
  }
}

class Token {
  TokenId id;
  /// server will return string for u64
  String amount;

  Token(this.id, this.amount);

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(TokenId.fromJson(json["id"]), json["amount"]);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id.toJson(),
      "amount": amount
    };
  }
}
