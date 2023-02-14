
import 'dart:convert';
import 'dart:typed_data';

import 'package:aptos/aptos.dart';

class PropertyValue {
  String type;

  dynamic value;

  PropertyValue(this.type, this.value);
}

class PropertyMap {
  Map<String, PropertyValue> data = {};

  setProperty(String key, PropertyValue value) {
    data[key] = value;
  }

  String toJson() {
    return data.toString();
  }
}

TypeTag getPropertyType(String typ) {
  TypeTag typeTag;
  if (typ == "string" || typ == "String") {
    typeTag = TypeTagStruct(stringStructTag);
  } else {
    typeTag = TypeTagParser(typ).parseTypeTag();
  }
  return typeTag;
}

List<Uint8List> getPropertyValueRaw(List<String> values, List<String> types) {
  if (values.length != types.length) {
    throw ArgumentError("Length of property values and types not match");
  }

  final results = <Uint8List>[];
  for (var index = 0; index < types.length; index++) {
    try {
      final typeTag = getPropertyType(types[index]);
      final serializer = Serializer();
      serializeArg(values[index], typeTag, serializer);
      results.add(serializer.getBytes());
    } catch (error) {
      // if not support type, just use the raw string bytes
      results.add(Uint8List.fromList(utf8.encode(values[index])));
    }
  }

  return results;
}

PropertyMap deserializePropertyMap(dynamic rawPropertyMap) {
  final entries = rawPropertyMap["map"]["data"];
  final pm = PropertyMap();
  entries.forEach((prop) {
    final key = prop["key"];
    String val = prop["value"]["value"];
    String typ = prop["value"]["type"];
    final typeTag = getPropertyType(typ);
    final newValue = deserializeValueBasedOnTypeTag(typeTag, val);
    final pv = PropertyValue(typ, newValue);
    pm.setProperty(key, pv);
  });
  return pm;
}

String deserializeValueBasedOnTypeTag(TypeTag tag, String val) {
  final de = Deserializer(HexString(val).toUint8Array());
  String res = "";
  if (tag is TypeTagU8) {
    res = de.deserializeU8().toString();
  } else if (tag is TypeTagU64) {
    res = de.deserializeU64().toString();
  } else if (tag is TypeTagU128) {
    res = de.deserializeU128().toString();
  } else if (tag is TypeTagBool) {
    res = de.deserializeBool() ? "true" : "false";
  } else if (tag is TypeTagAddress) {
    res = HexString.fromUint8Array(de.deserializeFixedBytes(32)).hex();
  } else if (tag is TypeTagStruct && tag.isStringTypeTag()) {
    res = de.deserializeStr();
  } else {
    res = val;
  }
  return res;
}
