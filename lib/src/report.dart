import 'dart:convert';

import 'package:flutter_wcag_audit/src/config.dart';
import 'package:flutter_wcag_audit/src/finding.dart';
import 'package:flutter_wcag_audit/src/report_writer.dart';

/// Complete result of auditing one rendered application state.
final class WcagAuditReport {
  const WcagAuditReport({
    required this.standard,
    required this.findings,
    required this.nodesInspected,
  });

  final WcagStandard standard;
  final List<WcagFinding> findings;
  final int nodesInspected;

  Iterable<WcagFinding> get violations => findings.where(
    (WcagFinding finding) => finding.severity == WcagFindingSeverity.violation,
  );

  Iterable<WcagFinding> get warnings => findings.where(
    (WcagFinding finding) => finding.severity == WcagFindingSeverity.warning,
  );

  bool get passes => violations.isEmpty;

  Map<String, Object> toJson() => <String, Object>{
    'standard': standard.name,
    'passes': passes,
    'nodesInspected': nodesInspected,
    'summary': <String, int>{
      'violations': violations.length,
      'warnings': warnings.length,
    },
    'findings': findings
        .map((WcagFinding finding) => finding.toJson())
        .toList(),
  };

  String toJsonString({bool pretty = true}) =>
      (pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder())
          .convert(toJson());

