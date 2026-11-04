import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wcag_audit/src/report.dart';

/// Matches an audit report that contains no machine-detectable violations.
const Matcher hasNoWcagViolations = _HasNoWcagViolations();

final class _HasNoWcagViolations extends Matcher {
  const _HasNoWcagViolations();

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) =>
      item is WcagAuditReport && item.passes;

  @override
  Description describe(Description description) =>
      description.add('a WCAG audit report with no violations');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) {
    if (item is! WcagAuditReport) {
      return mismatchDescription.add('was ${item.runtimeType}');
    }
    return mismatchDescription.add('\n${item.toTerminalString()}');
  }
}
