/// 语音记账解析工具：从识别文本中提取金额、分类、收支类型。
/// 供首页长按录音和语音弹窗共用。
class VoiceParseResult {
  final double? amount;
  final String category;
  final bool isExpense;
  final bool hasCategory;
  const VoiceParseResult({
    required this.amount,
    required this.category,
    required this.isExpense,
    required this.hasCategory,
  });
}

class VoiceParser {
  static VoiceParseResult parse(String text) {
    final amount = _extractAmount(text);
    final category = _matchCategory(text);
    final isExpense = !_isIncome(text);
    return VoiceParseResult(
      amount: amount,
      category: category,
      isExpense: isExpense,
      hasCategory: category != '其他',
    );
  }

  static double? _extractAmount(String text) {
    final m = RegExp(r'\d+\.?\d*').firstMatch(text);
    if (m != null) {
      final v = double.tryParse(m.group(0)!);
      if (v != null && v > 0) return v;
    }
    return _chineseToNum(text);
  }

  static double? _chineseToNum(String text) {
    const digits = {'零':0,'一':1,'二':2,'两':2,'三':3,'四':4,'五':5,'六':6,'七':7,'八':8,'九':9};
    const units = {'十':10,'百':100,'千':1000,'万':10000,'亿':100000000};
    final cnChars = RegExp(r'[零一二两三四五六七八九十百千万亿]+');
    for (final match in cnChars.allMatches(text)) {
      final s = match.group(0)!;
      if (s.isEmpty) continue;
      final result = _parseCnNum(s, digits, units);
      if (result != null && result > 0) return result;
    }
    return null;
  }

  static double? _parseCnNum(String s, Map<String,int> digits, Map<String,int> units) {
    double total = 0;
    double current = 0;
    double lastUnit = 1;
    for (int i = 0; i < s.length; i++) {
      final ch = s[i];
      if (digits.containsKey(ch)) {
        current = digits[ch]!.toDouble();
      } else if (units.containsKey(ch)) {
        final unit = units[ch]!.toDouble();
        if (current == 0 && unit == 10) current = 1;
        if (unit >= 10000) {
          total = (total + current * lastUnit) * unit;
          current = 0;
          lastUnit = 1;
        } else {
          total += current * unit;
          lastUnit = unit;
          current = 0;
        }
      }
    }
    if (current > 0) {
      if (lastUnit >= 10) {
        total += current * (lastUnit / 10);
      } else {
        total += current;
      }
    }
    return total > 0 ? total : null;
  }

  static String _matchCategory(String text) {
    const keywords = {
      '餐饮': ['吃饭', '餐饮', '美食', '外卖', '早餐', '午餐', '晚餐', '午饭', '晚饭', '面条', '火锅', '奶茶', '咖啡', '买菜', '饭', '面', '吃'],
      '交通': ['交通', '打车', '公交', '地铁', '出租车', '滴滴', '加油', '停车', '车费', '高铁', '火车'],
      '购物': ['购物', '买东西', '网购', '淘宝', '京东', '拼多多', '超市'],
      '娱乐': ['娱乐', '游戏', '电影', '唱歌', '玩'],
      '居家': ['居家', '生活', '日用品', '水电', '房租', '物业'],
      '医疗': ['医疗', '医院', '买药', '看病', '药店', '挂号', '药'],
      '教育': ['教育', '学费', '培训', '买书', '学习', '课程'],
      '通讯': ['通讯', '话费', '宽带', '充值'],
      '服饰': ['服饰', '衣服', '裤子', '鞋'],
      '宠物': ['宠物', '猫粮', '狗粮', '猫', '狗'],
      '运动': ['运动', '健身', '跑步'],
      '数码': ['数码', '手机', '电脑', '耳机'],
      '礼物': ['礼物', '送礼'],
      '社交': ['社交', '聚会', '请客', '份子钱'],
      '旅行': ['旅行', '旅游', '酒店', '机票'],
    };
    for (final e in keywords.entries) {
      for (final kw in e.value) {
        if (text.contains(kw)) return e.key;
      }
    }
    return '其他';
  }

  static bool _isIncome(String text) {
    const kw = ['收入', '工资', '兼职', '理财', '礼金', '报销', '红包', '赚钱', '到账', '进账'];
    return kw.any(text.contains);
  }
}
