import 'package:flutter/material.dart';

import '../data/interview_models.dart';
import 'widgets/interview_widgets.dart';

/// A saved interview's report, opened from history.
class InterviewReportScreen extends StatelessWidget {
  final InterviewSession? session;

  const InterviewReportScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final session = this.session;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          session == null
              ? 'Interview report'
              : formatShortDate(session.createdAt),
        ),
      ),
      body: session == null
          ? const Center(child: Text('This report is no longer available.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [InterviewReportView(session: session)],
            ),
    );
  }
}
