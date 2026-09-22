import 'package:flutter_riverpod/flutter_riverpod.dart';

class PowerChangeEvent {
  const PowerChangeEvent({
    required this.oldPower,
    required this.newPower,
  });

  final int oldPower;
  final int newPower;

  int get delta => newPower - oldPower;
  bool get isIncrease => delta > 0;
}

class PowerChangeNotifier extends Notifier<PowerChangeEvent?> {
  @override
  PowerChangeEvent? build() => null;

  void emit({required int oldPower, required int newPower}) {
    if (oldPower == newPower) return;
    state = PowerChangeEvent(oldPower: oldPower, newPower: newPower);
  }

  void clear() => state = null;
}

final NotifierProvider<PowerChangeNotifier, PowerChangeEvent?> powerChangeProvider =
    NotifierProvider<PowerChangeNotifier, PowerChangeEvent?>(
  PowerChangeNotifier.new,
);
