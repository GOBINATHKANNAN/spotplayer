import 'package:flutter/material.dart';
import 'package:spotube/services/security/app_lock_service.dart';

class AppLockOverlay extends StatefulWidget {
  final Widget child;

  const AppLockOverlay({super.key, required this.child});

  @override
  State<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends State<AppLockOverlay> {
  bool _isLocked = false;
  bool _isChecking = true;
  final TextEditingController _pinController = TextEditingController();
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkLockStatus();
  }

  Future<void> _checkLockStatus() async {
    final enabled = await AppLockService.isLockEnabled();
    if (mounted) {
      setState(() {
        _isLocked = enabled;
        _isChecking = false;
      });
    }
    if (enabled) {
      _tryBiometricUnlock();
    }
  }

  Future<void> _tryBiometricUnlock() async {
    final success = await AppLockService.authenticateBiometric();
    if (success && mounted) {
      setState(() {
        _isLocked = false;
      });
    }
  }

  Future<void> _unlockWithPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;

    final valid = await AppLockService.verifyPin(pin);
    if (valid && mounted) {
      setState(() {
        _isLocked = false;
        _errorMessage = '';
      });
    } else if (mounted) {
      setState(() {
        _errorMessage = 'Incorrect PIN. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!_isLocked) {
      return widget.child;
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F12),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 64,
                  color: Color(0xFF1DB954),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SPOTPLAYER LOCKED',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your security PIN to continue',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••',
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _unlockWithPin(),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _unlockWithPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'UNLOCK',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _tryBiometricUnlock,
                  icon: const Icon(Icons.fingerprint, color: Colors.white70),
                  label: const Text(
                    'Use Biometrics',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
