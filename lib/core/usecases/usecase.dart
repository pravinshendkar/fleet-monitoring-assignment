import 'package:equatable/equatable.dart';

abstract class UseCase<TResult, Params> {
  Future<TResult> call(Params params);
}

class NoParams extends Equatable {
  @override
  List<Object?> get props => [];
}
