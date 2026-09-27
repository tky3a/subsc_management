import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// サービス名の頭文字を表示するタイル（ロゴの代わり）。
class ServiceMonogram extends StatelessWidget {
  const ServiceMonogram({super.key, required this.serviceId, required this.name, this.size = 40});

  final int serviceId;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = AppColors.tileFor(serviceId);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: size * 0.42),
        ),
      ),
    );
  }
}

/// 月額 / 年額などの小さなバッジ。
class ContractBadge extends StatelessWidget {
  const ContractBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.badgeLine),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLabel)),
    );
  }
}

/// 塗りつぶしのステータスバッジ（契約中・使用中など）。
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w700)),
    );
  }
}

/// タブ画面の見出し（小さな補足 + 大きなタイトル）。
class PageHeading extends StatelessWidget {
  const PageHeading({super.key, required this.caption, required this.title, this.trailing});

  final String caption;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(caption, style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
              const SizedBox(height: 2),
              Semantics(
                header: true,
                child: Text(title,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// セクションの小見出し。
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textLabel)),
          ),
        ),
        if (trailing != null) Text(trailing!, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
      ],
    );
  }
}

/// 角丸のカード型タップ領域。
class TapCard extends StatelessWidget {
  const TapCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.borderColor,
    this.radius = 16,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? AppColors.surface, width: 1.5),
    );
    return Material(
      color: AppColors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 画面下部に固定するアクション領域。
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.navBar,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), child: child),
      ),
    );
  }
}

/// ラベルと値の小さなタイル（月額換算 / 年間など）。
class ValueTile extends StatelessWidget {
  const ValueTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSub)),
          const SizedBox(height: 2),
          Text(value, style: mono(17)),
        ],
      ),
    );
  }
}

/// 金額入力欄（通貨記号つき）。
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.symbol,
    required this.decimal,
    required this.label,
    this.highlight = false,
    this.onChanged,
    this.fontSize = 17,
  });

  final TextEditingController controller;
  final String symbol;
  final bool decimal;
  final String label;
  final bool highlight;
  final ValueChanged<String>? onChanged;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c));
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: mono(fontSize, weight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixText: '$symbol ',
        prefixStyle: mono(fontSize, color: AppColors.textSub),
        enabledBorder: highlight ? border(AppColors.warn) : null,
        suffixIcon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.icon),
      ),
    );
  }
}
