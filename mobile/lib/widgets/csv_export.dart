/// Handing the user a CSV file, on whichever platform this build is running.
///
/// There is no file-picker or share plugin in this project, and the app ships
/// as a Flutter web build (see mobile/vercel.json), so the web implementation
/// is the one that matters: it makes a Blob and clicks an anchor, which is a
/// real browser download. The stub keeps Android/Windows builds compiling and
/// falls back to the clipboard, which is the best a plugin-free build can do
/// there - [exportCsv] reports which of the two happened so the caller can
/// tell the user the truth rather than always claiming "downloaded".
library;

export 'csv_export_stub.dart' if (dart.library.js_interop) 'csv_export_web.dart';

/// What [exportCsv] actually managed to do.
enum CsvExportResult {
  /// The browser was handed a file and started a download.
  downloaded,

  /// No download path on this platform; the CSV text is on the clipboard.
  copiedToClipboard,
}

/// Escapes one CSV field: doubles any quote and wraps the value whenever it
/// contains a comma, a quote or a newline. Client names carry commas often
/// enough ("Sharma, A.") that skipping this silently shifts every later
/// column in the row.
String csvField(Object? value) {
  final text = value?.toString() ?? '';
  if (!text.contains(RegExp(r'[",\n\r]'))) return text;
  return '"${text.replaceAll('"', '""')}"';
}

/// Joins rows into a CSV document. \r\n because Excel on Windows is the most
/// likely thing to open this, and it is the ending every other consumer also
/// accepts.
String toCsv(List<List<Object?>> rows) =>
    rows.map((r) => r.map(csvField).join(',')).join('\r\n');
