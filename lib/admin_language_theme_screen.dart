import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/language_provider.dart';
import 'package:near_kirana/widgets/admin_top_header.dart';

class AdminLanguageThemeScreen extends StatefulWidget {
  const AdminLanguageThemeScreen({super.key});

  @override
  State<AdminLanguageThemeScreen> createState() => _AdminLanguageThemeScreenState();
}

class _AdminLanguageThemeScreenState extends State<AdminLanguageThemeScreen> {
  // ── Language state ──────────────────────────────────────────────────────────
  String _selectedLanguage = 'en';

  // ── Theme state ─────────────────────────────────────────────────────────────
  // Project currently only supports Light mode.
  // We store the user's choice but only Light actually changes anything.
  String _selectedTheme = 'light'; // 'light' | 'dark' | 'system'

  // ── Color state ─────────────────────────────────────────────────────────────
  String _selectedColor = 'green'; // default NearKirana green

  bool _isSaving = false;

  // Supported languages by the project's localization system
  static const _languages = [
    {'code': 'en', 'label': 'English', 'native': 'English', 'flag': '🇮🇳'},
    {'code': 'hi', 'label': 'Hindi', 'native': 'हिन्दी', 'flag': '🇮🇳'},
  ];

  static const _colors = [
    {'key': 'green',  'label': 'Green\n(Default)', 'value': Color(0xFF306D29)},
    {'key': 'blue',   'label': 'Blue',             'value': Color(0xFF1976D2)},
    {'key': 'purple', 'label': 'Purple',           'value': Color(0xFF7B1FA2)},
    {'key': 'red',    'label': 'Red',              'value': Color(0xFFD32F2F)},
    {'key': 'orange', 'label': 'Orange',           'value': Color(0xFFE65100)},
    {'key': 'teal',   'label': 'Teal',             'value': Color(0xFF00695C)},
    {'key': 'indigo', 'label': 'Indigo',           'value': Color(0xFF283593)},
    {'key': 'pink',   'label': 'Pink',             'value': Color(0xFFC2185B)},
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final langProv = Provider.of<LanguageProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = langProv.currentLanguage;
      _selectedTheme = prefs.getString('admin_theme') ?? 'light';
      _selectedColor = prefs.getString('admin_color') ?? 'green';
    });
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    try {
      final langProv = Provider.of<LanguageProvider>(context, listen: false);
      await langProv.setLanguage(_selectedLanguage);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_theme', _selectedTheme);
      await prefs.setString('admin_color', _selectedColor);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully'),
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetToDefault() async {
    final langProv = Provider.of<LanguageProvider>(context, listen: false);
    await langProv.setLanguage('en');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_theme', 'light');
    await prefs.setString('admin_color', 'green');
    setState(() {
      _selectedLanguage = 'en';
      _selectedTheme = 'light';
      _selectedColor = 'green';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset to default settings'),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Only clear non-auth keys
      final keys = prefs.getKeys().where((k) =>
          !k.contains('isAdmin') &&
          !k.contains('customer') &&
          !k.contains('current_shop'));
      for (final k in keys) {
        await prefs.remove(k);
      }
      await _loadPreferences();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          const AdminTopHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page header
                  Text('Language & Theme', style: AppTextStyles.heading1(color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text(
                    'Customize your admin panel appearance and language preferences',
                    style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                  ),
                  const SizedBox(height: 32),

                  // Two-column layout
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _buildLeftColumn()),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: _buildRightColumn()),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildLeftColumn(),
                        const SizedBox(height: 24),
                        _buildRightColumn(),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────── LEFT COLUMN ──────────────────

  Widget _buildLeftColumn() {
    return Column(
      children: [
        _buildLanguageSettingsCard(),
        const SizedBox(height: 24),
        _buildThemeSettingsCard(),
        const SizedBox(height: 24),
        _buildThemeColorsCard(),
      ],
    );
  }

  Widget _buildLanguageSettingsCard() {
    final currentLang = _languages.firstWhere(
      (l) => l['code'] == _selectedLanguage,
      orElse: () => _languages.first,
    );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.language, color: AppColors.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Language Settings', style: AppTextStyles.title(color: AppColors.textDark)),
                  Text('Choose your preferred language for the admin panel',
                      style: AppTextStyles.captionMedium(color: AppColors.textMid)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Select Language', style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
          const SizedBox(height: 8),
          // Dropdown
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLanguage,
                isExpanded: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                borderRadius: BorderRadius.circular(8),
                icon: const Icon(Icons.keyboard_arrow_down),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLanguage = val);
                },
                items: _languages.map((lang) {
                  return DropdownMenuItem<String>(
                    value: lang['code'] as String,
                    child: Row(
                      children: [
                        Text(lang['flag'] as String, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Text(
                          '${lang['native']} (${lang['label']})',
                          style: AppTextStyles.bodyMedium(color: AppColors.textDark),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Info callout
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBDEFB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF1976D2), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The language will be applied across the entire admin panel.',
                        style: AppTextStyles.captionMedium(color: const Color(0xFF0D47A1)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You may need to refresh the page for all changes to take effect.',
                        style: AppTextStyles.captionMedium(color: const Color(0xFF0D47A1)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSettingsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.palette_outlined, color: AppColors.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme Settings', style: AppTextStyles.title(color: AppColors.textDark)),
                  Text('Choose your preferred theme for the admin panel',
                      style: AppTextStyles.captionMedium(color: AppColors.textMid)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildThemeCard(
                key: 'light',
                icon: Icons.wb_sunny_outlined,
                label: 'Light Theme',
                desc: 'Clean and bright interface',
                preview: _buildLightPreview(),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildThemeCard(
                key: 'dark',
                icon: Icons.nightlight_round_outlined,
                label: 'Dark Theme',
                desc: 'Easy on the eyes during low light',
                preview: _buildDarkPreview(),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildThemeCard(
                key: 'system',
                icon: Icons.computer_outlined,
                label: 'System Theme',
                desc: 'Automatically match your system theme',
                preview: _buildSystemPreview(),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required String key,
    required IconData icon,
    required String label,
    required String desc,
    required Widget preview,
  }) {
    final isSelected = _selectedTheme == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedTheme = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview area
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: SizedBox(height: 110, child: preview),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: isSelected ? AppColors.primaryDark : AppColors.textMid),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTextStyles.bodyMedium(
                          color: isSelected ? AppColors.primaryDark : AppColors.textDark,
                        )),
                        Text(desc, style: AppTextStyles.captionMedium(color: AppColors.textMid)),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppColors.primaryDark, size: 18)
                  else
                    Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLightPreview() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Row(
        children: [
          Container(width: 30, color: const Color(0xFF306D29)),
          Expanded(
            child: Column(
              children: [
                Container(height: 18, color: Colors.white, margin: const EdgeInsets.all(4),
                  child: Row(children: [
                    const SizedBox(width: 4),
                    Expanded(child: Container(height: 8, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))),
                    const SizedBox(width: 4),
                  ]),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        Row(children: [
                          _miniCard(Colors.green.shade50, const Color(0xFF306D29)),
                          const SizedBox(width: 4),
                          _miniCard(Colors.blue.shade50, Colors.blue),
                          const SizedBox(width: 4),
                          _miniCard(Colors.orange.shade50, Colors.orange),
                        ]),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Expanded(child: _chartBars(Colors.green.shade300)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkPreview() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Row(
        children: [
          Container(width: 30, color: const Color(0xFF16213E)),
          Expanded(
            child: Column(
              children: [
                Container(height: 18, color: const Color(0xFF0F3460), margin: const EdgeInsets.all(4)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        Row(children: [
                          _miniCard(const Color(0xFF1A3A5C), Colors.blue.shade300),
                          const SizedBox(width: 4),
                          _miniCard(const Color(0xFF1A3A5C), Colors.purple.shade300),
                          const SizedBox(width: 4),
                          _miniCard(const Color(0xFF1A3A5C), Colors.orange.shade300),
                        ]),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF16213E),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: _chartBars(Colors.blue.shade400),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemPreview() {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: Row(
        children: [
          Container(width: 30, color: const Color(0xFF555555)),
          Expanded(
            child: Column(
              children: [
                Container(height: 18, color: Colors.white, margin: const EdgeInsets.all(4)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        Row(children: [
                          _miniCard(Colors.grey.shade200, Colors.grey.shade600),
                          const SizedBox(width: 4),
                          _miniCard(Colors.grey.shade200, Colors.grey.shade600),
                          const SizedBox(width: 4),
                          _miniCard(Colors.grey.shade200, Colors.grey.shade600),
                        ]),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: _chartBars(Colors.grey.shade400),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniCard(Color bg, Color accent) {
    return Expanded(
      child: Container(
        height: 18,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
        margin: const EdgeInsets.only(right: 1),
        child: Center(child: Container(width: 12, height: 3, color: accent, margin: const EdgeInsets.only(bottom: 2))),
      ),
    );
  }

  Widget _chartBars(Color color) {
    final heights = [0.4, 0.7, 0.5, 0.85, 0.6, 0.9, 0.55];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: heights.map((h) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: FractionallySizedBox(
            heightFactor: h,
            alignment: Alignment.bottomCenter,
            child: Container(decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(2)))),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildThemeColorsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.color_lens_outlined, color: AppColors.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme Colors', style: AppTextStyles.title(color: AppColors.textDark)),
                  Text('Choose a primary color for the admin panel',
                      style: AppTextStyles.captionMedium(color: AppColors.textMid)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _colors.map((c) => _buildColorSwatch(
              key: c['key'] as String,
              label: c['label'] as String,
              color: c['value'] as Color,
            )).toList(),
          ),
          const SizedBox(height: 32),
          // Save button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePreferences,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Preferences'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSwatch({required String key, required String label, required Color color}) {
    final isSelected = _selectedColor == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = key),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.black26, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withAlpha(100), blurRadius: 8, spreadRadius: 2)]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 56,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.captionMedium(color: AppColors.textMid).copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────── RIGHT COLUMN ─────────────────

  Widget _buildRightColumn() {
    return Column(
      children: [
        _buildPreviewCard(),
        const SizedBox(height: 24),
        _buildQuickActionsCard(),
        const SizedBox(height: 24),
        _buildSupportedLanguagesCard(),
      ],
    );
  }

  Widget _buildPreviewCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined, color: AppColors.textDark, size: 20),
              const SizedBox(width: 8),
              Text('Preview', style: AppTextStyles.title(color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 4),
          Text('See how the theme and language will look',
              style: AppTextStyles.captionMedium(color: AppColors.textMid)),
          const SizedBox(height: 16),
          // Mini dashboard preview
          Container(
            height: 170,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF8F9FA),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildMiniDashboardPreview(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniDashboardPreview() {
    return Row(
      children: [
        // Sidebar
        Container(
          width: 36,
          color: const Color(0xFF306D29),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const CircleAvatar(radius: 10, backgroundColor: Colors.white24),
              const SizedBox(height: 8),
              ...List.generate(6, (_) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Container(width: 20, height: 4, color: Colors.white30,
                    margin: const EdgeInsets.symmetric(horizontal: 8)),
              )),
            ],
          ),
        ),
        // Content
        Expanded(
          child: Column(
            children: [
              // Header
              Container(
                height: 22,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(child: Container(height: 8, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))),
                    const SizedBox(width: 4),
                    Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Container(width: 24, height: 8, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
              // KPI row
              Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    _previewKpiCard(Colors.green.shade100),
                    const SizedBox(width: 4),
                    _previewKpiCard(Colors.blue.shade100),
                    const SizedBox(width: 4),
                    _previewKpiCard(Colors.orange.shade100),
                  ],
                ),
              ),
              // Chart area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(width: 40, height: 4, color: Colors.grey.shade300),
                              const SizedBox(height: 4),
                              Expanded(child: _chartBars(const Color(0xFF306D29))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Center(
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF306D29), width: 8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _previewKpiCard(Color color) {
    return Expanded(
      child: Container(
        height: 28,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 20, height: 3, color: Colors.white70),
            const SizedBox(height: 2),
            Container(width: 12, height: 3, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.textDark, size: 20),
              const SizedBox(width: 8),
              Text('Quick Actions', style: AppTextStyles.title(color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionRow(
            Icons.refresh_outlined,
            'Reset to Default',
            'Restore default language and theme',
            _resetToDefault,
          ),
          Divider(color: Colors.grey.shade100, height: 8),
          _buildActionRow(
            Icons.delete_sweep_outlined,
            'Clear Cache',
            'Clear cached data and reload settings',
            _clearCache,
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppColors.textDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMedium(color: AppColors.textDark)),
                  Text(subtitle, style: AppTextStyles.captionMedium(color: AppColors.textMid)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 16, color: AppColors.textMid),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportedLanguagesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public, color: AppColors.primaryDark, size: 20),
              const SizedBox(width: 8),
              Text('Supported Languages', style: AppTextStyles.title(color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Available languages in the admin panel',
              style: AppTextStyles.captionMedium(color: AppColors.textMid)),
          const SizedBox(height: 16),
          // Only show the 2 languages the app actually supports
          ..._languages.map((lang) {
            final isActive = lang['code'] == _selectedLanguage;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(lang['flag'] as String, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${lang['native']} (${lang['label']})',
                      style: AppTextStyles.bodyMedium(color: AppColors.textDark),
                    ),
                  ),
                  if (isActive)
                    const Icon(Icons.check_circle, color: AppColors.primaryDark, size: 20)
                  else
                    Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 20),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────── HELPERS ─────────────────────

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
