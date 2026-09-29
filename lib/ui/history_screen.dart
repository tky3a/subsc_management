import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'widgets.dart';

/// 履歴画面。月ごとの合計と、選んだ月の内訳（前月からの変化つき）を表示する。
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _selected;
  List<MonthlyRecord> _records = const [];
  Map<int, MonthlyRecord> _previous = const {};
  int _loadedRevision = -1;
  String? _loadedMonth;

  Future<void> _loadBreakdown(AppState state, String ym, String? prevYm) async {
    final records = await state.repo.recordsOfMonth(ym);
    final prev = prevYm == null ? const <MonthlyRecord>[] : await state.repo.recordsOfMonth(prevYm);
    if (!mounted) return;
    setState(() {
      _records = records;
      _previous = {for (final r in prev) r.subscriptionId: r};
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final totals = state.monthlyTotals; // 新しい順
    final selected = totals.any((t) => t.yearMonth == _selected)
        ? _selected!
        : (totals.isEmpty ? null : totals.first.yearMonth);

    String? previousOf(String ym) {
      final i = totals.indexWhere((t) => t.yearMonth == ym);
      return i >= 0 && i + 1 < totals.length ? totals[i + 1].yearMonth : null;
    }

    // 選択月かデータが変わったら内訳を読み直す
    if (selected != null && (selected != _loadedMonth || state.revision != _loadedRevision)) {
      _loadedMonth = selected;
      _loadedRevision = state.revision;
      _loadBreakdown(state, selected, previousOf(selected));
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const PageHeading(caption: '毎月の記録', title: '履歴'),
          const SizedBox(height: 18),
          if (totals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('まだ記録がありません。サブスクを登録すると毎月記録されます。',
                  style: TextStyle(fontSize: 14, color: AppColors.textSub)),
            ),
          for (var i = 0; i < totals.length; i++) ...[
            _MonthTile(
              total: totals[i],
              previous: i + 1 < totals.length ? totals[i + 1] : null,
              selected: totals[i].yearMonth == selected,
              onTap: () => setState(() => _selected = totals[i].yearMonth),
            ),
            const SizedBox(height: 8),
          ],
          if (selected != null) ...[
            const SizedBox(height: 12),
            SectionLabel('${yearMonthLabel(selected)}の内訳', trailing: '月額換算'),
            const SizedBox(height: 4),
            for (final r in _records) _BreakdownRow(record: r, previous: _previous[r.subscriptionId]),
          ],
        ],
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({required this.total, required this.previous, required this.selected, required this.onTap});

  final MonthlyTotal total;
  final MonthlyTotal? previous;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final diff = previous == null ? null : total.totalJpy - previous!.totalJpy;
    final diffText = diff == null
        ? '前月の記録なし'
        : diff.round() == 0
            ? '先月と同じ'
            : '先月から ${signedYen(diff)}';

    return Semantics(
      selected: selected,
      child: TapCard(
        onTap: onTap,
        borderColor: selected ? AppColors.accent : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(yearMonthLabel(total.yearMonth),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(diffText,
                      style: TextStyle(
                        fontSize: 12,
                        color: diff != null && diff.round() != 0 ? AppColors.warn : AppColors.textSub,
                      )),
                ],
              ),
            ),
            Text(yen(total.totalJpy), style: mono(19, weight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.record, required this.previous});

  final MonthlyRecord record;
  final MonthlyRecord? previous;

  String get _note {
    final price = money(record.price, record.currencySymbol, record.minorUnitFactor);
    if (record.isForeign) return '$price × ${rateLabel(record.rateToJpy)}';
    if (record.intervalMonths > 1) return '$price / ${intervalUnit(record.intervalMonths)} を月割り';
    return '$price / 月';
  }

  /// 前月からの変化（金額変更 / レート変動 / 契約変更）。
  String? get _change {
    final prev = previous;
    if (prev == null) return null;
    final diff = record.monthlyCostJpy - prev.monthlyCostJpy;
    if (diff.round() == 0) return null;
    final reason = record.price != prev.price
        ? '金額変更'
        : record.rateToJpy != prev.rateToJpy
            ? 'レート変動'
            : '契約変更';
    return '$reason ${signedYen(diff)}';
  }

  @override
  Widget build(BuildContext context) {
    final change = _change;
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          ServiceMonogram(serviceId: record.serviceId, name: record.serviceName, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${record.serviceName}  ${record.planName}',
                    style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_note, style: mono(11, color: AppColors.textSub)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(yen(record.monthlyCostJpy), style: mono(15)),
              if (change != null)
                Text(change, style: const TextStyle(fontSize: 11, color: AppColors.warn)),
            ],
          ),
        ],
      ),
    );
  }
}
