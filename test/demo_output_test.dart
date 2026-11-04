import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wcag_audit/flutter_wcag_audit.dart';

void main() {
  testWidgets('demonstrates the WCAG audit report', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: <Widget>[
              Semantics(
                button: true,
                identifier: 'delete-control',
                child: GestureDetector(
                  onTap: () {},
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: Icon(Icons.delete, size: 12),
                  ),
                ),
              ),
              const TextField(),
              const Text(
                'Continue',
                style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    final WcagAuditReport report = await tester.auditWcag(
      config: const WcagAuditConfig(checkTextScaling: false),
    );

    // ignore: avoid_print
    print('\n${report.toTerminalString()}\n');

    expect(report.passes, isFalse);
    expect(
      report.findings.map((WcagFinding finding) => finding.ruleId),
      containsAll(<String>[
        'wcag/accessible-control-name',
        'wcag/minimum-target-size',
        'wcag/text-field-name',
        'wcag/text-contrast',
      ]),
    );
  });
}
