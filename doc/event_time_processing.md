# Deterministic Event-Time Telemetry & Geofence Transition Strategy

This document outlines the explicit strategies employed by Fleet Console for handling real-world IoT telemetry anomalies.

---

## 1. Raw Observation vs. Confirmed Transition

* **`TelemetryPacket` / Location Observation**: Raw GPS telemetry emitted by a vehicle (lat, lng, speed, SOC, temp, timestamp, accuracy).
* **`GeofenceTransition` (ENTER / EXIT)**: A confirmed domain event generated only after spatial filtering, accuracy checks, and hysteresis conditions are satisfied.

---

## 2. Telemetry Anomaly Strategies

### A. Duplicate Packets
* **Strategy**: Primary deduplication occurs using unique `packet_id` (UUID or deterministic hash of `vehicle_id + event_timestamp`).
* **Storage**: DuckDB enforces `INSERT INTO telemetry_packets ... ON CONFLICT (packet_id) DO NOTHING`.
* **State Impact**: Duplicate packets yield zero database mutations and trigger zero new geofence transitions or trips.

### B. Late & Out-of-Order Packets
* **Strategy**: Telemetry ingest pipeline sorts every incoming batch by `event_timestamp` ascending before executing domain evaluation.
* **Vehicle State Update**: `vehicles` table `last_seen_at` and `last_soc` only update if `event_timestamp >= current_last_seen_at`.
* **Trip Re-evaluation**: Late packets arriving after a trip was completed trigger a boundary check to recalculate total distance and max speed without generating duplicate trips.

### C. Inaccurate GPS Readings
* **Strategy**: Packets with `gps_accuracy > 50.0` meters or negative/invalid coordinates are flagged as untrusted and excluded from geofence spatial detection.

### D. GPS Jitter & Spatial Hysteresis
* **Strategy**: Spatial boundary flickering is prevented using distance hysteresis:
  * **ENTER Confirmation**: Vehicle must be within `radius` for 2 consecutive ordered telemetry readings.
  * **EXIT Confirmation**: Vehicle must be outside `radius + 50.0` meters for 2 consecutive ordered telemetry readings.

### E. Overlapping Geofences
* **Strategy**: Geofence presence is maintained independently as state tuples: `(vehicle_id, geofence_id)`.
* A vehicle inside two overlapping geofences (e.g. "North Region" and "Depot A") produces active transitions for both geofences independently.

### F. Missing Intervals / Disconnections
* **Strategy**: If a vehicle loses connectivity and reconnects at a distant location, missing intervals are inferred. An `EXIT` is confirmed for the former geofence, completing the previous trip and starting a new trip from the current exit/entry point.

### G. Geofence Edits & Deactivation
* **Strategy**:
  * Deactivated geofences (`is_active = false`) are ignored during transition detection.
  * Modifying a geofence definition (center/radius) applies to subsequent telemetry evaluation; previously completed trips remain intact.
