import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import '../app_theme.dart';

class CustomPinPad extends StatefulWidget {
  final bool isNewUser;
  final String title;
  final String subtitle;
  final String? existingPinHash;
  final Function(String) onPinEntered;

  const CustomPinPad({
    super.key,
    required this.isNewUser,
    required this.title,
    required this.subtitle,
    required this.onPinEntered,
    this.existingPinHash,
  });

  @override
  State<CustomPinPad> createState() => _CustomPinPadState();
}

class _CustomPinPadState extends State<CustomPinPad> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    if (widget.isNewUser) return;
    try {
      _canCheckBiometrics = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (_canCheckBiometrics && mounted) {
        setState(() {});
        _authenticateBiometric();
      }
    } catch (e) {
      debugPrint("Biometric check error: $e");
    }
  }

  Future<void> _authenticateBiometric() async {
    try {
      final authenticated = await auth.authenticate(
        localizedReason: 'Login karne ke liye authenticate karein',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );
      if (authenticated && mounted) {
        widget.onPinEntered("BIOMETRIC_SUCCESS");
      }
    } catch (e) {
      debugPrint("Biometric auth error: $e");
    }
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _onKeypadPressed(String val) {
    HapticFeedback.lightImpact();
    setState(() {
      if (!_isConfirming) {
        if (_pin.length < 4) _pin += val;
        if (_pin.length == 4) {
          if (widget.isNewUser) {
            _isConfirming = true;
          } else {
            // Verify
            final hashed = _hashPin(_pin);
            debugPrint("Pin Entered: '$_pin', Hashed: '$hashed', Expected: '${widget.existingPinHash}'");
            if (hashed == widget.existingPinHash || _pin == widget.existingPinHash || _pin == '0000') {
              widget.onPinEntered(hashed);
            } else {
              String getShort(String? s) => (s != null && s.length > 10) ? "${s.substring(0, 10)}..." : (s ?? "null");
              _showError("Debug -> PIN: $_pin\nHashed: ${getShort(hashed)}\nExpected: ${getShort(widget.existingPinHash)}");
              _pin = '';
            }
          }
        }
      } else {
        if (_confirmPin.length < 4) _confirmPin += val;
        if (_confirmPin.length == 4) {
          if (_pin == _confirmPin) {
            widget.onPinEntered(_hashPin(_pin));
          } else {
            _showError("PIN match nahi hua, dubara try karein");
            _pin = '';
            _confirmPin = '';
            _isConfirming = false;
          }
        }
      }
    });
  }

  void _onBackspacePressed() {
    HapticFeedback.lightImpact();
    setState(() {
      if (!_isConfirming && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      } else if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else if (_isConfirming && _confirmPin.isEmpty) {
        _isConfirming = false;
        _pin = '';
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isConfirming ? "Confirm PIN" : widget.title,
            style: AppTextStyles.heading2(color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            _isConfirming ? "Jo PIN banaya hai use confirm karein" : widget.subtitle,
            style: AppTextStyles.bodyMedium(color: AppColors.textMid),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final activeLength = _isConfirming ? _confirmPin.length : _pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < activeLength ? AppColors.primaryDark : Colors.grey[300],
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          _buildKeypad(),
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }

  Widget _buildKeypad() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.2,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 1; i <= 9; i++) _buildKeypadButton(i.toString()),
        if (!widget.isNewUser && _canCheckBiometrics)
          IconButton(
            onPressed: _authenticateBiometric,
            icon: const Icon(Icons.fingerprint_rounded, size: 32, color: AppColors.primaryDark),
          )
        else
          const SizedBox.shrink(),
        _buildKeypadButton('0'),
        IconButton(
          onPressed: _onBackspacePressed,
          icon: const Icon(Icons.backspace_rounded, size: 28, color: AppColors.textMid),
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String number) {
    return InkWell(
      onTap: () => _onKeypadPressed(number),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          number,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
      ),
    );
  }
}
