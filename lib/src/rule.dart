import 'package:flutter_wcag_audit/src/config.dart';
import 'package:flutter_wcag_audit/src/finding.dart';
import 'package:flutter_wcag_audit/src/snapshot.dart';

/// Contract implemented by every automated audit rule.
abstract interface class WcagRule {
  /// Stable rule identifier.
  String get id;

  /// Evaluates a rendered semantics snapshot.
  Iterable<WcagFinding> evaluate(
    List<SemanticsNodeSnapshot> nodes,
    WcagAuditConfig config,
  );
}
