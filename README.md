# Flutter WCAG Audit — Accessibility Testing for Android, iOS and Web

`flutter_wcag_audit` is an automated Flutter accessibility checker for WCAG
2.1 and WCAG 2.2. It audits rendered widget tests for semantic labels, touch
target sizes, text contrast, and 200% text resizing, then produces actionable
terminal, JSON, HTML, and SARIF reports for CI.

Use the same Flutter WCAG audit API for Android, iOS, web, and desktop widget
tests. Findings include the WCAG success criterion, user impact, suggested
Flutter fix, and a best-effort Dart source location.

> This package is an audit assistant, not a compliance certificate. Automated
> checks cannot determine complete WCAG conformance; manual evaluation and
> testing with assistive technologies are still required.

## Current checks

- Interactive controls have accessible names — WCAG 4.1.2.
- Text fields have accessible labels — WCAG 3.3.2.
- Interactive targets meet the configured minimum size — WCAG 2.5.8 for the
  default WCAG 2.2 AA profile.
- Repeated interactive names are surfaced as review warnings — WCAG 2.4.6.
- Rendered text meets normal and large-text contrast ratios — WCAG 1.4.3.
- Layouts remain usable at 200% text size — WCAG 1.4.4.
- Findings include a best-effort `file:line:column` source location in debug
  tests.

## Usage

Add the package as a development dependency:

```yaml
dev_dependencies:
  flutter_wcag_audit: ^0.1.0
```

Audit the currently rendered state in a widget test:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wcag_audit/flutter_wcag_audit.dart';
import 'package:my_app/main.dart';

void main() {
  testWidgets('checkout is accessible', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();

    final report = await tester.auditWcag();

    expect(report, hasNoWcagViolations);
  });
}
```

When a violation is found, the matcher prints the WCAG criterion, affected
semantics element, user impact, and a suggested repair.

### Stronger mobile target sizing

The WCAG 2.2 AA default is 24 by 24 logical pixels. Use the stronger mobile
recommendation when desired:

```dart
final report = await tester.auditWcag(
  config: const WcagAuditConfig.mobileRecommended(),
);
```

### JSON output

```dart
final json = report.toJsonString();
```

### HTML and SARIF reports

Write a standalone HTML report for people and a SARIF 2.1.0 report for GitHub
code scanning:

```dart
await report.writeHtml('build/wcag/audit.html');
await report.writeSarif('build/wcag/audit.sarif');
```

The parent directories are created automatically. File writing is supported
by VM-based Flutter tests; browser tests can use `toHtmlString()` and
`toSarifString()` and send the result to their own storage layer.

### Audit configuration

```dart
final report = await tester.auditWcag(
  config: const WcagAuditConfig(
    checkTextContrast: true,
    checkTextScaling: true,
    textScaleFactor: 2,
  ),
);
```

The text-scaling audit restores the original platform scale before returning.

## Scope

An audit checks only the application state currently rendered by the test.
Create tests for important routes and states such as validation errors, open
dialogs, empty data, loaded data, and expanded menus.

The initial development release uses Flutter's semantics, render, and layer
trees. Focus traversal, non-text contrast, baseline management, and a debug
overlay are planned next.

