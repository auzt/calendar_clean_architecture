// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

// ✅ Import OAuth Configuration
import 'core/constants/google_oauth_config.dart';
import 'core/adapters/color_adapter.dart';
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

  // Initialize Date Formatting for Indonesian locale
  await initializeDateFormatting('id_ID', null);

  try {
    // ✅ Register Hive adapters
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ColorAdapter());
      print('✅ ColorAdapter registered successfully');
    }

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CalendarEventModelAdapter());
      print('✅ CalendarEventModelAdapter registered successfully');
    }
  } catch (e) {
    print('⚠️ Adapter registration error: $e');
    // Continue anyway - app might still work
  }

  // ✅ Debug OAuth configuration
  if (GoogleOAuthConfig.enableDebugLogs) {
    print('🔑 Google OAuth Configuration:');
    print('   Platform: ${_getCurrentPlatform()}');
    print('   Client ID: ${GoogleOAuthConfig.clientId}');
    print('   Project Number: ${GoogleOAuthConfig.projectNumber}');
    print('   Scopes: ${GoogleOAuthConfig.scopes.join(', ')}');
  }

  runApp(MyApp());
}

String _getCurrentPlatform() {
  if (kIsWeb) return 'Web';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  return 'Unknown';
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CalendarBloc>(create: (context) => _createCalendarBloc()),
      ],
      child: MaterialApp(
        title: 'Calendar App with Google Integration',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
          ),
        ),
        home: const CalendarHomePage(),
      ),
    );
  }

  CalendarBloc _createCalendarBloc() {
    // ✅ Network
    final networkInfo = NetworkInfoImpl(Connectivity());

    // ✅ Data sources dengan OAuth configuration
    final googleSignIn = _createGoogleSignIn();
    final remoteDataSource = GoogleCalendarRemoteDataSourceImpl(
      googleSignIn: googleSignIn,
    );
    final localDataSource = LocalCalendarDataSourceImpl();

    // ✅ Initialize local data source
    localDataSource.init().catchError((error) {
      print('⚠️ Local data source initialization error: $error');
    });

    // ✅ Repository
    final repository = CalendarRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      networkInfo: networkInfo,
    );

    // ✅ Use cases
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

  // ✅ Create GoogleSignIn based on platform dengan OAuth config
  GoogleSignIn _createGoogleSignIn() {
    try {
      if (kIsWeb) {
        // ✅ Web configuration
        return GoogleSignIn(
          clientId: GoogleOAuthConfig.webClientId,
          scopes: GoogleOAuthConfig.scopes,
        );
      } else if (Platform.isAndroid) {
        // ✅ Android configuration (menggunakan google-services.json)
        return GoogleSignIn(
          scopes: GoogleOAuthConfig.scopes,
          // Android client ID akan dibaca dari google-services.json
        );
      } else if (Platform.isIOS) {
        // ✅ iOS configuration (menggunakan GoogleService-Info.plist)
        return GoogleSignIn(
          scopes: GoogleOAuthConfig.scopes,
          // iOS client ID akan dibaca dari GoogleService-Info.plist
        );
      }
    } catch (e) {
      print('⚠️ Error creating GoogleSignIn: $e');
    }

    // ✅ Fallback configuration
    return GoogleSignIn(
      clientId: GoogleOAuthConfig.webClientId,
      scopes: GoogleOAuthConfig.scopes,
    );
  }
}

// ✅ Global error handler
class MyAppErrorHandler {
  static void handleError(dynamic error, StackTrace stackTrace) {
    if (GoogleOAuthConfig.enableDebugLogs) {
      print('🚨 Global Error: $error');
      print('📍 Stack Trace: $stackTrace');
    }

    // Bisa ditambahkan logging ke crash analytics di production
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }
}

// ✅ Custom error widget untuk development
class MyAppErrorWidget extends StatelessWidget {
  final FlutterErrorDetails errorDetails;

  const MyAppErrorWidget({super.key, required this.errorDetails});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Something went wrong!'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'An error occurred in the application',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (GoogleOAuthConfig.enableDebugLogs) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    errorDetails.exception.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Restart app atau navigate ke home
                  runApp(MyApp());
                },
                child: const Text('Restart App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
