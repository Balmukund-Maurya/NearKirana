import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class CustomPinPad extends StatefulWidget {
  final bool isNewUser;
  final String title;
  final String subtitle;
  final Function(String pin) onPinEntered;
  final String? existingPinHash;
  final int lockoutSeconds;

  const CustomPinPad({
    super.key,
    required this.isNewUser,
    required this.title,
    required this.subtitle,
    required this.onPinEntered,
    this.existingPinHash,
    this.lockoutSeconds = 0,
  });

  /// Helper to hash PIN
  static String hashPin(String pin) {
    if (pin == "BIOMETRIC_SUCCESS") return pin;
    var bytes = utf8.encode("${pin}kirana_salt_2026"); // Add salt
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  State<CustomPinPad> createState() => _CustomPinPadState();
}

class _CustomPinPadState extends State<CustomPinPad> {
  String pin = "";
  bool isError = false;
  int wrongAttempts = 0;
  bool isLockedOut = false;
  int lockoutSecondsRemaining = 0;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    if (widget.lockoutSeconds > 0) {
      isLockedOut = true;
      lockoutSecondsRemaining = widget.lockoutSeconds;
      _startLockoutTimer();
    } else if (!widget.isNewUser) {
      _checkBiometrics();
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (canAuthenticate) {
        final List<BiometricType> availableBiometrics = await auth.getAvailableBiometrics();
        if (availableBiometrics.isNotEmpty) {
          bool didAuthenticate = await auth.authenticate(
            localizedReason: 'Kirana App me login karne ke liye verify karein',
            persistAcrossBackgrounding: true,
          );

          if (didAuthenticate && mounted) {
            widget.onPinEntered("BIOMETRIC_SUCCESS");
          }
        }
      }
    } on Exception {
      debugPrint("Biometric Error: \$e");
    }
  }

  void _startLockoutTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        lockoutSecondsRemaining--;
      });
      if (lockoutSecondsRemaining <= 0) {
        setState(() {
          isLockedOut = false;
          wrongAttempts = 0;
          isError = false;
        });
        return false;
      }
      return true;
    });
  }

  void _onKeyPressed(String val) {
    if (isLockedOut) return;
    
    HapticFeedback.lightImpact();

    if (val == "DEL") {
      if (pin.isNotEmpty) {
        setState(() {
          pin = pin.substring(0, pin.length - 1);
          isError = false;
        });
      }
    } else {
      if (pin.length < 4) {
        setState(() {
          pin += val;
          isError = false;
        });

        if (pin.length == 4) {
          // Auto submit
          _verifyPin();
        }
      }
    }
  }

  void _verifyPin() {
    if (widget.isNewUser) {
      widget.onPinEntered(CustomPinPad.hashPin(pin));
    } else {
      final inputHash = CustomPinPad.hashPin(pin);
      if (inputHash == widget.existingPinHash || pin == widget.existingPinHash) {
        widget.onPinEntered(inputHash); 
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          isError = true;
          wrongAttempts++;
          pin = "";
        });

        if (wrongAttempts >= 5) {
          setState(() {
            isLockedOut = true;
            lockoutSecondsRemaining = 30;
          });
          _startLockoutTimer();
        }
      }
    }
  }

  Widget _buildNumpadButton(String val) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onKeyPressed(val),
            borderRadius: BorderRadius.circular(40),
            splashColor: Colors.grey.withValues(alpha: 0.3),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: val == "" ? Colors.transparent : Colors.grey.shade100,
              ),
              child: Center(
                child: val == "DEL"
                    ? const Icon(Icons.backspace_outlined, color: Colors.black87)
                    : Text(
                        val,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Icon(Icons.lock_outline_rounded, size: 48, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),

          if (isLockedOut)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_clock, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Too many wrong attempts!\nPlease wait $lockoutSecondsRemaining seconds.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                bool isFilled = index < pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isError
                        ? Colors.red
                        : (isFilled ? Colors.green : Colors.grey.shade300),
                    boxShadow: isFilled && !isError
                        ? [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 8)]
                        : null,
                  ),
                );
              }),
            ),
          
          if (!widget.isNewUser && wrongAttempts > 0 && !isLockedOut)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '$wrongAttempts/5 galat attempts. ${5 - wrongAttempts} baaki.',
                style: TextStyle(
                  color: wrongAttempts >= 3 ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(height: 40),

          Column(
            children: [
              Row(
                children: [
                  _buildNumpadButton("1"),
                  _buildNumpadButton("2"),
                  _buildNumpadButton("3"),
                ],
              ),
              Row(
                children: [
                  _buildNumpadButton("4"),
                  _buildNumpadButton("5"),
                  _buildNumpadButton("6"),
                ],
              ),
              Row(
                children: [
                  _buildNumpadButton("7"),
                  _buildNumpadButton("8"),
                  _buildNumpadButton("9"),
                ],
              ),
              Row(
                children: [
                  _buildNumpadButton(""),
                  _buildNumpadButton("0"),
                  _buildNumpadButton("DEL"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
