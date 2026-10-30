import os
import re

lib_dir = '/Users/balmukund/Documents/flutterProject/Aditya_Kirana/lib'

# Walk through all dart files
for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()

            # First, clean up previous manual injections
            content = content.replace("behavior: SnackBarBehavior.floating, margin: EdgeInsets.only(bottom: margin > 0 ? margin : 0, left: 20, right: 20), ", "")
            content = content.replace("behavior: SnackBarBehavior.floating, margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 150 > 0 ? MediaQuery.of(context).size.height - 150 : 0, left: 20, right: 20), ", "")
            # Clean up the custom _showTopSnackBar usage in admin_product_forms.dart
            # Wait, no, we'll leave _showTopSnackBar alone.

            # Now, for all instances of SnackBar(
            # We want to replace `SnackBar(` with `SnackBar(behavior: SnackBarBehavior.floating, margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 150 > 0 ? MediaQuery.of(context).size.height - 150 : 0, left: 20, right: 20), `
            
            # Since some SnackBars already have behavior, let's remove it first
            content = re.sub(r'behavior:\s*SnackBarBehavior\.floating\s*,', '', content)
            
            # Now find `SnackBar(` that is followed by anything (but NOT our custom margin)
            # Actually, just replace `SnackBar(` with our string.
            # But wait, there are occurrences of `SnackBar(` inside comments or variable definitions? Rare.
            # Let's replace `SnackBar(` with `SnackBar(behavior: SnackBarBehavior.floating, margin: EdgeInsets.only(bottom: (MediaQuery.of(context).size.height - 150) > 0 ? (MediaQuery.of(context).size.height - 150) : 0, left: 20, right: 20), `
            
            # Only if it's called inside a method where `context` is available! 
            # `ScaffoldMessenger.of(context).showSnackBar(SnackBar(` is exactly what we want.
            
            pattern = r'ScaffoldMessenger\.of\([^)]+\)\.showSnackBar\(\s*SnackBar\('
            replacement = r'ScaffoldMessenger.of(context).showSnackBar(\nSnackBar(behavior: SnackBarBehavior.floating, margin: EdgeInsets.only(bottom: (MediaQuery.of(context).size.height - 150) > 0 ? (MediaQuery.of(context).size.height - 150) : 0, left: 20, right: 20),\n'
            
            new_content = re.sub(pattern, replacement, content)
            
            if new_content != content:
                with open(filepath, 'w') as f:
                    f.write(new_content)
                print(f"Updated {file}")

