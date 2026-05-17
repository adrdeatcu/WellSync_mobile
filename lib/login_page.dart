import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthMode { login, register }

class MobileLoginPage extends StatefulWidget {
  const MobileLoginPage({super.key});

  @override
  State<MobileLoginPage> createState() => _MobileLoginPageState();
}

class _MobileLoginPageState extends State<MobileLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AuthMode _mode = AuthMode.login;
  bool _loading = false;
  String? _error;

  final _supabase = Supabase.instance.client;

  Future<void> _handleSubmit() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      if (_mode == AuthMode.register) {
        final res = await _supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (res.user == null) {
          throw Exception('Registration failed');
        }

        // profiles row is created by Supabase trigger
        setState(() {
          _mode = AuthMode.login;
        });
      } else {
        final res = await _supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (res.session == null) {
          throw Exception('Login failed');
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MobileDashboardPage()),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.5, -1.0), // approx 160deg like CSS
            end: Alignment(0.8, 1.0),
            colors: [
              Color(0xFFEAF5F3), // #eaf5f3
              Color(0xFFC9E6E0), // #c9e6e0
            ],
          ),
        ),
        child: Stack(
          children: [
            // Top-left blob
            const Positioned(
              top: -160,
              left: -160,
              child: _Blob(
                width: 420,
                height: 420,
                opacity: 0.35,
              ),
            ),
            // Bottom-right blob
            const Positioned(
              bottom: -160,
              right: -160,
              child: _Blob(
                width: 420,
                height: 420,
                opacity: 0.28,
              ),
            ),

            // Center content
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brand: logo + tagline
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          _WellSyncLogo(),
                          SizedBox(height: 12),
                          Text(
                            'Your health in sync',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 15,
                              letterSpacing: 0.3,
                              color: Color(0xFF4A6E6C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFD8E9E6)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(31, 95, 99, 0.35),
                              blurRadius: 60,
                              offset: Offset(0, 24),
                              spreadRadius: -24,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _mode == AuthMode.login
                                  ? 'Welcome back'
                                  : 'Create your account',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F3B3A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _mode == AuthMode.login
                                  ? 'Sign in to continue your wellness journey.'
                                  : 'Start syncing your health today.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF5D7B79),
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Email field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Email',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF2C4F4D),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _wellSyncInputDecoration(
                                    hintText: 'you@example.com',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Password field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Password',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF2C4F4D),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: _wellSyncInputDecoration(
                                    hintText: '••••••••',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDECEC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFF5C2C0),
                                  ),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFB3261E),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Submit button
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: EdgeInsets.zero,
                                  backgroundColor: const Color(0xFF1F5F63),
                                ),
                                child: Text(
                                  _loading
                                      ? 'Please wait...'
                                      : _mode == AuthMode.login
                                          ? 'Sign in'
                                          : 'Create account',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Switch text
                            Center(
                              child: TextButton(
                                onPressed: _loading
                                    ? null
                                    : () {
                                        setState(() {
                                          _mode = _mode == AuthMode.login
                                              ? AuthMode.register
                                              : AuthMode.login;
                                        });
                                      },
                                child: Text(
                                  _mode == AuthMode.login
                                      ? 'New to WellSync? Create an account'
                                      : 'Already have an account? Sign in',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1F5F63),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),
                      const Text(
                        '© 2026 WellSync. All rights reserved.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B8B89),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Logo widget (matches .ws-logo)
class _WellSyncLogo extends StatelessWidget {
  const _WellSyncLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/wellsync-logo.png',
      height: 140,
      fit: BoxFit.contain,
    );
  }
}

// Background blob (matches .ws-blob)
class _Blob extends StatelessWidget {
  final double width;
  final double height;
  final double opacity;

  const _Blob({
    required this.width,
    required this.height,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1F5F63),
              Color(0xFF7CC2B5),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _wellSyncInputDecoration({required String hintText}) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: const Color(0xFFF6FBFA),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: Color(0xFFCFE2DF),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: Color(0xFFCFE2DF),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: Color(0xFF1F5F63),
      ),
    ),
  );
}

class MobileDashboardPage extends StatelessWidget {
  const MobileDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WellSync Mobile Dashboard')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MobileLoginPage()),
            );
          },
          child: const Text('Log out'),
        ),
      ),
    );
  }
}