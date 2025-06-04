// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:google_sign_in/google_sign_in.dart'; // No longer directly used here
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

// ✅ Import OAuth Configuration
import 'core/constants/google_oauth_config.dart';
import 'core/adapters/color_adapter.dart';
import 'core/network/network_info.dart';
import 'core/network/google_auth_service.dart'; // Import GoogleAuthService
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

  print('🚀 Starting Calendar App...');

  // ✅ Set up global error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    MyAppErrorHandler.handleError(
        details.exception, details.stack ?? StackTrace.current);
  };

  // Initialize Hive
  await Hive.initFlutter();
  print('✅ Hive initialized');

  // Initialize Date Formatting for Indonesian locale
  await initializeDateFormatting('id_ID', null);
  print('✅ Date formatting initialized');

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
    print('   Development Mode: ${GoogleOAuthConfig.isDevelopment}');
  }

  print('✅ App initialization complete');
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
        // ✅ Add error widget builder for better error handling
        builder: (context, widget) {
          ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
            return MyAppErrorWidget(errorDetails: errorDetails);
          };
          return widget!;
        },
      ),
    );
  }

  CalendarBloc _createCalendarBloc() {
    print('🏗️ Creating Calendar Bloc...');

    // ✅ Network
    final networkInfo = NetworkInfoImpl(Connectivity());
    print('   ✅ Network info created');

    // ✅ Initialize and use GoogleAuthService
    final googleAuthService = GoogleAuthService();
    googleAuthService.initialize(); // Initialize GoogleAuthService
    print('   ✅ GoogleAuthService initialized');

    // ✅ Data sources
    // final googleSignIn = _createGoogleSignIn(); // REMOVED: GoogleAuthService handles this
    final remoteDataSource = GoogleCalendarRemoteDataSourceImpl(
      // googleSignIn: googleSignIn, // REMOVED
      googleAuthService: googleAuthService, // ADDED
    );
    print('   ✅ Remote data source created');

    final localDataSource = LocalCalendarDataSourceImpl();
    print('   ✅ Local data source created');

    // ✅ Initialize local data source
    localDataSource.init().then((_) {
      print('   ✅ Local data source initialized');
    }).catchError((error) {
      print('   ⚠️ Local data source initialization error: $error');
    });

    // ✅ Repository
    final repository = CalendarRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      networkInfo: networkInfo,
    );
    print('   ✅ Repository created');

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
    print('   ✅ Use cases created');

    final bloc = CalendarBloc(useCases: useCases);
    print('✅ Calendar Bloc created successfully');

    return bloc;
  }

  // REMOVED _createGoogleSignIn method as GoogleAuthService now handles GoogleSignIn instance.
}

// ✅ Global error handler
class MyAppErrorHandler {
  static void handleError(dynamic error, StackTrace stackTrace) {
    if (GoogleOAuthConfig.enableDebugLogs) {
      print('🚨 Global Error: $error');
      print('📍 Stack Trace: $stackTrace');
    }

    // Log critical errors
    if (error.toString().contains('Invalid argument (expiry)') ||
        error.toString().contains('Access token') ||
        error.toString().contains('OAuth') ||
        error.toString().contains('Google')) {
      print('🔴 CRITICAL AUTH ERROR: $error');
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
    final isAuthError = errorDetails.exception
            .toString()
            .contains('Invalid argument (expiry)') ||
        errorDetails.exception.toString().contains('Access token') ||
        errorDetails.exception.toString().contains('OAuth') ||
        errorDetails.exception.toString().contains('Google');

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(
              isAuthError ? 'Authentication Error' : 'Something went wrong!'),
          backgroundColor: isAuthError ? Colors.orange : Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isAuthError ? Icons.lock_clock : Icons.error_outline,
                    size: 64, color: isAuthError ? Colors.orange : Colors.red),
                const SizedBox(height: 16),
                Text(
                  isAuthError
                      ? 'Google Authentication Error'
                      : 'An error occurred in the application',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isAuthError
                      ? 'There was a problem with Google Calendar authentication. Please try signing in again.'
                      : 'The application encountered an unexpected error.',
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAuthError ? Colors.orange : Colors.blue,
                  ),
                  child: Text(isAuthError ? 'Try Again' : 'Restart App'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
