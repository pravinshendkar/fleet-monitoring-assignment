# Fleet Console (Local-First EV Fleet Management)

A high-performance, local-first Electric Vehicle (EV) fleet management console application built with **Flutter**, **Clean Architecture**, **BLoC/Cubit**, and an embedded **DuckDB C FFI** database engine.

---

## 1. Architecture & Local-First Design

```
Flutter UI (Views)
      ↓
Cubit (State Management)
      ↓
Domain Use Cases (Business Logic & Event Rules)
      ↓
Repository Contracts (Abstraction Layer)
      ↓
Data Sources (DuckDB SQL Local Persistence & Event Bus)
      ↓
DuckDB C FFI Engine (Single Source of Truth)
```

### Why Local-First with DuckDB?
* **DuckDB as Single Source of Truth**: The local embedded DuckDB database stores all vehicles, telemetry packets, geofences, geofence events, alerts, and automatic trips. The application does not maintain an in-memory shadow list of vehicles.
* **SQL Aggregation at Scale**: Status counts, geofence vehicle occupancy, and paginated vehicle lists execute directly in DuckDB SQL C/C++ primitives rather than loading millions of rows into Dart memory.
* **Event-Time Telemetry Pipeline & Independent Signals**: Telemetry packets can arrive late, out-of-order, or as partial signal updates. All domain rules (alert escalation, geofence hysteresis, trip boundaries, and per-signal freshness checks) evaluate telemetry strictly based on `event_timestamp` and per-signal timestamps rather than overall ingestion order.

---

## 2. Core Features Overview

* 🚐 **Fleet Home**: Real-time status count chips (`ALL`, `OFFLINE`, `MOVING`, `IDLE`, `STOPPED`), vehicle search, status filtering, and SQL-paginated infinite scrolling list rendering.
* ⚡ **Vehicle Detail**: Real-time telemetry pings, independent signal freshness/staleness verdicts (SOC, Speed, Temp, Odometer tracked separately), and chronological SOC battery history timeline.
* ⚠️ **Alert Lifecycle**: SOC < 20% (Warning), SOC < 10% (Critical), and Temp > 45°C (Critical) alert escalation with out-of-order packet deduplication. Supports alert dismissal with mandatory reason selection, a 5-second SnackBar **UNDO** option, and resolution handling.
* 📍 **Geofence Management**: Create, edit, and deactivate geofences. Uses Haversine distance calculations and a **2-consecutive-ping hysteresis strategy** to prevent GPS jitter from triggering false transitions.
* 🗺️ **Automatic Trips**: Derived automatically from confirmed geofence `EXIT` and `ENTRY` events. Supports single active trip constraints, origin-return trips, and late `EXIT`/`ENTRY` event boundary revisions with Haversine distance, max speed, and SOC consumption recalculation.

---

## 3. Setup & Quickstart Guide

### Prerequisites
* Flutter SDK (`^3.24.0` / `3.41.6`)
* Dart SDK (`^3.5.0`)
* Target platform toolchain (Android Studio / Xcode / Chrome / Build Essential)

### Installation & Execution Commands

```bash
# 1. Install dependencies
flutter pub get

# 2. Run static analysis (0 errors guaranteed)
dart analyze

# 3. Run full automated test suite
flutter test

# 4. Launch the application on your target platform:

# Android (Device or Emulator)
flutter run -d android

# iOS (Device or Simulator - macOS required)
flutter run -d ios

# Web Browser
flutter run -d chrome

# Desktop (Linux / macOS / Windows)
flutter run -d linux

# 5. Run the dedicated 2,000,000 row scale benchmark script
dart run bin/run_scale_benchmark.dart
```

---

## 4. 30-Second Feature Tour

Follow this step-by-step sequence when testing the application:

