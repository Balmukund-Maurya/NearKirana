import os

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Generic translation fixes where I used AppLocalizations on a LanguageProvider object
    content = content.replace("langProvider.date", "AppLocalizations.of(context)!.date")
    content = content.replace("langProvider.total_amount", "AppLocalizations.of(context)!.total_amount")
    content = content.replace("langProvider.order_cancelled", "AppLocalizations.of(context)!.order_cancelled")
    content = content.replace("langProvider.cancel_order_q", "AppLocalizations.of(context)!.cancel_order_q")
    content = content.replace("langProvider.cancel_order_sure", "AppLocalizations.of(context)!.cancel_order_sure")
    content = content.replace("langProvider.no_btn", "AppLocalizations.of(context)!.no_btn")
    content = content.replace("langProvider.yes_cancel", "AppLocalizations.of(context)!.yes_cancel")
    content = content.replace("langProvider.cancel_order_btn", "AppLocalizations.of(context)!.cancel_order_btn")
    content = content.replace("langProvider.out_for_delivery", "AppLocalizations.of(context)!.out_for_delivery")
    content = content.replace("langProvider.delivery_pin", "AppLocalizations.of(context)!.delivery_pin")
    content = content.replace("langProvider.items", "AppLocalizations.of(context)!.items")

    content = content.replace("AppLocalizations.of(context)!.currentLanguage", "Provider.of<LanguageProvider>(context, listen: false).currentLanguage")
    content = content.replace("AppLocalizations.of(context)!.setLanguage", "Provider.of<LanguageProvider>(context, listen: false).setLanguage")

    with open(filepath, 'w') as f:
        f.write(content)

fix_file("lib/my_orders_screen.dart")
fix_file("lib/main.dart")
fix_file("lib/customer_profile_tab.dart")
fix_file("lib/cart_screen.dart")
fix_file("lib/customer_shop_tab.dart")
fix_file("lib/khata_screen.dart")
fix_file("lib/khata_statement_screen.dart")
