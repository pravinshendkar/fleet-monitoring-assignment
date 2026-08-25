# Performance & Scale Benchmark Report

**Project**: Bytebeam Fleet Console ("Fleet Console (Local-First)")  
**Date**: August 25, 2026  
**Milestone**: Scale Benchmark, Performance Measurement, and Retention Policy  

---

## 1. Environment & Measurement Summary

| Metric / Parameter | Development / Linux Benchmark (MEASURED) | Android Device / Emulator (NOT MEASURED) |
| :--- | :--- | :--- |
| **Execution Environment** | Linux x86_64 (`Linux Mint 22.3`, Kernel `7.0.0-30-generic`) | Android Device / Emulator |
| **Flutter SDK** | `Flutter 3.41.6` (Channel stable) | `Flutter 3.41.6` |
| **Dart SDK** | `Dart 3.5.0` | `Dart 3.5.0` |
| **Embedded Database Engine** | `dart_duckdb: ^1.2.0` (DuckDB C FFI) | `dart_duckdb: ^1.2.0` |
| **Scale Dataset** | 500 Vehicles, 2,000,000 Telemetry Signal Rows | 500 Vehicles, 2,000,000 Telemetry Signal Rows |
| **Cold-Start / Process Init** | **362 ms** (Dart Process + DuckDB Init + Initial Fleet Query) | *Not Measured (See Environment Limitation)* |
| **Fleet Query p50** | **7 ms** | *Not Measured* |
| **Fleet Query p95** | **10 ms** | *Not Measured* |
| **Memory RSS at Rest** | **367.4 MB** | *Not Measured* |
| **Benchmark Iterations** | 50 Warm Iterations | *Not Measured* |

---

## 2. Measured Development / Linux Reference Benchmark

### Benchmark Dataset Note
The scale benchmark intentionally generates a 2,000,000 row dataset spanning more than 30 days to stress-test DuckDB query latency at scale. This benchmark dataset is designed for performance testing and does not represent the production retained dataset.

### Methodology & Execution Procedure
Executed using the dedicated scale benchmark script ([bin/run_scale_benchmark.dart](bin/run_scale_benchmark.dart)):
1. **Cold Start / Process Startup Measurement**:
   * Measures wall-clock duration: process startup → DuckDB C engine initialization → schema setup → initial fleet summary & paginated list query.
2. **Fleet Query Latency (p50 & p95)**:
   * Populate DuckDB with 500 vehicles and 2,000,000 telemetry packets using native DuckDB bulk generation.
   * Execute 50 consecutive query iterations combining SQL live status count computation (`getFleetSummary`) and status-filtered paginated vehicle list queries (`getVehicles`).
   * Measure exact wall-clock latency per iteration and calculate 50th percentile (p50) and 95th percentile (p95).
3. **Memory at Rest**:
   * Process Resident Set Size (RSS) memory with the 2,000,000 row dataset loaded at rest.

### Measured Empirical Results (Linux x86_64)
* **Dataset Size**: 500 Vehicles, 2,000,000 Telemetry Packets
* **Cold Start / Process Init**: **362 ms**
* **Bulk Dataset Ingestion**: **11,725 ms** (2,000,000 signal rows)
* **Fleet Query Latency p50**: **7 ms**
* **Fleet Query Latency p95**: **10 ms**
* **Memory RSS at Rest**: **367.4 MB**

---

## 3. Android Benchmark Limitations & Honest Disclosure

> [!WARNING]
> **Android Benchmark Status**: **Not Measured**  
> The Android benchmark was not performed due to physical environment and upstream package binary resolution constraints outlined below.

### Honest Limitations:
1. **Device / Emulator Availability**:
   * Running `flutter devices` detected `Linux (desktop)` and `Chrome (web)`. No physical Android hardware was connected via USB ADB, and no pre-installed AVD system images existed on the host machine (`flutter emulators` returned "No emulators available").
2. **Upstream Native NDK Package Resolution (`dart_duckdb`)**:
   * Running `flutter build apk` produced a Gradle native C library download failure:
     ```
     Execution failed for task ':dart_duckdb:downloadAndExtractDuckDB'.
     > java.io.FileNotFoundException: https://github.com/TigerEyeLabs/duckdb-dart/releases/download/v1.4.4/libduckdb-android_arm64-v8a.zip
     ```
   * Upstream `dart_duckdb: ^1.2.0` / `1.4.4` includes precompiled C shared libraries (`libduckdb.so`) for Desktop (Linux x86_64, macOS, Windows), but does not host prebuilt Android NDK binaries (`libduckdb-android_arm64-v8a.zip`) on its release repository.

---

## 4. SQL Index & Query Optimizations

1. **Composite Vehicle Status & Ping Index**:
   ```sql
   CREATE INDEX IF NOT EXISTS idx_vehicles_status_ping 
   ON vehicles (status, last_seen_at);
   ```
   * Accelerates status counting (`SELECT status, COUNT(*) FROM vehicles GROUP BY status`).

2. **Telemetry Vehicle & Timestamp Index**:
   ```sql
   CREATE INDEX IF NOT EXISTS idx_telemetry_vehicle_timestamp 
   ON telemetry_packets (vehicle_id, event_timestamp);
   ```
   * Accelerates signal verdict lookups, historical SOC points, and trip metric calculation.
