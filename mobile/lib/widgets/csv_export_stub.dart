import 'package:flutter/services.dart';

import 'csv_export.dart' show CsvExportResult;

/// Non-web fallback. Nothing in this project can write to the device
/// filesystem or open a share sheet (no path_provider, no share_plus), so the
/// honest thing is to put the CSV on the clipboard and say so, rather than
/// pretending a file was saved.
Future<CsvExportResult> exportCsv(String filename, String csv) async {
  await Clipboard.setData(ClipboardData(text: csv));
  return CsvExportResult.copiedToClipboard;
}
