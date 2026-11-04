import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wcag_audit/src/config.dart';
import 'package:flutter_wcag_audit/src/finding.dart';
import 'package:flutter_wcag_audit/src/source_location.dart';

Future<List<WcagFinding>> captureTextContrastFindings(
  WidgetTester tester,
  WcagAuditConfig config,
) async {
  if (!config.checkTextContrast) return const <WcagFinding>[];

  final List<WcagFinding> findings = <WcagFinding>[];
  for (final RenderView renderView in tester.binding.renderViews) {
    final OffsetLayer? layer = renderView.debugLayer as OffsetLayer?;
    if (layer == null) continue;

    late final ui.Image image;
    final ByteData? bytes = await tester.binding.runAsync<ByteData?>(() async {
      image = await layer.toImage(
        renderView.paintBounds,
        pixelRatio: 1 / renderView.flutterView.devicePixelRatio,
      );
      return image.toByteData();
    });
    if (bytes == null) {
      image.dispose();
      continue;
    }

    try {
      for (final Element element in tester.allElements) {
        if (element.renderObject?.owner != renderView.owner) continue;
        final _TextDetails? details = _textDetails(element);
        if (details == null || details.text.trim().isEmpty) continue;

        final RenderObject? renderObject = element.renderObject;
        if (renderObject is! RenderBox || !renderObject.attached) continue;
        final Rect bounds = MatrixUtils.transformRect(
          renderObject.getTransformTo(null),
          renderObject.paintBounds.inflate(2),
        );
        final Map<Color, int> histogram = _colorsWithinRect(
          bytes,
          bounds,
          image.width,
          image.height,
        );
        if (histogram.length < 2) continue;

        final _ContrastReport report = _ContrastReport(histogram);
        final double required = _requiredRatio(
          details.fontSize,
          details.isBold,
        );
        if (report.ratio + 0.01 >= required) continue;

        findings.add(
          WcagFinding(
            ruleId: 'wcag/text-contrast',
            criterion: '1.4.3',
            criterionName: 'Contrast (Minimum)',
            severity: WcagFindingSeverity.violation,
            message:
                'Text contrast is ${report.ratio.toStringAsFixed(2)}:1; '
                'at least ${required.toStringAsFixed(1)}:1 is required. '
                'Foreground estimate ${_hex(report.darkColor)}, '
                'background estimate ${_hex(report.lightColor)}.',
            impact: 'Low-vision users may be unable to read this text.',
            suggestion:
                'Use a darker foreground or lighter background until the required ratio is met.',
            element: 'Text("${_shorten(details.text)}")',
            source: sourceLocationForElement(element),
          ),
        );
      }
    } finally {
      image.dispose();
    }
  }
  return findings;
}

final class _TextDetails {
  const _TextDetails(this.text, this.fontSize, this.isBold);

  final String text;
  final double? fontSize;
  final bool isBold;
}

_TextDetails? _textDetails(Element element) {
  final Widget widget = element.widget;
  if (widget is Text) {
    final TextStyle inherited = DefaultTextStyle.of(element).style;
    final TextStyle? provided = widget.style;
    final TextStyle style = provided == null || provided.inherit
        ? inherited.merge(provided)
        : provided;
    final String text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    return _TextDetails(text, style.fontSize, _isBold(style.fontWeight));
  }
  if (widget is EditableText) {
    return _TextDetails(
      widget.controller.text,
      widget.style.fontSize,
      _isBold(widget.style.fontWeight),
    );
  }
  return null;
}

bool _isBold(FontWeight? weight) =>
    weight != null && weight.index >= FontWeight.w700.index;

double _requiredRatio(double? fontSize, bool isBold) {
  final double size = fontSize ?? 12;
  // WCAG defines large text as 18pt regular or 14pt bold. Flutter font sizes
  // are logical pixels, so convert points using the CSS 4:3 ratio.
  return (isBold && size >= 18.67) || size >= 24 ? 3 : 4.5;
}

final class _ContrastReport {
  factory _ContrastReport(Map<Color, int> histogram) {
    double weightedLightness = 0;
    int pixelCount = 0;
    for (final MapEntry<Color, int> entry in histogram.entries) {
      weightedLightness +=
          HSLColor.fromColor(entry.key).lightness * entry.value;
      pixelCount += entry.value;
    }
    final double average = weightedLightness / pixelCount;
    MapEntry<Color, int>? light;
    MapEntry<Color, int>? dark;
    for (final MapEntry<Color, int> entry in histogram.entries) {
      if (HSLColor.fromColor(entry.key).lightness <= average) {
        if (entry.value > (dark?.value ?? 0)) dark = entry;
      } else if (entry.value > (light?.value ?? 0)) {
        light = entry;
      }
    }
    final Color lightColor = light?.key ?? dark!.key;
    final Color darkColor = dark?.key ?? light!.key;
    return _ContrastReport._(lightColor, darkColor);
  }

  const _ContrastReport._(this.lightColor, this.darkColor);

  final Color lightColor;
  final Color darkColor;

  double get ratio =>
      (lightColor.computeLuminance() + 0.05) /
      (darkColor.computeLuminance() + 0.05);
}

Map<Color, int> _colorsWithinRect(
  ByteData data,
  Rect bounds,
  int width,
  int height,
) {
  final Rect clipped = bounds.intersect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  if (clipped.isEmpty) return const <Color, int>{};

  final Map<int, int> rgbaCounts = <int, int>{};
  for (int x = clipped.left.floor(); x < clipped.right.ceil(); x++) {
    for (int y = clipped.top.floor(); y < clipped.bottom.ceil(); y++) {
      final int rgba = data.getUint32((y * width + x) * 4);
      rgbaCounts.update(rgba, (int count) => count + 1, ifAbsent: () => 1);
    }
  }
  return rgbaCounts.map((int rgba, int count) {
    final int argb = (rgba << 24) | (rgba >> 8) & 0xFFFFFFFF;
    return MapEntry<Color, int>(Color(argb), count);
  });
}

String _hex(Color color) {
  final int value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

String _shorten(String text) =>
    text.length <= 40 ? text : '${text.substring(0, 37)}…';
