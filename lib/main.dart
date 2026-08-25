import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/di/dependency_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Dependency Composition Root & Database
  final container = await DependencyContainer.create();

  // 2. Launch Application Widget
  runApp(FleetConsoleApp(container: container));
}
