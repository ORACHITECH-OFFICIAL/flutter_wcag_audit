import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wcag_audit/flutter_wcag_audit.dart';
import 'package:flutter_wcag_audit_example/main.dart';

void main() {
  testWidgets('example screen has no automated WCAG violations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());

    final WcagAuditReport report = await tester.auditWcag(
      config: const WcagAuditConfig.mobileRecommended(),
    );

    expect(report, hasNoWcagViolations);
  });
}