  /// Produces a standalone, accessible HTML report.
  String toHtmlString() {
    final String rows = findings
        .map((WcagFinding finding) {
          final String source = finding.source?.toString() ?? 'Unavailable';
          return '''
<article class="finding ${finding.severity.name}">
  <h2>${_html(finding.severity.name.toUpperCase())}: WCAG ${_html(finding.criterion)} — ${_html(finding.criterionName)}</h2>
  <dl>
    <dt>Rule</dt><dd><code>${_html(finding.ruleId)}</code></dd>
    <dt>Element</dt><dd>${_html(finding.element)}</dd>
    <dt>Source</dt><dd><code>${_html(source)}</code></dd>
    <dt>Problem</dt><dd>${_html(finding.message)}</dd>
    <dt>Impact</dt><dd>${_html(finding.impact)}</dd>
    <dt>Suggested fix</dt><dd>${_html(finding.suggestion)}</dd>
  </dl>
</article>''';
        })
        .join('\n');
    final String status = passes ? 'Passed' : 'Failed';
    return '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Flutter WCAG audit — $status</title>
  <style>
    :root { color-scheme: light dark; font-family: system-ui, sans-serif; }
    body { max-width: 72rem; margin: 0 auto; padding: 2rem; line-height: 1.5; }
    .summary, .finding { border: 1px solid #7778; border-radius: .6rem; padding: 1rem 1.25rem; margin: 1rem 0; }
    .violation { border-left: .45rem solid #c62828; }
    .warning { border-left: .45rem solid #ef6c00; }
    .manualCheck { border-left: .45rem solid #1565c0; }
    h1, h2 { line-height: 1.2; }
    h2 { font-size: 1.1rem; }
    dt { font-weight: 700; margin-top: .65rem; }
    dd { margin-left: 0; }
    code { overflow-wrap: anywhere; }
  </style>
</head>
<body>
  <main>
    <h1>Flutter WCAG audit: $status</h1>
    <section class="summary" aria-label="Audit summary">
      <p><strong>${violations.length}</strong> violations, <strong>${warnings.length}</strong> warnings.</p>
      <p>${_html(standard.name)} · $nodesInspected semantics nodes inspected.</p>
    </section>
    ${rows.isEmpty ? '<p>No automated violations or warnings were found.</p>' : rows}
  </main>
</body>
</html>''';
  }

  /// Produces a SARIF 2.1.0 report suitable for GitHub code scanning.
  Map<String, Object> toSarif() {
    final Map<String, WcagFinding> uniqueRules = <String, WcagFinding>{
      for (final WcagFinding finding in findings) finding.ruleId: finding,
    };
    return <String, Object>{
      r'$schema': 'https://json.schemastore.org/sarif-2.1.0.json',
      'version': '2.1.0',
      'runs': <Object>[
        <String, Object>{
          'tool': <String, Object>{
            'driver': <String, Object>{
              'name': 'flutter_wcag_audit',
              'informationUri':
                  'https://www.w3.org/WAI/standards-guidelines/wcag/',
              'rules': uniqueRules.values.map(_sarifRule).toList(),
            },
          },
          'results': findings.map(_sarifResult).toList(),
        },
      ],
    };
  }

  /// Encodes [toSarif] as JSON.
  String toSarifString({bool pretty = true}) =>
      (pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder())
          .convert(toSarif());

  /// Writes a standalone HTML report. File writing is available on VM tests.
  Future<void> writeHtml(String path) => writeReportFile(path, toHtmlString());

  /// Writes a SARIF report. File writing is available on VM tests.
  Future<void> writeSarif(String path) =>
      writeReportFile(path, toSarifString());

  String toTerminalString() {
    if (findings.isEmpty) {
      return '✓ WCAG audit passed — $nodesInspected semantics nodes inspected.';
    }
    final StringBuffer output = StringBuffer()
      ..writeln(
        passes ? '⚠ WCAG audit passed with warnings' : '✗ WCAG audit failed',
      )
      ..writeln(
        '${violations.length} violation(s), ${warnings.length} warning(s)',
      )
      ..writeln();
    for (final WcagFinding finding in findings) {
      output
        ..writeln(
          '${_severityLabel(finding.severity)}  WCAG ${finding.criterion} — ${finding.criterionName}',
        )
        ..writeln('Rule: ${finding.ruleId}')
        ..writeln('Element: ${finding.element}')
        ..write(finding.source == null ? '' : 'Source: ${finding.source}\n')
        ..writeln('Problem: ${finding.message}')
        ..writeln('Impact: ${finding.impact}')
        ..writeln('Suggested fix: ${finding.suggestion}')
        ..writeln();
    }
    return output.toString().trimRight();
  }

  static String _severityLabel(WcagFindingSeverity severity) =>
      switch (severity) {
        WcagFindingSeverity.violation => 'ERROR',
        WcagFindingSeverity.warning => 'WARNING',
        WcagFindingSeverity.manualCheck => 'MANUAL',
      };

  static String _html(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  static Map<String, Object> _sarifRule(WcagFinding finding) =>
      <String, Object>{
        'id': finding.ruleId,
        'shortDescription': <String, String>{
          'text': 'WCAG ${finding.criterion} — ${finding.criterionName}',
        },
        'helpUri': _understandingUrl(finding.criterion),
      };

  static Map<String, Object> _sarifResult(WcagFinding finding) =>
      <String, Object>{
        'ruleId': finding.ruleId,
        'level': switch (finding.severity) {
          WcagFindingSeverity.violation => 'error',
          WcagFindingSeverity.warning => 'warning',
          WcagFindingSeverity.manualCheck => 'note',
        },
        'message': <String, String>{'text': finding.message},
        if (finding.source case final SourceLocation source)
          'locations': <Object>[
            <String, Object>{
              'physicalLocation': <String, Object>{
                'artifactLocation': <String, String>{
                  'uri': Uri.file(source.file).toString(),
                },
                'region': <String, int>{
                  'startLine': source.line,
                  'startColumn': source.column,
                },
              },
            },
          ],
      };

  static String _understandingUrl(String criterion) {
    final String slug = switch (criterion) {
      '1.4.3' => 'contrast-minimum',
      '1.4.4' => 'resize-text',
      '2.4.6' => 'headings-and-labels',
      '2.5.5' => 'target-size-enhanced',
      '2.5.8' => 'target-size-minimum',
      '3.3.2' => 'labels-or-instructions',
      '4.1.2' => 'name-role-value',
      _ => '',
    };
    return slug.isEmpty
        ? 'https://www.w3.org/WAI/WCAG22/quickref/'
        : 'https://www.w3.org/WAI/WCAG22/Understanding/$slug.html';
  }

  @override
  String toString() => toTerminalString();
}
