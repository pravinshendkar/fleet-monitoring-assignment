# Telemetry Retention & Compaction Policy

**Project**: Fleet Console ("Fleet Console (Local-First)")  
**Date**: August 25, 2026  
**Milestone**: Scale Benchmark, Performance Measurement, and Retention Policy  

---

> [!IMPORTANT]
> **Implementation Status Notice**:  
> The 30-day rolling retention policy is the proposed production policy for this take-home assignment. Automatic compaction/deletion is documented as a design specification but is **NOT implemented in the current application scope** to prevent deleting development seed data during local test sessions.

---

## 1. Overview & Policy Rationale

In a local-first mobile fleet application managing 500 electric vehicles streaming telemetry every 10–15 seconds, raw high-frequency telemetry grows by approximately **3 to 4 million rows per day (~500 MB/day)**. Allowing local storage to grow infinitely on mobile devices would cause storage exhaustion and performance degradation.

This document outlines the **30-Day Rolling Telemetry Retention Policy** designed for the Fleet Console.

---

## 2. Retention Windows & Policy Rules

| Telemetry Data Category | Retention Window | Policy Action After Window | Rationale |
| :--- | :--- | :--- | :--- |
| **High-Frequency Raw Telemetry** (`telemetry_packets`) | **30 Days** | Deleted / Compacted | Detailed sub-minute GPS pings & speed packets are only needed for real-time operation and recent diagnostics. |
| **Completed Trips** (`trips`) | **Permanent (Infinite)** | Preserved 100% | Historical trip boundaries (`start_time`, `end_time`, `start_geofence_id`, `end_geofence_id`), distance, max speed, and SOC used remain fully intact forever. |
| **Historical Geofence Transitions** (`geofence_events`) | **Permanent (Infinite)** | Preserved 100% | Geofence entry and exit events (`evt_entry_*`, `evt_exit_*`) remain permanently stored to back historical trips. |
| **Alert History & Dismissals** (`alerts`) | **Permanent (Infinite)** | Preserved 100% | Critical battery warnings, overheating alerts, dismissal reasons, and resolution states are preserved permanently for audit logs. |
| **Aggregated SOC Points** | **Hourly Averages (1 Year)** | Compacted from raw | Hourly average SOC readings are computed before deleting raw telemetry to allow long-term vehicle battery degradation charting. |

---

## 3. Compaction Implementation & SQL Execution Strategy

When implemented in production, compaction would run periodically as a background maintenance task during local database maintenance windows:

```sql
-- 1. Create hourly SOC aggregate summaries for records older than 30 days
INSERT INTO soc_hourly_aggregates (vehicle_id, hour_timestamp, avg_soc, min_soc, max_soc)
SELECT 
  vehicle_id, 
  date_trunc('hour', event_timestamp) as hour_timestamp,
  AVG(battery_level) as avg_soc,
  MIN(battery_level) as min_soc,
  MAX(battery_level) as max_soc
FROM telemetry_packets
WHERE event_timestamp < (now() - INTERVAL '30 DAY')
GROUP BY vehicle_id, date_trunc('hour', event_timestamp)
ON CONFLICT (vehicle_id, hour_timestamp) DO NOTHING;

-- 2. Delete raw sub-second/sub-minute telemetry packets older than 30 days
DELETE FROM telemetry_packets
WHERE event_timestamp < (now() - INTERVAL '30 DAY');

-- 3. Reclaim DuckDB storage space
CHECKPOINT;
```

---

## 4. Explicit Trade-Offs & Data Impact Analysis

### What the Application Retains:
* ✅ 100% of historical trips (with start/end geofences, total distance, max speed, and SOC consumed).
* ✅ 100% of geofence entry/exit transition events.
* ✅ 100% of alert logs (including severity, trigger values, dismissal reasons, and resolution times).
* ✅ Current vehicle state (`last_seen_at`, `status`, `last_soc`, `last_latitude`, `last_longitude`).
* ✅ Long-term hourly SOC trend lines for vehicle health analytics.

### What the Application Loses After 30 Days:
* ⚠️ Sub-minute granular GPS breadcrumbs (e.g. 10-second ping coordinates) for dates older than 30 days.
* ⚠️ Replayability of sub-minute speed spikes on historical trips older than 30 days.

### Why This Policy Is Appropriate:
Bounding raw telemetry retention to 30 days limits local storage growth while guaranteeing zero loss of operational fleet summary analytics, trip records, or safety alert history.
