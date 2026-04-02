import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/l10n/app_localizations.dart';

class HealthCheckScreen extends StatefulWidget {
  const HealthCheckScreen({super.key});

  @override
  State<HealthCheckScreen> createState() => _HealthCheckScreenState();
}

class _HealthCheckScreenState extends State<HealthCheckScreen> {
  bool _loading = false;
  String? _status;
  String? _error;
  Map<String, dynamic>? _details;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await locator<Dio>().get(
        AppConfig.healthCheckEndpoint,
      );

      if (mounted) {
        setState(() {
          _status = resp.data['status'] ?? "Unknown";
          _details = resp.data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = context.tr("تعذر الاتصال بسيرفر الوزارة. تأكد أن السيرفر يعمل.");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr("حالة النظام"), style: GoogleFonts.cairo())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_error != null)
                    Text(_error!, style: GoogleFonts.cairo(color: Colors.red), textAlign: TextAlign.center),
                  if (_status != null)
                    Column(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 80),
                        const SizedBox(height: 10),
                        Text("${context.tr("الحالة:")} $_status", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        if (_details != null)
                          ...(_details!.entries.map((e) => ListTile(title: Text(e.key), subtitle: Text(e.value.toString())))),
                      ],
                    ),
                  const Spacer(),
                  ElevatedButton(onPressed: _fetch, child: Text(context.tr("تحديث"))),
                ],
              ),
            ),
    );
  }
}
