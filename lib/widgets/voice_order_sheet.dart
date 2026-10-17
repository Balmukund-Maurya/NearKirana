// Interactive Voice Grocery Ordering Bottom Sheet
// Feature 61: Voice-Based Grocery Ordering (वॉइस-बेस्ड ग्रॉसरी ऑर्डरिंग)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../cart_provider.dart';
import '../user_provider.dart';
import '../voice_order_models.dart';
import '../voice_order_service.dart';
import '../language_provider.dart';

class VoiceOrderSheet extends StatefulWidget {
  final String shopId;
  final VoiceOrderService? voiceService;
  final List<VoiceCatalogProduct>? initialCatalog;
  final String? initialPrompt;
  final bool isPulsingEnabled;

  const VoiceOrderSheet({
    super.key,
    required this.shopId,
    this.voiceService,
    this.initialCatalog,
    this.initialPrompt,
    this.isPulsingEnabled = true,
  });

  /// Static helper to open sheet with smooth modal animation
  static Future<void> show(
    BuildContext context, {
    required String shopId,
    VoiceOrderService? voiceService,
    List<VoiceCatalogProduct>? initialCatalog,
    String? initialPrompt,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceOrderSheet(
        shopId: shopId,
        voiceService: voiceService,
        initialCatalog: initialCatalog,
        initialPrompt: initialPrompt,
      ),
    );
  }

  @override
  State<VoiceOrderSheet> createState() => _VoiceOrderSheetState();
}

