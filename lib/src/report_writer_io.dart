import 'dart:io';

Future<void> writeReportFile(String path, String contents) async {
  final File file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}
