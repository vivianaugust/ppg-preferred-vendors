// lib/test/widget/sheet_data_service_test.dart
import 'dart:io';
import 'dart:convert';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:ppg_preferred_vendors/utils/logger.dart';
import 'package:flutter/foundation.dart'; // Add this import for @visibleForTesting

class SheetDataService {
  final String spreadsheetUrl;
  @visibleForTesting // This is correct for public member `spreadsheetId`
  late String spreadsheetId;
  // REMOVED @visibleForTesting from _sheetsApi as it's private
  late sheets.SheetsApi _sheetsApi;

  // Added optional named parameters for testing purposes
  SheetDataService({
    required this.spreadsheetUrl,
    @visibleForTesting sheets.SheetsApi? sheetsApi, // Allow injecting mock SheetsApi
    @visibleForTesting String? testSpreadsheetId, // Allow injecting test spreadsheet ID
  }) {
    if (sheetsApi != null) {
      _sheetsApi = sheetsApi;
    }
    if (testSpreadsheetId != null) {
      spreadsheetId = testSpreadsheetId;
    }
  }

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

  // REMOVED @visibleForTesting from _extractSpreadsheetIdFromUrl as it's private
  String _extractSpreadsheetIdFromUrl(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    // Expecting URL format like: /sheets/d/SPREADSHEET_ID/edit
    if (pathSegments.length >= 3 && pathSegments[0] == 'sheets' && pathSegments[1] == 'd') {
      return pathSegments[2];
    }
    throw Exception('Invalid Google Sheet URL format: $url');
  }

  // --- The rest of your methods remain unchanged ---

  Future<List<List<Object?>>?> getSheetData(String sheetName) async {
    try {
      final response = await _sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        sheetName,
      );
      return response.values;
    } catch (e, s) {
      AppLogger.error('Failed to get sheet data from $sheetName', e, s);
      return null;
    }
  }

  Future<Map<String, List<Object?>>> extractColumns(List<List<Object?>> data) async {
    if (data.length < 2) return {}; // Need at least 2 rows for headers and data

    final Map<String, List<Object?>> columns = {};
    final List<Object?> headers = data[1]; // Assuming headers are in the second row

    for (int colIndex = 0; colIndex < headers.length; colIndex++) {
      final header = headers[colIndex]?.toString().trim();
      if (header != null && header.isNotEmpty) {
        columns[header] = [];
        for (int rowIndex = 2; rowIndex < data.length; rowIndex++) {
          // Start from the third row for data
          if (data[rowIndex].length > colIndex) {
            columns[header]?.add(data[rowIndex][colIndex]);
          } else {
            columns[header]?.add(''); // Add empty string if data is missing for this column
          }
        }
      }
    }
    return columns;
  }

  Future<Map<String, List<List<Object?>>>> groupByService(List<List<Object?>> data) async {
    if (data.length < 2) return {};

    final Map<String, List<List<Object?>>> groupedData = {};
    final List<Object?> headers = data[1]; // Assuming headers are in the second row
    final int serviceColumnIndex = headers.indexOf('Service'); // Find the index of the 'Service' column

    if (serviceColumnIndex == -1) {
      AppLogger.error('Service column not found in sheet headers.');
      return {};
    }

    for (int rowIndex = 2; rowIndex < data.length; rowIndex++) {
      final row = data[rowIndex];
      if (row.length > serviceColumnIndex) {
        final serviceName = row[serviceColumnIndex]?.toString().trim();
        if (serviceName != null && serviceName.isNotEmpty) {
          groupedData.putIfAbsent(serviceName, () => []).add(row);
        }
      }
    }
    return groupedData;
  }

  Future<void> appendRow(String sheetName, List<Object?> values) async {
    final valueRange = sheets.ValueRange(values: [values]);
    try {
      await _sheetsApi.spreadsheets.values.append(
        valueRange,
        spreadsheetId,
        '$sheetName!A:A', // Append to the first column, new row
        valueInputOption: 'USER_ENTERED',
      );
      AppLogger.info('Successfully appended row to $sheetName');
    } catch (e, s) {
      AppLogger.error('Failed to append row to $sheetName', e, s);
      rethrow; // Re-throw to indicate failure
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
      AppLogger.error('Failed to update cells: ${updates.keys.join(', ')} in row $rowIndex', e, s);
      rethrow;
    }
  }
}