class _VoiceOrderSheetState extends State<VoiceOrderSheet>
    with SingleTickerProviderStateMixin {
  late final VoiceOrderService _service;
  late final VoiceListeningController _controller;
  late final TextEditingController _textController;

  List<VoiceCatalogProduct> _catalog = [];
  bool _isLoadingCatalog = true;
  VoiceOrderParseResult? _parseResult;
  bool _isProcessingParse = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  final List<String> _quickPrompts = [
    '2 kilo atta aur 1 litre doodh',
    '1 packet bread aur 2 packet doodh',
    '500 gram paneer aur aadha kilo tamatar',
    '2 packet maggi aur 1 kg cheeni',
    '2 kg aloo aur 1 kg pyaaz',
    'teen packet surf excel aur ek packet namak',
  ];

  @override
  void initState() {
    super.initState();
    _service = widget.voiceService ?? VoiceOrderService();
    _controller = VoiceListeningController();
    _textController = TextEditingController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPulsingEnabled) {
      _pulseController.repeat(reverse: true);
    }

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadCatalogAndInitialize();
  }

  Future<void> _loadCatalogAndInitialize() async {
    if (widget.initialCatalog != null && widget.initialCatalog!.isNotEmpty) {
      _catalog = widget.initialCatalog!;
      setState(() => _isLoadingCatalog = false);
    } else {
      final fetched = await _service.fetchCatalog(widget.shopId);
      if (mounted) {
        setState(() {
          _catalog = fetched;
          _isLoadingCatalog = false;
        });
      }
    }

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _processQuery(widget.initialPrompt!);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onMicTap() {
    HapticFeedback.mediumImpact();
    if (_controller.isListening) {
      _controller.stopListening();
    } else {
      // Listen for speech result or errors
      void listener() {
        if (_controller.state == VoiceListeningState.success) {
          _controller.removeListener(listener);
          _textController.text = _controller.currentTranscript;
          _processQuery(_controller.currentTranscript);
        } else if (_controller.state == VoiceListeningState.error) {
          _controller.removeListener(listener);
          if (mounted && _controller.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_controller.errorMessage!),
                backgroundColor: Colors.orange.shade800,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }

      _controller.addListener(listener);
      // Start REAL microphone listening with user's selected language
      final langProvider = Provider.of<LanguageProvider>(context, listen: false);
      final targetLocale = (langProvider.isHindi || langProvider.isHinglish) ? 'hi_IN' : 'en_IN';
      _controller.startListening(localeId: targetLocale);
    }
  }

  void _onQuickPromptSelected(String prompt) {
    HapticFeedback.selectionClick();
    _textController.text = prompt;
    _processQuery(prompt);
  }

  Future<void> _processQuery(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _isProcessingParse = true);

    final result = await _service.processSpokenQuery(
      spokenText: text,
      shopId: widget.shopId,
      preloadedCatalog: _catalog,
    );

    if (mounted) {
      setState(() {
        _parseResult = result;
        _isProcessingParse = false;
      });
    }
  }

  void _onCandidateSelected(int itemIndex, VoiceCatalogProduct candidate) {
    if (_parseResult == null) return;
    HapticFeedback.selectionClick();

    final updatedItems = List<ParsedVoiceItem>.from(_parseResult!.parsedItems);
    final currentItem = updatedItems[itemIndex];

    updatedItems[itemIndex] = currentItem.copyWith(
      selectedProduct: candidate,
      status: VoiceItemStatus.ready,
    );

    setState(() {
      _parseResult = VoiceOrderParseResult(
        spokenText: _parseResult!.spokenText,
        detectedLanguage: _parseResult!.detectedLanguage,
        parsedItems: updatedItems,
      );
    });
  }

  void _onQuantityChanged(int itemIndex, double delta) {
    if (_parseResult == null) return;
    HapticFeedback.selectionClick();

    final updatedItems = List<ParsedVoiceItem>.from(_parseResult!.parsedItems);
    final currentItem = updatedItems[itemIndex];
    final isLoose = currentItem.effectiveProduct?.isLoose ?? false;
    final step = isLoose ? 0.5 : 1.0;
    final newQty = (currentItem.finalQuantity + (delta * step)).clamp(
      step,
      currentItem.effectiveProduct?.stockQuantity ?? 999.0,
    );

    updatedItems[itemIndex] = currentItem.copyWith(finalQuantity: newQty);

    setState(() {
      _parseResult = VoiceOrderParseResult(
        spokenText: _parseResult!.spokenText,
        detectedLanguage: _parseResult!.detectedLanguage,
        parsedItems: updatedItems,
      );
    });
  }

  void _onRemoveItem(int itemIndex) {
    if (_parseResult == null) return;
    HapticFeedback.mediumImpact();

    final updatedItems = List<ParsedVoiceItem>.from(_parseResult!.parsedItems)
      ..removeAt(itemIndex);

    setState(() {
      _parseResult = VoiceOrderParseResult(
        spokenText: _parseResult!.spokenText,
        detectedLanguage: _parseResult!.detectedLanguage,
        parsedItems: updatedItems,
      );
    });
  }

  Future<void> _onConfirmAddToCart() async {
    if (_parseResult == null || !_parseResult!.allResolved) return;
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final addedCount = _service.addItemsToCart(
      cartProvider: cartProvider,
      items: _parseResult!.parsedItems,
    );

    if (addedCount > 0) {
      // Audit log save
      _service.saveVoiceOrderLog(
        shopId: widget.shopId,
        customerPhone: userProvider.phoneNumber,
        spokenText: _parseResult!.spokenText,
        items: _parseResult!.parsedItems,
      );

      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Added $addedCount voice items to your cart! (कार्ट में सामान जुड़ गया)',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Title & Close Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: AppColors.primaryDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice Grocery Ordering',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'बोलकर सामान मंगाएं (Hindi / Hinglish / English)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMid),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Body
          Expanded(
            child: _isLoadingCatalog
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppColors.primaryDark),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Animated Mic Hero Section
                        _buildMicHeroSection(),

                        const SizedBox(height: 16),

                        // Spoken Text Input / Preview
                        _buildTranscriptField(),

                        const SizedBox(height: 16),

                        // Quick Voice Prompt Chips
                        if (_parseResult == null) _buildQuickPromptChips(),

                        // Parse Progress or Results
                        if (_isProcessingParse)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                children: [
                                  CircularProgressIndicator(
                                    color: AppColors.primaryDark,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Parsing items & checking store stock...',
                                    style: TextStyle(
                                      color: AppColors.textMid,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_parseResult != null)
                          _buildParsedItemsReview(),
                      ],
                    ),
                  ),
          ),

          // Bottom Action Confirm Bar
          if (_parseResult != null && _parseResult!.parsedItems.isNotEmpty)
            _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildMicHeroSection() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final isListening = _controller.isListening;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isListening
                  ? [
                      Colors.teal.shade50,
                      Colors.green.shade50.withValues(alpha: 0.6),
                    ]
                  : [Colors.grey.shade50, Colors.grey.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isListening ? AppColors.primaryDark : Colors.grey.shade200,
              width: isListening ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              // Rippling Mic Button
              GestureDetector(
                onTap: _onMicTap,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final scale = isListening ? _pulseAnimation.value : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryDark,
                          boxShadow: [
                            BoxShadow(
                              color: isListening
                                  ? AppColors.primaryDark.withValues(alpha: 0.45)
                                  : Colors.black.withValues(alpha: 0.15),
                              blurRadius: isListening ? 22 : 10,
                              spreadRadius: isListening ? 6 : 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          isListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Status message
              Text(
                isListening
                    ? 'Listening... Speak now (हम सुन रहे हैं...)'
                    : 'Tap mic to speak (बोलने के लिए माइक दबाएं)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isListening ? AppColors.primaryDark : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Example: "Do kilo atta aur ek litre doodh add karo"',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTranscriptField() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isListening &&
            _controller.currentTranscript.isNotEmpty &&
            _textController.text != _controller.currentTranscript) {
          _textController.value = TextEditingValue(
            text: _controller.currentTranscript,
            selection: TextSelection.collapsed(
              offset: _controller.currentTranscript.length,
            ),
          );
        }

        final isListening = _controller.isListening;
        return Container(
          decoration: BoxDecoration(
            color: isListening
                ? AppColors.primaryDark.withValues(alpha: 0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isListening
                  ? AppColors.primaryDark.withValues(alpha: 0.45)
                  : Colors.grey.shade200,
              width: isListening ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Icon(
                isListening
                    ? Icons.mic_rounded
                    : Icons.record_voice_over_rounded,
                color: isListening ? Colors.redAccent : AppColors.primaryDark,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: isListening
                        ? 'Listening to your voice... (हम सुन रहे हैं...)'
                        : 'Type or spoken words appear here...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                  onSubmitted: _processQuery,
                ),
              ),
              if (_textController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.send_rounded,
                    color: AppColors.primaryDark,
                    size: 20,
                  ),
                  onPressed: () => _processQuery(_textController.text),
                  tooltip: 'Parse Words',
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickPromptChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tips_and_updates_rounded, color: Colors.amber, size: 16),
            const SizedBox(width: 6),
            Text(
              'Quick Sample Voice Prompts (क्विक बोलकर देखें):',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMid,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickPrompts.map((p) {
            return ActionChip(
              avatar: const Icon(Icons.volume_up_rounded, size: 14, color: AppColors.primaryDark),
              label: Text(
                p,
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
              ),
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () => _onQuickPromptSelected(p),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildParsedItemsReview() {
    final result = _parseResult!;
    final items = result.parsedItems;

    if (items.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Could not recognize grocery items in phrase. Please speak clearly or try sample prompts.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.amber.shade900),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recognized Items (${items.length})',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${result.detectedLanguage} Detected',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // List of parsed item cards
        ...List.generate(items.length, (index) {
          final item = items[index];
          return _buildItemCard(index, item);
        }),
      ],
    );
  }

  Widget _buildItemCard(int index, ParsedVoiceItem item) {
    final status = item.status;
    final effectiveProd = item.effectiveProduct;

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case VoiceItemStatus.ready:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case VoiceItemStatus.ambiguous:
        statusColor = item.selectedProduct != null ? Colors.green : Colors.amber.shade800;
        statusIcon = item.selectedProduct != null
            ? Icons.check_circle_rounded
            : Icons.help_outline_rounded;
        break;
      case VoiceItemStatus.outOfStock:
        statusColor = Colors.red.shade700;
        statusIcon = Icons.cancel_rounded;
        break;
      case VoiceItemStatus.notFound:
        statusColor = Colors.grey.shade600;
        statusIcon = Icons.search_off_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == VoiceItemStatus.ambiguous && item.selectedProduct == null
              ? Colors.amber.shade400
              : Colors.grey.shade200,
          width: status == VoiceItemStatus.ambiguous && item.selectedProduct == null ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Item name, parsed quantity & delete
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product thumbnail / default icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: effectiveProd?.name.isNotEmpty == true
                      ? Text(
                          effectiveProd!.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        )
                      : const Icon(
                          Icons.shopping_cart_rounded,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Raw Voice Segment
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      effectiveProd?.name ?? item.rawItemName,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Spoken: "${item.rawSegment.trim()}"',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppColors.textLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                onPressed: () => _onRemoveItem(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Ambiguity Disambiguation Banner & Choices
          if (status == VoiceItemStatus.ambiguous && item.selectedProduct == null) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline_rounded, color: Colors.amber.shade900, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Multiple brands found. Tap to pick preferred:',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: item.candidateProducts.map((cand) {
                      return ChoiceChip(
                        label: Text(
                          '${cand.name} (₹${cand.price.toStringAsFixed(0)})',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        selected: item.selectedProduct?.id == cand.id,
                        selectedColor: AppColors.primaryLight.withValues(alpha: 0.35),
                        backgroundColor: Colors.white,
                        onSelected: (selected) {
                          if (selected) {
                            _onCandidateSelected(index, cand);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          // Controls: Quantity stepper, price, status badge
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              // Left: Quantity Stepper & Price
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (effectiveProd != null && status != VoiceItemStatus.outOfStock) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_rounded, size: 16),
                            onPressed: () => _onQuantityChanged(index, -1.0),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '${item.finalQuantity % 1 == 0 ? item.finalQuantity.toInt() : item.finalQuantity.toStringAsFixed(2)} ${item.unit ?? (effectiveProd.isLoose ? "kg" : "pkt")}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            onPressed: () => _onQuantityChanged(index, 1.0),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (effectiveProd != null)
                    Text(
                      '₹${item.effectivePrice.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                ],
              ),

              // Right: Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      item.status == VoiceItemStatus.ambiguous && item.selectedProduct != null
                          ? 'Choice Selected'
                          : item.status.label,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final result = _parseResult!;
    final isReady = result.allResolved;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (result.hasAmbiguity) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '⚠️ Please pick brand choice for items above',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${result.readyCount} items ready',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Total: ₹${result.totalEstimatedCost.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isReady ? _onConfirmAddToCart : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
                  label: Text(
                    'Confirm & Add to Cart',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
