/// DB の行を表すモデル。
library;

class Service {
  const Service({
    required this.id,
    required this.name,
    required this.category,
    required this.planCount,
    required this.hasForeignCurrency,
  });

  final int id;
  final String name;
  final String? category;
  final int planCount;
  final bool hasForeignCurrency;

  factory Service.fromMap(Map<String, Object?> m) => Service(
        id: m['id'] as int,
        name: m['name'] as String,
        category: m['category'] as String?,
        planCount: m['plan_count'] as int,
        hasForeignCurrency: (m['foreign_count'] as int) > 0,
      );
}

class Plan {
  const Plan({
    required this.id,
    required this.serviceId,
    required this.name,
    required this.currencyCode,
    required this.currencySymbol,
    required this.minorUnitFactor,
    required this.price,
    required this.intervalMonths,
  });

  final int id;
  final int serviceId;
  final String name;
  final String currencyCode;
  final String currencySymbol;
  final int minorUnitFactor;
  final int price;
  final int intervalMonths;

  bool get isForeign => currencyCode != 'JPY';

  factory Plan.fromMap(Map<String, Object?> m) => Plan(
        id: m['id'] as int,
        serviceId: m['service_id'] as int,
        name: m['name'] as String,
        currencyCode: m['currency_code'] as String,
        currencySymbol: m['symbol'] as String,
        minorUnitFactor: m['minor_unit_factor'] as int,
        price: m['price'] as int,
        intervalMonths: m['billing_interval_months'] as int,
      );
}

/// v_subscriptions の 1 行。
class Subscription {
  const Subscription({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.category,
    required this.planId,
    required this.planName,
    required this.intervalMonths,
    required this.currencyCode,
    required this.currencySymbol,
    required this.minorUnitFactor,
    required this.planPrice,
    required this.customPrice,
    required this.effectivePrice,
    required this.rateToJpy,
    required this.priceJpy,
    required this.monthlyCostJpy,
    required this.yearlyCostJpy,
    required this.startDate,
    required this.billingDay,
    required this.status,
  });

  final int id;
  final int serviceId;
  final String serviceName;
  final String? category;
  final int planId;
  final String planName;
  final int intervalMonths;
  final String currencyCode;
  final String currencySymbol;
  final int minorUnitFactor;
  final int planPrice;
  final int? customPrice;
  final int effectivePrice;

  /// 外貨でレート未登録なら null（円換算の値もすべて null）。
  final double? rateToJpy;
  final int? priceJpy;
  final double? monthlyCostJpy;
  final double? yearlyCostJpy;
  final String startDate;
  final int? billingDay;
  final String status;

  bool get isManual => customPrice != null && customPrice != planPrice;
  bool get isForeign => currencyCode != 'JPY';
  bool get hasRate => rateToJpy != null;

  factory Subscription.fromMap(Map<String, Object?> m) => Subscription(
        id: m['subscription_id'] as int,
        serviceId: m['service_id'] as int,
        serviceName: m['service_name'] as String,
        category: m['category'] as String?,
        planId: m['plan_id'] as int,
        planName: m['plan_name'] as String,
        intervalMonths: m['billing_interval_months'] as int,
        currencyCode: m['currency_code'] as String,
        currencySymbol: m['currency_symbol'] as String,
        minorUnitFactor: m['minor_unit_factor'] as int,
        planPrice: m['plan_price'] as int,
        customPrice: m['custom_price'] as int?,
        effectivePrice: m['effective_price'] as int,
        rateToJpy: (m['rate_to_jpy'] as num?)?.toDouble(),
        priceJpy: m['price_jpy'] as int?,
        monthlyCostJpy: (m['monthly_cost_jpy'] as num?)?.toDouble(),
        yearlyCostJpy: (m['yearly_cost_jpy'] as num?)?.toDouble(),
        startDate: m['start_date'] as String,
        billingDay: m['billing_day'] as int?,
        status: m['status'] as String,
      );
}

/// subscription_monthly_records の 1 行（サービス名などを結合したもの）。
class MonthlyRecord {
  const MonthlyRecord({
    required this.subscriptionId,
    required this.serviceId,
    required this.serviceName,
    required this.planName,
    required this.yearMonth,
    required this.price,
    required this.currencyCode,
    required this.currencySymbol,
    required this.minorUnitFactor,
    required this.intervalMonths,
    required this.rateToJpy,
    required this.priceJpy,
    required this.monthlyCostJpy,
  });

  final int subscriptionId;
  final int serviceId;
  final String serviceName;
  final String planName;
  final String yearMonth;
  final int price;
  final String currencyCode;
  final String currencySymbol;
  final int minorUnitFactor;
  final int intervalMonths;
  final double rateToJpy;
  final int priceJpy;
  final double monthlyCostJpy;

  bool get isForeign => currencyCode != 'JPY';

  factory MonthlyRecord.fromMap(Map<String, Object?> m) => MonthlyRecord(
        subscriptionId: m['subscription_id'] as int,
        serviceId: m['service_id'] as int,
        serviceName: m['service_name'] as String,
        planName: m['plan_name'] as String,
        yearMonth: m['year_month'] as String,
        price: m['price'] as int,
        currencyCode: m['currency_code'] as String,
        currencySymbol: m['symbol'] as String,
        minorUnitFactor: m['minor_unit_factor'] as int,
        intervalMonths: m['billing_interval_months'] as int,
        rateToJpy: (m['rate_to_jpy'] as num).toDouble(),
        priceJpy: m['price_jpy'] as int,
        monthlyCostJpy: (m['monthly_cost_jpy'] as num).toDouble(),
      );
}

class MonthlyTotal {
  const MonthlyTotal({required this.yearMonth, required this.count, required this.totalJpy});

  final String yearMonth;
  final int count;
  final double totalJpy;

  factory MonthlyTotal.fromMap(Map<String, Object?> m) => MonthlyTotal(
        yearMonth: m['year_month'] as String,
        count: m['subscription_count'] as int,
        totalJpy: (m['monthly_total_jpy'] as num).toDouble(),
      );
}

class ExchangeRate {
  const ExchangeRate({required this.id, required this.currencyCode, required this.rateToJpy, required this.rateDate});

  final int id;
  final String currencyCode;
  final double rateToJpy;
  final String rateDate;

  factory ExchangeRate.fromMap(Map<String, Object?> m) => ExchangeRate(
        id: m['id'] as int,
        currencyCode: m['currency_code'] as String,
        rateToJpy: (m['rate_to_jpy'] as num).toDouble(),
        rateDate: m['rate_date'] as String,
      );
}
