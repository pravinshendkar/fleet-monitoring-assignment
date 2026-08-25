import 'package:flutter/material.dart';
import 'dependency_container.dart';

class DependencyProvider extends InheritedWidget {
  final DependencyContainer container;

  const DependencyProvider({
    super.key,
    required this.container,
    required super.child,
  });

  static DependencyContainer of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<DependencyProvider>();
    assert(provider != null, 'No DependencyProvider found in context');
    return provider!.container;
  }

  @override
  bool updateShouldNotify(DependencyProvider oldWidget) => container != oldWidget.container;
}
