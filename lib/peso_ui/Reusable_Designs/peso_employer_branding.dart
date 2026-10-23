import 'package:flutter/material.dart';

/// Official, locally bundled employer marks used when a saved job has no logo URL.
/// A saved employer-provided URL always takes precedence in the UI.
class PesoEmployerBranding {
  PesoEmployerBranding._();

  static const jcrccLogoAsset = 'lib/assets/peso_employer_jcrcc.png';
  static const puregoldLogoAsset = 'lib/assets/peso_employer_puregold.png';

  static String? logoAssetForCompany(String? company) {
    final normalized = (company ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    if (normalized.isEmpty) return null;

    if (normalized.contains('jcrcc') ||
        normalized.contains('j c rodriguez construction corporation') ||
        normalized.contains('j c rodriguez construction') ||
        normalized.contains('rodriguez construction corporation')) {
      return jcrccLogoAsset;
    }
    if (normalized.contains('puregold')) return puregoldLogoAsset;
    return null;
  }

  static String? logoAssetForJob(Map<String, dynamic> job) {
    final company = job['company']?.toString().trim();
    final title = job['title']?.toString().trim();
    return logoAssetForCompany(company?.isNotEmpty == true ? company : title);
  }
}

/// Renders a saved employer logo first, then the locally bundled official logo
/// for known employers, then a neutral business icon. No demo brand is invented.
class PesoEmployerLogo extends StatelessWidget {
  const PesoEmployerLogo({
    super.key,
    required this.company,
    this.logoUrl,
    this.size = 28,
    this.fit = BoxFit.contain,
  });

  final String? company;
  final String? logoUrl;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final asset = PesoEmployerBranding.logoAssetForCompany(company);
    final url = logoUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _fallback(asset),
      );
    }
    return _fallback(asset);
  }

  Widget _fallback(String? asset) {
    if (asset == null) return Icon(Icons.business_rounded, size: size);
    return Image.asset(
      asset,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.business_rounded, size: size),
    );
  }
}
