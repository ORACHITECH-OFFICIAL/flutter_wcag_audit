import 'package:flutter_wcag_audit/src/report_writer_stub.dart'
    if (dart.library.io) 'package:flutter_wcag_audit/src/report_writer_io.dart'
    as implementation;

Future<void> writeReportFile(String path, String contents) =>
    implementation.writeReportFile(path, contents);
