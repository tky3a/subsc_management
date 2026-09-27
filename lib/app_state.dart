import 'package:flutter/widgets.dart';

import 'data/models.dart';
import 'data/repository.dart';
import 'util/format.dart';

enum Period { month, year }

/// 画面間で共有する状態。変更操作のあとは [refresh] で月次記録と表示を更新する。
class AppState extends ChangeNotifier {
  AppState(this.repo);

  final SubscriptionRepository repo;

  bool loaded = false;
  Period period = Period.month;
  List<Subscription> subscriptions = const [];
  List<MonthlyTotal> monthlyTotals = const [];
  List<ExchangeRate> usdRates = const [];

  /// 表示の区切り（何か変わるたびに増える）。履歴画面などの再読み込みに使う。
  int revision = 0;

  ExchangeRate? get latestUsdRate => usdRates.isEmpty ? null : usdRates.first;

  double get monthlyTotal =>
      subscriptions.fold(0, (sum, s) => sum + (s.monthlyCostJpy ?? 0));

  int get missingRateCount => subscriptions.where((s) => !s.hasRate).length;

  Future<void> refresh() async {
    await repo.recordMonthly(currentYearMonth());
    final results = await Future.wait([
      repo.activeSubscriptions(),
      repo.monthlyTotals(),
      repo.rates('USD'),
    ]);
    subscriptions = results[0] as List<Subscription>;
    monthlyTotals = results[1] as List<MonthlyTotal>;
    usdRates = results[2] as List<ExchangeRate>;
    loaded = true;
    revision++;
    notifyListeners();
  }

  void setPeriod(Period value) {
    if (period == value) return;
    period = value;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// 再描画の購読をせずに取得する（ボタンのハンドラ内など）。
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
