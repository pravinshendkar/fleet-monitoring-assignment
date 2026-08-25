# Bytebeam Fleet Console (Local-First EV Fleet Management)

A high-performance, local-first Electric Vehicle (EV) fleet management console built with **Flutter**, **Clean Architecture**, and an embedded **DuckDB C FFI** database engine.

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
* **Event-Time Telemetry Pipeline**: Packets can arrive late and out-of-order. All domain rules (alert escalation, geofence hysteresis, and trip boundaries) evaluate telemetry based on `event_timestamp` rather than ingestion order.

---

## 2. Core Features Overview

* 🚐 **Fleet Home**: Real-time status count chips (`MOVING`, `IDLE`, `STOPPED`, `CHARGING`), vehicle search, status filtering, and SQL-paginated list rendering.
* ⚡ **Vehicle Detail**: Real-time telemetry pings, signal freshness/staleness verdicts (> 10 mins old), and chronological SOC battery history timeline.
* ⚠️ **Alert Lifecycle**: SOC < 20% (Warning), SOC < 10% (Critical), and Temp > 45°C (Critical) alert escalation. Supports alert dismissal with mandatory reason selection, a 5-second SnackBar **UNDO** option, and resolution handling.
* 📍 **Geofence Management**: Create, edit, and deactivate geofences. Uses Haversine distance calculations and a **2-consecutive-ping hysteresis strategy** to prevent GPS jitter from triggering false transitions.
* 🗺️ **Automatic Trips**: Derived automatically from confirmed geofence `EXIT` and `ENTRY` events. Supports single active trip constraints, origin-return trips, and late `EXIT`/`ENTRY` event boundary revisions with Haversine distance, max speed, and SOC consumption recalculation.

---

## 3. Setup & Quickstart Guide

### Prerequisites
* Flutter SDK (`^3.24.0` / `3.41.6`)
* Dart SDK (`^3.5.0`)
* C Compiler toolchain (`gcc` / `g++` / build-essential on Linux desktop)

### Installation & Execution Commands

```bash
# 1. Install dependencies
flutter pub get

# 2. Run static analysis (0 errors guaranteed)
dart analyze

# 3. Run full automated test suite (75 passing tests)
flutter test

# 4. Launch the application on Linux Desktop
flutter run -d linux

# 5. Run the dedicated 2,000,000 row scale benchmark script
dart run bin/run_scale_benchmark.dart
```

---

## 4. 30-Second Feature Tour

Follow this step-by-step sequence when testing the application:

1. **Launch App**: Open `Fleet Console`. The application bootstraps DuckDB, seeds the initial development fleet, and paints `FleetHomeView`.
2. **View Summary Chips**: Observe the live status count chips (`ALL`, `MOVING`, `IDLE`, `STOPPED`, `CHARGING`) generated via SQL queries.
3. **Filter Vehicles**: Tap the `MOVING` chip or type `EV-001` in the search bar to filter the paginated list.
4. **Open Vehicle Detail**: Tap any vehicle card to navigate to `VehicleDetailView`.
5. **Inspect Signals & SOC History**: View signal freshness verdicts (NORMAL/STALE) and the chronological SOC history table.
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

**Result**: **75 / 75 tests passing** across 12 test files covering domain rules, use cases, repositories, DuckDB persistence, late-event handling, Cubit states, and Widget UI views.

---

## 6. Performance & Scale Benchmark Summary

* **Dataset Size**: **500 Electric Vehicles, 2,000,000 Telemetry Signal Rows**
* **Cold-Start Duration**: **362 ms** (Linux x86_64 reference)
* **Fleet Query Latency (p50)**: **7 ms**
* **Fleet Query Latency (p95)**: **10 ms**
* **Process Memory (RSS)**: **367.4 MB**

Full empirical methodology and query index optimizations are documented in [docs/performance_benchmark.md](file:///home/pravin/Pravin/flutter_projects/fleet_console/docs/performance_benchmark.md).

---

## 7. Telemetry Retention & Compaction Policy

High-frequency telemetry is governed by a **30-Day Rolling Telemetry Retention Policy**:
* Detailed sub-minute raw telemetry packets older than 30 days are compacted into hourly SOC summary points and deleted.
* 100% of historical completed trips, geofence transition events, alert logs, and vehicle states are preserved permanently.

Full policy specification and trade-off analysis are documented in [docs/retention_policy.md](file:///home/pravin/Pravin/flutter_projects/fleet_console/docs/retention_policy.md).

---

## 8. Scope & Cut Decisions

1. **Android Benchmark Limitation**:  
   * *Cut Decision*: Performed scale benchmark on Linux x86_64 desktop reference environment; Android benchmark was not performed.
   * *Rationale*: No physical Android device was connected via USB ADB, no pre-installed AVD system images existed on host (`flutter emulators` returned "No emulators available"), and upstream `dart_duckdb: ^1.2.0` Gradle scripts fail downloading prebuilt Android native binaries (`libduckdb-android_arm64-v8a.zip` 404).
2. **Geofence Map Component**:  
   * *Cut Decision*: Implemented coordinate/radius form inputs instead of embedding third-party Google Maps tiles.
   * *Rationale*: Avoids external API key dependencies and ensures 100% offline, reproducible testing.
3. **Retention Compaction Deployment**:  
   * *Cut Decision*: retention policy and compaction SQL are documented as production maintenance specifications rather than running destructive cleanup during local developer sessions.

---

## 9. AI Assistant Disclosure

As permitted by the assignment guidelines, AI coding assistants (Gemini / Antigravity pair programmer) were utilized during development for code generation, test suite expansion, and design verification. The complete, uncurated step-by-step conversation trajectory is preserved in the local environment logs.
