import 'package:flutter/material.dart';
import '../../domain/entities/signal_reading.dart';

class SignalReadingRow extends StatelessWidget {
  final SignalReading signal;

  const SignalReadingRow({super.key, required this.signal});

  @override
  Widget build(BuildContext context) {
    final isStale = signal.verdict == SignalVerdict.stale;
    final isNone = signal.verdict == SignalVerdict.none;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Signal Name & Age
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isStale ? Colors.grey[600] : Colors.black87,
                  ),
                ),
                if (!isNone && signal.timestamp != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Age: ${signal.ageString}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isStale ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Signal Value
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              signal.displayValue,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isStale ? Colors.grey[600] : Colors.black,
              ),
            ),
          ),

          // Verdict Pill
          _buildVerdictPill(signal),
        ],
      ),
    );
  }

  Widget _buildVerdictPill(SignalReading signal) {
    switch (signal.verdict) {
      case SignalVerdict.normal:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: const Text(
            'NORMAL',
            style: TextStyle(
              color: Colors.green,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );

      case SignalVerdict.alert:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: const Text(
            'ALERT',
            style: TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );

      case SignalVerdict.stale:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Text(
            'STALE',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );

      case SignalVerdict.none:
        return const SizedBox(
          width: 60,
        ); // Empty placeholder for never-reported signal
    }
  }
}
