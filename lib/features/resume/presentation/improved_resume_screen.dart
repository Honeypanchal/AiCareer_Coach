import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_theme.dart';
import '../../interview/presentation/widgets/interview_widgets.dart';
import '../data/resume_models.dart';
import '../data/resume_pdf.dart';

/// Preview of the improved CV with share / save / print actions.
class ImprovedResumeScreen extends StatefulWidget {
  final ImprovedResume? resume;

  const ImprovedResumeScreen({super.key, required this.resume});

  @override
  State<ImprovedResumeScreen> createState() => _ImprovedResumeScreenState();
}

class _ImprovedResumeScreenState extends State<ImprovedResumeScreen> {
  ResumeFonts? _fonts;
  bool _fontsLoaded = false;

  // Noto Sans covers accents, ₹, dashes and other characters Helvetica can't
  // draw. It is downloaded once and cached; without internet the PDF falls
  // back to the built-in font.
  Future<ResumeFonts?> _loadFonts() async {
    if (_fontsLoaded) return _fonts;
    try {
      _fonts = ResumeFonts(
        regular: await PdfGoogleFonts.notoSansRegular(),
        bold: await PdfGoogleFonts.notoSansBold(),
      );
    } catch (_) {
      _fonts = null;
    }
    _fontsLoaded = true;
    return _fonts;
  }

  String get _fileName {
    final name = widget.resume?.name.trim() ?? '';
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return safe.isEmpty ? 'Resume.pdf' : '${safe}_Resume.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final resume = widget.resume;
    if (resume == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Improved CV')),
        body: const Center(child: Text('Please start again from Resume Check.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Improved CV')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: InterviewCard(
              padding: EdgeInsets.zero,
              borderColor: AppColors.warning,
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: const Icon(Icons.fact_check_outlined,
                      color: AppColors.warning),
                  title: const Text('Check before you send',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    resume.tips.isEmpty
                        ? 'Read it once to make sure every detail is right'
                        : '${resume.tips.length} thing${resume.tips.length == 1 ? '' : 's'} to add or check',
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    const Text(
                      'Only facts from your original resume are used, so add real numbers and links yourself.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                    PointList(
                      title: 'To add or check',
                      points: resume.tips,
                      icon: Icons.edit_note_rounded,
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (format) async =>
                  buildResumePdf(resume, fonts: await _loadFonts()),
              pdfFileName: _fileName,
              initialPageFormat: PdfPageFormat.a4,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              allowPrinting: true,
              allowSharing: true,
              loadingWidget: const Center(child: CircularProgressIndicator()),
              onError: (context, error) => const Center(
                child: Text('Could not create the PDF. Please try again.'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
