// Draws the PrepPilot logo and writes the PNGs used for the app icons.
//
//   flutter test tool/logo/render_logo_test.dart
//   dart run flutter_launcher_icons
//
// It lives in tool/ so the normal `flutter test` run skips it.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _gradientStart = Color(0xFF8B7BFF);
const _gradientEnd = Color(0xFF4B44CC);
const _sparkle = Color(0xFFFFD166);

/// The paper plane, flight path and sparkle, drawn in a 1024 × 1024 box.
void paintMark(Canvas canvas, {double scale = 1}) {
  canvas.save();
  canvas.translate(512, 512);
  canvas.scale(scale);
  // The drawing's own centre is about (542, 550); shift it to the middle.
  canvas.translate(-542, -550);

  final white = Paint()..color = Colors.white;

  // Flight path: dots that grow toward the plane.
  final path = Path()
    ..moveTo(170, 880)
    ..quadraticBezierTo(250, 650, 420, 640);
  final metric = path.computeMetrics().first;
  const dots = 6;
  for (var i = 0; i < dots; i++) {
    final t = i / (dots - 1);
    final pos = metric.getTangentForOffset(metric.length * t)!.position;
    canvas.drawCircle(
      pos,
      9 + 9 * t,
      Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.45 * t),
    );
  }

  // Plane: upper wing, lower wing and the folded keel.
  const tip = Offset(800, 230);
  const tail = Offset(250, 470);
  const fold = Offset(480, 560);
  const bottom = Offset(590, 820);
  const keel = Offset(500, 680);

  canvas.drawPath(
    Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tail.dx, tail.dy)
      ..lineTo(fold.dx, fold.dy)
      ..close(),
    white,
  );
  canvas.drawPath(
    Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(fold.dx, fold.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..close(),
    Paint()..color = Colors.white.withValues(alpha: 0.88),
  );
  canvas.drawPath(
    Path()
      ..moveTo(fold.dx, fold.dy)
      ..lineTo(keel.dx, keel.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..close(),
    Paint()..color = const Color(0xFFD9D5FF),
  );

  // AI sparkle: a four-point star near the tip.
  _star(canvas, const Offset(835, 395), 62, _sparkle);
  _star(canvas, const Offset(905, 300), 28, _sparkle);

  canvas.restore();
}

void _star(Canvas canvas, Offset c, double r, Color color) {
  final inner = r * 0.28;
  final star = Path();
  for (var i = 0; i < 8; i++) {
    final radius = i.isEven ? r : inner;
    final angle = -math.pi / 2 + i * math.pi / 4;
    final p = c + Offset(math.cos(angle), math.sin(angle)) * radius;
    i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(star..close(), Paint()..color = color);
}

void _background(Canvas canvas, {required bool rounded}) {
  const rect = Rect.fromLTWH(0, 0, 1024, 1024);
  final paint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_gradientStart, _gradientEnd],
    ).createShader(rect);
  if (rounded) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(230)),
      paint,
    );
  } else {
    canvas.drawRect(rect, paint);
  }
}

Future<void> _write(String path, void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(1024, 1024);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render PrepPilot logo', () async {
    // Full icon: rounded gradient square (web, README, store listing).
    await _write('assets/logo/logo.png', (c) {
      _background(c, rounded: true);
      paintMark(c, scale: 0.86);
    });
    // Square version for launchers that apply their own mask.
    await _write('assets/logo/logo_square.png', (c) {
      _background(c, rounded: false);
      paintMark(c, scale: 0.86);
    });
    // Android adaptive icon foreground (transparent).
    await _write('assets/logo/logo_foreground.png', (c) {
      // flutter_launcher_icons adds a 16% inset that keeps it in the safe zone.
      paintMark(c);
    });
    await _write('assets/logo/logo_background.png', (c) {
      _background(c, rounded: false);
    });
    // Mark only, for use inside the app (splash, about).
    await _write('assets/logo/logo_mark.png', (c) => paintMark(c));
  });
}
