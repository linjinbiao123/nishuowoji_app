import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 默认账本ID（首次启动自动创建的"日常账本"）
const String kDefaultLedgerId = 'default_ledger';

class Ledger {
  final String id;
  final String name;
  final int color; // Color 的 int 值
  final DateTime created;

  Ledger({
    required this.id,
    required this.name,
    required this.color,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'created': created.toIso8601String(),
  };

  factory Ledger.fromJson(Map<String, dynamic> j) => Ledger(
    id: j['id'] as String,
    name: j['name'] as String,
    color: j['color'] as int,
    created: DateTime.tryParse(j['created'] as String? ?? '') ?? DateTime.now(),
  );

  Ledger copyWith({String? name, int? color}) => Ledger(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    created: created,
  );
}

class Record {
  final double amount;
  final String category;
  final String note;
  final DateTime time;
  final bool isExpense; // true=支出，false=收入
  final String ledgerId; // 所属账本

  Record({
    required this.amount,
    required this.category,
    required this.note,
    required this.time,
    required this.isExpense,
    this.ledgerId = kDefaultLedgerId,
  });

  // 计算带符号的金额（支出为负，收入为正）
  double get signedAmount => isExpense ? -amount : amount;

  Map<String, dynamic> toJson() => {
    'amount': amount.toString(),
    'category': category,
    'note': note,
    'time': time.toIso8601String(),
    'isExpense': isExpense ? '1' : '0',
    'ledgerId': ledgerId,
  };

  factory Record.fromJson(Map<String, dynamic> j) => Record(
    amount: double.parse(j['amount'] as String),
    category: j['category'] as String,
    note: j['note'] as String,
    time: DateTime.parse(j['time'] as String),
    isExpense: j['isExpense'] == '1',
    ledgerId: (j['ledgerId'] as String?) ?? kDefaultLedgerId,
  );
}

class Storage {
  static const _key = 'records';
  static const _customCategoryKey = 'custom_categories';
  static const _ledgerKey = 'ledgers';
  static const _currentLedgerKey = 'current_ledger_id';

  // ---- 账本管理 ----

  /// 首次启动时确保至少存在一个账本（自动创建"日常账本"）
  static Future<void> ensureDefaultLedger() async {
    final ledgers = await getLedgers();
    if (ledgers.isEmpty) {
      await saveLedgers([
        Ledger(id: kDefaultLedgerId, name: '日常账本', color: 0xFF10B981),
      ]);
    }
    final cur = await getCurrentLedgerId();
    // 当前账本ID无效时，回退到第一个账本
    final all = await getLedgers();
    if (all.isNotEmpty && !all.any((l) => l.id == cur)) {
      await setCurrentLedgerId(all.first.id);
    }
    await _migrateLegacyBudgets();
  }

