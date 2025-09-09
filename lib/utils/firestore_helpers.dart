// lib/utils/firestore_helpers.dart

/// Normalizes a string for consistent search and Firestore IDs.
/// Converts to lowercase, removes non-alphanumeric (except space), trims, and replaces spaces with underscores.
String normalizeString(String input) {
  return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]+'), '').trim().replaceAll(' ', '_');
}