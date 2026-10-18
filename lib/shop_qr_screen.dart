import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'shop_provider.dart';
import 'language_provider.dart';

class ShopQrScreen extends StatefulWidget {
  const ShopQrScreen({super.key});

  @override
  State<ShopQrScreen> createState() => _ShopQrScreenState();
}

class _ShopQrScreenState extends State<ShopQrScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _shareQR(String Function(String, String, String) t) async {
    HapticFeedback.lightImpact();
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
      final shopName = Provider.of<ShopProvider>(context, listen: false).shopName ?? 'Shop';

      final shareText = t(
        'Order groceries & essentials online from $shopName! Scan this QR code or visit our online store.',
        'अब $shopName से घर बैठे ऑनलाइन राशन और सामान मंगवाएं! इस क्यूआर कोड को स्कैन करें।',
        'Ab $shopName se online kirana aur saman order karein! Scan this QR code to visit.',
      );

      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          files: [XFile(imagePath.path)],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing QR: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    final shopProvider = Provider.of<ShopProvider>(context);
    final shopId = shopProvider.currentShopId ?? '';
    final shopName = shopProvider.shopName ?? 'NearKirana Store';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('Store Standee & QR', 'दुकान का QR स्टैंडी', 'Store Standee & QR'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            Text(
              t('Customer Online Order Link', 'ऑनलाइन ऑर्डर लिंक', 'Customer Online Order Link'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                t(
                  'Print or share this QR standee on your counter so customers can quickly order from home.',
                  'अपनी दुकान के काउंटर पर यह QR लगाएं ताकि ग्राहक घर बैठे सीधे आपसे सामान मंगा सकें।',
                  'Print ya share karein is QR standee ko taaki customers ghar se order kar sakein.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
              ),
              const SizedBox(height: 20),

              // Zepto/Blinkit Merchant Standee Card
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top merchant logo badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF0C831F)),
                            const SizedBox(width: 6),
                            Text(
                              t('NearKirana Partner', 'नियरकिराना पार्टनर', 'NearKirana Partner'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0C831F),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF0C831F)),
                          const SizedBox(width: 4),
                          Text(
                            t('Scan to Order Online', 'ऑनलाइन ऑर्डर के लिए स्कैन करें', 'Scan to Order Online'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // QR Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: QrImageView(
                          data: shopId,
                          version: QrVersions.auto,
                          size: 190.0,
                          backgroundColor: const Color(0xFFF8FAFC),
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF0F172A),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Store ID: ${shopId.length > 12 ? shopId.substring(0, 12) : shopId}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t('Fast Local Delivery • Best Prices', 'तेज लोकल डिलीवरी • बेहतरीन दाम', 'Fast Local Delivery • Best Prices'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C831F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Share Standee Button
              SizedBox(
                width: 320,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSharing ? null : () => _shareQR(t),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C831F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.share_rounded, size: 20),
                  label: Text(
                    _isSharing
                        ? t('Sharing...', 'शेयर किया जा रहा है...', 'Sharing...')
                        : t('Share QR via WhatsApp', 'व्हाट्सएप पर QR शेयर करें', 'Share QR via WhatsApp'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
