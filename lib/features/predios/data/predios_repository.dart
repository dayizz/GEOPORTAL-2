import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'predios_firestore_repository.dart';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/api/api_client.dart';
import 'package:uuid/uuid.dart';

import '../../../core/google_sheets/google_sheets_service.dart';
import '../models/predio.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final prediosRepositoryProvider = Provider<PrediosFirestoreRepository>((ref) {
  return PrediosFirestoreRepository();
});
