/// The WCAG conformance profile used by an audit.
enum WcagStandard {
  /// WCAG 2.1 Level AA.
  wcag21AA,

  /// WCAG 2.2 Level AA.
  wcag22AA,
}

/// Configuration for a WCAG audit.
final class WcagAuditConfig {
  /// Creates an audit configuration.
  const WcagAuditConfig({
    this.standard = WcagStandard.wcag22AA,
    this.minimumTargetWidth = 24,
    this.minimumTargetHeight = 24,
    this.checkDuplicateNames = true,
    this.checkTextContrast = true,
    this.checkTextScaling = true,
    this.textScaleFactor = 2,
  });

  /// A stricter configuration using the common 44 by 44 mobile target size.
  const WcagAuditConfig.mobileRecommended({
    this.standard = WcagStandard.wcag22AA,
    this.minimumTargetWidth = 44,
    this.minimumTargetHeight = 44,
    this.checkDuplicateNames = true,
    this.checkTextContrast = true,
    this.checkTextScaling = true,
    this.textScaleFactor = 2,
  });

  /// The standard against which findings are described.
  final WcagStandard standard;

  /// Minimum logical-pixel width for an interactive target.
  final double minimumTargetWidth;

  /// Minimum logical-pixel height for an interactive target.
  final double minimumTargetHeight;

  /// Whether repeated interactive names should generate warnings.
  final bool checkDuplicateNames;

  /// Whether rendered text should be checked against WCAG contrast ratios.
  final bool checkTextContrast;

  /// Whether the rendered screen should be retested with enlarged text.
  final bool checkTextScaling;

  /// Text scale applied by the resize-text audit. WCAG testing commonly uses 2.
  final double textScaleFactor;
}
