import 'dart:io';
import 'dart:convert';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';

class SheetDataService {
  final String spreadsheetUrl;
  late final String spreadsheetId;
  late final SheetsApi _sheetsApi;
  Spreadsheet? _spreadsheet;

  SheetDataService({required this.spreadsheetUrl});

  /// Initialize from a local file path (Desktop use)
  Future<void> initializeFromFile(String pathToJson) async {
    final jsonString = await File(pathToJson).readAsString();
    await initializeFromJson(jsonString);
  }

  /// Initialize from embedded asset (Mobile/Web use)
  Future<void> initializeFromJson(String jsonString) async {
    final jsonData = json.decode(jsonString);
    final credentials = ServiceAccountCredentials.fromJson(jsonData);

    final client = await clientViaServiceAccount(
      credentials,
      [SheetsApi.spreadsheetsScope], // Use full access for write support
    );

    _sheetsApi = SheetsApi(client);
    spreadsheetId = _extractSpreadsheetIdFromUrl(spreadsheetUrl);

    // Load spreadsheet metadata
    _spreadsheet = await _sheetsApi.spreadsheets.get(spreadsheetId);
  }

  /// Extract spreadsheet ID from URL
  String _extractSpreadsheetIdFromUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    if (segments.contains('d') && segments.length > segments.indexOf('d') + 1) {
      return segments[segments.indexOf('d') + 1];
    } else {
      throw Exception('Spreadsheet ID could not be extracted.');
    }
  }

  /// Retrieve raw sheet data
  Future<List<List<Object?>>?> getSheetData(String sheetName) async {
    final response = await _sheetsApi.spreadsheets.values.get(
      spreadsheetId,
      sheetName,
    );
    return response.values;
  }

  /// Convert sheet into a column map using header names
  Future<Map<String, List<String>>> extractColumns(List<List<Object?>> data) async {
    if (data.length < 2) return {};

    final headers = data[1].map((e) => e.toString()).toList();
    final Map<String, List<String>> columns = {
      for (var header in headers) header: []
    };

    for (var i = 2; i < data.length; i++) {
      final row = data[i];
      for (var j = 0; j < headers.length; j++) {
        if (j < row.length && row[j] != null && row[j].toString().isNotEmpty) {
          columns[headers[j]]?.add(row[j].toString());
        }
      }
    }

    return columns;
  }

  /// Group rows by first column value (e.g., by service category)
  Future<Map<String, List<List<Object?>>>> groupByService(List<List<Object?>> data) async {
    final Map<String, List<List<Object?>>> services = {};
    String? currentService;

    for (var i = 2; i < data.length; i++) {
      final row = data[i];
      if (row.isEmpty) continue;

      if (row[0] != null && row[0].toString().trim().isNotEmpty) {
        currentService = row[0].toString();
      }

      if (currentService != null) {
        services.putIfAbsent(currentService, () => []).add(row);
      }
    }

    return services;
  }

  /// Append a row to a specific sheet tab (e.g., Newsletter)
  Future<void> appendRow(String sheetName, List<String> values) async {
    final range = '$sheetName!A:A'; // Appends to the first available row
    final valueRange = ValueRange.fromJson({
      'values': [values],
    });

    await _sheetsApi.spreadsheets.values.append(
      valueRange,
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }
}
