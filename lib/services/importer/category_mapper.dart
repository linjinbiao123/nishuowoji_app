import '../categories.dart';

/// 分类映射器。
///
/// 把对方 App 的原始分类名映射为本 App 的内置/自定义分类。
/// 匹配策略（优先级从高到低）：
///   1. 精确匹配（含同义词别名表）
///   2. 关键词包含匹配（原始名含某关键词 → 目标分类）
///   3. 均失败 → 作为"自定义分类"写入并保留原名称（绝不丢数据）
class CategoryMapper {
  /// 同义词别名：对方分类名(归一化) -> 本 App 分类名
  static const Map<String, String> _aliases = {
    // 支出
    '餐饮': '餐饮', '吃饭': '餐饮', '餐馆': '餐饮', '饭': '餐饮', '外卖': '餐饮',
    '食堂': '餐饮', '早餐': '餐饮', '午餐': '餐饮', '晚餐': '餐饮', '夜宵': '餐饮',
    '咖啡': '餐饮', '奶茶': '餐饮', '饮料': '餐饮', '烟酒': '餐饮', '宵夜': '餐饮',
    '食品': '餐饮', '零食': '餐饮', '水果': '餐饮', '菜': '餐饮', '聚餐': '餐饮',
    '交通': '交通', '打车': '交通', '的士': '交通', '出租车': '交通', '网约车': '交通',
    '地铁': '交通', '公交': '交通', '巴士': '交通', '火车': '交通', '高铁': '交通',
    '飞机': '交通', '机票': '交通', '加油': '交通', '油费': '交通', '停车': '交通',
    '停车费': '交通', '过路费': '交通', '养车': '交通', '租车': '交通', '出行': '交通',
    '购物': '购物', '淘宝': '购物', '天猫': '购物', '京东': '购物', '拼多多': '购物',
    '超市': '购物', '商场': '购物', '日用': '购物', '日用品': '购物', '百货': '购物',
    '家居': '购物', '家具': '购物', '家电': '购物', '数码': '数码', '手机': '数码',
    '电脑': '数码', '相机': '数码', '电子产品': '数码', '设备': '数码',
    '娱乐': '娱乐', '游戏': '娱乐', '电影': '娱乐', '演出': '娱乐', 'ktv': '娱乐',
    '健身': '运动', '运动': '运动', '体育': '运动', '球': '运动',
    '居家': '居家', '房租': '居家', '物业': '居家', '水电': '居家', '水电费': '居家',
    '燃气': '居家', '暖气': '居家', '维修': '居家', '家政': '居家', '装修': '居家',
    '医疗': '医疗', '医院': '医疗', '药品': '医疗', '药': '医疗', '看病': '医疗',
    '门诊': '医疗', '保健': '医疗', '体检': '医疗', '保险': '其他',
    '教育': '教育', '学费': '教育', '培训': '教育', '书': '教育', '书籍': '教育',
    '网课': '教育', '课程': '教育', '考试': '教育',
    '通讯': '通讯', '话费': '通讯', '电话费': '通讯', '流量': '通讯', '宽带': '通讯',
    '网费': '通讯', '短信': '通讯',
    '服饰': '服饰', '衣服': '服饰', '服装': '服饰', '鞋': '服饰', '包': '服饰',
    '美容': '美容', '化妆': '美容', '护肤': '美容', '美发': '美容', '理发': '美容',
    '美甲': '美容', '医美': '美容',
    '社交': '社交', '人情': '社交', '请客': '社交', '送礼': '社交', '份子钱': '社交',
    '旅行': '旅行', '旅游': '旅行', '酒店': '旅行', '住宿': '旅行', '景点': '旅行',
    '门票': '旅行', '签证': '旅行',
    '宠物': '宠物', '猫': '宠物', '狗': '宠物', '宠物用品': '宠物', '宠物医疗': '宠物',
    '礼物': '礼物', '礼品': '礼物', '红包': '红包', '礼金': '礼金',
    '其他': '其他',
    // 收入
    '工资': '工资', '薪金': '工资', '薪资': '工资', '薪水': '工资', '薪酬': '工资',
    '奖金': '工资', '绩效': '工资', '津贴': '工资', '提成': '工资',
    '兼职': '兼职', '副业': '兼职', '外包': '兼职', '零工': '兼职',
    '理财': '理财', '利息': '理财', '分红': '理财', '投资': '理财', '收益': '理财',
    '报销': '报销', '退款': '报销', '返现': '其他',
  };

