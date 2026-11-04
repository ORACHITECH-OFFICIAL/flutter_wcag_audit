import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wcag_audit/src/config.dart';
import 'package:flutter_wcag_audit/src/contrast.dart';
import 'package:flutter_wcag_audit/src/finding.dart';
import 'package:flutter_wcag_audit/src/report.dart';
import 'package:flutter_wcag_audit/src/rule.dart';
import 'package:flutter_wcag_audit/src/rules.dart';
import 'package:flutter_wcag_audit/src/snapshot.dart';
import 'package:flutter_wcag_audit/src/text_scaling.dart';

/// Adds WCAG auditing to Flutter's [WidgetTester].
extension WcagWidgetTester on WidgetTester {
  /// Audits the currently rendered application state.
  Future<WcagAuditReport> auditWcag({
    WcagAuditConfig config = const WcagAuditConfig(),
    List<WcagRule> rules = defaultWcagRules,
  }) async {
    final SemanticsHandle handle = ensureSemantics();
    try {
      await pump();
      final List<SemanticsNodeSnapshot> nodes = captureSemantics(this);
      final List<WcagFinding> findings = <WcagFinding>[
        for (final WcagRule rule in rules) ...rule.evaluate(nodes, config),
        ...await captureTextContrastFindings(this, config),
        ...await captureTextScalingFindings(this, config),
      ];
      return WcagAuditReport(
        standard: config.standard,
        findings: List<WcagFinding>.unmodifiable(findings),
        nodesInspected: nodes.length,
      );
    } finally {
      handle.dispose();
    }
  }
}
