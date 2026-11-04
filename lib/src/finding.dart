/// How confidently the audit can classify an accessibility issue.
enum WcagFindingSeverity {
  /// A machine-detectable failure that should normally fail CI.
  violation,

  /// A suspicious pattern that needs developer review.
  warning,

  /// A check requiring human judgment.
  manualCheck,
}

/// Best-effort source position associated with a rendered Flutter element.
final class SourceLocation {
  /// Creates a source location.
  const SourceLocation({
    required this.file,
    required this.line,
    required this.column,
  });

  /// Absolute source file path when Flutter provides one.
  final String file;

  /// One-based line number.
  final int line;

  /// One-based column number.
  final int column;

  /// Serializes the location.
  Map<String, Object> toJson() => <String, Object>{
    'file': file,
    'line': line,
    'column': column,
  };

  @override
  String toString() => '$file:$line:$column';
}

/// A single accessibility audit result.
final class WcagFinding {
  /// Creates a finding.
  const WcagFinding({
    required this.ruleId,
    required this.criterion,
    required this.criterionName,
    required this.severity,
    required this.message,
    required this.impact,
    required this.suggestion,
    required this.element,
    this.source,
  });

  /// Stable identifier suitable for configuration and baselines.
  final String ruleId;

  /// WCAG success criterion, such as `4.1.2`.
  final String criterion;

  /// Human-readable success criterion name.
  final String criterionName;

  /// Classification of this finding.
  final WcagFindingSeverity severity;

  /// Concise description of the detected condition.
  final String message;

  /// Why the issue affects users.
  final String impact;

  /// A concrete direction for repairing the issue.
  final String suggestion;

  /// Best available description of the affected semantics node.
  final String element;

  /// Best-effort location of the widget that produced the finding.
  final SourceLocation? source;

  /// Serializes this finding for machine-readable reports.
  Map<String, Object> toJson() => <String, Object>{
    'ruleId': ruleId,
    'criterion': criterion,
    'criterionName': criterionName,
    'severity': severity.name,
    'message': message,
    'impact': impact,
    'suggestion': suggestion,
    'element': element,
    if (source != null) 'source': source!.toJson(),
  };
}
