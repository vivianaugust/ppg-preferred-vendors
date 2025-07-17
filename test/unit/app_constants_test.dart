// test/unit/app_constants_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ppg_preferred_vendors/utils/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('All constants are defined and accessible', () {
      expect(AppConstants.googleSheetUrl, isA<String>());
      expect(AppConstants.googleSheetUrl, isNotEmpty);

      expect(AppConstants.googleSheetJsonAssetPath, isA<String>());
      expect(AppConstants.googleSheetJsonAssetPath, isNotEmpty);

      expect(AppConstants.mainSheetName, isA<String>());
      expect(AppConstants.mainSheetName, isNotEmpty);

      expect(AppConstants.usersCollection, isA<String>());
      expect(AppConstants.usersCollection, isNotEmpty);

      expect(AppConstants.savedVendorsSubcollection, isA<String>());
      expect(AppConstants.savedVendorsSubcollection, isNotEmpty);
    });
  });
}