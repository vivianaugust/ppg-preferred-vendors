// lib/utils/app_constants.dart
class AppConstants {
  static const String googleSheetUrl = 'https://docs.google.com/sheets/d/1ECu-mlgF7D-3prakOfytBeGUTg3w4PsTwc-qwCuwvos/edit#gid=493049';
  static const String googleSheetJsonAssetPath = 'assets/ppg-vendors-d80304679d8f.json';
  static const String mainSheetName = 'Main List';

  // Define the 0-based index where your actual data rows start in the Google Sheet's retrieved data.
  // If your sheet has 2 header rows (e.g., row 1 and row 2 are headers),
  // then your data starts at sheet row 3, which is index 2 in a 0-indexed list.
  static const int dataRowStartIndex = 2; // Assuming data starts at sheet row 3 (after 2 header rows)

  static const String usersCollection = 'users';
  static const String savedVendorsSubcollection = 'saved_vendors';
}