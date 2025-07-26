// lib/services/sheet_data_service.dart (Assuming it's in a services folder)
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
      [sheets.SheetsApi.spreadsheetsScope],
      baseClient: http.Client(),
    );

    _sheetsApi = sheets.SheetsApi(client);
    spreadsheetId = _extractSpreadsheetIdFromUrl(spreadsheetUrl);
  }

  /// Extract spreadsheet ID from URL
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

  /// Retrieve raw sheet data for a given sheet name.
  /// The `range` parameter for `get` can be the sheet name alone to get all data.
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
        } else if (j < headers.length) {
          columns[headers[j]]?.add('');
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
    final range = '$sheetName!A:A';
    final valueRange = sheets.ValueRange.fromJson({
      'values': [values],
    });

    try {
      await _sheetsApi.spreadsheets.values.append(
        valueRange,
        spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      );
      AppLogger.info('Successfully appended row to $sheetName');
    } catch (e, s) {
      AppLogger.error('Failed to append row to $sheetName: $e', e, s);
      rethrow;
    }
  }

  /// Updates specific cells in a given row by their column letter.
  /// This prevents overwriting formulas in other columns.
  /// [sheetName]: The name of the sheet (e.g., 'Main List').
  /// [rowIndex]: The 1-based index of the row to update.
  /// [updates]: A Map where keys are column letters (e.g., 'K', 'L') and values are the new content.
  Future<void> updateCells(
    String sheetName,
    int rowIndex,
    Map<String, Object> updates,
  ) async {
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

    try {
      await _sheetsApi.spreadsheets.values.batchUpdate(
        sheets.BatchUpdateValuesRequest(
          data: valueRanges,
          valueInputOption: 'USER_ENTERED',
        ),
        spreadsheetId,
      );
      AppLogger.info('Successfully updated cells: ${updates.keys.join(', ')} in row $rowIndex');
    } catch (e, s) {
      AppLogger.error('Failed to update cells: $e', e, s);
      rethrow;
    }
  }

  /// --- NEW METHOD: Deletes rows from a specific sheet ---
  /// [sheetName]: The name of the sheet.
  /// [rowIndicesToDelete]: A list of 1-based sheet row indices to delete.
  /// IMPORTANT: Deleting multiple rows can shift indices. It's often safer
  /// to delete one by one in reverse order, or re-fetch data after a batch delete.
  /// This implementation sorts indices in reverse to handle contiguous deletions
  /// more safely within one batch request.
  Future<void> deleteRows(String sheetName, List<int> rowIndicesToDelete) async {
    if (rowIndicesToDelete.isEmpty) return;

    // Sort in reverse order to delete rows from the bottom up,
    // which prevents indices from shifting unexpectedly during a batch delete.
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
                startIndex: rowIndex - 1, // Google Sheets API uses 0-based index, exclusive end
                endIndex: rowIndex,       // So, for row N (1-based), it's startIndex N-1, endIndex N
              ),
            ),
          ),
        );
      }

      await _sheetsApi.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: requests),
        spreadsheetId,
      );
      AppLogger.info('Successfully deleted rows: $rowIndicesToDelete from $sheetName');
    } catch (e, s) {
      AppLogger.error('Failed to delete rows from $sheetName: $e', e, s);
      rethrow;
    }
  }

  /// --- NEW HELPER: Gets the Sheet ID from its name ---
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