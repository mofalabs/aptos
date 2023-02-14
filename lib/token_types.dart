
import 'package:aptos/bcs/consts.dart';
import 'package:aptos/utils/property_map_serde.dart';

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

  /// default properties of token data
  late PropertyMap defaultProperties;

  /// mutability config of tokendata fields
  late List<bool> mutabilityConfig;

  TokenData(
    this.collection, 
    this.description, 
    this.name, 
    this.maximum, 
    this.supply, 
    this.uri,
    Map defaultProperties,
    Map mutabilityConfig
  ) {
    this.defaultProperties = deserializePropertyMap(defaultProperties);
    this.mutabilityConfig = mutabilityConfig.values.toList().cast<bool>();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "collection": collection,
      "description": description,
      "name": name,
      "maximum": maximum ?? MAX_U32_NUMBER,
      "supply": supply,
      "uri": uri,
      "default_properties": defaultProperties.toJson(),
      "mutability_config": mutabilityConfig.toString()
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

  PropertyMap tokenProperties;

  Token(this.id, this.amount, this.tokenProperties);

  factory Token.fromJson(Map<String, dynamic> json) {
    PropertyMap propertyMap = deserializePropertyMap(json["token_properties"]);
    return Token(TokenId.fromJson(json["id"]), json["amount"], propertyMap);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id.toJson(),
      "amount": amount
    };
  }
}
