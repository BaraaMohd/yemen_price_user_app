import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/auth_session.dart';
import '../products/screens/merchant_store_screen.dart';
import '../ministry/screens/ministry_dashboard_screen.dart';
import 'login_screen.dart';

class MerchantAppGateScreen extends StatefulWidget {
  const MerchantAppGateScreen({super.key});

  @override
  State<MerchantAppGateScreen> createState() => _MerchantAppGateScreenState();
}

class _MerchantAppGateScreenState extends State<MerchantAppGateScreen> {
  late final Future<Widget> _startScreenFuture = _resolveStartScreen();

  Future<Widget> _resolveStartScreen() async {
    final role = await AuthSession.role();
    if (role == AuthSession.roleMinistry) {
      return const MinistryDashboardScreen();
    }
    final hasMerchantSession = await AuthSession.hasMerchantSession();
    if (hasMerchantSession) {
      return const MerchantStoreScreen();
    }
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _startScreenFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text("Loading merchant app...", style: GoogleFonts.cairo()),
                ],
              ),
            ),
          );
        }
        return snapshot.data!;
      },
    );
  }
}
