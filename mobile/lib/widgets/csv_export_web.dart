import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'csv_export.dart' show CsvExportResult;

/// Browser download: wrap the CSV in a Blob, point a hidden anchor at an
/// object URL for it, and click it. The object URL is revoked straight after
/// - it pins the whole blob in memory until it is, and an owner exporting a
/// few times a day would otherwise leak a copy per export for the life of
/// the tab.
Future<CsvExportResult> exportCsv(String filename, String csv) async {
  // The BOM is what makes Excel read the file as UTF-8 rather than the local
  // ANSI codepage - without it a rupee sign or a non-Latin client name comes
  // out as mojibake in the one program most likely to open this.
  final blob = web.Blob(
    <JSAny>['﻿$csv'.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return CsvExportResult.downloaded;
}
