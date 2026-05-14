import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final estructuraUsersRepositoryProvider = Provider<EstructuraUsersRepository>(
  (ref) => EstructuraUsersRepository(Supabase.instance.client),
);

class EstructuraUsersRepository {
  EstructuraUsersRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'usuarios_estructura';

  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await _client
        .from(_table)
        .select()
        .order('updated_at', ascending: false);

    return (response as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<void> upsertUser(Map<String, dynamic> user) async {
    final payload = Map<String, dynamic>.from(user)
      ..['updated_at'] = DateTime.now().toIso8601String();
    payload.putIfAbsent('created_at', () => DateTime.now().toIso8601String());

    await _client.from(_table).upsert(payload, onConflict: 'id');
  }

  Future<void> deleteUser(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
