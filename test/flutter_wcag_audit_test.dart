import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wcag_audit/flutter_wcag_audit.dart';

void main() {
  testWidgets('passes an accessible screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              IconButton(
                tooltip: 'Delete item',
                onPressed: () {},
                icon: const Icon(Icons.delete),
              ),
              const TextField(
                decoration: InputDecoration(labelText: 'Email address'),
              ),
            ],
          ),
        ),
      ),
    );

    final WcagAuditReport report = await tester.auditWcag(
      config: const WcagAuditConfig(
        checkTextContrast: false,
        checkTextScaling: false,
      ),
    );

    expect(report, hasNoWcagViolations);
    expect(report.toJson()['passes'], isTrue);
  });

  testWidgets('reports an unnamed and undersized control', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Semantics(
            button: true,
            identifier: 'delete-control',
            child: GestureDetector(
              onTap: () {},
              child: const SizedBox(width: 16, height: 16),
            ),
          ),
        ),
      ),
    );

    final WcagAuditReport report = await tester.auditWcag(
      config: const WcagAuditConfig(
        checkTextContrast: false,
        checkTextScaling: false,
      ),
    );

    expect(report.passes, isFalse);
    expect(
      report.findings.map((WcagFinding finding) => finding.ruleId),
      containsAll(<String>[
        'wcag/accessible-control-name',
        'wcag/minimum-target-size',
      ]),
    );
    expect(report.toTerminalString(), contains('WCAG 4.1.2'));
    expect(report.toTerminalString(), contains('delete-control'));
    expect(
      report.toTerminalString(),
      contains('flutter_wcag_audit_test.dart:'),
    );
  });

  testWidgets('reports an unlabeled text field', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TextField())),
    );

    final WcagAuditReport report = await tester.auditWcag(
      config: const WcagAuditConfig(
        checkTextContrast: false,
        checkTextScaling: false,
      ),
    );

    expect(
      report.findings.map((WcagFinding finding) => finding.ruleId),
      contains('wcag/text-field-name'),
    );
  });

  testWidgets('duplicate names are warnings and do not fail the audit', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: <Widget>[
            IconButton(
              tooltip: 'More',
              onPressed: () {},
              icon: const Icon(Icons.more_horiz),
            ),
            IconButton(
              tooltip: 'More',
              onPressed: () {},
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    );

    final WcagAuditReport report = await tester.auditWcag(
      config: const WcagAuditConfig(
        checkTextContrast: false,
        checkTextScaling: false,
      ),
    );

    expect(report.passes, isTrue);
    expect(report.warnings, hasLength(1));
  });

  testWidgets(
    'reports insufficient normal-text contrast with source location',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ColoredBox(
            color: Colors.white,
            child: Center(
              child: Text(
                'Low contrast text',
                style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 16),
              ),
            ),
          ),
        ),
      );

      final WcagAuditReport report = await tester.auditWcag(
        config: const WcagAuditConfig(checkTextScaling: false),
      );
      final WcagFinding finding = report.findings.singleWhere(
        (WcagFinding item) => item.ruleId == 'wcag/text-contrast',
      );

      expect(finding.criterion, '1.4.3');
      expect(finding.message, contains('4.5:1'));
      expect(finding.source?.file, endsWith('flutter_wcag_audit_test.dart'));
    },
  );

  testWidgets('accepts high-contrast text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ColoredBox(
          color: Colors.white,
          child: Center(
            child: Text(
              'High contrast text',
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
        ),
      ),
    );

    final WcagAuditReport report = await tester.auditWcag(
      config: const WcagAuditConfig(checkTextScaling: false),
    );

    expect(
      report.findings.where(
        (WcagFinding item) => item.ruleId == 'wcag/text-contrast',
      ),
      isEmpty,
    );
  });

  testWidgets('reports layout overflow at 200 percent text size', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 170,
            child: Row(
              children: <Widget>[
                Text('Account preferences', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
    final double originalScale = tester.platformDispatcher.textScaleFactor;

    final WcagAuditReport report = await tester.auditWcag(
      config: const WcagAuditConfig(checkTextContrast: false),
    );

    expect(
      report.findings.map((WcagFinding item) => item.ruleId),
      contains('wcag/text-scale-overflow'),
    );
    expect(report.toTerminalString(), contains('200%'));
    expect(tester.platformDispatcher.textScaleFactor, originalScale);
  });

  test('writes accessible HTML and SARIF 2.1.0 reports', () async {
    final WcagAuditReport report = WcagAuditReport(
      standard: WcagStandard.wcag22AA,
      nodesInspected: 1,
      findings: const <WcagFinding>[
        WcagFinding(
          ruleId: 'wcag/accessible-control-name',
          criterion: '4.1.2',
          criterionName: 'Name, Role, Value',
          severity: WcagFindingSeverity.violation,
          message: 'Control <button> has no name.',
          impact: 'Its purpose is unavailable.',
          suggestion: 'Add a semantic label.',
          element: '<button>',
          source: SourceLocation(
            file: '/tmp/example.dart',
            line: 12,
            column: 3,
          ),
        ),
      ],
    );
    final Directory directory = await Directory.systemTemp.createTemp(
      'flutter_wcag_audit_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File htmlFile = File('${directory.path}/reports/audit.html');
    final File sarifFile = File('${directory.path}/reports/audit.sarif');

    await report.writeHtml(htmlFile.path);
    await report.writeSarif(sarifFile.path);

    final String html = await htmlFile.readAsString();
    final String sarif = await sarifFile.readAsString();
    expect(html, contains('<html lang="en">'));
    expect(html, contains('&lt;button&gt;'));
    expect(sarif, contains('"version": "2.1.0"'));
    expect(sarif, contains('wcag/accessible-control-name'));
    expect(sarif, contains('"startLine": 12'));
  });
}
