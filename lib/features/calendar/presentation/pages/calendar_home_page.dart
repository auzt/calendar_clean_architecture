// lib/features/calendar/presentation/pages/calendar_home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/extensions.dart';
import '../../domain/entities/calendar_date_range.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart' as calendar_events;
import '../bloc/calendar_state.dart';
import '../widgets/month_view_widget.dart';
import 'add_event_page.dart';
import 'day_view_page.dart';

class CalendarHomePage extends StatefulWidget {
  const CalendarHomePage({super.key});

  @override
  State<CalendarHomePage> createState() => _CalendarHomePageState();
}

class _CalendarHomePageState extends State<CalendarHomePage>
    with WidgetsBindingObserver {
  // ✅ ADDED: Observer untuk lifecycle
  late DateTime _currentMonth;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _pageController = PageController(initialPage: 1000);

    // ✅ ADDED: Observer untuk lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Load initial events
    _loadEventsForMonth(_currentMonth);

    // Check Google auth status
    context.read<CalendarBloc>().add(const calendar_events.CheckGoogleAuth());
  }

  @override
  void dispose() {
    // ✅ ADDED: Remove observer
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  // ✅ ADDED: Override didChangeAppLifecycleState untuk auto refresh
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // ✅ KUNCI: Refresh events ketika app kembali ke foreground
    if (state == AppLifecycleState.resumed) {
      print('📱 App resumed - refreshing month view events');
      _loadEventsForMonth(_currentMonth);
    }
  }

  void _loadEventsForMonth(DateTime month) {
    final startDate = AppDateUtils.getStartOfMonth(month);
    final endDate = AppDateUtils.getEndOfMonth(month);
    final dateRange = CalendarDateRange(startDate: startDate, endDate: endDate);

    print('🔄 Loading events for month: ${month.year}-${month.month}');
    context.read<CalendarBloc>().add(
          calendar_events.LoadCalendarEvents(
            dateRange: dateRange,
            forceRefresh:
                false, // ✅ CHANGED: false untuk performance, tapi bisa di-override
          ),
        );
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _currentMonth = newMonth;
    });
    _loadEventsForMonth(newMonth);
  }

  // ✅ ADDED: Method untuk force refresh (manual)
  void _forceRefreshCurrentMonth() {
    final startDate = AppDateUtils.getStartOfMonth(_currentMonth);
    final endDate = AppDateUtils.getEndOfMonth(_currentMonth);
    final dateRange = CalendarDateRange(startDate: startDate, endDate: endDate);

    print('🔄 Force refreshing events for current month');
    context.read<CalendarBloc>().add(
          calendar_events.LoadCalendarEvents(
            dateRange: dateRange,
            forceRefresh: true, // ✅ Force refresh
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppDateUtils.formatDisplayDate(_currentMonth).split(',')[1].trim(),
        ),
        centerTitle: false,
        actions: [
          BlocBuilder<CalendarBloc, CalendarState>(
            builder: (context, state) {
              if (state is CalendarLoaded) {
                return IconButton(
                  onPressed: state.isGoogleAuthenticated
                      ? _showSyncDialog
                      : _showAuthDialog,
                  icon: Icon(
                    state.isGoogleAuthenticated
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                    color: state.isGoogleAuthenticated
                        ? Colors.green
                        : Colors.grey,
                  ),
                  tooltip: state.isGoogleAuthenticated
                      ? 'Google Calendar Tersinkron'
                      : 'Login ke Google Calendar',
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            onPressed: () {
              final today = DateTime.now();
              final todayMonth = DateTime(today.year, today.month, 1);
              if (todayMonth != _currentMonth) {
                _onMonthChanged(todayMonth);
                _pageController.animateToPage(
                  1000,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            icon: const Icon(Icons.today),
            tooltip: 'Hari Ini',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _forceRefreshCurrentMonth(); // ✅ CHANGED: Use force refresh method
                  break;
                case 'clear_cache':
                  _clearCache();
                  break;
                case 'logout':
                  _signOut();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_cache',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('Clear Cache'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout Google'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocListener<CalendarBloc, CalendarState>(
        listener: (context, state) {
          if (state is CalendarError) {
            _showErrorSnackBar(state.message);
          } else if (state is GoogleAuthSuccess) {
            _showSuccessSnackBar('Berhasil login ke Google Calendar');
            _forceRefreshCurrentMonth(); // ✅ ADDED: Refresh setelah auth
          } else if (state is GoogleAuthFailed) {
            _showErrorSnackBar('Login gagal: ${state.message}');
          } else if (state is GoogleSignedOut) {
            _showSuccessSnackBar('Berhasil logout dari Google Calendar');
          } else if (state is EventCreated ||
              state is EventUpdated ||
              state is EventDeleted) {
            // ✅ ADDED: Auto refresh setelah event changes
            print('📝 Event changed - refreshing month view');
            _forceRefreshCurrentMonth();
          }
        },
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  final monthOffset = index - 1000;
                  final newMonth = DateTime(
                    DateTime.now().year,
                    DateTime.now().month + monthOffset,
                    1,
                  );
                  _onMonthChanged(newMonth);
                },
                itemBuilder: (context, index) {
                  final monthOffset = index - 1000;
                  final month = DateTime(
                    DateTime.now().year,
                    DateTime.now().month + monthOffset,
                    1,
                  );
                  return MonthViewWidget(
                    month: month,
                    onDateTap: (date) => _navigateToDayView(date),
                    onDateLongPress: (date) => _showQuickAddEvent(date),
                  );
                },
              ),
            ),
            _buildStatusBar(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEvent(DateTime.now()),
        tooltip: 'Tambah Event',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatusBar() {
    return BlocBuilder<CalendarBloc, CalendarState>(
      builder: (context, state) {
        if (state is CalendarLoading) {
          return Container(
            padding: const EdgeInsets.all(8),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Memuat events...'),
              ],
            ),
          );
        } else if (state is CalendarSyncing) {
          return Container(
            padding: const EdgeInsets.all(8),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Sinkronisasi dengan Google Calendar...'),
              ],
            ),
          );
        } else if (state is CalendarLoaded) {
          return Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  state.isGoogleAuthenticated
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                  size: 16,
                  color:
                      state.isGoogleAuthenticated ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.isGoogleAuthenticated
                        ? 'Tersinkron • ${state.events.length} events • ${state.lastSyncTime?.timeAgo ?? 'Belum pernah sync'}'
                        : '${state.events.length} events • Offline mode',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _navigateToDayView(DateTime date) async {
    // ✅ IMPROVED: Tunggu hasil dari day view dan refresh jika ada perubahan
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DayViewPage(initialDate: date)),
    );

    // ✅ KUNCI: Refresh month view setelah kembali dari day view
    print('🔙 Returned from day view - refreshing month view');
    _forceRefreshCurrentMonth();
  }

  void _navigateToAddEvent(DateTime date) async {
    // ✅ IMPROVED: Tunggu hasil dari add event dan refresh jika ada perubahan
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEventPage(initialDate: date)),
    );

    // ✅ KUNCI: Refresh month view setelah kembali dari add event
    print('🔙 Returned from add event - refreshing month view');
    _forceRefreshCurrentMonth();
  }

  void _showQuickAddEvent(DateTime date) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Tambah Event'),
              subtitle: Text(AppDateUtils.formatDisplayDate(date)),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddEvent(date);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_day),
              title: const Text('Lihat Detail Hari'),
              onTap: () {
                Navigator.pop(context);
                _navigateToDayView(date);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAuthDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login ke Google Calendar'),
        content: const Text(
          'Login untuk sinkronisasi otomatis dengan Google Calendar Anda.',
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
                    const calendar_events.AuthenticateGoogle(),
                  );
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sinkronisasi Manual'),
        content: const Text('Sync ulang events dengan Google Calendar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final startDate = AppDateUtils.getStartOfMonth(_currentMonth);
              final endDate = AppDateUtils.getEndOfMonth(_currentMonth);
              final dateRange = CalendarDateRange(
                startDate: startDate,
                endDate: endDate,
              );
              context.read<CalendarBloc>().add(
                    calendar_events.SyncWithGoogle(dateRange),
                  );
            },
            child: const Text('Sync'),
          ),
        ],
      ),
    );
  }

  void _refreshEvents() {
    _forceRefreshCurrentMonth(); // ✅ CHANGED: Use dedicated method
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'Hapus semua data cache? Data akan dimuat ulang dari server.',
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

  void _signOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Keluar dari Google Calendar? Data lokal akan dihapus.',
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.white,
          onPressed: () => _forceRefreshCurrentMonth(), // ✅ CHANGED
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
}
