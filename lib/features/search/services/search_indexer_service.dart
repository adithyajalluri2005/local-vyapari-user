import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [SearchIndexerService]
///
/// @deprecated Client-side database sync of the entire database collection to Firestore
/// is deprecated to ensure secure database writes, minimize API quota consumption, and
/// prevent concurrency issues.
///
/// Production indexes must be managed via backend Firebase Cloud Functions onRTDBUpdate triggers.
@Deprecated('Cloud Function handles indexing. Do not call client-side.')
class SearchIndexerService {
  Future<void> syncShopsToFirestore() async {
    // Deprecated: Disabling sync to enforce backend-driven indexing
    return;
  }
}

final searchIndexerServiceProvider = Provider((ref) => SearchIndexerService());