1. **Launch App**: Open `Fleet Console`. The application bootstraps DuckDB, seeds the initial development fleet, and paints `FleetHomeView`.
2. **View Summary Chips**: Observe the live status count chips (`ALL`, `OFFLINE`, `MOVING`, `IDLE`, `STOPPED`) generated via SQL queries.
3. **Filter Vehicles**: Tap the `MOVING` chip or type `EV-001` in the search bar to filter the paginated list.
4. **Open Vehicle Detail**: Tap any vehicle card to navigate to `VehicleDetailView`.
5. **Inspect Signals & SOC History**: View independent signal freshness verdicts (NORMAL/STALE) and the chronological SOC history table.
6. **Open Alerts View**: Tap the `Alerts` icon in the top action bar to open `AlertsView`.
7. **Dismiss & Undo Alert**: Tap `Dismiss` on an active alert, select a dismissal reason (e.g. *Maintenance In Progress*), confirm dismissal, and tap **UNDO** on the 5-second SnackBar to restore it.
8. **Open Geofences View**: Tap the `Geofences` icon in the top action bar to view active/inactive geofences and current vehicle counts.
9. **Create Geofence**: Tap `+ Add Geofence`, enter a name (e.g. *Central Hub*), coordinates (`12.9716`, `77.5946`), radius (`500m`), and save.
10. **Open Trips View**: Tap the `Trips` icon in the top action bar to view automatically generated trips, route headers (`Warehouse → Station`), status chips (`IN_PROGRESS`/`COMPLETED`), and metric summaries (Distance, Max Speed, SOC used).

---

## 5. Test Suite Verification

Run the full test suite using:
```bash
flutter test
```

**Result**: Automated tests passing across all test files covering domain rules, use cases, repositories, DuckDB persistence, late-event handling, Cubit states, and Widget UI views.

---

## 6. Performance & Scale Benchmark Summary

### Measured Linux Reference Benchmark
* **Scale Dataset**: **500 Electric Vehicles, 2,000,000 Telemetry Signal Rows**
* **Cold Start / Process Init**: **362 ms** (Dart Process + DuckDB Init + Initial Fleet Query)
* **Fleet Query Latency (p50)**: **7 ms**
* **Fleet Query Latency (p95)**: **10 ms**
* **Process Memory (RSS)**: **367.4 MB**

### Android Benchmark Status: Not Measured
The Android benchmark was not performed because the execution environment lacked a connected Android device or pre-installed AVD emulator images, and upstream `dart_duckdb: ^1.2.0` Gradle scripts failed downloading prebuilt Android C binary ZIPs.

Full empirical methodology and query index optimizations are documented in [docs/performance_benchmark.md](docs/performance_benchmark.md).

---

## 7. Telemetry Retention & Compaction Policy

High-frequency telemetry is governed by a **30-Day Rolling Telemetry Retention Policy**:
* The 30-day rolling retention policy is the proposed production policy for this application. Automatic compaction/deletion is documented as a design specification but is **NOT implemented in the current application scope** to prevent deleting development seed data during local test sessions.
* Detailed sub-minute raw telemetry packets older than 30 days are specified for compaction into hourly SOC summary points and deletion.
* 100% of historical completed trips, geofence transition events, alert logs, and vehicle states are preserved permanently.

Full policy specification and trade-off analysis are documented in [docs/retention_policy.md](docs/retention_policy.md).

---

## 8. Scope & Cut Decisions

1. **Android Benchmark Limitation**:
   * *Cut Decision*: Performed scale benchmark on Linux x86_64 desktop reference environment; Android benchmark was not performed.
   * *Rationale*: No physical Android device was connected via USB ADB, no pre-installed AVD system images existed on host (`flutter emulators` returned "No emulators available"), and upstream `dart_duckdb: ^1.2.0` Gradle scripts fail downloading prebuilt Android native binaries (`libduckdb-android_arm64-v8a.zip` 404).
2. **Geofence Map Component**:
   * *Cut Decision*: Implemented coordinate/radius form inputs instead of embedding third-party Google Maps tiles.
   * *Rationale*: Avoids external API key dependencies and ensures 100% offline, reproducible testing.
3. **Retention Compaction Deployment**:
   * *Cut Decision*: Retention policy and compaction SQL are documented as production maintenance specifications rather than running destructive cleanup during local developer sessions.

---

## 9. Portfolio Presentation

This repository is presented as a clean, production-grade Flutter portfolio project demonstrating enterprise architecture, local-first analytical database integration with DuckDB, real-time telemetry processing, geofencing algorithms, and state management best practices.
