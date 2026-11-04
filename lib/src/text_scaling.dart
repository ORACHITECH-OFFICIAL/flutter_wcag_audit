import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wcag_audit/src/config.dart';
import 'package:flutter_wcag_audit/src/finding.dart';
import 'package:flutter_wcag_audit/src/source_location.dart';

Future<List<WcagFinding>> captureTextScalingFindings(
  WidgetTester tester,
  WcagAuditConfig config,
) async {
  if (!config.checkTextScaling) return const <WcagFinding>[];

  final double originalScale = tester.platformDispatcher.textScaleFactor;
  final FlutterExceptionHandler? originalErrorHandler = FlutterError.onError;
  final List<FlutterErrorDetails> overflowErrors = <FlutterErrorDetails>[];
  final Set<RenderParagraph> clippedAtBaseline = _clippedParagraphs(tester);

  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('overflowed by')) {
      overflowErrors.add(details);
      return;
    }
    originalErrorHandler?.call(details);
  };

  try {
    tester.platformDispatcher.textScaleFactorTestValue = config.textScaleFactor;
    await tester.pump();
    _drainOverflowExceptions(tester, overflowErrors);

    final List<WcagFinding> findings = <WcagFinding>[
      ..._flexOverflowFindings(tester, config.textScaleFactor),
      ..._clippedTextFindings(
        tester,
        config.textScaleFactor,
        clippedAtBaseline,
      ),
    ];

    if (findings.isEmpty && overflowErrors.isNotEmpty) {
      findings.add(
        WcagFinding(
          ruleId: 'wcag/text-scale-overflow',
          criterion: '1.4.4',
          criterionName: 'Resize Text',
          severity: WcagFindingSeverity.violation,
          message:
              'The layout reported ${overflowErrors.length} overflow error(s) at '
              '${_scaleLabel(config.textScaleFactor)} text size.',
          impact:
              'Users who enlarge text may lose content or be unable to operate controls.',
          suggestion:
              'Remove fixed dimensions, allow wrapping, or use Flexible/Expanded and scrollable layouts.',
          element: 'Rendered layout',
        ),
      );
    }
    return findings;
  } finally {
    tester.platformDispatcher.textScaleFactorTestValue = originalScale;
    try {
      // Keep the overflow-capturing handler installed for the restoration
      // frame; MediaQuery can still lay out once with the enlarged scaler.
      await tester.pump();
      _drainOverflowExceptions(tester, overflowErrors);
    } finally {
      FlutterError.onError = originalErrorHandler;
    }
  }
}

void _drainOverflowExceptions(
  WidgetTester tester,
  List<FlutterErrorDetails> overflowErrors,
) {
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    final Object captured = exception!;
    if (captured.toString().contains('overflowed by')) {
      overflowErrors.add(FlutterErrorDetails(exception: captured));
      continue;
    }
    throw captured;
  }
}

Iterable<WcagFinding> _flexOverflowFindings(
  WidgetTester tester,
  double scale,
) sync* {
  final Set<RenderFlex> reported = <RenderFlex>{};
  for (final Element element in tester.allElements) {
    final RenderObject? renderObject = element.renderObject;
    if (renderObject is! RenderFlex || !reported.add(renderObject)) continue;
    if (!_flexChildrenExceedBounds(renderObject)) continue;

    yield WcagFinding(
      ruleId: 'wcag/text-scale-overflow',
      criterion: '1.4.4',
      criterionName: 'Resize Text',
      severity: WcagFindingSeverity.violation,
      message:
          '${renderObject.direction == Axis.horizontal ? 'Row' : 'Column'} '
          'content exceeds its bounds at ${_scaleLabel(scale)} text size.',
      impact:
          'Users who enlarge text may lose content or be unable to operate controls.',
      suggestion:
          'Allow text to wrap, remove fixed dimensions, or use Flexible/Expanded and scrolling.',
      element: renderObject.direction == Axis.horizontal ? 'Row' : 'Column',
      source: sourceLocationForElement(element),
    );
  }
}

bool _flexChildrenExceedBounds(RenderFlex flex) {
  final Rect available = Offset.zero & flex.size;
  RenderBox? child = flex.firstChild;
  while (child != null) {
    final FlexParentData data = child.parentData! as FlexParentData;
    final Rect occupied = data.offset & child.size;
    if (occupied.left < available.left - precisionErrorTolerance ||
        occupied.top < available.top - precisionErrorTolerance ||
        occupied.right > available.right + precisionErrorTolerance ||
        occupied.bottom > available.bottom + precisionErrorTolerance) {
      return true;
    }
    child = flex.childAfter(child);
  }
  return false;
}

Iterable<WcagFinding> _clippedTextFindings(
  WidgetTester tester,
  double scale,
  Set<RenderParagraph> clippedAtBaseline,
) sync* {
  final Set<RenderParagraph> reported = <RenderParagraph>{};
  for (final Element element in tester.allElements) {
    final RenderObject? renderObject = element.renderObject;
    if (renderObject is! RenderParagraph || !reported.add(renderObject)) {
      continue;
    }
    if (!renderObject.didExceedMaxLines ||
        clippedAtBaseline.contains(renderObject)) {
      continue;
    }

    yield WcagFinding(
      ruleId: 'wcag/text-scale-clipped',
      criterion: '1.4.4',
      criterionName: 'Resize Text',
      severity: WcagFindingSeverity.violation,
      message:
          'Text exceeds maxLines and is clipped at ${_scaleLabel(scale)} text size.',
      impact: 'Enlarged text may be hidden from low-vision users.',
      suggestion:
          'Avoid fixed maxLines for essential text, or provide expansion and scrolling.',
      element: 'Text("${_shorten(renderObject.text.toPlainText())}")',
      source: sourceLocationForElement(element),
    );
  }
}

Set<RenderParagraph> _clippedParagraphs(WidgetTester tester) =>
    <RenderParagraph>{
      for (final Element element in tester.allElements)
        if (element.renderObject case final RenderParagraph paragraph)
          if (paragraph.didExceedMaxLines) paragraph,
    };

String _scaleLabel(double scale) => '${(scale * 100).round()}%';

String _shorten(String text) =>
    text.length <= 40 ? text : '${text.substring(0, 37)}…';
