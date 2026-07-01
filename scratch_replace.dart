import 'dart:io';

import 'package:flutter/material.dart';

class ScratchReplace {
  static void showManualAddProductForm(BuildContext context) {
    final nameController = TextEditingController();
    final barcodeController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final quantityController = TextEditingController();
    bool isLoose = true;
    bool isFoodItem = true;
    bool isVegetarian = true;
    File? pickedImage;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scratch placeholder.')),
      );
    }

    debugPrint('Scratch placeholder used: ${nameController.text}');
    debugPrint('Scratch placeholder values: $isLoose, $isFoodItem, $isVegetarian, ${pickedImage?.path}');
    debugPrint('Scratch placeholder values: ${barcodeController.text}, ${priceController.text}, ${stockController.text}, ${quantityController.text}');
  }
}
