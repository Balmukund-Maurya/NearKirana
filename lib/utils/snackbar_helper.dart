import 'package:flutter/material.dart';

class SnackbarHelper {
  static void showSnackBar(
    BuildContext context, 
    String message, 
    {bool isError = false}
  ) {
    if (!context.mounted) return;
    
    // Calculate margin to push the SnackBar to the top of the screen
    final mediaQuery = MediaQuery.of(context);
    final topMargin = 50.0; // Distance from top
    // Total height - top margin - estimated snackbar height (approx 60)
    final bottomMargin = mediaQuery.size.height - topMargin - 60;
    
    ScaffoldMessenger.of(context).clearSnackBars(); // Clear previous
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: bottomMargin > 0 ? bottomMargin : 0,
          left: 20,
          right: 20,
        ),
        backgroundColor: isError ? Colors.red : const Color(0xFF4CAF50),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
