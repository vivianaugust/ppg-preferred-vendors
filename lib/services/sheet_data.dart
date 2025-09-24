// lib/services/sheet_data_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:ppg_preferred_vendors/utils/logger.dart';

class SheetDataService {
  final String spreadsheetUrl;
  late final String spreadsheetId;
  late final sheets.SheetsApi _sheetsApi;

  SheetDataService({required this.spreadsheetUrl});

  Future<void> initializeFromFile(String pathToJson) async {
    final jsonString = await File(pathToJson).readAsString();
    await initializeFromJson(jsonString);
  }

  Future<void> initializeFromJson(String jsonString) async {
    try {
      final jsonData = json.decode(jsonString);
      final credentials = ServiceAccountCredentials.fromJson(jsonData);
      final client = await clientViaServiceAccount(
        credentials,
        [sheets.SheetsApi.spreadsheetsScope],
        baseClient: http.Client(),
      );
      _sheetsApi = sheets.SheetsApi(client);
      spreadsheetId = _extractSpreadsheetIdFromUrl(spreadsheetUrl);
    } catch (e, s) {
      AppLogger.fatal('Failed to initialize SheetDataService from JSON: $e', e, s);
      rethrow;
    }
  }

  String _extractSpreadsheetIdFromUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    if (segments.contains('d') && segments.length > segments.indexOf('d') + 1) {
      return segments[segments.indexOf('d') + 1];
    } else {
      AppLogger.error('Spreadsheet ID could not be extracted from URL: $url');
      throw Exception('Spreadsheet ID could not be extracted.');
    }
  }

  Future<List<List<Object?>>?> getSheetData(String sheetName) async {
    try {
      final response = await _sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        sheetName,
      );
      return response.values;
    } catch (e, s) {
      AppLogger.error('Error getting sheet data for $sheetName: $e', e, s);
      return null;
    }
  }

  Future<Map<String, List<String>>> extractColumns(List<List<Object?>> data) async {
    // This is a data-transformation method. No external calls or user interactions, so no logging is needed.
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
        } else if (j < headers.length) {
          columns[headers[j]]?.add('');
        }
      }
    }
    return columns;
  }

  Future<Map<String, List<List<Object?>>>> groupByService(List<List<Object?>> data) async {
    // This is a data-transformation method. No external calls or user interactions, so no logging is needed.
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

  Future<void> appendRow(String sheetName, List<String> values) async {
    try {
      final range = '$sheetName!A:A';
      final valueRange = sheets.ValueRange.fromJson({
        'values': [values],
      });
      await _sheetsApi.spreadsheets.values.append(
        valueRange,
        spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      );
    } catch (e, s) {
      AppLogger.error('Failed to append row to $sheetName: $e', e, s);
      rethrow;
    }
  }

  Future<void> updateCells(
    String sheetName,
    int rowIndex,
    Map<String, Object> updates,
  ) async {
    try {
      final List<sheets.ValueRange> valueRanges = [];
      updates.forEach((columnLetter, value) {
        final String range = '$sheetName!$columnLetter$rowIndex';
        valueRanges.add(
          sheets.ValueRange(
            range: range,
            values: [[value]],
          ),
        );
      });
      await _sheetsApi.spreadsheets.values.batchUpdate(
        sheets.BatchUpdateValuesRequest(
          data: valueRanges,
          valueInputOption: 'USER_ENTERED',
        ),
        spreadsheetId,
      );
    } catch (e, s) {
      AppLogger.error('Failed to update cells in row $rowIndex of $sheetName: $e', e, s);
      rethrow;
    }
  }

  Future<void> deleteRows(String sheetName, List<int> rowIndicesToDelete) async {
    if (rowIndicesToDelete.isEmpty) return;
    rowIndicesToDelete.sort((a, b) => b.compareTo(a));
    try {
      final List<sheets.Request> requests = [];
      final int? sheetId = await _getSheetId(sheetName);
      if (sheetId == null) {
        throw Exception('Sheet ID not found for sheetName: $sheetName');
      }
      for (int rowIndex in rowIndicesToDelete) {
        requests.add(
          sheets.Request(
            deleteDimension: sheets.DeleteDimensionRequest(
              range: sheets.DimensionRange(
                sheetId: sheetId,
                dimension: 'ROWS',
                startIndex: rowIndex - 1,
                endIndex: rowIndex,
              ),
            ),
          ),
        );
      }
      await _sheetsApi.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: requests),
        spreadsheetId,
      );
    } catch (e, s) {
      AppLogger.error('Failed to delete rows from $sheetName: $e', e, s);
      rethrow;
    }
  }

  Future<int?> _getSheetId(String sheetName) async {
    try {
      final spreadsheet = await _sheetsApi.spreadsheets.get(spreadsheetId);
      return spreadsheet.sheets
          ?.firstWhere(
            (sheet) => sheet.properties?.title == sheetName,
            orElse: () => throw Exception('Sheet "$sheetName" not found.'),
          )
          .properties
          ?.sheetId;
    } catch (e, s) {
      AppLogger.error('Error getting sheet ID for $sheetName: $e', e, s);
      return null;
    }
  }
}