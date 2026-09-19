import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # We want to find patterns like:
    # ScaffoldMessenger.of(context).showSnackBar(
    #   SnackBar(behavior: SnackBarBehavior.floating, content: Text('Some text'), backgroundColor: ...),
    # );
    
    # We will use a parser that tracks parentheses.
    idx = 0
    new_content = ""
    changes = 0
    
    while True:
        target = "ScaffoldMessenger.of(context).showSnackBar("
        pos = content.find(target, idx)
        if pos == -1:
            new_content += content[idx:]
            break
            
        new_content += content[idx:pos]
        
        # Now find the matching closing parenthesis for showSnackBar(
        paren_count = 1
        curr = pos + len(target)
        while curr < len(content) and paren_count > 0:
            if content[curr] == '(':
                paren_count += 1
            elif content[curr] == ')':
                paren_count -= 1
            curr += 1
            
        # The block from pos to curr is the whole ScaffoldMessenger call.
        block = content[pos:curr]
        
        # We need to extract the message text from Text('...') or Text("...")
        # and whether it's an error (contains AppColors.error or Colors.red)
        
        # Extract Text content
        text_match = re.search(r"Text\((['\"])(.*?)\1", block)
        if text_match:
            message = text_match.group(2)
            # Check if there is string interpolation inside the string (e.g., 'Error: $e').
            # If so, we need to extract the raw string with $ variables.
            raw_text_match = re.search(r"Text\((['\"])(.*?)\1\)", block, re.DOTALL)
            if raw_text_match:
                 message = raw_text_match.group(2)
        else:
            # Fallback if no Text found
            message = "Operation completed"
            
        is_error = "error" in block.lower() or "red" in block.lower() or "failed" in message.lower()
        
        error_flag = ", isError: true" if is_error else ""
        
        # Replace with AppUtils call
        # Make sure to handle string quoting correctly.
        # If the message has quotes, we should wrap it carefully.
        # Actually, let's just extract the exact string literal including quotes from the block.
        string_literal_match = re.search(r"Text\((['\"].*?['\"])\)", block, re.DOTALL)
        if string_literal_match:
            exact_string = string_literal_match.group(1)
            replacement = f"AppUtils.showTopSnackBar(context, {exact_string}{error_flag})"
        else:
            replacement = f"AppUtils.showTopSnackBar(context, '{message}'{error_flag})"
            
        new_content += replacement
        idx = curr
        changes += 1

    if changes > 0:
        # Add import for AppUtils if not present
        if "import 'package:aditya_kirana/app_utils.dart';" not in new_content and "import '../app_utils.dart';" not in new_content:
             # Just add it after the first import
             first_import_idx = new_content.find("import ")
             if first_import_idx != -1:
                 new_content = new_content[:first_import_idx] + "import 'package:aditya_kirana/app_utils.dart';\n" + new_content[first_import_idx:]
        
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated {filepath} ({changes} replacements)")

# Create app_utils.dart
app_utils_code = """import 'package:flutter/material.dart';
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
"""
with open('/Users/balmukund/Documents/flutterProject/Aditya_Kirana/lib/app_utils.dart', 'w') as f:
    f.write(app_utils_code)

for root, _, files in os.walk('/Users/balmukund/Documents/flutterProject/Aditya_Kirana/lib'):
    for file in files:
        if file.endswith('.dart') and file != 'app_utils.dart':
            process_file(os.path.join(root, file))

