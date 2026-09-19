import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'app_theme.dart';
import 'shop_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class ShopQrScreen extends StatefulWidget {
  const ShopQrScreen({super.key});

  @override
  State<ShopQrScreen> createState() => _ShopQrScreenState();
}

class _ShopQrScreenState extends State<ShopQrScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _shareQR() async {
    setState(() => _isSharing = true);
    try {
      final image = await _screenshotController.capture(
        delay: const Duration(milliseconds: 10),
      );
      if (image == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final imagePath = await File('${directory.path}/shop_qr.png').create();
      await imagePath.writeAsBytes(image);

      if (!mounted) return;
      final shopName =
          Provider.of<ShopProvider>(context, listen: false).shopName ?? 'Shop';

      await SharePlus.instance.share(
        ShareParams(
          text:
              'Hello, You can now order from $shopName online. Scan this QR Code to visit our online shop.',
          files: [XFile(imagePath.path)],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing QR: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = Provider.of<ShopProvider>(context);
    final shopId = shopProvider.currentShopId ?? '';
    final shopName = shopProvider.shopName ?? 'My Shop';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Shop QR Code',
          style: AppTextStyles.heading2(color: AppColors.textDark),
        ),
        backgroundColor: AppColors.cardBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      backgroundColor: AppColors.cardBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Share this QR code with your customers so they can easily find your shop and place orders.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium(color: AppColors.textMid),
              ),
              const SizedBox(height: 32),
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shopName,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scan to Order Online',
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textMid,
                        ),
                      ),
                      const SizedBox(height: 24),
                      QrImageView(
                        data: shopId,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Powered by NearKirana',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSharing ? null : _shareQR,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isSharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.share_rounded, color: Colors.white),
                  label: Text(
                    _isSharing ? 'Sharing...' : 'Share QR Code',
                    style: AppTextStyles.bodySemiBold(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
