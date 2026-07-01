import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppUtils {
  static void showTopSnackBar(BuildContext context, String message, {bool isError = false}) {
    final margin = MediaQuery.of(context).size.height - 150;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: margin > 0 ? margin : 0,
          left: 20,
          right: 20,
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
