// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'core/network/network_info.dart';
import 'features/calendar/data/datasources/google_calendar_remote_datasource.dart';
import 'features/calendar/data/datasources/local_calendar_datasource.dart';
import 'features/calendar/data/repositories/calendar_repository_impl.dart';
import 'features/calendar/data/models/calendar_event_model.dart';
import 'features/calendar/domain/usecases/calendar_usecases.dart';
import 'features/calendar/domain/usecases/get_calendar_events.dart';
import 'features/calendar/domain/usecases/get_events_for_date.dart';
import 'features/calendar/domain/usecases/create_calendar_event.dart';
import 'features/calendar/domain/usecases/update_calendar_event.dart';
import 'features/calendar/domain/usecases/delete_calendar_event.dart';
import 'features/calendar/domain/usecases/sync_google_calendar.dart';
import 'features/calendar/domain/usecases/authenticate_google_calendar.dart';
import 'features/calendar/domain/usecases/watch_calendar_events.dart';
import 'features/calendar/presentation/bloc/calendar_bloc.dart';
import 'features/calendar/presentation/pages/calendar_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(CalendarEventModelAdapter());
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CalendarBloc>(
          create: (context) => _createCalendarBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Calendar App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 2,
          ),
        ),
        home: const CalendarHomePage(),
      ),
    );
  }

  CalendarBloc _createCalendarBloc() {
    // Network
    final networkInfo = NetworkInfoImpl(Connectivity());
    
    // Data sources
    final googleSignIn = GoogleSignIn(
      scopes: ['https://www.googleapis.com/auth/calendar'],
    );
    final remoteDataSource = GoogleCalendarRemoteDataSourceImpl(
      googleSignIn: googleSignIn,
    );
    final localDataSource = LocalCalendarDataSourceImpl();
    
    // Initialize local data source
    localDataSource.init();
    
    // Repository
    final repository = CalendarRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      networkInfo: networkInfo,
    );
    
    // Use cases
    final useCases = CalendarUseCases(
      getCalendarEvents: GetCalendarEvents(repository),
      getEventsForDate: GetEventsForDate(repository),
      createCalendarEvent: CreateCalendarEvent(repository),
      updateCalendarEvent: UpdateCalendarEvent(repository),
      deleteCalendarEvent: DeleteCalendarEvent(repository),
      syncGoogleCalendar: SyncGoogleCalendar(repository),
      authenticateGoogleCalendar: AuthenticateGoogleCalendar(repository),
      watchCalendarEvents: WatchCalendarEvents(repository),
    );
    
    return CalendarBloc(useCases: useCases);
  }
}

// lib/features/calendar/presentation/pages/calendar_home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/calendar_date_range.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart' as calendar_events;
import '../bloc/calendar_state.dart';
import '../widgets/month_view_widget.dart';
import 'add_event_page.dart';
import 'day_view_page.dart';

class CalendarHomePage extends StatefulWidget {
  const CalendarHomePage({Key? key}) : super(key: key);

  @override
  State<CalendarHomePage> createState() => _CalendarHomePageState();
}

class _CalendarHomePageState extends State<CalendarHomePage> {
  late DateTime _currentMonth;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _pageController = PageController(initialPage: 1000);
    
    // Load initial events
    _loadEventsForMonth(_currentMonth);
    
    // Check Google auth status
    context.read<CalendarBloc>().add(const calendar_events.CheckGoogleAuth());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadEventsForMonth(DateTime month) {
    final startDate = AppDateUtils.getStartOfMonth(month);
    final endDate = AppDateUtils.getEndOfMonth(month);
    final dateRange = CalendarDateRange(startDate: startDate, endDate: endDate);
    
    context.read<CalendarBloc>().add(
      calendar_events.LoadCalendarEvents(dateRange: dateRange),
    );
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _currentMonth = newMonth;
    });
    _loadEventsForMonth(newMonth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppDateUtils.formatDisplayDate(_currentMonth).split(',')[1].trim()),
        centerTitle: false,
        actions: [
          BlocBuilder<CalendarBloc, CalendarState>(
            builder: (context, state) {
              if (state is CalendarLoaded) {
                return IconButton(
                  onPressed: state.isGoogleAuthenticated ? _showSyncDialog : _showAuthDialog,
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
                  _refreshEvents();
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
            _loadEventsForMonth(_currentMonth);
          } else if (state is GoogleAuthFailed) {
            _showErrorSnackBar('Login gagal: ${state.message}');
          } else if (state is GoogleSignedOut) {
            _showSuccessSnackBar('Berhasil logout dari Google Calendar');
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
        child: const Icon(Icons.add),
        tooltip: 'Tambah Event',
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
                  state.isGoogleAuthenticated ? Icons.cloud_done : Icons.cloud_off,
                  size: 16,
                  color: state.isGoogleAuthenticated ? Colors.green : Colors.grey,
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

  void _navigateToDayView(DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DayViewPage(initialDate: date),
      ),
    );
  }

  void _navigateToAddEvent(DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventPage(initialDate: date),
      ),
    );
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
              context.read<CalendarBloc>().add(const calendar_events.AuthenticateGoogle());
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
              final dateRange = CalendarDateRange(startDate: startDate, endDate: endDate);
              context.read<CalendarBloc>().add(calendar_events.SyncWithGoogle(dateRange));
            },
            child: const Text('Sync'),
          ),
        ],
      ),
    );
  }

  void _refreshEvents() {
    final startDate = AppDateUtils.getStartOfMonth(_currentMonth);
    final endDate = AppDateUtils.getEndOfMonth(_currentMonth);
    final dateRange = CalendarDateRange(startDate: startDate, endDate: endDate);
    
    context.read<CalendarBloc>().add(
      calendar_events.LoadCalendarEvents(
        dateRange: dateRange,
        forceRefresh: true,
      ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Hapus semua data cache? Data akan dimuat ulang dari server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CalendarBloc>().add(const calendar_events.ClearCache());
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
        content: const Text('Keluar dari Google Calendar? Data lokal akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CalendarBloc>().add(const calendar_events.SignOutGoogle());
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
          onPressed: () => _refreshEvents(),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}