import 'dart:io';

import 'package:share_plus/share_plus.dart';

import 'csv_export.dart' show CsvExportResult;

/// Android (and other app builds): writes the CSV to a file and opens the
/// phone's share sheet, so it can be saved to Files or Drive, or sent on
/// WhatsApp or email. The web build downloads it instead.
///
/// Directory.systemTemp is the app's own cache folder on Android (Flutter
/// points TMPDIR there), so no path_provider is needed.
Future<CsvExportResult> exportCsv(String filename, String csv) async {
  final file = File('${Directory.systemTemp.path}/$filename');
  await file.writeAsString(csv);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'text/csv')],
    subject: filename,
  ));
  return CsvExportResult.shared;
}
