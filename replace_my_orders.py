with open('lib/my_orders_screen.dart', 'r') as f:
    content = f.read()

replacements = {
    "title: const Text('Cancel Order?')": "title: Text(langProvider.translate('cancel_order_q'))",
    "content: const Text('Are you sure you want to cancel this order?')": "content: Text(langProvider.translate('cancel_order_sure'))",
    "child: const Text('No')": "child: Text(langProvider.translate('no_btn'))",
    "child: const Text('Yes, Cancel'": "child: Text(langProvider.translate('yes_cancel')",
    "SnackBar(content: Text('Order Cancelled Successfully.'))": "SnackBar(content: Text(langProvider.translate('order_cancelled')))",
    "label: const Text('Cancel Order'": "label: Text(langProvider.translate('cancel_order_btn')",
}

for old, new_str in replacements.items():
    content = content.replace(old, new_str)

with open('lib/my_orders_screen.dart', 'w') as f:
    f.write(content)