  /// 关键词包含匹配：原始名含 key → 映射到 value。
  /// 顺序即优先级（靠前的更具体，如"手机"应在"数码"前匹配）。
  static const List<MapEntry<String, String>> _keywordRules = [
    MapEntry('工资', '工资'), MapEntry('薪', '工资'), MapEntry('奖金', '工资'),
    MapEntry('绩效', '工资'), MapEntry('提成', '工资'), MapEntry('津贴', '工资'),
    MapEntry('兼职', '兼职'), MapEntry('副业', '兼职'), MapEntry('外包', '兼职'),
    MapEntry('理财', '理财'), MapEntry('利息', '理财'), MapEntry('分红', '理财'),
    MapEntry('投资', '理财'), MapEntry('收益', '理财'),
    MapEntry('报销', '报销'), MapEntry('退款', '报销'), MapEntry('返现', '其他'),
    MapEntry('红', '红包'), MapEntry('礼金', '礼金'),
    MapEntry('手机', '数码'), MapEntry('电脑', '数码'), MapEntry('相机', '数码'),
    MapEntry('数码', '数码'), MapEntry('电子', '数码'), MapEntry('设备', '数码'),
    MapEntry('美容', '美容'), MapEntry('化妆', '美容'), MapEntry('护肤', '美容'),
    MapEntry('美发', '美容'), MapEntry('理发', '美容'), MapEntry('美甲', '美容'),
    MapEntry('医美', '美容'),
    MapEntry('服饰', '服饰'), MapEntry('衣服', '服饰'), MapEntry('服装', '服饰'),
    MapEntry('鞋', '服饰'), MapEntry('包', '服饰'),
    MapEntry('宠物', '宠物'), MapEntry('猫', '宠物'), MapEntry('狗', '宠物'),
    MapEntry('旅行', '旅行'), MapEntry('旅游', '旅行'), MapEntry('酒店', '旅行'),
    MapEntry('住宿', '旅行'), MapEntry('景点', '旅行'), MapEntry('门票', '旅行'),
    MapEntry('签证', '旅行'),
    MapEntry('社交', '社交'), MapEntry('人情', '社交'), MapEntry('请客', '社交'),
    MapEntry('送礼', '社交'), MapEntry('份子', '社交'),
    MapEntry('礼物', '礼物'), MapEntry('礼品', '礼物'),
    MapEntry('教育', '教育'), MapEntry('学费', '教育'), MapEntry('培训', '教育'),
    MapEntry('书', '教育'), MapEntry('课程', '教育'), MapEntry('考试', '教育'),
    MapEntry('网课', '教育'),
    MapEntry('医疗', '医疗'), MapEntry('医院', '医疗'), MapEntry('药', '医疗'),
    MapEntry('看病', '医疗'), MapEntry('门诊', '医疗'), MapEntry('保健', '医疗'),
    MapEntry('体检', '医疗'),
    MapEntry('居家', '居家'), MapEntry('房租', '居家'), MapEntry('物业', '居家'),
    MapEntry('水电', '居家'), MapEntry('燃气', '居家'), MapEntry('暖气', '居家'),
    MapEntry('维修', '居家'), MapEntry('家政', '居家'), MapEntry('装修', '居家'),
    MapEntry('通讯', '通讯'), MapEntry('话费', '通讯'), MapEntry('流量', '通讯'),
    MapEntry('宽带', '通讯'), MapEntry('网费', '通讯'),
    MapEntry('交通', '交通'), MapEntry('打车', '交通'), MapEntry('出租', '交通'),
    MapEntry('网约', '交通'), MapEntry('地铁', '交通'), MapEntry('公交', '交通'),
    MapEntry('火车', '交通'), MapEntry('高铁', '交通'), MapEntry('飞机', '交通'),
    MapEntry('机票', '交通'), MapEntry('加油', '交通'), MapEntry('油费', '交通'),
    MapEntry('停车', '交通'), MapEntry('过路', '交通'), MapEntry('养车', '交通'),
    MapEntry('租车', '交通'), MapEntry('出行', '交通'),
    MapEntry('娱乐', '娱乐'), MapEntry('游戏', '娱乐'), MapEntry('电影', '娱乐'),
    MapEntry('演出', '娱乐'), MapEntry('ktv', '娱乐'),
    MapEntry('运动', '运动'), MapEntry('健身', '运动'), MapEntry('体育', '运动'),
    MapEntry('球', '运动'),
    MapEntry('购物', '购物'), MapEntry('淘宝', '购物'), MapEntry('天猫', '购物'),
    MapEntry('京东', '购物'), MapEntry('拼多多', '购物'), MapEntry('超市', '购物'),
    MapEntry('商场', '购物'), MapEntry('日用', '购物'), MapEntry('百货', '购物'),
    MapEntry('家居', '购物'), MapEntry('家具', '购物'), MapEntry('家电', '购物'),
    MapEntry('餐饮', '餐饮'), MapEntry('饭', '餐饮'), MapEntry('外卖', '餐饮'),
    MapEntry('食堂', '餐饮'), MapEntry('早餐', '餐饮'), MapEntry('午餐', '餐饮'),
    MapEntry('晚餐', '餐饮'), MapEntry('咖啡', '餐饮'), MapEntry('奶茶', '餐饮'),
    MapEntry('饮料', '餐饮'), MapEntry('烟酒', '餐饮'), MapEntry('零食', '餐饮'),
    MapEntry('水果', '餐饮'), MapEntry('菜', '餐饮'), MapEntry('聚餐', '餐饮'),
    MapEntry('食品', '餐饮'), MapEntry('宵夜', '餐饮'), MapEntry('夜宵', '餐饮'),
  ];

