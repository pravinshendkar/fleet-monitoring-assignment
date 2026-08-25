import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/fleet/presentation/cubits/fleet_home/fleet_home_cubit.dart';
import '../features/fleet/presentation/views/fleet_home_view.dart';
import 'di/dependency_container.dart';
import 'di/dependency_provider.dart';

class FleetConsoleApp extends StatelessWidget {
  final DependencyContainer container;

  const FleetConsoleApp({super.key, required this.container});

  @override
  Widget build(BuildContext context) {
    return DependencyProvider(
      container: container,
      child: MaterialApp(
        title: 'Fleet Console',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: BlocProvider(
          create: (context) => FleetHomeCubit(
            getFleetSummaryUseCase: container.getFleetSummaryUseCase,
            getVehiclesUseCase: container.getVehiclesUseCase,
            vehicleRepository: container.vehicleRepository,
          ),
          child: const FleetHomeView(),
        ),
      ),
    );
  }
}
