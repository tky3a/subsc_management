import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'widgets.dart';

/// 為替レート画面。ドル → 円のレートを手入力で登録する。
class RatesScreen extends StatefulWidget {
  const RatesScreen({super.key});

  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  final _rate = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  double? get _entered {
    final v = double.tryParse(_rate.text.trim().replaceAll(',', ''));
    return v != null && v > 0 ? v : null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final rate = _entered!;
    final state = AppScope.read(context);
    setState(() => _saving = true);
    await state.repo.saveRate('USD', rate, isoDate(_date));
    await state.refresh();
    if (!mounted) return;
    setState(() => _saving = false);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('1ドル = ${rateLabel(rate)}（${dateLabel(isoDate(_date))}）を登録しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final latest = state.latestUsdRate;
    if (!_prefilled && latest != null) {
      _rate.text = latest.rateToJpy.toStringAsFixed(1);
      _prefilled = true;
    }
    final entered = _entered;
    final usdSubs = state.subscriptions.where((s) => s.currencyCode == 'USD').toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const PageHeading(caption: 'ドル建てを円に換算', title: '為替レート'),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('USD（米ドル）', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    const Text('現在 ', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
                    Text(latest == null ? '未登録' : rateLabel(latest.rateToJpy),
                        style: mono(12, color: latest == null ? AppColors.warn : AppColors.text)),
                  ],
                ),
                TextField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  style: mono(22, weight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: '1 ドルあたりの円',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    fillColor: AppColors.background,
                    prefixText: r'$1 = ',
                    prefixStyle: mono(16, color: AppColors.textSub),
                    suffixText: '円',
                    hintText: '150.0',
                  ),
                ),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '適用日',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      fillColor: AppColors.background,
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.icon),
                    ),
                    child: Text(dateLabel(isoDate(_date)), style: mono(15)),
                  ),
                ),
                for (final s in usdSubs)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${s.serviceName} ${s.planName} ${money(s.effectivePrice, s.currencySymbol, s.minorUnitFactor)}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSub),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('→ ', style: mono(13, color: AppColors.textSub)),
                        Text(
                          entered == null ? '—' : yen(s.effectivePrice / s.minorUnitFactor * entered),
                          style: mono(15),
                        ),
                        Text(' / ${intervalUnit(s.intervalMonths)}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
                      ],
                    ),
                  ),
                FilledButton(
                  onPressed: entered != null && !_saving ? _save : null,
                  child: const Text('このレートを登録'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('登録したレート'),
          const SizedBox(height: 6),
          if (state.usdRates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('まだ登録がありません', style: TextStyle(fontSize: 13, color: AppColors.textSub)),
            ),
          for (var i = 0; i < state.usdRates.length; i++)
            Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
              child: Row(
                children: [
                  Text(dateLabel(state.usdRates[i].rateDate), style: mono(14, color: AppColors.textLabel)),
                  if (i == 0) ...[const SizedBox(width: 8), const StatusBadge('使用中')],
                  const Spacer(),
                  Text(rateLabel(state.usdRates[i].rateToJpy),
                      style: mono(14, color: i == 0 ? AppColors.text : AppColors.textSub)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
