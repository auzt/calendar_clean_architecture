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

  // Register Hive adapters
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(CalendarEventModelAdapter());
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CalendarBloc>(create: (context) => _createCalendarBloc()),
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
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
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
