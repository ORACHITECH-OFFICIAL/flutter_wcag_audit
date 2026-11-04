import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wcag_audit/src/finding.dart';
import 'package:flutter_wcag_audit/src/source_location.dart';

/// An immutable, rule-friendly representation of a semantics node.
final class SemanticsNodeSnapshot {
  const SemanticsNodeSnapshot({
    required this.id,
    required this.identifier,
    required this.label,
    required this.tooltip,
    required this.value,
    required this.logicalBounds,
    required this.hasTapAction,
    required this.hasLongPressAction,
    required this.isTextField,
    required this.isLink,
    required this.isHidden,
    required this.isInvisible,
    required this.isMergedIntoParent,
    required this.source,
  });

  final int id;
  final String identifier;
  final String label;
  final String tooltip;
  final String value;
  final Rect logicalBounds;
  final bool hasTapAction;
  final bool hasLongPressAction;
  final bool isTextField;
  final bool isLink;
  final bool isHidden;
  final bool isInvisible;
  final bool isMergedIntoParent;
  final SourceLocation? source;

  bool get isInteractive => hasTapAction || hasLongPressAction;

  bool get isExcluded => isHidden || isInvisible || isMergedIntoParent;

  String get accessibleName {
    if (label.trim().isNotEmpty) return label.trim();
    return tooltip.trim();
  }

  String get description {
    final String stableId = identifier.isEmpty ? 'semantics#$id' : identifier;
    final String name = accessibleName;
    return name.isEmpty ? stableId : '$stableId ("$name")';
  }
}

List<SemanticsNodeSnapshot> captureSemantics(WidgetTester tester) {
  final List<SemanticsNodeSnapshot> result = <SemanticsNodeSnapshot>[];
  final List<_SourceCandidate> sourceCandidates = _sourceCandidates(tester);

  for (final RenderView view in tester.binding.renderViews) {
    final SemanticsNode? root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root == null) continue;
    _captureNode(
      root,
      view.flutterView.devicePixelRatio,
      sourceCandidates,
      result,
    );
  }

  return result;
}

void _captureNode(
  SemanticsNode node,
  double devicePixelRatio,
  List<_SourceCandidate> sourceCandidates,
  List<SemanticsNodeSnapshot> output,
) {
  Rect bounds = node.rect;
  SemanticsNode? current = node;
  while (current != null) {
    final Matrix4? transform = current.transform;
    if (transform != null) {
      bounds = MatrixUtils.transformRect(transform, bounds);
    }
    current = current.parent;
  }

  final SemanticsData data = node.getSemanticsData();
  final Rect logicalBounds = Rect.fromLTWH(
    bounds.left / devicePixelRatio,
    bounds.top / devicePixelRatio,
    bounds.width / devicePixelRatio,
    bounds.height / devicePixelRatio,
  );
  output.add(
    SemanticsNodeSnapshot(
      id: node.id,
      identifier: data.identifier,
      label: data.label,
      tooltip: data.tooltip,
      value: data.value,
      logicalBounds: logicalBounds,
      hasTapAction: data.hasAction(ui.SemanticsAction.tap),
      hasLongPressAction: data.hasAction(ui.SemanticsAction.longPress),
      isTextField: data.flagsCollection.isTextField,
      isLink: data.flagsCollection.isLink,
      isHidden: data.flagsCollection.isHidden,
      isInvisible: node.isInvisible,
      isMergedIntoParent: node.isMergedIntoParent,
      source: _closestSource(logicalBounds, sourceCandidates),
    ),
  );

  node.visitChildren((SemanticsNode child) {
    _captureNode(child, devicePixelRatio, sourceCandidates, output);
    return true;
  });
}

final class _SourceCandidate {
  const _SourceCandidate(this.bounds, this.source);

  final Rect bounds;
  final SourceLocation source;
}

List<_SourceCandidate> _sourceCandidates(WidgetTester tester) {
  final List<_SourceCandidate> result = <_SourceCandidate>[];
  for (final Element element in tester.allElements) {
    if (!debugIsWidgetLocalCreation(element.widget)) continue;
    final RenderObject? renderObject = element.renderObject;
    if (renderObject is! RenderBox || !renderObject.attached) continue;
    final SourceLocation? source = sourceLocationForElement(element);
    if (source == null) continue;
    final Rect bounds = MatrixUtils.transformRect(
      renderObject.getTransformTo(null),
      renderObject.paintBounds,
    );
    if (bounds.isEmpty || !bounds.isFinite) continue;
    result.add(_SourceCandidate(bounds, source));
  }
  result.sort(
    (_SourceCandidate a, _SourceCandidate b) =>
        (a.bounds.width * a.bounds.height).compareTo(
          b.bounds.width * b.bounds.height,
        ),
  );
  return result;
}

SourceLocation? _closestSource(
  Rect semanticsBounds,
  List<_SourceCandidate> candidates,
) {
  final Offset center = semanticsBounds.center;
  for (final _SourceCandidate candidate in candidates) {
    if (candidate.bounds.contains(center)) return candidate.source;
  }
  return null;
}
