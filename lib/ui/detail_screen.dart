import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'widgets.dart';

/// 詳細画面。金額の手動編集・履歴の確認・解約を行う。
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.subscriptionId});

  final int subscriptionId;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Subscription? _sub;
  List<MonthlyRecord> _history = const [];
  final _price = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = AppScope.read(context).repo;
    final sub = await repo.subscription(widget.subscriptionId);
    final history = await repo.recordsOfSubscription(widget.subscriptionId);
    if (!mounted || sub == null) return;
    setState(() {
      _sub = sub;
      _history = history;
      _price.text = moneyInput(sub.effectivePrice, sub.minorUnitFactor);
    });
  }

  int? get _entered => _sub == null ? null : parseMoney(_price.text, _sub!.minorUnitFactor);

  Future<void> _save() async {
    final sub = _sub!;
    final entered = _entered!;
    final state = AppScope.read(context);
    setState(() => _saving = true);
    // プラン金額と同じならプラン金額に従う（手動金額を解除）
    await state.repo.updateCustomPrice(sub.id, entered == sub.planPrice ? null : entered);
    await state.refresh();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${sub.serviceName} の金額を保存しました')));
  }

  Future<void> _cancel() async {
    final sub = _sub!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${sub.serviceName} を解約済みにしますか？'),
        content: const Text('一覧と合計から外れます。これまでの履歴は残ります。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('やめる')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('解約済みにする'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final state = AppScope.read(context);
    await state.repo.cancelSubscription(sub.id, isoDate(DateTime.now()));
    await state.refresh();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${sub.serviceName} を解約済みにしました')));
  }

  @override
  Widget build(BuildContext context) {
    final sub = _sub;
    if (sub == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }

    final entered = _entered;
    final isManual = entered != null && entered != sub.planPrice;
    final rate = sub.rateToJpy;
    final monthlyJpy =
        (entered == null || rate == null) ? null : entered / sub.minorUnitFactor * rate / sub.intervalMonths;
    final changed = entered != null && entered != sub.effectivePrice;
    final contract = contractLabel(sub.intervalMonths);

    return Scaffold(
      appBar: AppBar(
        actions: const [Padding(padding: EdgeInsets.only(right: 20), child: StatusBadge('契約中'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Row(
            children: [
              ServiceMonogram(serviceId: sub.serviceId, name: sub.serviceName, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(sub.serviceName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    ),
                    Text('${sub.planName} · $contract', style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MoneyField(
                  controller: _price,
                  symbol: sub.currencySymbol,
                  decimal: sub.minorUnitFactor > 1,
                  label: '表示金額（請求1回あたり）',
                  highlight: isManual,
                  fontSize: 24,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entered == null
                              ? '金額を入力してください'
                              : isManual
                                  ? '手動で変更中（プラン金額 ${money(sub.planPrice, sub.currencySymbol, sub.minorUnitFactor)}）'
                                  : 'プラン金額のまま表示しています',
                          style: TextStyle(
                            fontSize: 12,
                            color: entered == null || isManual ? AppColors.warn : AppColors.textSub,
                          ),
                        ),
                      ),
                      if (isManual)
                        TextButton.icon(
                          onPressed: () => setState(
                              () => _price.text = moneyInput(sub.planPrice, sub.minorUnitFactor)),
                          icon: const Icon(Icons.restart_alt, size: 16),
                          label: const Text('プラン金額に戻す', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.text,
                            backgroundColor: AppColors.raised,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                ),
                if (sub.isForeign)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      rate == null ? '為替レート未登録' : '1ドル = ${rateLabel(rate)} で換算',
                      style: TextStyle(fontSize: 12, color: rate == null ? AppColors.warn : AppColors.textSub),
                    ),
                  ),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(child: ValueTile(label: '月額換算', value: monthlyJpy == null ? '—' : yen(monthlyJpy))),
                    Expanded(child: ValueTile(label: '年間', value: monthlyJpy == null ? '—' : yen(monthlyJpy * 12))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('契約情報'),
          const SizedBox(height: 6),
          _InfoRow('契約形態', sub.intervalMonths == 1 ? '月額（毎月請求）' : '$contract（${sub.intervalMonths}か月ごとに請求）'),
          _InfoRow('開始日', dateLabel(sub.startDate), monoValue: true),
          _InfoRow('請求日',
              sub.billingDay == null ? '未設定' : (sub.intervalMonths == 1 ? '毎月${sub.billingDay}日' : '${sub.billingDay}日')),
          const SizedBox(height: 22),
          const SectionLabel('金額の履歴', trailing: '月ごとの記録'),
          const SizedBox(height: 6),
          if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('まだ記録がありません', style: TextStyle(fontSize: 13, color: AppColors.textSub)),
            ),
          for (var i = 0; i < _history.length; i++)
            _HistoryRow(record: _history[i], previous: i + 1 < _history.length ? _history[i + 1] : null),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: Row(
          spacing: 10,
          children: [
            OutlinedButton(
              onPressed: _saving ? null : _cancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.dangerLine),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: const Text('解約する'),
            ),
            Expanded(
              child: FilledButton(
                onPressed: (entered != null && changed && !_saving) ? _save : null,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.monoValue = false});

  final String label;
  final String value;
  final bool monoValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
          const Spacer(),
          Text(value, style: monoValue ? mono(14) : const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record, required this.previous});

  final MonthlyRecord record;
  final MonthlyRecord? previous;

  @override
  Widget build(BuildContext context) {
    final diff = previous == null ? 0.0 : record.monthlyCostJpy - previous!.monthlyCostJpy;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          Text(yearMonthShort(record.yearMonth), style: mono(14, color: AppColors.textLabel)),
          const Spacer(),
          if (diff.round() != 0) ...[
            Text(signedYen(diff), style: const TextStyle(fontSize: 12, color: AppColors.warn)),
            const SizedBox(width: 10),
          ],
          Text(money(record.price, record.currencySymbol, record.minorUnitFactor), style: mono(14)),
          if (record.isForeign) ...[
            const SizedBox(width: 6),
            Text('(${yen(record.priceJpy)})', style: mono(12, color: AppColors.textSub)),
          ],
        ],
      ),
    );
  }
}
