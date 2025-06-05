// lib/core/services/event_sync_service.dart
// Service untuk background sync tanpa mengganggu UI

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/calendar/domain/entities/calendar_event.dart';
import '../../features/calendar/domain/repositories/calendar_repository.dart';

class EventSyncService {
  static EventSyncService? _instance;
  final CalendarRepository _repository;

  // Queue untuk batch sync
  final List<CalendarEvent> _pendingSyncEvents = [];
  Timer? _syncTimer;
  bool _isSyncing = false;

  // Event stream untuk notifikasi real-time
  final StreamController<EventSyncStatus> _statusController =
      StreamController<EventSyncStatus>.broadcast();

  EventSyncService._(this._repository);

  factory EventSyncService(CalendarRepository repository) {
    return _instance ??= EventSyncService._(repository);
  }

  Stream<EventSyncStatus> get statusStream => _statusController.stream;

  /// Tambah event ke queue untuk background sync
  void queueEventForSync(CalendarEvent event, SyncAction action) {
    // ✅ FIXED: Handle async authentication check properly
    _checkAuthAndQueue(event, action);
  }

  /// Helper method untuk check auth secara async
  Future<void> _checkAuthAndQueue(
      CalendarEvent event, SyncAction action) async {
    try {
      final authResult = await _repository.isGoogleCalendarAuthenticated();
      final isAuthenticated = authResult.fold((l) => false, (r) => r);

      if (!isAuthenticated) {
        print('⚠️ Skipping sync - not authenticated: ${event.title}');
        _statusController.add(
            EventSyncStatus.skipped(event.id, action, 'Not authenticated'));
        return;
      }

      print(
          '📝 Queuing event for background sync: ${event.title} (${action.name})');

      // Tandai event dengan action type
      final eventWithAction = event.copyWith(additionalData: {
        ...?event.additionalData,
        '_syncAction': action.name,
        '_queueTime': DateTime.now().toIso8601String(),
      });

      _pendingSyncEvents.add(eventWithAction);
      _startSyncTimer();

      _statusController.add(EventSyncStatus.queued(event.id, action));
    } catch (e) {
      print('❌ Error checking auth for sync: $e');
      _statusController
          .add(EventSyncStatus.error('Auth check failed: ${e.toString()}'));
    }
  }

  /// Start timer untuk batch sync
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 500), _processSyncQueue);
  }

  /// Process semua events dalam queue
  Future<void> _processSyncQueue() async {
    if (_isSyncing || _pendingSyncEvents.isEmpty) return;

    _isSyncing = true;
    print('🔄 Processing sync queue: ${_pendingSyncEvents.length} events');

    final eventsToSync = List<CalendarEvent>.from(_pendingSyncEvents);
    _pendingSyncEvents.clear();

    try {
      for (final event in eventsToSync) {
        await _syncSingleEvent(event);

        // Small delay to prevent overwhelming the API
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('✅ Background sync completed for ${eventsToSync.length} events');
      _statusController.add(EventSyncStatus.completed(eventsToSync.length));
    } catch (e) {
      print('❌ Background sync error: $e');
      _statusController.add(EventSyncStatus.error(e.toString()));

      // Re-queue failed events untuk retry
      _pendingSyncEvents.addAll(eventsToSync);
      _startRetryTimer();
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync single event berdasarkan action type
  Future<void> _syncSingleEvent(CalendarEvent event) async {
    final actionString = event.additionalData?['_syncAction'] as String?;
    final action = SyncAction.values.firstWhere(
      (a) => a.name == actionString,
      orElse: () => SyncAction.update,
    );

    print('🔄 Syncing ${action.name}: ${event.title}');
    _statusController.add(EventSyncStatus.syncing(event.id, action));

    try {
      switch (action) {
        case SyncAction.create:
          await _repository.createEvent(event);
          break;
        case SyncAction.update:
          await _repository.updateEvent(event);
          break;
        case SyncAction.delete:
          await _repository.deleteEvent(event.id);
          break;
      }

      print('✅ Synced ${action.name}: ${event.title}');
      _statusController.add(EventSyncStatus.success(event.id, action));
    } catch (e) {
      print('❌ Sync failed for ${event.title}: $e');
      _statusController
          .add(EventSyncStatus.failed(event.id, action, e.toString()));
      rethrow;
    }
  }

  /// Start retry timer untuk failed syncs
  void _startRetryTimer() {
    Timer(const Duration(seconds: 30), () {
      if (_pendingSyncEvents.isNotEmpty) {
        print('🔄 Retrying failed syncs...');
        _processSyncQueue();
      }
    });
  }

  /// Manual flush queue (untuk testing atau immediate sync)
  Future<void> flushQueue() async {
    _syncTimer?.cancel();
    await _processSyncQueue();
  }

  /// Clear all pending syncs
  void clearQueue() {
    _pendingSyncEvents.clear();
    _syncTimer?.cancel();
    print('🗑️ Sync queue cleared');
  }

  /// Get current queue status
  Map<String, dynamic> getQueueStatus() {
    return {
      'pendingCount': _pendingSyncEvents.length,
      'isSyncing': _isSyncing,
      'pendingEvents': _pendingSyncEvents
          .map((e) => {
                'id': e.id,
                'title': e.title,
                'action': e.additionalData?['_syncAction'],
                'queueTime': e.additionalData?['_queueTime'],
              })
          .toList(),
    };
  }

  void dispose() {
    _syncTimer?.cancel();
    _statusController.close();
    _instance = null;
  }
}

enum SyncAction { create, update, delete }

class EventSyncStatus {
  final String type;
  final String? eventId;
  final SyncAction? action;
  final String? message;
  final int? count;

  const EventSyncStatus._({
    required this.type,
    this.eventId,
    this.action,
    this.message,
    this.count,
  });

  factory EventSyncStatus.queued(String eventId, SyncAction action) =>
      EventSyncStatus._(type: 'queued', eventId: eventId, action: action);

  factory EventSyncStatus.syncing(String eventId, SyncAction action) =>
      EventSyncStatus._(type: 'syncing', eventId: eventId, action: action);

  factory EventSyncStatus.success(String eventId, SyncAction action) =>
      EventSyncStatus._(type: 'success', eventId: eventId, action: action);

  factory EventSyncStatus.failed(
          String eventId, SyncAction action, String error) =>
      EventSyncStatus._(
          type: 'failed', eventId: eventId, action: action, message: error);

  factory EventSyncStatus.completed(int count) =>
      EventSyncStatus._(type: 'completed', count: count);

  factory EventSyncStatus.error(String error) =>
      EventSyncStatus._(type: 'error', message: error);

  // ✅ ADDED: Status untuk skip authentication
  factory EventSyncStatus.skipped(
          String eventId, SyncAction action, String reason) =>
      EventSyncStatus._(
          type: 'skipped', eventId: eventId, action: action, message: reason);

  @override
  String toString() =>
      'EventSyncStatus(type: $type, eventId: $eventId, action: $action, message: $message)';
}
