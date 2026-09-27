import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'add_service_screen.dart';
import 'detail_screen.dart';
import 'widgets.dart';

/// 一覧画面。合計と契約中のサブスクを月 / 年で切り替えて表示する。
class ListScreen extends StatelessWidget {
  const ListScreen({super.key, required this.onOpenRates});

  final VoidCallback onOpenRates;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isYear = state.period == Period.year;
    final subs = state.subscriptions;
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            PageHeading(
              caption: '${now.year}年${now.month}月',
              title: 'サブスク',
              trailing: _PeriodToggle(
                period: state.period,
                onChanged: state.setPeriod,
              ),
            ),
            const SizedBox(height: 20),
            _TotalCard(state: state, isYear: isYear, onOpenRates: onOpenRates),
            const SizedBox(height: 20),
            SectionLabel('契約中', trailing: subs.isEmpty ? null : '金額の高い順'),
            const SizedBox(height: 10),
            if (subs.isEmpty)
              const _EmptyState()
            else
              for (final s in subs) ...[
                _SubscriptionRow(sub: s, isYear: isYear),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AddServiceScreen()),
        ),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add),
        label: const Text('追加', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.period, required this.onChanged});

  final Period period;
  final ValueChanged<Period> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, Period value) {
      final selected = period == value;
      return Semantics(
        button: true,
        selected: selected,
        label: '$labelで表示',
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => onChanged(value),
            child: SizedBox(
              width: 56,
              height: 40,
              child: Center(
                child: Text(label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.onAccent : AppColors.textSub,
                    )),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
        option('月', Period.month),
        option('年', Period.year),
      ]),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.state, required this.isYear, required this.onOpenRates});

  final AppState state;
  final bool isYear;
  final VoidCallback onOpenRates;

  @override
  Widget build(BuildContext context) {
    final monthly = state.monthlyTotal;
    final total = isYear ? monthly * 12 : monthly;
    final cross = isYear ? monthly : monthly * 12;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isYear ? '年間の合計' : '今月の合計（月額換算）',
              style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(yen(total), style: mono(44, weight: FontWeight.w500)),
                ),
              ),
              const SizedBox(width: 6),
              Text(isYear ? '/ 年' : '/ 月', style: const TextStyle(fontSize: 15, color: AppColors.textSub)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.line),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(isYear ? '月あたり ' : '年間では ', style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
              Text(yen(cross), style: mono(13)),
              const Spacer(),
              Text('契約中 ${state.subscriptions.length}件',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
            ],
          ),
          if (state.missingRateCount > 0) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: onOpenRates,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.warn),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ドル建て ${state.missingRateCount}件はレート未登録のため合計に含まれていません',
                        style: const TextStyle(fontSize: 12, color: AppColors.warn),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.warn),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({required this.sub, required this.isYear});

  final Subscription sub;
  final bool isYear;

  /// 金額の下に添える補足（ドル換算・月割りなど）。
  String? get _note {
    if (sub.isForeign && sub.hasRate) {
      // 表示期間（1 か月 / 12 か月）あたりの外貨額
      final minor = (sub.effectivePrice * (isYear ? 12 : 1) / sub.intervalMonths).round();
      return '${money(minor, sub.currencySymbol, sub.minorUnitFactor)} × ${rateLabel(sub.rateToJpy!)}';
    }
    if (!isYear && sub.intervalMonths > 1) {
      return '${money(sub.effectivePrice, sub.currencySymbol, sub.minorUnitFactor)}/${intervalUnit(sub.intervalMonths)} を月割り';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cost = isYear ? sub.yearlyCostJpy : sub.monthlyCostJpy;
    final display = cost == null
        ? money(sub.effectivePrice, sub.currencySymbol, sub.minorUnitFactor)
        : yen(cost);
    final note = _note;
    final contract = contractLabel(sub.intervalMonths);

    return Semantics(
      button: true,
      label: '${sub.serviceName} ${sub.planName} $contract $display ${isYear ? '年間' : '月あたり'}',
      excludeSemantics: true,
      child: TapCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => DetailScreen(subscriptionId: sub.id)),
        ),
        child: Row(
          children: [
            ServiceMonogram(serviceId: sub.serviceId, name: sub.serviceName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub.serviceName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(sub.planName,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSub),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      ContractBadge(contract),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(display, style: mono(17, weight: FontWeight.w500)),
                if (!sub.hasRate)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('レート未登録', style: TextStyle(fontSize: 11, color: AppColors.warn)),
                  ),
                if (sub.isManual)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('手動で変更', style: TextStyle(fontSize: 11, color: AppColors.warn)),
                  ),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(note, style: mono(11, color: AppColors.textSub)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.badgeLine),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 32, color: AppColors.icon),
          SizedBox(height: 12),
          Text('まだサブスクが登録されていません', style: TextStyle(fontSize: 15)),
          SizedBox(height: 4),
          Text('右下の「追加」から登録できます', style: TextStyle(fontSize: 13, color: AppColors.textSub)),
        ],
      ),
    );
  }
}
