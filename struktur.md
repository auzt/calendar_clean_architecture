lib/
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   └── google_calendar_constants.dart
│   ├── error/
│   │   ├── exceptions.dart
│   │   ├── failures.dart
│   │   └── error_handler.dart
│   ├── network/
│   │   ├── api_client.dart
│   │   ├── google_auth_service.dart
│   │   └── network_info.dart
│   ├── utils/
│   │   ├── date_utils.dart
│   │   ├── extensions.dart
│   │   └── validators.dart
│   └── widgets/
│       ├── loading_widget.dart
│       ├── error_widget.dart
│       └── custom_dialog.dart
├── features/
│   └── calendar/
│       ├── data/
│       │   ├── datasources/
│       │   │   ├── google_calendar_remote_datasource.dart
│       │   │   └── local_calendar_datasource.dart
│       │   ├── models/
│       │   │   ├── calendar_event_model.dart
│       │   │   ├── calendar_response_model.dart
│       │   │   └── google_event_model.dart
│       │   └── repositories/
│       │       └── calendar_repository_impl.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── calendar_event.dart
│       │   │   └── calendar_date_range.dart
│       │   ├── repositories/
│       │   │   └── calendar_repository.dart
│       │   └── usecases/
│       │       ├── get_calendar_events.dart
│       │       ├── create_calendar_event.dart
│       │       ├── update_calendar_event.dart
│       │       ├── delete_calendar_event.dart
│       │       └── sync_google_calendar.dart
│       └── presentation/
│           ├── bloc/
│           │   ├── calendar_bloc.dart
│           │   ├── calendar_event.dart
│           │   └── calendar_state.dart
│           ├── pages/
│           │   ├── calendar_home_page.dart
│           │   ├── month_view_page.dart
│           │   ├── day_view_page.dart
│           │   └── add_event_page.dart
│           └── widgets/
│               ├── month_view_widget.dart
│               ├── day_view_widget.dart
│               ├── event_card_widget.dart
│               ├── date_picker_widget.dart
│               └── event_form_widget.dart
└── main.dart