import 'package:flutter_wcag_audit/src/config.dart';
import 'package:flutter_wcag_audit/src/finding.dart';
import 'package:flutter_wcag_audit/src/rule.dart';
import 'package:flutter_wcag_audit/src/snapshot.dart';

const List<WcagRule> defaultWcagRules = <WcagRule>[
  AccessibleControlNameRule(),
  TextFieldNameRule(),
  MinimumTargetSizeRule(),
  DuplicateControlNameRule(),
];

final class AccessibleControlNameRule implements WcagRule {
  const AccessibleControlNameRule();

  @override
  String get id => 'wcag/accessible-control-name';

  @override
  Iterable<WcagFinding> evaluate(
    List<SemanticsNodeSnapshot> nodes,
    WcagAuditConfig config,
  ) sync* {
    for (final SemanticsNodeSnapshot node in nodes) {
      if (node.isExcluded || node.isTextField || !node.isInteractive) continue;
      if (node.accessibleName.isNotEmpty) continue;
      yield WcagFinding(
        ruleId: id,
        criterion: '4.1.2',
        criterionName: 'Name, Role, Value',
        severity: WcagFindingSeverity.violation,
        message: 'Interactive control has no accessible name.',
        impact:
            'A screen-reader user may hear only “button” and cannot determine the control’s purpose.',
        suggestion:
            'Add a descriptive tooltip, an IconButton tooltip, or a Semantics label.',
        element: node.description,
        source: node.source,
      );
    }
  }
}

final class TextFieldNameRule implements WcagRule {
  const TextFieldNameRule();

  @override
  String get id => 'wcag/text-field-name';

  @override
  Iterable<WcagFinding> evaluate(
    List<SemanticsNodeSnapshot> nodes,
    WcagAuditConfig config,
  ) sync* {
    for (final SemanticsNodeSnapshot node in nodes) {
      if (node.isExcluded || !node.isTextField) continue;
      if (node.accessibleName.isNotEmpty) continue;
      yield WcagFinding(
        ruleId: id,
        criterion: '3.3.2',
        criterionName: 'Labels or Instructions',
        severity: WcagFindingSeverity.violation,
        message: 'Text field has no accessible label.',
        impact:
            'Screen-reader users cannot determine what information the field expects.',
        suggestion:
            'Use InputDecoration.labelText or provide an equivalent Semantics label.',
        element: node.description,
        source: node.source,
      );
    }
  }
}

final class MinimumTargetSizeRule implements WcagRule {
  const MinimumTargetSizeRule();

  @override
  String get id => 'wcag/minimum-target-size';

  @override
  Iterable<WcagFinding> evaluate(
    List<SemanticsNodeSnapshot> nodes,
    WcagAuditConfig config,
  ) sync* {
    for (final SemanticsNodeSnapshot node in nodes) {
      if (node.isExcluded || node.isLink || !node.isInteractive) continue;
      final bool tooNarrow =
          node.logicalBounds.width < config.minimumTargetWidth;
      final bool tooShort =
          node.logicalBounds.height < config.minimumTargetHeight;
      if (!tooNarrow && !tooShort) continue;
      yield WcagFinding(
        ruleId: id,
        criterion: config.standard == WcagStandard.wcag22AA ? '2.5.8' : '2.5.5',
        criterionName: 'Target Size',
        severity: config.standard == WcagStandard.wcag22AA
            ? WcagFindingSeverity.violation
            : WcagFindingSeverity.warning,
        message:
            'Interactive target is ${_size(node)}; configured minimum is '
            '${_number(config.minimumTargetWidth)}×${_number(config.minimumTargetHeight)}.',
        impact:
            'Small targets are difficult for users with limited dexterity or inaccurate pointing input.',
        suggestion:
            'Increase the hit area with padding or a constrained box; the visible icon may remain smaller.',
        element: node.description,
        source: node.source,
      );
    }
  }

  static String _size(SemanticsNodeSnapshot node) =>
      '${_number(node.logicalBounds.width)}×${_number(node.logicalBounds.height)}';

  static String _number(double value) =>
      value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}

final class DuplicateControlNameRule implements WcagRule {
  const DuplicateControlNameRule();

  @override
  String get id => 'wcag/duplicate-control-name';

  @override
  Iterable<WcagFinding> evaluate(
    List<SemanticsNodeSnapshot> nodes,
    WcagAuditConfig config,
  ) sync* {
    if (!config.checkDuplicateNames) return;
    final Map<String, List<SemanticsNodeSnapshot>> groups =
        <String, List<SemanticsNodeSnapshot>>{};
    for (final SemanticsNodeSnapshot node in nodes) {
      if (node.isExcluded || !node.isInteractive || node.accessibleName.isEmpty)
        continue;
      groups
          .putIfAbsent(
            node.accessibleName.toLowerCase(),
            () => <SemanticsNodeSnapshot>[],
          )
          .add(node);
    }
    for (final List<SemanticsNodeSnapshot> group in groups.values) {
      if (group.length < 2) continue;
      yield WcagFinding(
        ruleId: id,
        criterion: '2.4.6',
        criterionName: 'Headings and Labels',
        severity: WcagFindingSeverity.warning,
        message:
            '${group.length} interactive controls share the name “${group.first.accessibleName}”.',
        impact:
            'Repeated names can be ambiguous when controls perform different actions.',
        suggestion:
            'Confirm the surrounding context is sufficient, or make each accessible name more specific.',
        element: group
            .map((SemanticsNodeSnapshot node) => node.description)
            .join(', '),
        source: group.first.source,
      );
    }
  }
}
