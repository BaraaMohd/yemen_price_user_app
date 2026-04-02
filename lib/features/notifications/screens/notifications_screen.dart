import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _kEnabled = "notif_enabled";
  static const _kPriceAlerts = "notif_price_alerts";
  static const _kViolationAlerts = "notif_violation_alerts";
  static const _kExchangeAlerts = "notif_exchange_alerts";
  static const _kNewsAlerts = "notif_news_alerts";
  static const _kNearbyAlerts = "notif_nearby_alerts";
  static const _kRadiusKm = "notif_radius_km";
  static const _kPriceChangePct = "notif_price_change_pct";
  static const _kFrequency = "notif_frequency";
  static const _kQuietEnabled = "notif_quiet_enabled";
  static const _kQuietStart = "notif_quiet_start_min";
  static const _kQuietEnd = "notif_quiet_end_min";
  static const _kLastSaved = "notif_last_saved";

  bool _loading = true;
  bool _permissionGranted = true;

  bool _enabled = true;
  bool _priceAlerts = true;
  bool _violationAlerts = true;
  bool _exchangeAlerts = true;
  bool _newsAlerts = true;
  bool _nearbyAlerts = false;

  double _radiusKm = 10;
  double _priceChangePct = 5;
  String _frequency = "instant";

  bool _quietHoursEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  String? _lastSaved;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  int _toMinutes(TimeOfDay t) => (t.hour * 60) + t.minute;

  TimeOfDay _fromMinutes(int minutes) {
    final m = minutes % 60;
    final h = (minutes ~/ 60) % 24;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _loadSettings() async {
    await NotificationService.init();
    final prefs = await SharedPreferences.getInstance();
    final permission = await NotificationService.areNotificationsEnabled();
    setState(() {
      _permissionGranted = permission;
      _enabled = prefs.getBool(_kEnabled) ?? true;
      _priceAlerts = prefs.getBool(_kPriceAlerts) ?? true;
      _violationAlerts = prefs.getBool(_kViolationAlerts) ?? true;
      _exchangeAlerts = prefs.getBool(_kExchangeAlerts) ?? true;
      _newsAlerts = prefs.getBool(_kNewsAlerts) ?? true;
      _nearbyAlerts = prefs.getBool(_kNearbyAlerts) ?? false;
      _radiusKm = prefs.getDouble(_kRadiusKm) ?? 10;
      _priceChangePct = prefs.getDouble(_kPriceChangePct) ?? 5;
      _frequency = prefs.getString(_kFrequency) ?? "instant";
      _quietHoursEnabled = prefs.getBool(_kQuietEnabled) ?? false;
      _quietStart = _fromMinutes(prefs.getInt(_kQuietStart) ?? (22 * 60));
      _quietEnd = _fromMinutes(prefs.getInt(_kQuietEnd) ?? (7 * 60));
      _lastSaved = prefs.getString(_kLastSaved);
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, _enabled);
    await prefs.setBool(_kPriceAlerts, _priceAlerts);
    await prefs.setBool(_kViolationAlerts, _violationAlerts);
    await prefs.setBool(_kExchangeAlerts, _exchangeAlerts);
    await prefs.setBool(_kNewsAlerts, _newsAlerts);
    await prefs.setBool(_kNearbyAlerts, _nearbyAlerts);
    await prefs.setDouble(_kRadiusKm, _radiusKm);
    await prefs.setDouble(_kPriceChangePct, _priceChangePct);
    await prefs.setString(_kFrequency, _frequency);
    await prefs.setBool(_kQuietEnabled, _quietHoursEnabled);
    await prefs.setInt(_kQuietStart, _toMinutes(_quietStart));
    await prefs.setInt(_kQuietEnd, _toMinutes(_quietEnd));
    final nowIso = DateTime.now().toIso8601String();
    await prefs.setString(_kLastSaved, nowIso);
    if (!mounted) return;
    setState(() {
      _lastSaved = nowIso;
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _quietStart : _quietEnd;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _quietStart = picked;
      } else {
        _quietEnd = picked;
      }
    });
    await _saveSettings();
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return context.tr("لم يتم الحفظ بعد");
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return context.tr("لم يتم الحفظ بعد");
    String two(int v) => v.toString().padLeft(2, '0');
    final date = "${two(parsed.day)}-${two(parsed.month)}-${parsed.year}";
    final timeOfDay = TimeOfDay.fromDateTime(parsed);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(timeOfDay);
    return "$date • $time";
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withAlpha((0.8 * 255).round()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).primaryColor.withAlpha((0.25 * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr("الإشعارات"),
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr("تحكم بتنبيهات الأسعار والمخالفات وسعر الصرف."),
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  "${context.tr("آخر حفظ")}: ${_formatDateTime(_lastSaved)}",
                  style: GoogleFonts.cairo(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterSwitch() {
    return _sectionCard(
      child: SwitchListTile(
        value: _enabled,
        contentPadding: EdgeInsets.zero,
        title: Text(
          context.tr("تفعيل الإشعارات"),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          context.tr("سيرسل تنبيهات عند تغيّر الأسعار والمخالفات حسب منطقتك."),
          style: GoogleFonts.cairo(fontSize: 12),
        ),
        onChanged: (v) async {
          setState(() => _enabled = v);
          if (v && !_permissionGranted) {
            await _requestPermission();
          }
          await _saveSettings();
        },
      ),
    );
  }

  Widget _buildPermissionCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("صلاحية الإشعارات"),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _permissionGranted ? Icons.check_circle : Icons.error_outline,
                color: _permissionGranted ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _permissionGranted
                      ? context.tr("الإشعارات مفعلة على الجهاز")
                      : context.tr("الإشعارات غير مفعلة على الجهاز"),
                  style: GoogleFonts.cairo(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_permissionGranted)
            ElevatedButton(
              onPressed: _requestPermission,
              child: Text(context.tr("طلب الإذن")),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertTypes() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("أنواع التنبيهات"),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _priceAlerts,
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr("تغيّر أسعار السلع")),
            secondary: const Icon(Icons.trending_up),
            onChanged: (v) async {
              setState(() => _priceAlerts = v);
              await _saveSettings();
            },
          ),
          SwitchListTile(
            value: _violationAlerts,
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr("مخالفات الأسعار")),
            secondary: const Icon(Icons.report_outlined),
            onChanged: (v) async {
              setState(() => _violationAlerts = v);
              await _saveSettings();
            },
          ),
          SwitchListTile(
            value: _exchangeAlerts,
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr("سعر الصرف")),
            secondary: const Icon(Icons.currency_exchange),
            onChanged: (v) async {
              setState(() => _exchangeAlerts = v);
              await _saveSettings();
            },
          ),
          SwitchListTile(
            value: _newsAlerts,
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr("أخبار الوزارة")),
            secondary: const Icon(Icons.newspaper),
            onChanged: (v) async {
              setState(() => _newsAlerts = v);
              await _saveSettings();
            },
          ),
          SwitchListTile(
            value: _nearbyAlerts,
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr("المتاجر القريبة")),
            secondary: const Icon(Icons.store_mall_directory_outlined),
            onChanged: (v) async {
              setState(() => _nearbyAlerts = v);
              await _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSensitivity() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("النطاق"),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "${context.tr("ضمن")} ${_radiusKm.toStringAsFixed(0)} ${context.tr("كم")}",
            style: GoogleFonts.cairo(fontSize: 12),
          ),
          Slider(
            value: _radiusKm,
            min: 1,
            max: 50,
            divisions: 49,
            label: _radiusKm.toStringAsFixed(0),
            onChanged: (v) {
              setState(() => _radiusKm = v);
            },
            onChangeEnd: (_) => _saveSettings(),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr("حساسية التنبيه"),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "${context.tr("تنبيه عند تغيّر السعر بنسبة")} ${_priceChangePct.toStringAsFixed(0)}%",
            style: GoogleFonts.cairo(fontSize: 12),
          ),
          Slider(
            value: _priceChangePct,
            min: 1,
            max: 30,
            divisions: 29,
            label: _priceChangePct.toStringAsFixed(0),
            onChanged: (v) {
              setState(() => _priceChangePct = v);
            },
            onChangeEnd: (_) => _saveSettings(),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequency() {
    final options = [
      {"key": "instant", "label": context.tr("فوري")},
      {"key": "hourly", "label": context.tr("ساعي")},
      {"key": "daily", "label": context.tr("ملخص يومي")},
    ];

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("التوقيت"),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: options
                .map(
                  (o) => ChoiceChip(
                    label: Text(o["label"]!),
                    selected: _frequency == o["key"],
                    onSelected: (v) async {
                      if (!v) return;
                      setState(() => _frequency = o["key"]!);
                      await _saveSettings();
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _quietHoursEnabled,
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr("ساعات الهدوء")),
            subtitle: Text(context.tr("إيقاف الإشعارات ليلاً")),
            onChanged: (v) async {
              setState(() => _quietHoursEnabled = v);
              await _saveSettings();
            },
          ),
          if (_quietHoursEnabled)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(isStart: true),
                    child: Text(
                      "${context.tr("من")} ${_quietStart.format(context)}",
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(isStart: false),
                    child: Text(
                      "${context.tr("إلى")} ${_quietEnd.format(context)}",
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTestNotification() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("اختبار الإشعار"),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr("أرسل إشعاراً تجريبياً"),
            style: GoogleFonts.cairo(fontSize: 12),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              await NotificationService.showTestNotification();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr("تم إرسال إشعار تجريبي"))),
              );
            },
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(context.tr("تنبيه")),
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Text(
        context.tr("إعدادات الإشعارات تحفظ تلقائياً"),
        style: GoogleFonts.cairo(
          fontSize: 11,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr("الإشعارات"))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr("الإشعارات"))),
      body: ListView(
        children: [
          _buildHeader(),
          _buildPermissionCard(),
          _buildMasterSwitch(),
          _wrapDisabled(_buildAlertTypes()),
          _wrapDisabled(_buildRangeSensitivity()),
          _wrapDisabled(_buildFrequency()),
          _wrapDisabled(_buildTestNotification()),
          _buildHint(),
        ],
      ),
    );
  }

  Widget _wrapDisabled(Widget child) {
    if (_enabled) return child;
    return Opacity(
      opacity: 0.5,
      child: IgnorePointer(ignoring: true, child: child),
    );
  }

  Future<void> _requestPermission() async {
    final granted = await NotificationService.requestPermissions();
    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
    });
  }
}
