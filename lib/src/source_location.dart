import 'package:flutter/widgets.dart';
import 'package:flutter_wcag_audit/src/finding.dart';

/// Returns the closest user-authored creation location for [element].
SourceLocation? sourceLocationForElement(Element element) {
  SourceLocation? fallback;
  Element? current = element;

  while (current != null) {
    final SourceLocation? location = _creationLocation(current);
    fallback ??= location;
    if (location != null && debugIsWidgetLocalCreation(current.widget)) {
      return location;
    }
    Element? parent;
    current.visitAncestorElements((Element ancestor) {
      parent = ancestor;
      return false;
    });
    current = parent;
  }

  return fallback;
}

SourceLocation? _creationLocation(Element element) {
  SourceLocation? result;
  assert(() {
    // This package runs only inside Flutter's testing environment.
    // ignore: invalid_use_of_visible_for_testing_member
    final delegate = InspectorSerializationDelegate(
      service: WidgetInspectorService.instance,
    );
    final Map<String, Object?> json = element.toDiagnosticsNode().toJsonMap(
      delegate,
    );
    final Object? rawLocation = json['creationLocation'];
    if (rawLocation is! Map<Object?, Object?>) return true;

    final Object? rawFile = rawLocation['file'];
    final Object? rawLine = rawLocation['line'];
    final Object? rawColumn = rawLocation['column'];
    if (rawFile is! String || rawLine is! int || rawColumn is! int) return true;

    String file = rawFile;
    final Uri? uri = Uri.tryParse(rawFile);
    if (uri != null && uri.scheme == 'file') file = uri.toFilePath();
    result = SourceLocation(file: file, line: rawLine, column: rawColumn);
    return true;
  }());
  return result;
}
