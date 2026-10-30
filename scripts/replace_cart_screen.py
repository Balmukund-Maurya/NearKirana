with open('lib/cart_screen.dart', 'r') as f:
    content = f.read()

replacements = {
    "label: const Text('Adjust Location on Map 📍')": "label: Text(langProvider.translate('adjust_location'))",
    "SnackBar(content: Text('Please enter your House/Flat No.'))": "SnackBar(content: Text(langProvider.translate('enter_house_no')))",
    "content: Text('Please wait 3 minutes before placing another order.')": "content: Text(langProvider.translate('wait_3_min'))",
    "Text('Order Placed Successfully.',": "Text(langProvider.translate('order_placed'),",
    "content: Text('Thank you! Your order for ₹$processedTotal has been received.')": "content: Text(langProvider.translate('thank_you_order').replaceAll('{total}', processedTotal.toString()))",
    "child: Text('OK', style:": "child: Text(langProvider.translate('ok_btn'), style:",
    "Text('Confirm Order (₹$finalTotal)'": "Text(langProvider.translate('confirm_order').replaceAll('{total}', finalTotal.toString())",
    "Text('Requested quantity exceeds available stock.')": "Text(langProvider.translate('qty_exceeds'))",
}

for old, new_str in replacements.items():
    content = content.replace(old, new_str)

with open('lib/cart_screen.dart', 'w') as f:
    f.write(content)
