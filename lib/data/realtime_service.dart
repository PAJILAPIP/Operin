import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_support.dart';

/// Pemberitahuan saat data di server berubah (mis. pesanan baru dari HP
/// lain), agar controller memuat ulang tanpa user menekan tombol refresh.
abstract interface class RealtimeService {
  /// Memanggil [onChange] saat salah satu [tables] berubah. Kembalian:
  /// fungsi untuk berhenti berlangganan.
  VoidCallback watch(List<String> tables, VoidCallback onChange);
}

/// Tidak berlangganan apa pun (dipakai di test).
class NoopRealtimeService implements RealtimeService {
  const NoopRealtimeService();

  @override
  VoidCallback watch(List<String> tables, VoidCallback onChange) => () {};
}

/// Supabase Realtime (postgres_changes). Baris yang dikirim tetap disaring
/// oleh RLS, jadi user hanya diberi tahu perubahan yang boleh ia lihat.
class SupabaseRealtimeService implements RealtimeService {
  SupabaseRealtimeService({this.debounce = const Duration(milliseconds: 600)});

  /// Banyak perubahan beruntun (mis. satu RPC menulis beberapa tabel)
  /// digabung menjadi satu kali muat ulang.
  final Duration debounce;
  int _counter = 0;

  @override
  VoidCallback watch(List<String> tables, VoidCallback onChange) {
    Timer? timer;
    void schedule(PostgresChangePayload _) {
      timer?.cancel();
      timer = Timer(debounce, onChange);
    }

    final channel = supabase.channel('operin-${tables.join('-')}-${_counter++}');
    for (final table in tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: schedule,
      );
    }
    channel.subscribe((status, error) {
      if (error != null) debugPrint('Realtime $tables: $status $error');
    });

    return () {
      timer?.cancel();
      supabase.removeChannel(channel);
    };
  }
}
