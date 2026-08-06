import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../theme/app_theme.dart';
import '../theme/app_bg.dart';
import '../services/storage.dart';
import '../services/categories.dart';
import '../services/asr_service.dart';
import '../services/asr_model.dart';

enum _Stage { idle, recording, transcribing, result }

/// 语音记账弹窗：按住说话 → 本地离线识别 → 自动解析金额/分类 → 保存。
/// 识别完全离线；仅首次需联网下载一次语音模型（约 82MB）。
class VoiceRecordSheet extends StatefulWidget {
  const VoiceRecordSheet({super.key});
  @override
  State<VoiceRecordSheet> createState() => _VoiceRecordSheetState();
}

class _VoiceRecordSheetState extends State<VoiceRecordSheet>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  late final AnimationController _pulseCtrl;
  final _amountCtrl = TextEditingController();

  _Stage _stage = _Stage.idle;
  int _bgIndex = 0;
  String _text = '';
  String _error = '';
  String _category = '餐饮';
  bool _isExpense = true;
  bool _micReady = false;

  // 离线语音模型
  bool _modelReady = false;
  bool _downloading = false;
  double _progress = 0; // 0~1
  String _downloadError = '';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _init();
  }

  Future<void> _init() async {
    final bg = await Storage.getBgIndex();
    if (mounted) setState(() => _bgIndex = bg);
    if (kIsWeb) return; // 网页版不支持语音
    final ready = await AsrService.isReady;
    if (mounted) setState(() { _modelReady = ready; });
    // 麦克风权限
    final ok = await _recorder.hasPermission();
    if (mounted) setState(() => _micReady = ok);
  }

  /// 下载离线语音模型（约 82MB，仅首次需要）。
  Future<void> _downloadModel() async {
    setState(() { _downloading = true; _progress = 0; _downloadError = ''; });
    try {
      await AsrModel.download(onProgress: (received, total) {
        if (!mounted) return;
        final p = total > 0 ? received / total : 0.0;
        setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() { _downloading = false; _modelReady = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _downloadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _amountCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  AppBgTheme get _theme => AppBgTheme.all[_bgIndex % AppBgTheme.all.length];

  // ---------------- 录音 ----------------

  Future<void> _startRecording() async {
    if (!_micReady) {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        setState(() => _error = '未获得麦克风权限，请在系统设置中开启');
        return;
      }
      _micReady = true;
    }
    setState(() {
      _stage = _Stage.recording;
      _error = '';
      _text = '';
    });
    final path = AsrService.tempRecordPath();
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
    } catch (e) {
      if (mounted) setState(() { _stage = _Stage.idle; _error = '录音启动失败'; });
    }
  }

  Future<void> _stopRecording() async {
    if (_stage != _Stage.recording) return;
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _stage = _Stage.transcribing);
    try {
      // 让出一帧，先把"识别中"动画绘制出来，再执行本地识别
      await Future.delayed(const Duration(milliseconds: 60));
      final text = await AsrService.recognizeFile(path);
      if (!mounted) return;
      if (text.trim().isEmpty) {
        setState(() { _stage = _Stage.idle; _error = '没听清，请再说一次'; });
        return;
      }
      _parse(text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.idle;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _cancelRecording() async {
    if (_stage != _Stage.recording) return;
    await _recorder.cancel().catchError((_) => null);
    if (mounted) setState(() => _stage = _Stage.idle);
  }

  // ---------------- 解析 ----------------

  void _parse(String text) {
    final amount = _extractAmount(text);
    final category = _matchCategory(text);
    final isExpense = !_isIncome(text);
    final hasCategory = category != '其他';

    // 金额和分类都识别到 → 直接自动保存，不用动手
    if (amount != null && amount > 0 && hasCategory) {
      _autoSave(amount, category, isExpense, text);
      return;
    }

    // 否则进入手动确认界面
    setState(() {
      _text = text;
      _stage = _Stage.result;
      _category = category;
      _isExpense = isExpense;
      _amountCtrl.text = amount != null && amount > 0
          ? (amount == amount.roundToDouble() ? amount.toInt().toString() : amount.toString())
          : '';
    });
  }

  /// 自动保存并关闭弹窗
  Future<void> _autoSave(double amount, String category, bool isExpense, String text) async {
    await Storage.add(Record(
      amount: amount,
      category: category,
      note: text,
      time: DateTime.now(),
      isExpense: isExpense,
    ));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  /// 从文本中提取金额：先试阿拉伯数字，再试中文数字
  double? _extractAmount(String text) {
    // 1. 阿拉伯数字
    final m = RegExp(r'\d+\.?\d*').firstMatch(text);
    if (m != null) {
      final v = double.tryParse(m.group(0)!);
      if (v != null && v > 0) return v;
    }
    // 2. 中文数字（如"二十五""一百三""三千五""两块五"）
    return _chineseToNum(text);
  }

  /// 中文数字转阿拉伯数字，支持常见口语表达
  double? _chineseToNum(String text) {
    const digits = {'零':0,'一':1,'二':2,'两':2,'三':3,'四':4,'五':5,'六':6,'七':7,'八':8,'九':9};
    const units = {'十':10,'百':100,'千':1000,'万':10000,'亿':100000000};

    // 提取中文数字片段（连续的数字字符）
    final cnChars = RegExp(r'[零一二两三四五六七八九十百千万亿]+');
    final matches = cnChars.allMatches(text);
    for (final match in matches) {
      final s = match.group(0)!;
      if (s.isEmpty) continue;
      final result = _parseCnNum(s, digits, units);
      if (result != null && result > 0) return result;
    }
    return null;
  }

  double? _parseCnNum(String s, Map<String,int> digits, Map<String,int> units) {
    double total = 0;
    double current = 0;
    double lastUnit = 1;

    for (int i = 0; i < s.length; i++) {
      final ch = s[i];
      if (digits.containsKey(ch)) {
        current = digits[ch]!.toDouble();
      } else if (units.containsKey(ch)) {
        final unit = units[ch]!.toDouble();
        if (current == 0 && unit == 10) {
          // "十五" → 1*10+5, 十前面没有数字默认1
          current = 1;
        }
        if (unit >= 10000) {
          // 万/亿：把之前累积的乘以万
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
    // 处理尾部：如"一百三"的"三"= 3*10(上一级单位的1/10)
    if (current > 0) {
      if (lastUnit >= 10) {
        total += current * (lastUnit / 10);
      } else {
        total += current;
      }
    }
    return total > 0 ? total : null;
  }

  String _matchCategory(String text) {
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

  bool _isIncome(String text) {
    const kw = ['收入', '工资', '兼职', '理财', '礼金', '报销', '红包', '赚钱', '到账', '进账'];
    return kw.any(text.contains);
  }

  // ---------------- 保存 ----------------

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _snack('请输入有效金额');
      return;
    }
    await Storage.add(Record(
      amount: amount,
      category: _category,
      note: _text.isEmpty ? _category : _text,
      time: DateTime.now(),
      isExpense: _isExpense,
    ));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Center(child: Text(msg,
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppThemeMode.isLight
          ? const Color(0xFF323232)
          : _theme.base[1].withOpacity(0.96),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _theme.accent.withOpacity(0.35)),
      ),
      duration: const Duration(seconds: 2),
    ));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return Container(
      decoration: BoxDecoration(
        color: theme.base[1],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: theme.accent.withOpacity(0.5), width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppDark.divider,
                borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.mic, color: theme.accent, size: 24),
              const SizedBox(width: 10),
              Text('语音记账', style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800, color: AppDark.title)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('离线识别', style: TextStyle(fontSize: 11, color: AppDark.sub)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (kIsWeb)
            ..._buildWebUnsupported(theme)
          else if (!_modelReady)
            ..._buildDownloadArea(theme)
          else if (_stage == _Stage.result)
            ..._buildResult(theme)
          else
            ..._buildMicArea(theme),
        ],
      ),
    );
  }

  List<Widget> _buildWebUnsupported(AppBgTheme theme) {
    return [
      const SizedBox(height: 16),
      Icon(Icons.info_outline, size: 52, color: theme.accent),
      const SizedBox(height: 18),
      Text('网页版不支持语音记账', style: TextStyle(fontSize: 15, color: AppDark.title, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('语音识别需要在手机 App 中使用', style: TextStyle(fontSize: 12.5, color: AppDark.sub)),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildDownloadArea(AppBgTheme theme) {
    if (_downloading) {
      final percent = (_progress * 100).toStringAsFixed(0);
      return [
        const SizedBox(height: 10),
        Icon(Icons.downloading, size: 56, color: theme.accent),
        const SizedBox(height: 18),
        Text('正在下载语音模型…', style: TextStyle(fontSize: 15, color: AppDark.title, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('约 82MB，仅首次需要，下载后即可完全离线使用', style: TextStyle(fontSize: 12, color: AppDark.sub)),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progress > 0 ? _progress : null,
            minHeight: 8,
            backgroundColor: AppDark.track,
            valueColor: AlwaysStoppedAnimation(theme.accent),
          ),
        ),
        const SizedBox(height: 8),
        Text('$percent%', style: TextStyle(fontSize: 13, color: theme.accent, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
      ];
    }
    return [
      const SizedBox(height: 6),
      Icon(Icons.cloud_download_outlined, size: 56, color: theme.accent),
      const SizedBox(height: 18),
      Text('首次使用需下载语音模型', style: TextStyle(fontSize: 15, color: AppDark.title, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('约 82MB，下载一次后语音记账完全离线，录音不出手机',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppDark.sub, height: 1.5)),
      if (_downloadError.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(_downloadError, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
      ],
      const SizedBox(height: 22),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _downloadModel,
          icon: const Icon(Icons.download, color: Colors.white, size: 19),
          label: const Text('下载语音模型', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(height: 6),
    ];
  }

  List<Widget> _buildMicArea(AppBgTheme theme) {
    return [
      if (_error.isNotEmpty) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(_error, style: const TextStyle(fontSize: 12.5, color: AppColors.danger))),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      GestureDetector(
        onLongPressStart: (_) => _startRecording(),
        onLongPressEnd: (_) => _stopRecording(),
        onLongPressCancel: () => _cancelRecording(),
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) {
            final scale = _stage == _Stage.recording ? 1.0 + _pulseCtrl.value * 0.12 : 1.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _stage == _Stage.recording
                      ? theme.accent
                      : theme.accent.withOpacity(0.15),
                  border: Border.all(color: theme.accent, width: 2),
                ),
                child: Icon(
                  _stage == _Stage.transcribing ? Icons.hourglass_top : Icons.mic,
                  size: 48,
                  color: _stage == _Stage.recording ? Colors.white : theme.accent,
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 20),
      Text(
        _stage == _Stage.recording
            ? '正在聆听，松开结束'
            : _stage == _Stage.transcribing
                ? '正在识别…'
                : '按住 说话',
        style: TextStyle(fontSize: 14, color: AppDark.sub),
      ),
      const SizedBox(height: 6),
      Text('例如：「午餐花了 25 元」', style: TextStyle(fontSize: 12, color: AppDark.hint)),
    ];
  }

  List<Widget> _buildResult(AppBgTheme theme) {
    final cats = _isExpense ? Categories.builtinExpense : Categories.builtinIncome;
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppDark.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.record_voice_over, size: 18, color: theme.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(_text, style: TextStyle(fontSize: 14, color: AppDark.title, height: 1.4))),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // 金额
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppDark.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _amountCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
            color: _isExpense ? AppColors.danger : AppColors.success),
          decoration: InputDecoration(
            prefixText: '¥ ',
            prefixStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
              color: _isExpense ? AppColors.danger : AppColors.success),
            hintText: '0.00',
            hintStyle: TextStyle(color: AppDark.hint, fontSize: 26),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
      const SizedBox(height: 14),
      // 收支类型
      Row(
        children: [
          _typeChip('支出', _isExpense, AppColors.danger, () => setState(() { _isExpense = true; _category = _matchCategory(_text); })),
          const SizedBox(width: 10),
          _typeChip('收入', !_isExpense, AppColors.success, () => setState(() { _isExpense = false; _category = _matchCategory(_text); })),
        ],
      ),
      const SizedBox(height: 14),
      // 分类
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: cats.map((c) {
            final selected = c.name == _category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _category = c.name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? c.color.withOpacity(0.15) : AppDark.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? c.color : AppDark.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c.icon, size: 14, color: selected ? c.color : AppDark.sub),
                      const SizedBox(width: 4),
                      Text(c.name, style: TextStyle(fontSize: 12.5,
                        color: selected ? c.color : AppDark.sub, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() { _stage = _Stage.idle; _text = ''; _error = ''; }),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppDark.sub,
                side: BorderSide(color: AppDark.divider),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('重说', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('记一笔', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _typeChip(String label, bool selected, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : AppDark.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : AppDark.divider),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(
            color: selected ? color : AppDark.sub, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
