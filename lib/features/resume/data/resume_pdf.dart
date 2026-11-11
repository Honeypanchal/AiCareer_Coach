import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'resume_models.dart';

/// Fonts for the PDF. Without them the built-in Helvetica is used, which
/// only covers basic Latin characters, so text is cleaned up to match.
class ResumeFonts {
  final pw.Font regular;
  final pw.Font bold;

  const ResumeFonts({required this.regular, required this.bold});
}

/// Builds a single-column, ATS-friendly resume: real text (no images),
/// standard headings and a simple layout that parsers read correctly.
Future<Uint8List> buildResumePdf(ImprovedResume resume, {ResumeFonts? fonts}) {
  final clean = fonts == null ? latinSafe : (String s) => s;
  const accent = PdfColor.fromInt(0xFF3F3A99);
  const grey = PdfColor.fromInt(0xFF555566);

  final doc = pw.Document(
    title: '${clean(resume.name)} - Resume',
    author: clean(resume.name),
    theme: fonts == null
        ? null
        : pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
  );

  pw.Widget heading(String text) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12, bottom: 5),
        padding: const pw.EdgeInsets.only(bottom: 2),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: accent, width: 0.8)),
        ),
        child: pw.Text(
          clean(text).toUpperCase(),
          style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: accent,
              letterSpacing: 0.6),
        ),
      );

  pw.Widget bullet(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(left: 6, bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3.2, right: 6),
              child: pw.Container(
                width: 2.6,
                height: 2.6,
                decoration: const pw.BoxDecoration(
                    color: PdfColors.black, shape: pw.BoxShape.circle),
              ),
            ),
            pw.Expanded(
              child: pw.Text(clean(text),
                  style: const pw.TextStyle(fontSize: 9.8, lineSpacing: 1.5)),
            ),
          ],
        ),
      );

  List<pw.Widget> entry(ResumeEntry e) {
    final subtitle = [e.organization, e.location]
        .where((s) => s.isNotEmpty)
        .map(clean)
        .join(' | ');
    return [
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 5, bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(clean(e.title),
                      style: pw.TextStyle(
                          fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                  if (subtitle.isNotEmpty)
                    pw.Text(subtitle,
                        style: const pw.TextStyle(fontSize: 9.8, color: grey)),
                ],
              ),
            ),
            if (e.period.isNotEmpty)
              pw.Text(clean(e.period),
                  style: const pw.TextStyle(fontSize: 9.5, color: grey)),
          ],
        ),
      ),
      ...e.bullets.map(bullet),
    ];
  }

  pw.Widget listSection(ResumeListSection s) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.RichText(
          text: pw.TextSpan(
            style: const pw.TextStyle(fontSize: 9.8, lineSpacing: 1.5),
            children: [
              pw.TextSpan(
                  text: '${clean(s.title)}: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(text: s.items.map(clean).join(', ')),
            ],
          ),
        ),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      build: (context) => [
        pw.Text(clean(resume.name),
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        if (resume.headline.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(clean(resume.headline),
                style: const pw.TextStyle(fontSize: 11.5, color: accent)),
          ),
        if (resume.contact.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(resume.contact.map(clean).join('  |  '),
                style: const pw.TextStyle(fontSize: 9.5, color: grey)),
          ),
        if (resume.summary.isNotEmpty) ...[
          heading('Summary'),
          pw.Text(clean(resume.summary),
              style: const pw.TextStyle(fontSize: 9.8, lineSpacing: 1.5)),
        ],
        if (resume.skills.isNotEmpty) ...[
          heading('Skills'),
          ...resume.skills.map(listSection),
        ],
        if (resume.experience.isNotEmpty) ...[
          heading('Experience'),
          ...resume.experience.expand(entry),
        ],
        if (resume.projects.isNotEmpty) ...[
          heading('Projects'),
          ...resume.projects.expand(entry),
        ],
        if (resume.education.isNotEmpty) ...[
          heading('Education'),
          ...resume.education.expand(entry),
        ],
        for (final section in resume.extraSections) ...[
          heading(section.title),
          ...section.items.map(bullet),
        ],
      ],
    ),
  );

  return doc.save();
}

/// Replaces characters Helvetica can't draw with close ASCII ones.
String latinSafe(String text) {
  const replacements = {
    '–': '-', '—': '-', '‒': '-', '−': '-',
    '‘': "'", '’': "'", '“': '"', '”': '"',
    '•': '-', '●': '-', '…': '...', ' ': ' ',
    '₹': 'Rs.', '→': '->',
  };
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final replacement = replacements[char];
    if (replacement != null) {
      buffer.write(replacement);
    } else if (rune < 0x7F || (rune >= 0xA0 && rune <= 0xFF)) {
      buffer.write(char);
    }
  }
  return buffer.toString();
}
