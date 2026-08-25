import 'dart:async';

/// DatabaseEventBus provides a signal stream whenever database records are mutated.
/// Cubits listen to this event bus to re-query DuckDB reactively.
class DatabaseEventBus {
  final StreamController<DatabaseChangeEvent> _controller =
      StreamController<DatabaseChangeEvent>.broadcast();

  Stream<DatabaseChangeEvent> get stream => _controller.stream;

  void notify(DatabaseChangeEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() {
    _controller.close();
  }
}

enum DatabaseTable { telemetry, vehicles, alerts, geofences, trips, all }

class DatabaseChangeEvent {
  final DatabaseTable table;
  final String? entityId;
  final DateTime timestamp;

  DatabaseChangeEvent({
    required this.table,
    this.entityId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
