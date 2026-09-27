import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'widgets.dart';

/// 登録 2/2: プランを選び、金額・開始日・請求日を確認して登録する。
class AddPlanScreen extends StatefulWidget {
  const AddPlanScreen({super.key, required this.serviceId, required this.serviceName});

  final int serviceId;
  final String serviceName;

  @override
  State<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends State<AddPlanScreen> {
  List<Plan>? _plans;
  Plan? _plan;
  final _price = TextEditingController();
  final _billingDay = TextEditingController(text: DateTime.now().day.toString());
  DateTime _startDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _price.dispose();
    _billingDay.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final plans = await AppScope.read(context).repo.plans(widget.serviceId);
    if (!mounted) return;
    setState(() => _plans = plans);
    if (plans.isNotEmpty) _selectPlan(plans.first);
  }

  void _selectPlan(Plan plan) {
    setState(() {
      _plan = plan;
      _price.text = moneyInput(plan.price, plan.minorUnitFactor);
    });
  }

  int? get _enteredPrice => _plan == null ? null : parseMoney(_price.text, _plan!.minorUnitFactor);
  bool get _isManual => _plan != null && _enteredPrice != null && _enteredPrice != _plan!.price;

  int? get _billingDayValue {
    final v = int.tryParse(_billingDay.text.trim());
    return v != null && v >= 1 && v <= 31 ? v : null;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    final plan = _plan!;
    final state = AppScope.read(context);
    setState(() => _saving = true);
    await state.repo.addSubscription(
      planId: plan.id,
      customPrice: _isManual ? _enteredPrice : null,
      startDate: isoDate(_startDate),
      billingDay: _billingDayValue,
    );
    await state.refresh();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${widget.serviceName} ${plan.name} を登録しました')));
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;
    final plan = _plan;
    final rate = plan == null
        ? null
        : plan.isForeign
            ? AppScope.of(context).latestUsdRate?.rateToJpy
            : 1.0;
    final price = _enteredPrice;
    final monthlyJpy = (plan == null || price == null || rate == null)
        ? null
        : price / plan.minorUnitFactor * rate / plan.intervalMonths;
    final canSubmit = plan != null && price != null && _billingDayValue != null && !_saving;

    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text('2 / 2', style: mono(13, color: AppColors.textSub)),
          ),
        ],
      ),
      body: plans == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Row(
                  children: [
                    ServiceMonogram(serviceId: widget.serviceId, name: widget.serviceName, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(widget.serviceName,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                          ),
                          const Text('プランを選んで登録', style: TextStyle(fontSize: 13, color: AppColors.textSub)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SectionLabel('プラン'),
                const SizedBox(height: 8),
                for (final p in plans) ...[
                  _PlanOption(plan: p, selected: p.id == plan?.id, onTap: () => _selectPlan(p)),
                  const SizedBox(height: 8),
                ],
                if (plan != null) ...[
                  const SizedBox(height: 14),
                  const SectionLabel('契約内容'),
                  const SizedBox(height: 12),
                  MoneyField(
                    controller: _price,
                    symbol: plan.currencySymbol,
                    decimal: plan.minorUnitFactor > 1,
                    label: '請求金額（${intervalUnit(plan.intervalMonths)}ごと）',
                    highlight: _isManual,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_isManual)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '手動で変更（プラン金額 ${money(plan.price, plan.currencySymbol, plan.minorUnitFactor)}）',
                              style: const TextStyle(fontSize: 12, color: AppColors.warn),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _selectPlan(plan),
                            icon: const Icon(Icons.restart_alt, size: 16),
                            label: const Text('プラン金額に戻す', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(foregroundColor: AppColors.text),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    spacing: 10,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickStartDate,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '開始日',
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              suffixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.icon),
                            ),
                            child: Text(dateLabel(isoDate(_startDate)), style: mono(15)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _billingDay,
                          keyboardType: TextInputType.number,
                          style: mono(15),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: plan.intervalMonths == 1 ? '請求日（毎月）' : '請求日',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            suffixText: '日',
                            errorText: _billingDayValue == null ? '1〜31' : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
      bottomNavigationBar: plan == null
          ? null
          : BottomActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: [
                  if (monthlyJpy == null)
                    const Text('為替レートが未登録のため円換算できません（登録後に合計へ反映されます）',
                        style: TextStyle(fontSize: 12, color: AppColors.warn))
                  else
                    Row(
                      children: [
                        const Text('月額換算 ', style: TextStyle(fontSize: 13, color: AppColors.textSub)),
                        Text(yen(monthlyJpy), style: mono(15)),
                        const Spacer(),
                        const Text('年間 ', style: TextStyle(fontSize: 13, color: AppColors.textSub)),
                        Text(yen(monthlyJpy * 12), style: mono(15)),
                      ],
                    ),
                  FilledButton.icon(
                    onPressed: canSubmit ? _submit : null,
                    icon: const Icon(Icons.check),
                    label: const Text('登録する'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({required this.plan, required this.selected, required this.onTap});

  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = '${money(plan.price, plan.currencySymbol, plan.minorUnitFactor)} / ${intervalUnit(plan.intervalMonths)}';
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '${plan.name} ${contractLabel(plan.intervalMonths)} $price',
      excludeSemantics: true,
      child: TapCard(
        onTap: onTap,
        radius: 14,
        borderColor: selected ? AppColors.accent : null,
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 22, color: selected ? AppColors.accent : AppColors.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(contractLabel(plan.intervalMonths),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                ],
              ),
            ),
            Text(price, style: mono(15)),
          ],
        ),
      ),
    );
  }
}