  /// 旧版预算是全局存的，迁移到默认账本名下（预算现在按账本独立存储）
  static Future<void> _migrateLegacyBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('monthly_budget')) {
      final v = prefs.getDouble('monthly_budget') ?? 0;
      await prefs.setDouble('monthly_budget_$kDefaultLedgerId', v);
      await prefs.remove('monthly_budget');
    }
    if (prefs.containsKey('category_budgets')) {
      final v = prefs.getString('category_budgets') ?? '';
      await prefs.setString('category_budgets_$kDefaultLedgerId', v);
      await prefs.remove('category_budgets');
    }
  }

  static Future<List<Ledger>> getLedgers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ledgerKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Ledger.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLedgers(List<Ledger> ledgers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ledgerKey, jsonEncode(ledgers.map((e) => e.toJson()).toList()));
  }

  static Future<void> addLedger(Ledger l) async {
    final list = await getLedgers();
    list.add(l);
    await saveLedgers(list);
  }

  static Future<void> updateLedger(Ledger l) async {
    final list = await getLedgers();
    final idx = list.indexWhere((e) => e.id == l.id);
    if (idx != -1) {
      list[idx] = l;
      await saveLedgers(list);
    }
  }

  /// 删除账本及其全部记录；若删的是当前账本则切换到剩余第一个
  static Future<void> deleteLedger(String id) async {
    final ledgers = await getLedgers();
    ledgers.removeWhere((l) => l.id == id);
    await saveLedgers(ledgers);

    final raw = await getAllRaw();
    raw.removeWhere((r) => r.ledgerId == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, raw.map((e) => _encode(e.toJson())).join('|'));

    // 同步清掉该账本的预算数据
    await prefs.remove('monthly_budget_$id');
    await prefs.remove('category_budgets_$id');

    final cur = await getCurrentLedgerId();
    if (cur == id && ledgers.isNotEmpty) {
      await setCurrentLedgerId(ledgers.first.id);
    }
  }

  static Future<String> getCurrentLedgerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentLedgerKey) ?? kDefaultLedgerId;
  }

  static Future<void> setCurrentLedgerId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentLedgerKey, id);
  }

  /// 当前账本对象；账本列表为空时返回 null
  static Future<Ledger?> getCurrentLedger() async {
    final ledgers = await getLedgers();
    if (ledgers.isEmpty) return null;
    final id = await getCurrentLedgerId();
    return ledgers.firstWhere((l) => l.id == id, orElse: () => ledgers.first);
  }

  // ---- 记录读写 ----

  /// 全部账本的原始记录（不过滤）
  static Future<List<Record>> getAllRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = raw.split('|');
    return list.map((s) => Record.fromJson(_decode(s))).toList();
  }

  /// 指定账本的记录
  static Future<List<Record>> getForLedger(String ledgerId) async {
    final all = await getAllRaw();
    return all.where((r) => r.ledgerId == ledgerId).toList();
  }

  /// 当前账本的记录（所有页面默认使用这个方法）
  static Future<List<Record>> getAll() async {
    final currentId = await getCurrentLedgerId();
    return getForLedger(currentId);
  }

  /// 新增记录，自动归入当前账本
  static Future<void> add(Record r) async {
    final currentId = await getCurrentLedgerId();
    final tagged = Record(
      amount: r.amount,
      category: r.category,
      note: r.note,
      time: r.time,
      isExpense: r.isExpense,
      ledgerId: currentId,
    );
    final list = await getAllRaw();
    list.insert(0, tagged);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, list.map((e) => _encode(e.toJson())).join('|'));
  }

  /// 按"当前账本过滤后的列表"中的下标删除记录
  static Future<void> remove(int index) async {
    final currentId = await getCurrentLedgerId();
    final raw = await getAllRaw();
    // 找出当前账本记录在原始列表中的下标
    final filteredIndices = <int>[];
    for (var i = 0; i < raw.length; i++) {
      if (raw[i].ledgerId == currentId) filteredIndices.add(i);
    }
    if (index < 0 || index >= filteredIndices.length) return;
    raw.removeAt(filteredIndices[index]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, raw.map((e) => _encode(e.toJson())).join('|'));
  }

  /// 清空当前账本的全部记录
  static Future<void> clearCurrentLedger() async {
    final currentId = await getCurrentLedgerId();
    final raw = await getAllRaw();
    raw.removeWhere((r) => r.ledgerId == currentId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, raw.map((e) => _encode(e.toJson())).join('|'));
  }

  // 自定义分类持久化
  static Future<List<String>> getCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customCategoryKey);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',');
  }

  static Future<void> addCustomCategory(String name) async {
    final list = await getCustomCategories();
    if (!list.contains(name)) {
      list.add(name);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customCategoryKey, list.join(','));
    }
  }

  static Future<void> removeCustomCategory(String name) async {
    final list = await getCustomCategories();
    list.remove(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customCategoryKey, list.join(','));
  }

  // ---- 预算（按账本独立存储，新建账本默认空白） ----

  /// 月预算（当前账本）
  static Future<double> getMonthlyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final ledgerId = await getCurrentLedgerId();
    return prefs.getDouble('monthly_budget_$ledgerId') ?? 0;
  }

  static Future<void> setMonthlyBudget(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final ledgerId = await getCurrentLedgerId();
    await prefs.setDouble('monthly_budget_$ledgerId', amount);
  }

  /// 分类预算（当前账本，格式: "分类名=金额,分类名=金额"）
  static Future<Map<String, double>> getCategoryBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final ledgerId = await getCurrentLedgerId();
    final raw = prefs.getString('category_budgets_$ledgerId');
    if (raw == null || raw.isEmpty) return {};
    final map = <String, double>{};
    for (final item in raw.split(',')) {
      final parts = item.split('=');
      if (parts.length == 2) {
        map[parts[0]] = double.tryParse(parts[1]) ?? 0;
      }
    }
    return map;
  }

  static Future<void> setCategoryBudgets(Map<String, double> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    final ledgerId = await getCurrentLedgerId();
    final raw = budgets.entries.map((e) => '${e.key}=${e.value}').join(',');
    await prefs.setString('category_budgets_$ledgerId', raw);
  }

  // 已删除的分类
  static Future<List<String>> getDeletedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('deleted_categories');
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',');
  }

  static Future<void> addDeletedCategory(String name) async {
    final list = await getDeletedCategories();
    if (!list.contains(name)) {
      list.add(name);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('deleted_categories', list.join(','));
    }
  }

  static Future<void> restoreCategory(String name) async {
    final list = await getDeletedCategories();
    list.remove(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deleted_categories', list.join(','));
  }

  // 全局背景主题索引（0=深空蓝 1=极光紫 2=翡翠绿 3=樱花粉）
  static Future<int> getBgIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final i = prefs.getInt('stats_bg_theme') ?? 0;
    return i < 0 ? 0 : i; // 上限由各页面的 % AppBgTheme.all.length 兜底
  }

  static Future<void> setBgIndex(int i) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('stats_bg_theme', i);
  }

  /// 每日记账提醒开关（默认关闭）
  static Future<bool> getReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('reminder_enabled') ?? false;
  }

  static Future<void> setReminderEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', on);
  }

  /// 提醒时间（从当天零点起的分钟数，默认 20:00 = 1200）
  static Future<int> getReminderMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('reminder_minutes') ?? 20 * 60;
  }

  static Future<void> setReminderMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_minutes', minutes);
  }

  static String _encode(Map<String, dynamic> j) {
    return j.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  static Map<String, dynamic> _decode(String s) {
    final map = <String, dynamic>{};
    for (final part in s.split('&')) {
      final idx = part.indexOf('=');
      if (idx < 0) continue;
      final k = part.substring(0, idx);
      final v = part.substring(idx + 1);
      map[k] = v;
    }
    return map;
  }
}
