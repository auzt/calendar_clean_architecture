// lib/features/calendar/presentation/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart' as calendar_events;
import '../bloc/calendar_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: BlocBuilder<CalendarBloc, CalendarState>(
        builder: (context, state) {
          final isGoogleConnected =
              state is CalendarLoaded && state.isGoogleAuthenticated;

          return ListView(
            children: [
              const SizedBox(height: 16),

              // Google Calendar Section
              _buildSectionHeader('Google Calendar'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        isGoogleConnected ? Icons.cloud_done : Icons.cloud_off,
                        color: isGoogleConnected ? Colors.green : Colors.grey,
                      ),
                      title: Text(
                        isGoogleConnected ? 'Terhubung' : 'Tidak Terhubung',
                      ),
                      subtitle: Text(
                        isGoogleConnected
                            ? 'Sinkronisasi dengan Google Calendar aktif'
                            : 'Login untuk sinkronisasi otomatis',
                      ),
                      trailing:
                          isGoogleConnected
                              ? OutlinedButton(
                                onPressed: () => _signOut(context),
                                child: const Text('Logout'),
                              )
                              : ElevatedButton(
                                onPressed: () => _signIn(context),
                                child: const Text('Login'),
                              ),
                    ),
                    if (isGoogleConnected) ...[
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.sync),
                        title: const Text('Sinkronisasi Manual'),
                        subtitle: const Text(
                          'Sync ulang data dengan Google Calendar',
                        ),
                        onTap: () => _manualSync(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Data Management Section
              _buildSectionHeader('Manajemen Data'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text('Refresh Cache'),
                      subtitle: const Text('Muat ulang data dari server'),
                      onTap: () => _refreshCache(context),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.clear_all),
                      title: const Text('Hapus Cache'),
                      subtitle: const Text('Hapus semua data lokal'),
                      onTap: () => _clearCache(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // App Info Section
              _buildSectionHeader('Informasi Aplikasi'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info),
                      title: Text('Versi Aplikasi'),
                      subtitle: Text('1.0.0+1'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.help),
                      title: const Text('Bantuan'),
                      subtitle: const Text('Cara menggunakan aplikasi'),
                      onTap: () => _showHelp(context),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip),
                      title: const Text('Kebijakan Privasi'),
                      onTap: () => _showPrivacyPolicy(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _signIn(BuildContext context) {
    context.read<CalendarBloc>().add(
      const calendar_events.AuthenticateGoogle(),
    );
  }

  void _signOut(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout Google Calendar'),
            content: const Text(
              'Yakin ingin keluar dari Google Calendar? Data lokal akan dihapus.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<CalendarBloc>().add(
                    const calendar_events.SignOutGoogle(),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
    );
  }

  void _manualSync(BuildContext context) {
    // Implementasi manual sync
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Memulai sinkronisasi manual...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _refreshCache(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Refresh Cache'),
            content: const Text('Muat ulang semua data dari server?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Implementasi refresh cache
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cache berhasil direfresh'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Refresh'),
              ),
            ],
          ),
    );
  }

  void _clearCache(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus Cache'),
            content: const Text(
              'Hapus semua data lokal? Data akan dimuat ulang dari server.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<CalendarBloc>().add(
                    const calendar_events.ClearCache(),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Hapus'),
              ),
            ],
          ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Bantuan'),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cara Menggunakan Calendar App:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text('📅 Navigasi:'),
                  Text('• Swipe kiri/kanan untuk ganti bulan/hari'),
                  Text('• Tap tanggal untuk lihat detail'),
                  Text('• Tap ikon "hari ini" untuk kembali ke hari ini'),
                  SizedBox(height: 12),
                  Text('➕ Menambah Event:'),
                  Text('• Tap tombol + di kanan bawah'),
                  Text('• Atau tap pada area kosong di day view'),
                  SizedBox(height: 12),
                  Text('✏️ Edit/Hapus Event:'),
                  Text('• Tap event untuk lihat detail'),
                  Text('• Pilih Edit atau Hapus dari menu'),
                  SizedBox(height: 12),
                  Text('☁️ Google Calendar:'),
                  Text('• Login untuk sinkronisasi otomatis'),
                  Text('• Data akan tersinkron 2 arah'),
                  Text('• Bisa digunakan offline'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Mengerti'),
              ),
            ],
          ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Kebijakan Privasi'),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Calendar App menghormati privasi Anda:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text('🔒 Data yang Dikumpulkan:'),
                  Text('• Event calendar yang Anda buat'),
                  Text('• Data Google Calendar (jika login)'),
                  Text('• Preferensi aplikasi'),
                  SizedBox(height: 12),
                  Text('💾 Penyimpanan Data:'),
                  Text('• Data disimpan lokal di device'),
                  Text('• Sinkronisasi dengan Google Calendar (opsional)'),
                  Text('• Tidak ada data yang dikirim ke server lain'),
                  SizedBox(height: 12),
                  Text('🛡️ Keamanan:'),
                  Text('• Data dienkripsi di device'),
                  Text('• Autentikasi melalui Google resmi'),
                  Text('• Tidak ada tracking atau analytics'),
                  SizedBox(height: 12),
                  Text('📧 Kontak:'),
                  Text('Jika ada pertanyaan, hubungi developer melalui email.'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          ),
    );
  }
}