  /// 已写入的自定义分类名集合（避免重复写 storage）
  final Set<String> _addedCustom = {};

  /// 把原始分类映射到本 App 分类名；未匹配则作为自定义分类保留原名称。
  String map(String raw) {
    final key = _normalize(raw);
    if (key.isEmpty) return '其他';

    // 1. 精确/同义词匹配
    final alias = _aliases[key];
    if (alias != null) return alias;

    // 2. 关键词包含匹配
    for (final rule in _keywordRules) {
      if (key.contains(rule.key)) return rule.value;
    }

    // 3. 兜底：作为自定义分类保留原名称
    _ensureCustom(raw);
    return raw;
  }

  void _ensureCustom(String name) {
    if (_addedCustom.contains(name)) return;
    _addedCustom.add(name);
    // 延后由调用方统一持久化（这里仅记录），避免每条都写 storage。
  }

  /// 返回本次映射过程中产生的自定义分类名（供落库前批量持久化）。
  List<String> pendingCustomCategories() => _addedCustom.toList();

  /// 归一化：去空格、转小写、去常见标点，便于匹配
  static String _normalize(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_/、，。：:；;（）()]'), '');
  }

  /// 判断某分类名是否属于本 App 的已知分类（内置或已自定义）
  static bool isKnown(String name) {
    for (final c in Categories.builtinExpense) {
      if (c.name == name) return true;
    }
    for (final c in Categories.builtinIncome) {
      if (c.name == name) return true;
    }
    return false;
  }
}
