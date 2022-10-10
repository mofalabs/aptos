import 'dart:math';
import 'dart:typed_data';

import 'package:aptos/constants.dart';
import 'package:aptos/models/payload.dart';
import 'package:aptos/models/signature.dart';
import 'package:aptos/models/transaction.dart';
import 'package:aptos/utils/sha.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aptos/aptos.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aptos',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Transfer Aptos'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final privateKeyTextEditingController = TextEditingController();
  final addressTextEditingController = TextEditingController();
  final amountTextEditingController = TextEditingController();
  var message = "";

  Future<dynamic> _transfer(String privateKey, String receiverAddress, String amount) async {

    final account = AptosAccount(Uint8List.fromList(HEX.decode(privateKey)));
    final aptos = AptosClient(Constants.testnetAPI);
    final sender = account.address().hex();
    final accountInfo = await aptos.getAccount(sender);
    final milliseconds = DateTime.now().add(Duration(minutes: 1)).millisecondsSinceEpoch;
    final txSubmission = TransactionEncodeSubmissionRequest(
      sender: sender,
      sequenceNumber: accountInfo["sequence_number"],
      maxGasAmount: "1008",
      gasUnitPrice: "100",
      expirationTimestampSecs: milliseconds.toString(),
      payload: Payload(
          "entry_function_payload",
          "0x1::coin::transfer",
          ["0x1::aptos_coin::AptosCoin"],
          [receiverAddress, amount]
      )
    );

    final encodeTx = await aptos.encodeSubmission(txSubmission);
    final hex = HEX.decode(encodeTx.substring(2));
    final hexBytes = Uint8List.fromList(hex);
    final privateKeyBytes = HexString(privateKey).toUint8Array();
    final signingKey = ed25519.PrivateKey(privateKeyBytes);
    final signEncode = ed25519.sign(signingKey, hexBytes).sublist(0, 64);
    final tx = TransactionRequest(
        sender: txSubmission.sender,
        sequenceNumber: txSubmission.sequenceNumber,
        maxGasAmount: txSubmission.maxGasAmount,
        gasUnitPrice: txSubmission.gasUnitPrice,
        expirationTimestampSecs: txSubmission.expirationTimestampSecs,
        payload: txSubmission.payload,
        signature: Signature("ed25519_signature", account.pubKey().hex(), "0x"+HEX.encode(signEncode)));

    final result = await aptos.submitTransaction(tx);
    print(result);
    return result;
  }

  void _send() async {
    final privateKey = privateKeyTextEditingController.text.trim();
    final address = addressTextEditingController.text.trim();
    final amountText = amountTextEditingController.text.trim();

    if (privateKey.length != 128 && privateKey.length != 130) {
     setState(() {
       message = "invalid private key length";
     });
     return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null) {
      setState(() {
        message = "invalid aptos amount";
      });
      return;
    }

    final result = await _transfer(privateKey, address, (amount * pow(10, 8)).toInt().toString());
    setState(() {
      message = "txhash: ${result["hash"]}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
                controller: privateKeyTextEditingController,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Private key"
                )
            ),
            const SizedBox(height: 40),
              TextField(
                controller: addressTextEditingController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Receiver address"
                )
              ),
            const SizedBox(height: 20),
            TextField(
              controller: amountTextEditingController,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Aptos amount"
                )
            ),
            const SizedBox(height: 20),
            TextButton(
                onPressed: _send,
                child: const Text("Send", style: TextStyle(fontSize: 30))
            ),
            const SizedBox(height: 20),
            Text(message, style: const TextStyle(color: Colors.red))
          ],
        ),
      ),
      )
    );
  }
}
