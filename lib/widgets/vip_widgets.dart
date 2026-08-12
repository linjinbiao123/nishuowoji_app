import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_bg.dart';
import '../services/storage.dart';
import '../services/vip_service.dart';
import '../services/vip_crypto.dart';

/// 弹出 VIP 激活面板。激活成功返回 true。
Future<bool> showVipActivateSheet(BuildContext context, {String? feature}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => VipActivateSheet(feature: feature),
  );
  return r == true;
}

/// VIP 激活面板：展示设备码 + 输入卡密激活。
class VipActivateSheet extends StatefulWidget {
  final String? feature;
  const VipActivateSheet({super.key, this.feature});
  @override
  State<VipActivateSheet> createState() => _VipActivateSheetState();
}

class _VipActivateSheetState extends State<VipActivateSheet> {
  final _cardCtrl = TextEditingController();
  int _bgIndex = 0;
  String _deviceCode = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bg = await Storage.getBgIndex();
    final code = await VipService.getDeviceCode();
    if (mounted) setState(() { _bgIndex = bg; _deviceCode = code; });
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _cardCtrl.text.trim();
    if (key.isEmpty) { _tip('请输入卡密'); return; }
    setState(() => _busy = true);
    final r = await VipService.activate(key);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      final date = VipCrypto.isPermanent(r.expUnix)
          ? '永久有效'
          : '有效期至 ${DateTime.fromMillisecondsSinceEpoch(r.expUnix * 1000).toLocal().toString().substring(0, 10)}';
      _tip('激活成功，$date');
      Navigator.pop(context, true);
    } else {
      _tip('激活失败：${r.error}');
    }
  }

  void _tip(String msg, {bool inSheet = false}) {
    final theme = AppBgTheme.all[_bgIndex % AppBgTheme.all.length];
    // 在 BottomSheet 内部调用时，ScaffoldMessenger.of(context) 找到的是上层页面 Scaffold，
    // 导致 SnackBar 显示在 BottomSheet 后面/上层页面。改用 Overlay 显示 Toast，确保跟随当前页面。
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + (inSheet ? 110 : 60),
        left: 0,
        right: 0,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 80),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: AppThemeMode.isLight
                    ? const Color(0xFF323232)
                    : theme.base[1].withOpacity(0.96),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.accent.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: theme.accent, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(msg,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), entry.remove);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppBgTheme.all[_bgIndex % AppBgTheme.all.length];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.base[1],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: theme.accent.withOpacity(0.5), width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppDark.divider,
                    borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.workspace_premium, color: theme.accent, size: 26),
                  const SizedBox(width: 10),
                  Text('激活权限', style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800, color: AppDark.title)),
                ],
              ),
              const SizedBox(height: 8),
              Text('解锁多账本、数据导出、分类预算等全部功能',
                  style: TextStyle(fontSize: 12.5, color: AppDark.sub)),
              const SizedBox(height: 20),
              // 设备码
              Text('① 把设备码发给客服', style: TextStyle(fontSize: 13, color: AppDark.sub)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _deviceCode.isEmpty ? null : () {
                  Clipboard.setData(ClipboardData(text: _deviceCode));
                  _tip('设备码已复制', inSheet: true);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppDark.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_deviceCode.isEmpty ? '读取中…' : _deviceCode,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                                color: AppDark.title, letterSpacing: 1)),
                      ),
                      Icon(Icons.copy, size: 17, color: theme.accent),
                      const SizedBox(width: 6),
                      Text('复制', style: TextStyle(fontSize: 12.5, color: theme.accent)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // 卡密输入
              Text('② 输入收到的卡密', style: TextStyle(fontSize: 13, color: AppDark.sub)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppDark.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppDark.divider),
                ),
                child: TextField(
                  controller: _cardCtrl,
                  style: TextStyle(fontSize: 14, color: AppDark.title),
                  decoration: InputDecoration(
                    hintText: '粘贴卡密',
                    hintStyle: TextStyle(color: AppDark.hint, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _busy ? null : _activate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    disabledBackgroundColor: theme.accent.withOpacity(0.5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _busy
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('立即激活', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// VIP 功能锁定页（用于预算页等整页 gating）。
class VipLockScreen extends StatelessWidget {
  final String feature;
  final VoidCallback? onActivated;
  const VipLockScreen({super.key, required this.feature, this.onActivated});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: Storage.getBgIndex(),
      builder: (context, snap) {
        final theme = AppBgTheme.all[(snap.data ?? 0) % AppBgTheme.all.length];
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    color: theme.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline, size: 38, color: theme.accent),
                ),
                const SizedBox(height: 20),
                Text('「$feature」需要权限', style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: AppDark.title)),
                const SizedBox(height: 8),
                Text('激活权限即可使用多账本、数据导出、分类预算等全部功能',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppDark.sub, height: 1.5)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await showVipActivateSheet(context, feature: feature);
                    if (ok) onActivated?.call();
                  },
                  icon: Icon(Icons.workspace_premium, color: Colors.white, size: 18),
                  label: const Text('立即激活', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
