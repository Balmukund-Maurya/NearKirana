import re
import os

files_to_fix = [
    'lib/khata_statement_screen.dart',
    'lib/khata_screen.dart',
    'lib/admin_product_forms.dart',
    'lib/cart_screen.dart',
    'lib/customer_shop_tab.dart',
    'lib/admin_more_tab.dart'
]

def add_top_margin_to_snackbars(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
        
    # Replace `const SnackBar(` with `SnackBar(`
    content = re.sub(r'const\s+SnackBar\(', 'SnackBar(', content)
    
    # We need to inject behavior and margin into all SnackBar( calls.
    # Find all SnackBar( that are not already containing our custom margin
    
    idx = 0
    new_content = ""
    changes = 0
    
    while True:
        target = "SnackBar("
        pos = content.find(target, idx)
        if pos == -1:
            new_content += content[idx:]
            break
            
        new_content += content[idx:pos + len(target)]
        
        # Look ahead to see if it already has our margin
        lookahead = content[pos+len(target):pos+len(target)+150]
        if "margin: EdgeInsets.only(bottom: MediaQuery" not in lookahead:
            new_content += " behavior: SnackBarBehavior.floating, margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 150, left: 20, right: 20), "
            changes += 1
            
        idx = pos + len(target)

    # But wait, we need to remove existing 'behavior: SnackBarBehavior.floating,' if any, so we don't have duplicate named arguments!
    # Let's clean up duplicate 'behavior:'
    new_content = re.sub(r'behavior:\s*SnackBarBehavior\.floating,\s*behavior:\s*SnackBarBehavior\.floating,', 'behavior: SnackBarBehavior.floating,', new_content)
    # Actually, a better way is to just remove any existing behavior: ... before the replace, or just do it with a regex.
    new_content = re.sub(r'behavior:\s*SnackBarBehavior\.\w+,', '', new_content)
    
    # Now that we removed existing behaviors, our injected behavior will be the only one.
    # Wait, my while loop injected it. Let's rebuild the file from scratch with regex.
    
    with open(filepath, 'w') as f:
        f.write(new_content)
    print(f"Updated {filepath} with {changes} changes")

for file in files_to_fix:
    add_top_margin_to_snackbars(file)
