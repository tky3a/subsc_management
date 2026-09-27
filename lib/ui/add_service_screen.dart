import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'add_plan_screen.dart';
import 'widgets.dart';

const _allCategories = 'すべて';

/// 登録 1/2: サービスを選択する。
class AddServiceScreen extends StatefulWidget {
  const AddServiceScreen({super.key});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  List<Service>? _services;
  String _category = _allCategories;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final services = await AppScope.read(context).repo.services();
    if (mounted) setState(() => _services = services);
  }

  void _openPlans(int serviceId, String name) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AddPlanScreen(serviceId: serviceId, serviceName: name),
    ));
  }

  Future<void> _addCustom() async {
    final created = await showModalBottomSheet<(int, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CustomServiceSheet(),
    );
    if (created == null || !mounted) return;
    await _load();
    _openPlans(created.$1, created.$2);
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    final categories = [
      _allCategories,
      ...{for (final s in services ?? const <Service>[]) ?s.category},
    ];
    final q = _query.trim().toLowerCase();
    final filtered = (services ?? const <Service>[])
        .where((s) =>
            (_category == _allCategories || s.category == _category) &&
            (q.isEmpty || s.name.toLowerCase().contains(q)))
        .toList();

    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text('1 / 2', style: mono(13, color: AppColors.textSub)),
          ),
        ],
      ),
      body: services == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                Semantics(
                  header: true,
                  child: const Text('サービスを選択', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                const Text('契約しているアプリ・Webサービスを選んでください',
                    style: TextStyle(fontSize: 14, color: AppColors.textSub)),
                const SizedBox(height: 20),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'サービス名で検索',
                    prefixIcon: Icon(Icons.search, color: AppColors.textSub),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in categories)
                      ChoiceChip(
                        label: Text(c),
                        selected: c == _category,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _category = c),
                        selectedColor: AppColors.accent,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(color: c == _category ? AppColors.accent : AppColors.line),
                        shape: const StadiumBorder(),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          color: c == _category ? AppColors.onAccent : AppColors.textLabel,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final s in filtered) ...[
                  TapCard(
                    onTap: () => _openPlans(s.id, s.name),
                    child: Row(
                      children: [
                        ServiceMonogram(serviceId: s.id, name: s.name),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  ?s.category,
                                  '${s.planCount}プラン',
                                  if (s.hasForeignCurrency) 'ドル建て',
                                ].join(' · '),
                                style: const TextStyle(fontSize: 12, color: AppColors.textSub),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.icon),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('該当するサービスがありません',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSub)),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addCustom,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('一覧にないサービスを追加'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ],
            ),
    );
  }
}

/// マスタにないサービスをプラン 1 つと一緒に追加するシート。
class _CustomServiceSheet extends StatefulWidget {
  const _CustomServiceSheet();

  @override
  State<_CustomServiceSheet> createState() => _CustomServiceSheetState();
}

class _CustomServiceSheetState extends State<_CustomServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _planName = TextEditingController(text: '通常プラン');
  final _price = TextEditingController();
  String _currency = 'JPY';
  int _interval = 1;
  bool _saving = false;

  int get _factor => _currency == 'USD' ? 100 : 1;

  @override
  void dispose() {
    for (final c in [_name, _category, _planName, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = AppScope.read(context).repo;
    final name = _name.text.trim();
    setState(() => _saving = true);
    if (await repo.serviceNameExists(name)) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「$name」はすでに一覧にあります')));
      return;
    }
    final id = await repo.addCustomService(
      name: name,
      category: _category.text.trim().isEmpty ? null : _category.text.trim(),
      planName: _planName.text.trim(),
      currencyCode: _currency,
      price: parseMoney(_price.text, _factor)!,
      intervalMonths: _interval,
    );
    if (mounted) Navigator.of(context).pop((id, name));
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? v) => (v == null || v.trim().isEmpty) ? '入力してください' : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              const Text('サービスを追加', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'サービス名'),
                validator: required,
              ),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'カテゴリ（任意）', hintText: '動画 / 音楽 など'),
              ),
              TextFormField(
                controller: _planName,
                decoration: const InputDecoration(labelText: 'プラン名'),
                validator: required,
              ),
              Row(
                spacing: 10,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'JPY', label: Text('円')),
                      ButtonSegment(value: 'USD', label: Text('ドル')),
                    ],
                    selected: {_currency},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => setState(() => _currency = v.first),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: TextInputType.numberWithOptions(decimal: _currency == 'USD'),
                      style: mono(16),
                      decoration: InputDecoration(labelText: '金額', prefixText: _currency == 'USD' ? r'$ ' : '¥ '),
                      validator: (v) => parseMoney(v ?? '', _factor) == null ? '金額を入力してください' : null,
                    ),
                  ),
                ],
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('月額')),
                  ButtonSegment(value: 12, label: Text('年額')),
                ],
                selected: {_interval},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _interval = v.first),
              ),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: const Text('追加してプランを選ぶ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
