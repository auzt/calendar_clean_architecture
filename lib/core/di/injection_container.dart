// lib/core/di/injection_container.dart
import 'package:get_it/get_it.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';

import '../constants/google_calendar_constants.dart';
import '../network/network_info.dart';
import '../../features/calendar/data/datasources/google_calendar_remote_datasource.dart';
import '../../features/calendar/data/datasources/local_calendar_datasource.dart';
import '../../features/calendar/data/repositories/calendar_repository_impl.dart';
import '../../features/calendar/domain/repositories/calendar_repository.dart';
import '../../features/calendar/domain/usecases/calendar_usecases.dart';
import '../../features/calendar/domain/usecases/get_calendar_events.dart';
import '../../features/calendar/domain/usecases/get_events_for_date.dart';
import '../../features/calendar/domain/usecases/create_calendar_event.dart';
import '../../features/calendar/domain/usecases/update_calendar_event.dart';
import '../../features/calendar/domain/usecases/delete_calendar_event.dart';
import '../../features/calendar/domain/usecases/sync_google_calendar.dart';
import '../../features/calendar/domain/usecases/authenticate_google_calendar.dart';
import '../../features/calendar/domain/usecases/watch_calendar_events.dart';
import '../../features/calendar/presentation/bloc/calendar_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! Features - Calendar

  // Bloc
  sl.registerFactory(() => CalendarBloc(useCases: sl()));

  // Use cases
  sl.registerLazySingleton(
    () => CalendarUseCases(
      getCalendarEvents: sl(),
      getEventsForDate: sl(),
      createCalendarEvent: sl(),
      updateCalendarEvent: sl(),
      deleteCalendarEvent: sl(),
      syncGoogleCalendar: sl(),
      authenticateGoogleCalendar: sl(),
      watchCalendarEvents: sl(),
    ),
  );

  sl.registerLazySingleton(() => GetCalendarEvents(sl()));
  sl.registerLazySingleton(() => GetEventsForDate(sl()));
  sl.registerLazySingleton(() => CreateCalendarEvent(sl()));
  sl.registerLazySingleton(() => UpdateCalendarEvent(sl()));
  sl.registerLazySingleton(() => DeleteCalendarEvent(sl()));
  sl.registerLazySingleton(() => SyncGoogleCalendar(sl()));
  sl.registerLazySingleton(() => AuthenticateGoogleCalendar(sl()));
  sl.registerLazySingleton(() => WatchCalendarEvents(sl()));

  // Repository
  sl.registerLazySingleton<CalendarRepository>(
    () => CalendarRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data sources
  sl.registerLazySingleton<GoogleCalendarRemoteDataSource>(
    () => GoogleCalendarRemoteDataSourceImpl(googleSignIn: sl()),
  );

  sl.registerLazySingleton<LocalCalendarDataSource>(
    () => LocalCalendarDataSourceImpl(),
  );

  //! Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  //! External
  sl.registerLazySingleton(() => Connectivity());
  sl.registerLazySingleton(
    () => GoogleSignIn(scopes: GoogleCalendarConstants.scopes),
  );

  // Initialize Hive
  await _initHive();
}

Future<void> _initHive() async {
  // Tunggu sampai adapter ter-generate
  await Future.delayed(Duration.zero);

  // Cek apakah adapter sudah ter-register
  if (!Hive.isAdapterRegistered(0)) {
    // Adapter akan tersedia setelah code generation
    print(
      'CalendarEventModelAdapter akan ter-register setelah code generation',
    );
  }
}
