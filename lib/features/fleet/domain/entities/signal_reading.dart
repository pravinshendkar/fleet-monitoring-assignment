import 'package:equatable/equatable.dart';

enum SignalVerdict {
  normal,
  alert,
  stale,
  none, // Never reported
}

class SignalReading extends Equatable {
  final String label;
  final String displayValue;
  final DateTime? timestamp;
  final SignalVerdict verdict;
  final String? alertMessage;

  const SignalReading({
    required this.label,
    required this.displayValue,
    this.timestamp,
    required this.verdict,
    this.alertMessage,
  });

  bool get hasReported => timestamp != null && displayValue != '—';

  String get ageString {
    if (timestamp == null) return 'Never';
    final diff = DateTime.now().difference(timestamp!);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  List<Object?> get props => [label, displayValue, timestamp, verdict, alertMessage];
}

class SocPoint extends Equatable {
  final DateTime timestamp;
  final double soc;

  const SocPoint({
    required this.timestamp,
    required this.soc,
  });

  @override
  List<Object?> get props => [timestamp, soc];
}
