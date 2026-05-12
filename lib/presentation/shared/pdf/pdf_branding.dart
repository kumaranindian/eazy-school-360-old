import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../domain/entities/school.dart';

/// Global Unicode font for PDF text rendering
pw.Font? _unicodeFont;

/// Load Unicode font for PDF rendering (call once during app startup)
Future<void> loadPdfUnicodeFont() async {
  // Font loading disabled - no Roboto-Regular.ttf file exists
  // PDFs will use default fonts (Helvetica) which don't support Unicode
  // This is acceptable for the current use case
}

/// Lightweight container for everything the PDF header needs to render.
/// Built once per export by [PdfBranding.forSchool] and reused for every page.
class PdfBrandingContext {
  final String schoolName;
  final String schoolAddress;
  final String schoolPhone;
  final String schoolEmail;
  final String schoolWebsite;
  final pw.ImageProvider? logoImage;
  final String productName;

  const PdfBrandingContext({
    required this.schoolName,
    required this.schoolAddress,
    required this.schoolPhone,
    required this.schoolEmail,
    required this.schoolWebsite,
    required this.logoImage,
    this.productName = 'EazySchool 360',
  });

  bool get hasContact =>
      schoolAddress.isNotEmpty ||
      schoolPhone.isNotEmpty ||
      schoolEmail.isNotEmpty;
}

/// Helpers to produce a consistent branded header on every PDF export.
///
/// Usage:
/// ```dart
/// final branding = await PdfBranding.forSchool(schoolId);
/// final pdf = pw.Document();
/// pdf.addPage(pw.MultiPage(
///   header: (ctx) => PdfBranding.buildHeader(branding, title: 'Fee Receipt'),
///   build: (ctx) => [...],
/// ));
/// ```
class PdfBranding {
  static const _accentPdfColor = PdfColor.fromInt(0xFF4CAF50);
  static const _textPrimary = PdfColor.fromInt(0xFF111827);
  static const _textSecondary = PdfColor.fromInt(0xFF6B7280);
  static const _borderColor = PdfColor.fromInt(0xFFE5E7EB);

  // In-memory cache keyed by schoolId so we only hit Firestore once per session.
  static final Map<String, PdfBrandingContext> _cache = {};

  /// Clear cached branding (call when school settings change).
  static void clearCache() => _cache.clear();

  /// Fetch school + local logo and return a reusable branding context.
  /// Never throws — returns sensible defaults if data is missing.
  /// Results are cached in memory so repeated calls return instantly.
  static Future<PdfBrandingContext> forSchool(String schoolId) async {
    if (_cache.containsKey(schoolId)) return _cache[schoolId]!;

    String schoolName = '';
    String address = '';
    String phone = '';
    String email = '';
    String website = '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .get();
      if (doc.exists) {
        print('📄 [PDF_BRANDING] School doc exists for ID: $schoolId');
        final data = doc.data() as Map<String, dynamic>?;
        print('📄 [PDF_BRANDING] Raw data: ${data?.keys.toList()}');
        print('📄 [PDF_BRANDING] name field: ${data?['name']}');
        print('📄 [PDF_BRANDING] schoolName field: ${data?['schoolName']}');
        print('📄 [PDF_BRANDING] address: ${data?['address']}');
        print('📄 [PDF_BRANDING] phone: ${data?['phone']}');
        print('📄 [PDF_BRANDING] email: ${data?['email']}');

        final school = School.fromFirestore(doc);
        schoolName = school.schoolName;
        address = school.address;
        phone = school.phone;
        email = school.email;
        website = school.website;

        print('✅ [PDF_BRANDING] Parsed schoolName: $schoolName');
        print('✅ [PDF_BRANDING] Parsed address: $address');
        print('✅ [PDF_BRANDING] Parsed phone: $phone');
        print('✅ [PDF_BRANDING] Parsed email: $email');
        print('✅ [PDF_BRANDING] Parsed website: $website');
      } else {
        print('❌ [PDF_BRANDING] School doc does NOT exist for ID: $schoolId');
      }
    } catch (e) {
      print('❌ [PDF_BRANDING] Error loading school: $e');
      // Swallow — header should never block the export.
    }

    pw.ImageProvider? logo;
    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      // Logo is optional; header still renders without it.
    }

    final ctx = PdfBrandingContext(
      schoolName: schoolName,
      schoolAddress: address,
      schoolPhone: phone,
      schoolEmail: email,
      schoolWebsite: website,
      logoImage: logo,
    );
    _cache[schoolId] = ctx;
    return ctx;
  }

  /// Build the standard header widget for a PDF page.
  ///
  /// [title] is the document-specific title (e.g. "Fee Receipt", "Expense Report").
  /// [showLogo] controls whether to display the school logo (default: true).
  static pw.Widget buildHeader(
    PdfBrandingContext ctx, {
    String? title,
    String? subtitle,
    bool showLogo = true,
  }) {
    final textStyle = _unicodeFont != null
        ? pw.TextStyle(font: _unicodeFont!, fontFallback: [pw.Font.helvetica()])
        : null;

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _borderColor, width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (ctx.logoImage != null && showLogo)
            pw.Container(
              width: 54,
              height: 54,
              margin: const pw.EdgeInsets.only(right: 12),
              child: pw.Image(ctx.logoImage!, fit: pw.BoxFit.contain),
            ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  ctx.productName,
                  style: textStyle ??
                      pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _accentPdfColor,
                        letterSpacing: 1.2,
                      ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  ctx.schoolName.isEmpty ? 'School' : ctx.schoolName,
                  style: textStyle ??
                      pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _textPrimary,
                      ),
                ),
                if (ctx.schoolAddress.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    ctx.schoolAddress,
                    style: textStyle ??
                        const pw.TextStyle(fontSize: 9, color: _textSecondary),
                  ),
                ],
                if (ctx.schoolPhone.isNotEmpty || ctx.schoolEmail.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(
                      [
                        if (ctx.schoolPhone.isNotEmpty)
                          'Ph: ${ctx.schoolPhone}',
                        if (ctx.schoolEmail.isNotEmpty) ctx.schoolEmail,
                      ].join('  •  '),
                      style: textStyle ??
                          const pw.TextStyle(
                            fontSize: 9,
                            color: _textSecondary,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          if (title != null || subtitle != null)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (title != null)
                  pw.Text(
                    title,
                    style: textStyle ??
                        pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: _textPrimary,
                        ),
                  ),
                if (subtitle != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(
                      subtitle,
                      style: textStyle ??
                          const pw.TextStyle(
                            fontSize: 10,
                            color: _textSecondary,
                          ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Convenience footer: "Generated by EazySchool 360 on <date>" + page number.
  static pw.Widget buildFooter(PdfBrandingContext ctx, pw.Context pdfCtx) {
    final textStyle = _unicodeFont != null
        ? pw.TextStyle(
            fontSize: 8,
            color: _textSecondary,
            font: _unicodeFont!,
            fontFallback: [pw.Font.helvetica()])
        : const pw.TextStyle(fontSize: 8, color: _textSecondary);

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _borderColor, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by ${ctx.productName}',
            style: textStyle,
          ),
          pw.Text(
            'Page ${pdfCtx.pageNumber} of ${pdfCtx.pagesCount}',
            style: textStyle,
          ),
        ],
      ),
    );
  }

  /// Convenience helper returning an already-encoded logo for places
  /// that directly build [pw.Document] pages (e.g. raw bytes export).
  static Future<Uint8List?> loadLogoBytes() async {
    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      return bytes.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
