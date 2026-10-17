import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../language_provider.dart';
import '../sound_service.dart';

class LanguageBottomSheet extends StatelessWidget {
  const LanguageBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const LanguageBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    final currentCode = langProvider.currentLanguage;

    String sheetTitle = 'Select Language / भाषा चुनें';
    String sheetSubtitle = 'Choose your preferred language';
    if (langProvider.isHindi) {
      sheetTitle = 'अपनी भाषा चुनें';
      sheetSubtitle = 'अपनी पसंदीदा भाषा का चयन करें';
    } else if (langProvider.isHinglish) {
      sheetTitle = 'Language choose karein';
      sheetSubtitle = 'Apni pasandida bhasha chunein';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title & Subtitle
          Text(
            sheetTitle,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            sheetSubtitle,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Options
          _buildOption(
            context: context,
            code: 'en',
            title: 'English',
            subtitle: 'Default app language',
            icon: Icons.language_rounded,
            isSelected: currentCode == 'en',
            onTap: () => _selectLanguage(context, langProvider, 'en'),
          ),
          const SizedBox(height: 10),
          _buildOption(
            context: context,
            code: 'hi',
            title: 'हिंदी (Hindi)',
            subtitle: 'देवनागरी लिपि में संपूर्ण अनुभव',
            icon: Icons.translate_rounded,
            isSelected: currentCode == 'hi',
            onTap: () => _selectLanguage(context, langProvider, 'hi'),
          ),
          const SizedBox(height: 10),
          _buildOption(
            context: context,
            code: 'hinglish',
            title: 'Hinglish',
            subtitle: 'Hindi words in English script (Aasan bhasha)',
            icon: Icons.font_download_rounded,
            isSelected: currentCode == 'hinglish' || currentCode == 'hi_Latn',
            onTap: () => _selectLanguage(context, langProvider, 'hinglish'),
          ),
        ],
      ),
    );
  }

  void _selectLanguage(
    BuildContext context,
    LanguageProvider langProvider,
    String code,
  ) {
    langProvider.setLanguage(code);
    SoundService().languageSwitch();
    Navigator.pop(context);
  }

  Widget _buildOption({
    required BuildContext context,
    required String code,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryDark
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryDark.withValues(alpha: 0.15)
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryDark.withValues(alpha: 0.3)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.primaryDark
                    : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? AppColors.primaryDark
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LanguageTogglePill extends StatelessWidget {
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;

  const LanguageTogglePill({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    String label = 'EN';
    if (langProvider.isHindi) {
      label = 'हिं';
    } else if (langProvider.isHinglish) {
      label = 'Hing';
    }

    return GestureDetector(
      onTap: () => LanguageBottomSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFCBD5E1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: 15,
              color: iconColor ?? AppColors.primaryDark,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor ?? AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: (textColor ?? AppColors.primaryDark).withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
