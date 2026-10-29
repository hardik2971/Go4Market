import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser download of [content].
void downloadText(String fileName, String content, {String mime = 'text/csv;charset=utf-8'}) {
  // BOM so Excel opens UTF-8 (₹) correctly.
  final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(content)]);
  downloadBytes(fileName, bytes, mime: mime);
}

void downloadBytes(String fileName, Uint8List bytes, {String mime = 'application/octet-stream'}) {
  final blob = web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(a);
  a.click();
  a.remove();
  Timer(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url));
}

/// Opens a standalone HTML document in a new tab and calls print() once loaded.
void printHtml(String html) {
  final doc = html.contains('</body>')
      ? html.replaceFirst('</body>', '<script>window.onload=function(){setTimeout(function(){window.print()},300)}</script></body>')
      : html;
  final blob = web.Blob(<JSAny>[doc.toJS].toJS, web.BlobPropertyBag(type: 'text/html'));
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}

void openUrl(String url) => web.window.open(url, '_blank');

void setDocumentTitle(String title) => web.document.title = title;

/// Browser geolocation; completes with (lat, lng) or throws a String.
Future<(double, double)> currentPosition() {
  final c = Completer<(double, double)>();
  final geo = web.window.navigator.geolocation;
  geo.getCurrentPosition(
    ((web.GeolocationPosition p) {
      if (!c.isCompleted) c.complete((p.coords.latitude.toDouble(), p.coords.longitude.toDouble()));
    }).toJS,
    ((web.GeolocationPositionError e) {
      if (!c.isCompleted) c.completeError(e.message);
    }).toJS,
    web.PositionOptions(enableHighAccuracy: true, timeout: 15000, maximumAge: 10000),
  );
  return c.future;
}

String csvEscape(Object? v) {
  final s = v == null ? '' : '$v';
  if (s.contains(RegExp(r'[",\n\r]'))) return '"${s.replaceAll('"', '""')}"';
  return s;
}

String toCsv(List<String> header, List<List<Object?>> rows) =>
    [header.map(csvEscape).join(','), ...rows.map((r) => r.map(csvEscape).join(','))].join('\r\n');

/// Minimal CSV parser (RFC4180-ish, handles quotes and embedded commas/newlines).
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      if (row.any((c) => c.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  row.add(cell.toString());
  if (row.any((c) => c.isNotEmpty)) rows.add(row);
  if (rows.isNotEmpty && rows.first.isNotEmpty && rows.first.first.startsWith('﻿')) {
    rows.first[0] = rows.first.first.substring(1);
  }
  return rows;
}
