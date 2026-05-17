import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rvzdtprvsjtmhycosifj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ2emR0cHJ2c2p0bWh5Y29zaWZqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1MDgwMTMsImV4cCI6MjA5NDA4NDAxM30.HrPg7fAIauVQaBKExYmZhqK5K3-riHwoZqcRXXCr53k',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: session == null
          ? const MobileLoginPage()
          : const MobileDashboardPage(),
    );
  }
}