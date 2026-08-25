import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/alert.dart';
import '../cubits/alerts/alerts_cubit.dart';
import '../cubits/alerts/alerts_state.dart';
import '../widgets/dismiss_reason_sheet.dart';

class AlertsView extends StatefulWidget {
  const AlertsView({super.key});

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  int _selectedTab = 0; // 0: Active, 1: All

  @override
  void initState() {
    super.initState();
    context.read<AlertsCubit>().loadAlerts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Fleet Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AlertsCubit>().loadAlerts(),
          ),
        ],
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Filter Tabs (Active vs All)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(
                        value: 0,
                        label: Text('Active Alerts'),
                        icon: Icon(Icons.notifications_active, size: 18),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        label: Text('All Alerts'),
                        icon: Icon(Icons.history, size: 18),
                      ),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (Set<int> newSelection) {
                      setState(() {
                        _selectedTab = newSelection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main Alerts Body
          Expanded(
            child: BlocConsumer<AlertsCubit, AlertsState>(
              listener: (context, state) {
                if (state is AlertsLoaded && state.showUndoBanner) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Alert dismissed.'),
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'UNDO',
                        onPressed: () {
                          context.read<AlertsCubit>().undoDismissal();
                        },
                      ),
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is AlertsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is AlertsError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(state.message, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () =>
                                context.read<AlertsCubit>().loadAlerts(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state is AlertsLoaded) {
                  final list = _selectedTab == 0
                      ? state.activeAlerts
                      : state.allAlerts;

                  if (list.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    itemCount: list.length,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    itemBuilder: (context, index) {
                      final alert = list[index];
                      return _buildAlertCard(context, alert);
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, Alert alert) {
    final isDismissed = alert.status == AlertStatus.dismissed;
    final isResolved = alert.status == AlertStatus.resolved;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDismissed
              ? Colors.grey.withValues(alpha: 0.2)
              : (alert.isCritical
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.amber.withValues(alpha: 0.3)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Vehicle ID & Severity Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      alert.isCritical
                          ? Icons.error
                          : Icons.warning_amber_rounded,
                      color: isDismissed
                          ? Colors.grey
                          : (alert.isCritical ? Colors.red : Colors.amber[800]),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Vehicle: ${alert.vehicleId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                _buildSeverityChip(alert),
              ],
            ),
            const SizedBox(height: 10),

            // Description / Trigger Details
            Text(
              _getAlertDescription(alert),
              style: TextStyle(
                fontSize: 14,
                color: isDismissed ? Colors.grey[600] : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),

            Text(
              'Current reading: ${_formatValue(alert)} (Threshold: ${_formatThreshold(alert)})',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),

            if (isDismissed && alert.dismissalReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Dismissal reason: "${alert.dismissalReason}"',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Bottom Action Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Updated ${_formatAge(alert.updatedAt)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),

                if (!isDismissed && !isResolved)
                  TextButton.icon(
                    onPressed: () {
                      _showDismissReasonSheet(context, alert);
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Dismiss'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityChip(Alert alert) {
    if (alert.status == AlertStatus.resolved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'RESOLVED',
          style: TextStyle(
            color: Colors.green,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (alert.status == AlertStatus.dismissed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'DISMISSED',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final isCrit = alert.isCritical;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCrit
            ? Colors.red.withValues(alpha: 0.12)
            : Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        alert.severityLabel,
        style: TextStyle(
          color: isCrit ? Colors.red[800] : Colors.amber[900],
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showDismissReasonSheet(BuildContext context, Alert alert) {
    final cubit = context.read<AlertsCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DismissReasonSheet(
        onReasonSelected: (reason) {
          cubit.dismissAlert(alert, reason);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No Alerts Detected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'All vehicles are operating within normal battery and temperature parameters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  String _getAlertDescription(Alert alert) {
    switch (alert.type) {
      case AlertType.lowBattery:
      case AlertType.criticalBattery:
        return alert.isCritical
            ? 'Critical Low Battery Alert'
            : 'Low Battery Warning';
      case AlertType.overheating:
        return 'Battery Overheating Alert';
    }
  }

  String _formatValue(Alert alert) {
    if (alert.type == AlertType.overheating) {
      return '${alert.triggerValue.toStringAsFixed(1)}°C';
    }
    return '${alert.triggerValue.toStringAsFixed(0)}%';
  }

  String _formatThreshold(Alert alert) {
    if (alert.type == AlertType.overheating) {
      return '${alert.threshold.toStringAsFixed(0)}°C';
    }
    return '${alert.threshold.toStringAsFixed(0)}%';
  }

  String _formatAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
