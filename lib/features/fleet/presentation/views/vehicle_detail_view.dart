import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/signal_reading.dart';
import '../../domain/entities/vehicle.dart';
import '../cubits/vehicle_detail/vehicle_detail_cubit.dart';
import '../cubits/vehicle_detail/vehicle_detail_state.dart';
import '../widgets/signal_reading_row.dart';

class VehicleDetailView extends StatefulWidget {
  final String vehicleId;

  const VehicleDetailView({
    super.key,
    required this.vehicleId,
  });

  @override
  State<VehicleDetailView> createState() => _VehicleDetailViewState();
}

class _VehicleDetailViewState extends State<VehicleDetailView> {
  @override
  void initState() {
    super.initState();
    context.read<VehicleDetailCubit>().loadVehicleDetail();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Vehicle ${widget.vehicleId}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<VehicleDetailCubit>().loadVehicleDetail(),
          ),
        ],
        elevation: 0.5,
      ),
      body: BlocBuilder<VehicleDetailCubit, VehicleDetailState>(
        builder: (context, state) {
          if (state is VehicleDetailLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is VehicleDetailError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.read<VehicleDetailCubit>().loadVehicleDetail(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is VehicleDetailLoaded) {
            final details = state.details;
            final vehicle = details.vehicle;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vehicle Summary Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.electric_car, color: Colors.blue, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle?.name ?? widget.vehicleId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${widget.vehicleId}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (vehicle != null) _buildStatusChip(vehicle.status),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Signal Readings Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Text(
                            'SIGNAL READINGS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        SignalReadingRow(signal: details.socSignal),
                        const Divider(height: 1),
                        SignalReadingRow(signal: details.rangeSignal),
                        const Divider(height: 1),
                        SignalReadingRow(signal: details.speedSignal),
                        const Divider(height: 1),
                        SignalReadingRow(signal: details.tempSignal),
                        const Divider(height: 1),
                        SignalReadingRow(signal: details.odometerSignal),
                        const Divider(height: 1),
                        SignalReadingRow(signal: details.lastPingSignal),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SOC History Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SOC HISTORY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (details.socHistory.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(
                                child: Text(
                                  'No historical SOC telemetry recorded.',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                              ),
                            )
                          else ...[
                            _buildSocHistoryTable(details.socHistory),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildStatusChip(VehicleStatus status) {
    Color bg;
    Color fg;

    switch (status) {
      case VehicleStatus.moving:
        bg = Colors.green.withValues(alpha: 0.12);
        fg = Colors.green[800]!;
        break;
      case VehicleStatus.idle:
        bg = Colors.orange.withValues(alpha: 0.12);
        fg = Colors.orange[900]!;
        break;
      case VehicleStatus.stopped:
        bg = Colors.blueGrey.withValues(alpha: 0.12);
        fg = Colors.blueGrey[800]!;
        break;
      case VehicleStatus.offline:
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red[800]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSocHistoryTable(List<SocPoint> history) {
    // Show top 10 most recent entries in descending order for table reading
    final recentHistory = history.reversed.take(10).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Timestamp (UTC)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('Battery SOC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentHistory.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final pt = recentHistory[index];
            final timeStr = '${pt.timestamp.hour.toString().padLeft(2, '0')}:${pt.timestamp.minute.toString().padLeft(2, '0')}:${pt.timestamp.second.toString().padLeft(2, '0')}';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  Text(
                    '${pt.soc.toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
