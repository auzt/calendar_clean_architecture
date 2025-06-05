// lib/features/calendar/presentation/pages/calendar_home_page.dart
import 'dart:async';
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
import 'settings_page.dart';

class CalendarHomePage extends StatefulWidget {
  const CalendarHomePage({super.key});

  @override
  State<CalendarHomePage> createState() => _CalendarHomePageState();
}

class _CalendarHomePageState extends State<CalendarHomePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late DateTime _currentMonth;
  late PageController _pageController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  // Loading dialog tracking
  bool _isLoadingDialogShown = false;
  Timer? _loadingDialogTimer;

  // Sync state tracking
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _pageController = PageController(initialPage: 1000);

    // Initialize animation controller for FAB
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _fabAnimationController.forward();

    // Add observer untuk lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Load initial events with debug info
    print(
        '🏠 CalendarHomePage: Loading initial events for ${_currentMonth.year}-${_currentMonth.month}');
    _loadEventsForMonth(_currentMonth);

    // Check Google auth status
    context.read<CalendarBloc>().add(const calendar_events.CheckGoogleAuth());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _fabAnimationController.dispose();
    _loadingDialogTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Refresh events ketika app kembali ke foreground
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
    print(
        '📅 Date range: ${AppDateUtils.formatDisplayDate(startDate)} to ${AppDateUtils.formatDisplayDate(endDate)}');

    context.read<CalendarBloc>().add(
          calendar_events.LoadCalendarEvents(
            dateRange: dateRange,
            forceRefresh: false,
          ),
        );
  }

  void _onMonthChanged(DateTime newMonth) {
    print(
        '📅 Month changed from ${_currentMonth.year}-${_currentMonth.month} to ${newMonth.year}-${newMonth.month}');
    setState(() {
      _currentMonth = newMonth;
    });
    _loadEventsForMonth(newMonth);
  }

  void _forceRefreshCurrentMonth() {
    final startDate = AppDateUtils.getStartOfMonth(_currentMonth);
    final endDate = AppDateUtils.getEndOfMonth(_currentMonth);
    final dateRange = CalendarDateRange(startDate: startDate, endDate: endDate);

    print('🔄 Force refreshing events for current month');
    context.read<CalendarBloc>().add(
          calendar_events.LoadCalendarEvents(
            dateRange: dateRange,
            forceRefresh: true,
          ),
        );
  }

  // ✅ Enhanced sync dialog with clear information
  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.sync, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Sinkronisasi Manual'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Proses sinkronisasi manual akan:'),
            const SizedBox(height: 12),
            _buildSyncInfoItem(
                Icons.download, 'Mengambil data terbaru dari Google Calendar'),
            _buildSyncInfoItem(
                Icons.merge_type, 'Menggabungkan dengan data lokal'),
            _buildSyncInfoItem(
                Icons.delete_sweep, 'Menghapus duplikasi yang mungkin terjadi'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Proses ini aman dan tidak akan membuat duplikasi event.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _performManualSync();
            },
            icon: const Icon(Icons.sync),
            label: const Text('Mulai Sync'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _performManualSync() {
    setState(() {
      _isSyncing = true;
    });

    // Show loading dialog immediately
    _showLoadingDialog();

    // Start the sync process
    final startDate = AppDateUtils.getStartOfMonth(_currentMonth);
    final endDate = AppDateUtils.getEndOfMonth(_currentMonth);
    final dateRange = CalendarDateRange(
      startDate: startDate,
      endDate: endDate,
    );

    // Trigger sync
    context.read<CalendarBloc>().add(
          calendar_events.SyncWithGoogle(dateRange),
        );

    // Auto close loading dialog after timeout as backup
    _loadingDialogTimer = Timer(const Duration(seconds: 20), () {
      _dismissLoadingDialog();
      setState(() {
        _isSyncing = false;
      });
      _showErrorSnackBar('Sync timeout - proses terlalu lama');
    });
  }

  void _showLoadingDialog() {
    if (_isLoadingDialogShown) return;

    _isLoadingDialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Sinkronisasi dengan Google Calendar...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Mohon tunggu, proses ini mungkin memerlukan waktu beberapa detik.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _isLoadingDialogShown = false;
    });
  }

  void _dismissLoadingDialog() {
    if (_isLoadingDialogShown && Navigator.canPop(context)) {
      try {
        Navigator.pop(context);
        _isLoadingDialogShown = false;
      } catch (e) {
        print('⚠️ Error dismissing loading dialog: $e');
      }
    }
    _loadingDialogTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: BlocListener<CalendarBloc, CalendarState>(
        listener: _handleBlocState,
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
      floatingActionButton: _buildAnimatedFAB(),
      drawer: _buildDrawer(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        AppDateUtils.formatDisplayDate(_currentMonth).split(',')[1].trim(),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      centerTitle: false,
      actions: [
        // Google Calendar Status Icon
        BlocBuilder<CalendarBloc, CalendarState>(
          builder: (context, state) {
            if (state is CalendarLoaded) {
              return IconButton(
                onPressed: state.isGoogleAuthenticated
                    ? _showSyncDialog
                    : _showAuthDialog,
                icon: _isSyncing
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        state.isGoogleAuthenticated
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        color: state.isGoogleAuthenticated
                            ? Colors.green.shade100
                            : Colors.grey.shade300,
                      ),
                tooltip: state.isGoogleAuthenticated
                    ? 'Google Calendar Tersinkron'
                    : 'Login ke Google Calendar',
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Today Button
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

        // Menu Button
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: _handleMenuSelection,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Refresh'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text('Pengaturan'),
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
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title:
                    Text('Logout Google', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'refresh':
        _forceRefreshCurrentMonth();
        break;
      case 'settings':
        _navigateToSettings();
        break;
      case 'clear_cache':
        _clearCache();
        break;
      case 'logout':
        _signOut();
        break;
    }
  }

  Widget _buildStatusBar() {
    return BlocBuilder<CalendarBloc, CalendarState>(
      builder: (context, state) {
        if (state is CalendarLoading) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(top: BorderSide(color: Colors.blue.shade200)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Memuat events...',
                  style: TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        } else if (state is CalendarSyncing) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(top: BorderSide(color: Colors.orange.shade200)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sinkronisasi dengan Google Calendar... (${state.currentEvents.length} events)',
                    style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        } else if (state is CalendarLoaded) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
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
                    _buildStatusText(state),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (state.events.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${state.events.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
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

  String _buildStatusText(CalendarLoaded state) {
    if (state.isGoogleAuthenticated) {
      final syncText = state.lastSyncTime?.timeAgo ?? 'Belum pernah sync';
      return 'Tersinkron • ${state.events.length} events • $syncText';
    } else {
      return '${state.events.length} events • Mode offline';
    }
  }

  Widget _buildAnimatedFAB() {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton(
        onPressed: () => _navigateToAddEvent(DateTime.now()),
        tooltip: 'Tambah Event',
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.white, size: 32),
                SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendar App',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Kelola jadwal Anda',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Beranda'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Pengaturan'),
            onTap: () {
              Navigator.pop(context);
              _navigateToSettings();
            },
          ),
          const Divider(),
          BlocBuilder<CalendarBloc, CalendarState>(
            builder: (context, state) {
              final isAuthenticated =
                  state is CalendarLoaded && state.isGoogleAuthenticated;
              return ListTile(
                leading: Icon(
                  isAuthenticated ? Icons.cloud_done : Icons.cloud_off,
                  color: isAuthenticated ? Colors.green : Colors.grey,
                ),
                title:
                    Text(isAuthenticated ? 'Google Calendar' : 'Login Google'),
                subtitle:
                    Text(isAuthenticated ? 'Tersinkron' : 'Tidak terhubung'),
                onTap: () {
                  Navigator.pop(context);
                  if (isAuthenticated) {
                    _showSyncDialog();
                  } else {
                    _showAuthDialog();
                  }
                },
              );
            },
          ),
          const Spacer(),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Calendar App v1.0.1',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleBlocState(BuildContext context, CalendarState state) {
    // Handle loading dialog dismissal
    if (state is CalendarLoaded ||
        state is CalendarError ||
        state is GoogleAuthSuccess ||
        state is GoogleAuthFailed) {
      _dismissLoadingDialog();
      setState(() {
        _isSyncing = false;
      });
    }

    if (state is CalendarError) {
      print('❌ Calendar error: ${state.message}');
      _showErrorSnackBar(state.message);
    } else if (state is GoogleAuthSuccess) {
      print('✅ Google auth success');
      _showSuccessSnackBar('Berhasil login ke Google Calendar');
      _forceRefreshCurrentMonth();
    } else if (state is GoogleAuthFailed) {
      print('❌ Google auth failed: ${state.message}');
      _showErrorSnackBar('Login gagal: ${state.message}');
    } else if (state is GoogleSignedOut) {
      print('👋 Google signed out');
      _showSuccessSnackBar('Berhasil logout dari Google Calendar');
    } else if (state is EventCreated ||
        state is EventUpdated ||
        state is EventDeleted) {
      print('📝 Event changed - refreshing month view');
      _forceRefreshCurrentMonth();
    } else if (state is CalendarLoaded) {
      print('📋 Calendar loaded with ${state.events.length} events');

      // Show success message if this was a manual sync
      if (state.lastSyncTime != null && _isSyncing) {
        final now = DateTime.now();
        final syncAge = now.difference(state.lastSyncTime!);

        // If sync happened within last 30 seconds, likely a manual sync
        if (syncAge.inSeconds < 30) {
          _showSuccessSnackBar(
              'Sinkronisasi berhasil! ${state.events.length} events dimuat.');
        }
      }

      _lastSyncTime = state.lastSyncTime;
    } else if (state is CalendarSyncing) {
      print(
          '🔄 Calendar syncing with ${state.currentEvents.length} current events');
    }
  }

  void _navigateToDayView(DateTime date) async {
    print(
        '🗓️ Navigating to day view for ${AppDateUtils.formatDisplayDate(date)}');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DayViewPage(initialDate: date)),
    );

    print('🔙 Returned from day view - refreshing month view');
    _forceRefreshCurrentMonth();
  }

  void _navigateToAddEvent(DateTime date) async {
    print(
        '➕ Navigating to add event for ${AppDateUtils.formatDisplayDate(date)}');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEventPage(initialDate: date)),
    );

    print('🔙 Returned from add event - refreshing month view');
    _forceRefreshCurrentMonth();
  }

  void _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
    _forceRefreshCurrentMonth();
  }

  void _showQuickAddEvent(DateTime date) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppDateUtils.formatDisplayDate(date),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_circle, color: Colors.blue.shade700),
              ),
              title: const Text('Tambah Event'),
              subtitle: const Text('Buat event baru untuk hari ini'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddEvent(date);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.visibility, color: Colors.green.shade700),
              ),
              title: const Text('Lihat Detail Hari'),
              subtitle: const Text('Lihat semua event hari ini'),
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
        title: Row(
          children: [
            Icon(Icons.cloud, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Login ke Google Calendar'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Login untuk sinkronisasi otomatis dengan Google Calendar Anda.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Keuntungan login:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBenefitItem('Sinkronisasi 2 arah'),
                  _buildBenefitItem('Backup otomatis'),
                  _buildBenefitItem('Akses dari semua device'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nanti Saja'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.read<CalendarBloc>().add(
                    const calendar_events.AuthenticateGoogle(),
                  );
            },
            icon: const Icon(Icons.login),
            label: const Text('Login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.blue.shade700)),
        ],
      ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.clear_all, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Clear Cache'),
          ],
        ),
        content: const Text(
          'Hapus semua data cache? Data akan dimuat ulang dari server pada sync berikutnya.',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _signOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Logout Google Calendar'),
          ],
        ),
        content: const Text(
          'Keluar dari Google Calendar? Data lokal akan dihapus dan Anda perlu login ulang untuk sinkronisasi.',
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
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.white,
          onPressed: () => _forceRefreshCurrentMonth(),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
