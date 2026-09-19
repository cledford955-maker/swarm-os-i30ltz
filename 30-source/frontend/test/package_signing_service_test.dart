import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_flutter/services/package_signing_service.dart';

List<int> _hexToBytes(String hex) {
  final out = <int>[];
  for (var i = 0; i + 1 < hex.length; i += 2) {
    out.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return out;
}

String _bytesToHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  final svc = PackageSigningService.instance;
  const manifest = ExtensionManifest(
    id: 'test.ext',
    name: 'Test Extension',
    version: '1.0.0',
    publisher: 'test.developer',
    description: 'signing round-trip test',
    main: 'extension.js',
  );

  test('sign + verify round trip is real Ed25519, not the old HMAC', () async {
    final signed = await svc.signPackage(
      manifest: manifest,
      payloadContent: 'console.log("hi")',
      privateKeyHex: 'my-secret-phrase',
    );

    expect(signed.signature, startsWith('ED25519-SIG-'));
    expect(signed.publisherPublicKeyHex, isNotEmpty);

    final status = await svc.verifyPackage(signed);
    expect(status, SignatureVerificationStatus.unverifiedCommunity);
  });

  test('same phrase always yields the same publisher identity', () async {
    final a = await svc.signPackage(manifest: manifest, payloadContent: 'x', privateKeyHex: 'consistent-phrase');
    final b = await svc.signPackage(manifest: manifest, payloadContent: 'y', privateKeyHex: 'consistent-phrase');
    expect(a.publisherPublicKeyHex, b.publisherPublicKeyHex);
  });

  test('different phrases yield unlinkable identities', () async {
    final a = await svc.signPackage(manifest: manifest, payloadContent: 'x', privateKeyHex: 'phrase-one');
    final b = await svc.signPackage(manifest: manifest, payloadContent: 'x', privateKeyHex: 'phrase-two');
    expect(a.publisherPublicKeyHex, isNot(b.publisherPublicKeyHex));
  });

  test('tampered payload fails verification (fails closed)', () async {
    final signed = await svc.signPackage(
      manifest: manifest,
      payloadContent: 'original content',
      privateKeyHex: 'some-phrase',
    );

    final tampered = SignedPackage(
      manifest: signed.manifest,
      payloadBase64: base64Encode(utf8.encode('tampered content')),
      signature: signed.signature,
      publisherKeyFingerprint: signed.publisherKeyFingerprint,
      publisherPublicKeyHex: signed.publisherPublicKeyHex,
      verificationStatus: signed.verificationStatus,
    );

    final status = await svc.verifyPackage(tampered);
    expect(status, SignatureVerificationStatus.invalidSignature);
  });

  test('a package claiming officialRootFingerprint but signed with a different key is NOT official', () async {
    final signed = await svc.signPackage(
      manifest: manifest,
      payloadContent: 'x',
      privateKeyHex: 'not-the-root-key',
      publisherFingerprint: PackageSigningService.officialRootFingerprint,
    );
    // The fingerprint field is attacker-controlled and ignored by verification;
    // only the embedded public key (checked against officialRootPublicKeyHex) matters.
    final status = await svc.verifyPackage(signed);
    expect(status, SignatureVerificationStatus.unverifiedCommunity);
  });

  test('legacy HMAC-prefixed bundles are rejected, not silently trusted', () async {
    final legacy = SignedPackage(
      manifest: manifest,
      payloadBase64: base64Encode(utf8.encode('x')),
      signature: 'HMAC-SHA256-deadbeef',
      publisherKeyFingerprint: 'whatever',
      publisherPublicKeyHex: 'aa' * 32,
      verificationStatus: SignatureVerificationStatus.unverifiedCommunity,
    );
    final status = await svc.verifyPackage(legacy);
    expect(status, SignatureVerificationStatus.invalidSignature);
  });

  test('unsigned package reports unsigned', () async {
    final unsigned = SignedPackage(
      manifest: manifest,
      payloadBase64: base64Encode(utf8.encode('x')),
      signature: '',
      publisherKeyFingerprint: '',
      publisherPublicKeyHex: '',
      verificationStatus: SignatureVerificationStatus.unsigned,
    );
    final status = await svc.verifyPackage(unsigned);
    expect(status, SignatureVerificationStatus.unsigned);
  });

  // Requires the real root private key at 20-runtime/secrets/ — present on
  // i30ltz's dev machine, deliberately gitignored everywhere else. Skips
  // itself rather than failing when that file isn't there, since the whole
  // point of that key's custody is that it doesn't travel with the repo.
  test('a package genuinely signed by the root key verifies as officially trusted', () async {
    final keyFile = File('${Directory.current.path}/../../20-runtime/secrets/swarm_root_ed25519_private.key');
    if (!keyFile.existsSync()) {
      // ignore: avoid_print
      print('SKIPPED: root private key not present on this machine.');
      return;
    }
    final rootSeedHex = keyFile.readAsStringSync().trim();
    final rootKeyPair = await Ed25519().newKeyPairFromSeed(_hexToBytes(rootSeedHex));
    final rootPublicKey = await rootKeyPair.extractPublicKey();
    expect(_bytesToHex(rootPublicKey.bytes), PackageSigningService.officialRootPublicKeyHex,
        reason: 'the stored private key must match the public key hardcoded in the app');

    const payload = 'official payload';
    final digest = svc.calculateDigest(payload + jsonEncode(manifest.toJson()));
    final sig = await Ed25519().sign(utf8.encode(digest), keyPair: rootKeyPair);

    final officialPackage = SignedPackage(
      manifest: manifest,
      payloadBase64: base64Encode(utf8.encode(payload)),
      signature: 'ED25519-SIG-${_bytesToHex(sig.bytes)}',
      publisherKeyFingerprint: PackageSigningService.officialRootFingerprint,
      publisherPublicKeyHex: PackageSigningService.officialRootPublicKeyHex,
      verificationStatus: SignatureVerificationStatus.unverifiedCommunity,
    );

    final status = await svc.verifyPackage(officialPackage);
    expect(status, SignatureVerificationStatus.verifiedOfficial);
  });
}
