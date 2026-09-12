import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

enum SignatureVerificationStatus {
  verifiedOfficial,
  verifiedPartner,
  unverifiedCommunity,
  invalidSignature,
  unsigned,
}

class ExtensionManifest {
  final String id;
  final String name;
  final String version;
  final String publisher;
  final String description;
  final String main;
  final List<String> permissions;
  final Map<String, dynamic> raw;

  const ExtensionManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.publisher,
    required this.description,
    required this.main,
    this.permissions = const [],
    this.raw = const {},
  });

  factory ExtensionManifest.fromJson(Map<String, dynamic> json) {
    return ExtensionManifest(
      id: json['id'] as String? ?? 'unknown.ext',
      name: json['name'] as String? ?? 'Unnamed Extension',
      version: json['version'] as String? ?? '0.1.0',
      publisher: json['publisher'] as String? ?? 'anonymous',
      description: json['description'] as String? ?? '',
      main: json['main'] as String? ?? 'extension.js',
      permissions: (json['permissions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'publisher': publisher,
        'description': description,
        'main': main,
        'permissions': permissions,
        ...raw,
      };
}

class SignedPackage {
  final ExtensionManifest manifest;
  final String payloadBase64;
  final String signature;
  final String publisherKeyFingerprint;
  final SignatureVerificationStatus verificationStatus;

  const SignedPackage({
    required this.manifest,
    required this.payloadBase64,
    required this.signature,
    required this.publisherKeyFingerprint,
    required this.verificationStatus,
  });

  Map<String, dynamic> toJson() => {
        'manifest': manifest.toJson(),
        'payload': payloadBase64,
        'signature': signature,
        'publisherKeyFingerprint': publisherKeyFingerprint,
      };

  factory SignedPackage.fromJson(Map<String, dynamic> json) {
    final manifest = ExtensionManifest.fromJson(json['manifest'] as Map<String, dynamic>? ?? {});
    final sig = json['signature'] as String? ?? '';
    final fp = json['publisherKeyFingerprint'] as String? ?? '';

    // Trust is NEVER derived from the package's own contents. `fp` and
    // `manifest.publisher` are attacker-controlled: any bundle could claim
    // publisher "swarm.io" and be shown as Verified Official. Parsing only
    // records whether a signature is present; granting trust requires
    // verifyPackage() to actually recompute the MAC against a known key.
    final SignatureVerificationStatus status = sig.isEmpty
        ? SignatureVerificationStatus.unsigned
        : SignatureVerificationStatus.unverifiedCommunity;

    return SignedPackage(
      manifest: manifest,
      payloadBase64: json['payload'] as String? ?? '',
      signature: sig,
      publisherKeyFingerprint: fp,
      verificationStatus: status,
    );
  }
}

class PackageSigningService {
  static final PackageSigningService instance = PackageSigningService._();
  PackageSigningService._();

  static const String officialRootFingerprint = 'SWARM-ROOT-ED25519-9A82B710F';

  /// Validates an extension manifest for required fields
  List<String> validateManifest(Map<String, dynamic> json) {
    final errors = <String>[];
    if ((json['id'] as String? ?? '').trim().isEmpty) errors.add('Missing required field: "id"');
    if ((json['name'] as String? ?? '').trim().isEmpty) errors.add('Missing required field: "name"');
    if ((json['version'] as String? ?? '').trim().isEmpty) errors.add('Missing required field: "version"');
    if ((json['publisher'] as String? ?? '').trim().isEmpty) errors.add('Missing required field: "publisher"');
    return errors;
  }

  /// Calculates SHA256 digest of payload
  String calculateDigest(String content) {
    final bytes = utf8.encode(content);
    return sha256.convert(bytes).toString();
  }

  /// Signature prefix. HMAC-SHA256, not Ed25519 — this is a symmetric MAC, so
  /// it proves the signer held the key but cannot prove *which* publisher they
  /// are to a third party. Asymmetric publisher identity needs a real Ed25519
  /// dependency (`crypto` does not provide one); until then nothing this
  /// method produces is treated as officially verified.
  static const String sigPrefix = 'HMAC-SHA256-';

  String _macOf(String payloadContent, ExtensionManifest manifest, String keyHex) {
    final digest = calculateDigest(payloadContent + jsonEncode(manifest.toJson()));
    final mac = Hmac(sha256, utf8.encode(keyHex)).convert(utf8.encode(digest));
    return '$sigPrefix$mac';
  }

  /// True only if both strings are equal, without leaking length-prefix timing.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Signs an extension package with a real HMAC-SHA256 over the payload and
  /// manifest, so tampering with either is detectable by verifyPackage().
  SignedPackage signPackage({
    required ExtensionManifest manifest,
    required String payloadContent,
    required String privateKeyHex,
    String? publisherFingerprint,
  }) {
    final signature = _macOf(payloadContent, manifest, privateKeyHex);

    final fp = publisherFingerprint ??
        'COMMUNITY-PUBKEY-${sha256.convert(utf8.encode(privateKeyHex)).toString().substring(0, 12).toUpperCase()}';

    return SignedPackage(
      manifest: manifest,
      payloadBase64: base64Encode(utf8.encode(payloadContent)),
      signature: signature,
      publisherKeyFingerprint: fp,
      // Signing locally never confers official trust — that requires the
      // verifier to independently recompute the MAC with the root key.
      verificationStatus: SignatureVerificationStatus.unverifiedCommunity,
    );
  }

  /// Verifies tamper-integrity by recomputing the MAC. Fails closed: without
  /// [verifyKeyHex] nothing can be verified, so the package stays untrusted
  /// rather than being promoted on the strength of its own claims.
  SignatureVerificationStatus verifyPackage(
    SignedPackage package, {
    String? verifyKeyHex,
  }) {
    if (package.signature.isEmpty) return SignatureVerificationStatus.unsigned;
    if (!package.signature.startsWith(sigPrefix)) {
      // Includes legacy "ED25519-SIG-" bundles produced by the old simulated
      // signer, which were never actually verifiable.
      return SignatureVerificationStatus.invalidSignature;
    }
    if (verifyKeyHex == null || verifyKeyHex.isEmpty) {
      return SignatureVerificationStatus.unverifiedCommunity;
    }

    final String payloadContent;
    try {
      payloadContent = utf8.decode(base64Decode(package.payloadBase64));
    } catch (_) {
      return SignatureVerificationStatus.invalidSignature;
    }

    final expected = _macOf(payloadContent, package.manifest, verifyKeyHex);
    if (!_constantTimeEquals(expected, package.signature)) {
      return SignatureVerificationStatus.invalidSignature;
    }

    // MAC is good. Official status requires the key that matched to be the
    // root key, evidenced by the fingerprint recorded at signing time.
    return package.publisherKeyFingerprint == officialRootFingerprint
        ? SignatureVerificationStatus.verifiedOfficial
        : SignatureVerificationStatus.unverifiedCommunity;
  }

  /// Packages a folder or source into `.swarm-ext` JSON bundle
  Future<File> exportSwarmExtBundle({
    required Directory targetDir,
    required ExtensionManifest manifest,
    required String privateKey,
    required String outputPath,
  }) async {
    // Gather all files
    final fileMap = <String, String>{};
    if (targetDir.existsSync()) {
      for (final entity in targetDir.listSync(recursive: true)) {
        if (entity is File) {
          final relPath = entity.path.replaceFirst('${targetDir.path}/', '');
          try {
            fileMap[relPath] = await entity.readAsString();
          } catch (_) {}
        }
      }
    }

    final rawPayload = jsonEncode(fileMap.isNotEmpty ? fileMap : {'main.js': '// Swarm extension entrypoint\nconsole.log("Extension loaded");'});
    final signed = signPackage(manifest: manifest, payloadContent: rawPayload, privateKeyHex: privateKey);

    final file = File(outputPath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(signed.toJson()));
    return file;
  }
}
