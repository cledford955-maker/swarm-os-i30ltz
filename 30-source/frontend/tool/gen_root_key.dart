import 'dart:io';
import 'package:cryptography/cryptography.dart';

Future<void> main() async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final privateKeyData = await keyPair.extractPrivateKeyBytes();

  final pubHex = publicKey.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final privHex = privateKeyData.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  stdout.writeln('PUBLIC_HEX:$pubHex');
  stdout.writeln('PRIVATE_HEX:$privHex');
}
