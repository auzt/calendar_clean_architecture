// lib/main_with_di.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart'; // <--- TAMBAHKAN IMPORT INI

import 'core/di/injection_container.dart' as di;
import 'features/calendar/presentation/bloc/calendar_bloc.dart';
import 'features/calendar/presentation/pages/calendar_home_page.dart';

void main() async {
  // <--- PASTIKAN main ADALAH ASYNC
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Date Formatting for 'id_ID' locale
  await initializeDateFormatting('id_ID', null); // <--- TAMBAHKAN BARIS INI

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize dependency injection
  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CalendarBloc>(create: (context) => di.sl<CalendarBloc>()),
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
}
