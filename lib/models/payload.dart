
class Payload {
  Payload(this.type, this.function, this.typeArguments, this.arguments);

  final String type;
  final String function;
  final List<String> typeArguments;
  final List<dynamic> arguments;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "function": function,
      "type_arguments": typeArguments,
      "arguments": arguments
    };
  }
}