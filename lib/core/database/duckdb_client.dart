import 'dart:io';
import 'package:dart_duckdb/dart_duckdb.dart';
// ignore: implementation_imports
import 'package:dart_duckdb/src/ffi/load_library.dart' as duck_load;
import 'duckdb_tables.dart';

class DuckDbClient {
  Database? _db;
  Connection? _connection;

  Future<void> init([String path = 'fleet_console.duckdb']) async {
    if (Platform.isLinux) {
      try {
        final libPath = '${Directory.current.path}/build/linux/x64/debug/bundle/lib/libduckdb.so';
        if (File(libPath).existsSync()) {
          duck_load.open.overrideFor(OperatingSystem.linux, libPath);
        }
      } catch (_) {
        // Ignore fallback if library already bound
      }
    }

    _db = await duckdb.open(path);
    _connection = await duckdb.connect(_db!);
    await _createTables();
  }

  Connection get connection {
    if (_connection == null) {
      throw StateError('DuckDbClient is not initialized. Call init() first.');
    }
    return _connection!;
  }

  Future<void> _createTables() async {
    final conn = connection;
    await conn.execute(DuckDbTables.createTelemetryPacketsTable);
    await conn.execute(DuckDbTables.createTelemetryIndex);
    await conn.execute(DuckDbTables.createVehiclesTable);
    await conn.execute(DuckDbTables.createVehiclesIndex);
    await conn.execute(DuckDbTables.createAlertsTable);
    await conn.execute(DuckDbTables.createAlertsIndex);
    await conn.execute(DuckDbTables.createGeofencesTable);
    await conn.execute(DuckDbTables.createGeofenceEventsTable);
    await conn.execute(DuckDbTables.createTripsTable);
    await conn.execute(DuckDbTables.createTripsIndex);
  }

  Future<List<Map<String, dynamic>>> query(String sql) async {
    final conn = connection;
    final resultSet = await conn.query(sql);
    final names = resultSet.columnNames;
    final rows = resultSet.fetchAll();
    await resultSet.dispose();

    return rows.map((row) {
      final map = <String, dynamic>{};
      for (var i = 0; i < names.length; i++) {
        map[names[i]] = row[i];
      }
      return map;
    }).toList();
  }

  Future<void> execute(String sql) async {
    final conn = connection;
    await conn.execute(sql);
  }

  Future<void> close() async {
    await _connection?.dispose();
    await _db?.dispose();
    _connection = null;
    _db = null;
  }
}
