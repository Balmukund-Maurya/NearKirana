import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = 'hinglish'; // 'hinglish', 'hi', 'en'
  bool _isLoaded = false;

  String get currentLanguage => _currentLanguage;
  bool get isLoaded => _isLoaded;

  LanguageProvider() {
    loadSavedLanguage();
  }

  Future<void> loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('app_language');
      if (savedLang != null) {
        _currentLanguage = savedLang;
      }
    } catch (e) {
      debugPrint('Error loading language: $e');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _currentLanguage = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', lang);
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }

  String translate(String key) {
    final translations = {
      // FIX-13: or_divider key
      'or_divider': {
        'hinglish': 'ya',
        'hi': 'या',
        'en': 'or',
      },
      'app_name': {
        'hinglish': 'My Shop',
        'hi': 'मेरा दुकान',
        'en': 'My Shop',
      },
      'subtitle': {
        'hinglish': 'Aapki Apni Dukaan',
        'hi': 'आपकी अपनी दुकान',
        'en': 'Your Own Store',
      },
      'name_hint': {
        'hinglish': 'Apna Naam Likhein',
        'hi': 'अपना नाम लिखें',
        'en': 'Enter Your Name',
      },
      'mobile_hint': {
        'hinglish': 'Mobile Number',
        'hi': 'मोबाइल नंबर',
        'en': 'Mobile Number',
      },
      'enter_button': {
        'hinglish': 'Dukaan Mein Aayein',
        'hi': 'दुकान में आएं',
        'en': 'Enter Store',
      },
      'terms': {
        'hinglish': 'By continuing, you agree to our Terms & Conditions',
        'hi': 'आगे बढ़कर, आप हमारे नियम और शर्तों से सहमत होते हैं',
        'en': 'By continuing, you agree to our Terms & Conditions',
      },
      'owner_login': {
        'hinglish': 'Owner Login / Admin Access',
        'hi': 'मालिक लॉग इन / एडमिन एक्सेस',
        'en': 'Owner Login / Admin Access',
      },
      'language': {
        'hinglish': 'Bhasha Badlein',
        'hi': 'भाषा बदलें',
        'en': 'Change Language',
      },
      'error_loading': {
        'hinglish': 'Kuch galat ho gaya.',
        'hi': 'कुछ गलत हो गया।',
        'en': 'Something went wrong.',
      },
      'no_product': {
        'hinglish': 'Koi product nahi hai.',
        'hi': 'कोई प्रोडक्ट नहीं है।',
        'en': 'No products available.',
      },
      'add': {'hinglish': '+ Jodein', 'hi': '+ जोड़ें', 'en': '+ Add'},
      'added_to_cart': {
        'hinglish': 'Jhole mein daal diya!',
        'hi': 'झोले में डाल दिया!',
        'en': 'Added to cart!',
      },
      'admin_dashboard': {
        'hinglish': 'Admin Dashboard',
        'hi': 'एडमिन डैशबोर्ड',
        'en': 'Admin Dashboard',
      },
      'scan_barcode': {
        'hinglish': 'Scan Barcode / Naya Bill',
        'hi': 'स्कैन बारकोड / नया बिल',
        'en': 'Scan Barcode / New Bill',
      },
      'quick_add': {
        'hinglish': 'Khula Saman (Quick Add)',
        'hi': 'खुला सामान (क्विक ऐड)',
        'en': 'Loose Items (Quick Add)',
      },
      'shop_stock': {
        'hinglish': 'Dukaan Ka Stock',
        'hi': 'दुकान का स्टॉक',
        'en': 'Shop Stock',
      },
      'customer_ledger': {
        'hinglish': 'Grahak Ka Khata',
        'hi': 'ग्राहक का खाता',
        'en': 'Customer Ledger',
      },
      'live_orders': {
        'hinglish': 'Naye Orders (Live)',
        'hi': 'नए ऑर्डर्स (लाइव)',
        'en': 'New Orders (Live)',
      },
      'cart_title': {
        'hinglish': 'Aapka Jhola',
        'hi': 'आपका झोला',
        'en': 'Your Cart',
      },
      'total_amount': {
        'hinglish': 'Total',
        'hi': 'कुल राशि',
        'en': 'Total Amount',
      },
      'place_order': {
        'hinglish': 'Order Karein',
        'hi': 'ऑर्डर करें',
        'en': 'Place Order',
      },
      'home_delivery': {
        'hinglish': 'Ghar Tak Delivery',
        'hi': 'घर तक डिलीवरी',
        'en': 'Home Delivery',
      },
      'store_pickup': {
        'hinglish': 'Store Se Lenge',
        'hi': 'स्टोर से लेंगे',
        'en': 'Store Pickup',
      },
      'add_new_item': {
        'hinglish': 'Naya Item Jodein',
        'hi': 'नया आइटम जोड़ें',
        'en': 'Add New Item',
      },
      'store_closed_error': {
        'hinglish': 'Dukaan abhi band hai. Kripya baad mein koshish karein.',
        'hi': 'अभी दुकान बंद है। कृपया बाद में कोशिश करें।',
        'en':
            'The store is currently closed. Please try again during operating hours.',
      },
      'khata_limit_exceeded': {
        'hinglish':
            'Khata Limit Paar Ho Gayi! Adhiktam udhaar ₹{limit} hai. Kripya apna pichla bakaya chukayein.',
        'hi':
            'खाता सीमा पार हो गई! अधिकतम उधार ₹{limit} है। कृपया अपना पिछला बकाया चुकाएं।',
        'en':
            'Khata Limit Exceeded! Maximum allowed udhaar is ₹{limit}. Please pay your previous dues.',
      },
      'ghost_cart_error': {
        'hinglish':
            'Aapke cart mein kuch items ab uplabdh nahi hain aur unhe hata diya gaya hai.',
        'hi':
            'आपके कार्ट में कुछ आइटम अब उपलब्ध नहीं हैं और उन्हें हटा दिया गया है।',
        'en':
            'Some items in your cart are no longer available and were automatically removed.',
      },
      'out_of_stock': {
        'hinglish': 'Khatam Ho Gaya',
        'hi': 'स्टॉक खत्म',
        'en': 'Out of Stock',
      },
      'profile': {'hinglish': 'Profile', 'hi': 'प्रोफ़ाइल', 'en': 'Profile'},
      'my_profile': {
        'hinglish': 'Mera Profile',
        'hi': 'मेरी प्रोफ़ाइल',
        'en': 'My Profile',
      },
      'guest': {'hinglish': 'Mehman', 'hi': 'अतिथि', 'en': 'Guest'},
      'delivery_address': {
        'hinglish': 'Delivery Ka Pata',
        'hi': 'डिलीवरी का पता',
        'en': 'Delivery Address',
      },
      'app_language': {
        'hinglish': 'App Ki Bhasha',
        'hi': 'ऐप की भाषा',
        'en': 'App Language',
      },
      'help_support': {
        'hinglish': 'Madad / Support',
        'hi': 'मदद और सपोर्ट',
        'en': 'Help & Support',
      },
      'call_shop': {
        'hinglish': 'Dukandaar Ko Call Karein',
        'hi': 'दुकानदार को कॉल करें',
        'en': 'Call Shop Owner',
      },
      'whatsapp_support': {
        'hinglish': 'WhatsApp Support',
        'hi': 'व्हाट्सएप सपोर्ट',
        'en': 'WhatsApp Support',
      },
      'chat_with_us': {
        'hinglish': 'Hamse Baat Karein',
        'hi': 'हमसे बात करें',
        'en': 'Chat with us',
      },
      'logout': {'hinglish': 'Logout', 'hi': 'लॉग आउट', 'en': 'Logout'},
      'logout_confirm': {
        'hinglish':
            'Kya aap sach mein logout karna chahte hain? Aapka jhola khaali ho jayega.',
        'hi': 'क्या आप वाकई लॉग आउट करना चाहते हैं? आपका कार्ट खाली हो जाएगा।',
        'en': 'Are you sure you want to logout? Your cart will be cleared.',
      },
      'cancel': {'hinglish': 'Cancel', 'hi': 'रद्द करें', 'en': 'Cancel'},
      'no_address': {
        'hinglish': 'Koi pata nahi hai. Pehle order ke time jud jayega.',
        'hi': 'कोई पता सेव नहीं है। पहले ऑर्डर के दौरान जुड़ जाएगा।',
        'en': 'No address saved. It will be added during your first order.',
      },
      'house_no': {
        'hinglish': 'Makaan Number:',
        'hi': 'मकान नंबर:',
        'en': 'House No:',
      },
      'landmark_txt': {
        'hinglish': 'Landmark:',
        'hi': 'लैंडमार्क:',
        'en': 'Landmark:',
      },
      'shop_tab': {'hinglish': 'Dukaan', 'hi': 'दुकान', 'en': 'Shop'},
      'cart_tab': {'hinglish': 'Jhola', 'hi': 'कार्ट', 'en': 'Cart'},
      'orders_tab': {'hinglish': 'Orders', 'hi': 'ऑर्डर्स', 'en': 'Orders'},
      'my_orders': {
        'hinglish': 'Mere Orders',
        'hi': 'मेरे ऑर्डर्स',
        'en': 'My Orders',
      },
      'please_login': {
        'hinglish': 'Orders dekhne ke liye login karein.',
        'hi': 'ऑर्डर देखने के लिए कृपया लॉग इन करें।',
        'en': 'Please login to view orders.',
      },
      'cart_empty': {
        'hinglish': 'Aapka jhola khaali hai.',
        'hi': 'आपका कार्ट खाली है।',
        'en': 'Your cart is empty.',
      },
      'search_hint': {
        'hinglish': 'Samaan dhundhein...',
        'hi': 'उत्पाद खोजें...',
        'en': 'Search products...',
      },

      'cat_all': {'hinglish': 'Sabhi', 'hi': 'सभी', 'en': 'All'},
      'cat_dal': {'hinglish': 'Dal', 'hi': 'दाल', 'en': 'Dal'},
      'cat_rice': {'hinglish': 'Chawal', 'hi': 'चावल', 'en': 'Rice'},
      'cat_spices': {'hinglish': 'Masale', 'hi': 'मसाले', 'en': 'Spices'},
      'cat_oil': {'hinglish': 'Tel', 'hi': 'तेल', 'en': 'Oil'},
      'cat_snacks': {
        'hinglish': 'Snacks',
        'hi': 'नमकीन/स्नैक्स',
        'en': 'Snacks',
      },
      'cat_soap': {'hinglish': 'Sabun', 'hi': 'साबुन', 'en': 'Soap'},
      'cat_loose': {
        'hinglish': 'Khula Saman',
        'hi': 'खुला सामान',
        'en': 'Loose',
      },
      'fix_btn': {'hinglish': 'Theek Karein', 'hi': 'ठीक करें', 'en': 'Fix'},
      'max_stock': {
        'hinglish': 'Maximum limit pahunch gayi!',
        'hi': 'अधिकतम सीमा तक पहुँच गए!',
        'en': 'Maximum stock reached!',
      },
      'qty_exceeds': {
        'hinglish': 'Jitna manga hai, utna stock nahi hai.',
        'hi': 'मांगी गई मात्रा उपलब्ध स्टॉक से अधिक है।',
        'en': 'Requested quantity exceeds available stock.',
      },
      'adjust_location': {
        'hinglish': 'Map par location set karein 📍',
        'hi': 'मैप पर स्थान सेट करें 📍',
        'en': 'Adjust Location on Map 📍',
      },
      'enter_house_no': {
        'hinglish': 'Kripya apna House/Flat No daalein.',
        'hi': 'कृपया अपना मकान/फ्लैट नंबर दर्ज करें।',
        'en': 'Please enter your House/Flat No.',
      },
      'wait_3_min': {
        'hinglish': 'Agla order karne se pehle 3 minute rukein.',
        'hi': 'कृपया अगला ऑर्डर देने से पहले 3 मिनट प्रतीक्षा करें।',
        'en': 'Please wait 3 minutes before placing another order.',
      },
      'order_placed': {
        'hinglish': 'Order Safaltapurvak Ho Gaya.',
        'hi': 'ऑर्डर सफलतापूर्वक प्राप्त हुआ।',
        'en': 'Order Placed Successfully.',
      },
      'thank_you_order': {
        'hinglish': 'Dhanyawad! Aapka order mil gaya hai.',
        'hi': 'धन्यवाद! आपका ऑर्डर प्राप्त हो गया है।',
        'en': 'Thank you! Your order has been received.',
      },
      'thank_you_order_pickup': {
        'hinglish': 'Dhanyawad! Aapka order mil gaya hai. Kripya apna order dukaan se collect kar lein.',
        'hi': 'धन्यवाद! आपका ऑर्डर प्राप्त हो गया है। कृपया अपना ऑर्डर दुकान से ले लें।',
        'en': 'Thank you! Your order has been received. Please collect your order from the store.',
      },
      'ok_btn': {'hinglish': 'Theek Hai', 'hi': 'ठीक है', 'en': 'OK'},
      'confirm_order': {
        'hinglish': 'Order Confirm Karein',
        'hi': 'ऑर्डर की पुष्टि करें',
        'en': 'Confirm Order',
      },
      'cancel_order_q': {
        'hinglish': 'Order Cancel Karein?',
        'hi': 'ऑर्डर रद्द करें?',
        'en': 'Cancel Order?',
      },
      'cancel_order_sure': {
        'hinglish': 'Kya aap sach mein ye order cancel karna chahte hain?',
        'hi': 'क्या आप वाकई यह ऑर्डर रद्द करना चाहते हैं?',
        'en': 'Are you sure you want to cancel this order?',
      },
      'no_btn': {'hinglish': 'Nahi', 'hi': 'नहीं', 'en': 'No'},
      'yes_cancel': {
        'hinglish': 'Haan, Cancel karein',
        'hi': 'हाँ, रद्द करें',
        'en': 'Yes, Cancel',
      },
      'order_cancelled': {
        'hinglish': 'Order Cancel Ho Gaya.',
        'hi': 'ऑर्डर सफलतापूर्वक रद्द कर दिया गया।',
        'en': 'Order Cancelled Successfully.',
      },
      'cancel_order_btn': {
        'hinglish': 'Order Cancel Karein',
        'hi': 'ऑर्डर रद्द करें',
        'en': 'Cancel Order',
      },
      'name_lbl': {'hinglish': 'Naam', 'hi': 'नाम', 'en': 'Name'},
      'mobile_lbl': {'hinglish': 'Mobile', 'hi': 'मोबाइल', 'en': 'Mobile'},
      'address_lbl': {
        'hinglish': 'Pata (Address)',
        'hi': 'पता',
        'en': 'Address',
      },
      'edit_profile': {
        'hinglish': 'Profile Edit Karein',
        'hi': 'प्रोफ़ाइल संपादित करें',
        'en': 'Edit Profile',
      },
      'save_profile': {
        'hinglish': 'Save Karein',
        'hi': 'सेव करें',
        'en': 'Save Profile',
      },
      'contact_no': {
        'hinglish': 'Contact Number',
        'hi': 'संपर्क नंबर',
        'en': 'Contact Number',
      },
      'personal_info': {
        'hinglish': 'Personal Jankari',
        'hi': 'व्यक्तिगत जानकारी',
        'en': 'Personal Info',
      },
      'account_settings': {
        'hinglish': 'Account Settings',
        'hi': 'अकाउंट सेटिंग्स',
        'en': 'Account Settings',
      },
      'subtotal': {
        'hinglish': 'Samaan Ka Daam',
        'hi': 'सामान का दाम',
        'en': 'Subtotal',
      },
      'delivery_fee': {
        'hinglish': 'Delivery Fees',
        'hi': 'डिलीवरी शुल्क',
        'en': 'Delivery Fee',
      },
      'checkout': {'hinglish': 'Checkout', 'hi': 'चेकआउट', 'en': 'Checkout'},
      'order_no': {'hinglish': 'Order #', 'hi': 'ऑर्डर #', 'en': 'Order #'},
      'date': {'hinglish': 'Tareekh', 'hi': 'तारीख', 'en': 'Date'},
      'status': {'hinglish': 'Status', 'hi': 'स्थिति', 'en': 'Status'},
      'items': {'hinglish': 'Items', 'hi': 'आइटम्स', 'en': 'Items'},
      'out_for_delivery': {
        'hinglish': 'Delivery ke liye nikla:',
        'hi': 'डिलीवरी के लिए निकला:',
        'en': 'Out for delivery by',
      },
      'delivery_pin': {
        'hinglish': 'Delivery PIN',
        'hi': 'डिलीवरी पिन',
        'en': 'Delivery PIN',
      },
      'delivery_mode': {
        'hinglish': 'Delivery Mode',
        'hi': 'डिलीवरी मोड',
        'en': 'Delivery Mode',
      },
      'no_orders': {
        'hinglish': 'Aapka koi order nahi hai.',
        'hi': 'आपका कोई ऑर्डर नहीं है।',
        'en': 'No orders found.',
      },
      'view_history': {
        'hinglish': 'History Dekhein',
        'hi': 'हिस्ट्री देखें',
        'en': 'View History',
      },
      'khata': {'hinglish': 'Khata', 'hi': 'खाता', 'en': 'Khata'},
      'view_ledger': {
        'hinglish': 'Ledger Dekhein',
        'hi': 'लेजर देखें',
        'en': 'View Ledger',
      },
      // ---- ADMIN PANEL TRANSLATIONS ----
      'admin_user': {
        'hinglish': 'Admin User',
        'hi': 'एडमिन यूज़र',
        'en': 'Admin User',
      },
      'admin_role': {
        'hinglish': 'Dukaan Ka Malik',
        'hi': 'दुकान का मालिक',
        'en': 'Store Owner',
      },
      'store_management': {
        'hinglish': 'Dukaan Prabandhan',
        'hi': 'दुकान प्रबंधन',
        'en': 'Store Management',
      },
      'admin_customers': {
        'hinglish': 'Grahak',
        'hi': 'ग्राहक',
        'en': 'Customers',
      },
      'admin_customers_subtitle': {
        'hinglish': 'Sabhi grahak profiles manage karein',
        'hi': 'सभी ग्राहक प्रोफ़ाइल प्रबंधित करें',
        'en': 'Manage all customer profiles',
      },
      'store_settings': {
        'hinglish': 'Dukaan Settings',
        'hi': 'दुकान सेटिंग्स',
        'en': 'Store Settings',
      },
      'store_settings_subtitle': {
        'hinglish': 'Delivery fees, timings aur rules',
        'hi': 'डिलीवरी शुल्क, समय और नियम',
        'en': 'Delivery fees, timings & rules',
      },
      'app_settings': {
        'hinglish': 'App Settings',
        'hi': 'ऐप सेटिंग्स',
        'en': 'App Settings',
      },
      'language_setting': {
        'hinglish': 'Bhasha',
        'hi': 'भाषा',
        'en': 'Language',
      },
      'language_setting_subtitle': {
        'hinglish': 'App ki bhasha badlein',
        'hi': 'ऐप की भाषा बदलें',
        'en': 'Change app language',
      },
      'admin_logout': {
        'hinglish': 'Logout',
        'hi': 'लॉग आउट',
        'en': 'Logout',
      },
      'admin_logout_confirm': {
        'hinglish': 'Kya aap Admin panel se logout karna chahte hain?',
        'hi': 'क्या आप एडमिन पैनल से लॉग आउट करना चाहते हैं?',
        'en': 'Are you sure you want to log out of the admin panel?',
      },
      'admin_version': {
        'hinglish': 'Shop Admin - Version 1.0.0',
        'hi': 'शॉप एडमिन - संस्करण 1.0.0',
        'en': 'Shop Admin - Version 1.0.0',
      },
      'select_language': {
        'hinglish': 'Bhasha Chunein',
        'hi': 'भाषा चुनें',
        'en': 'Select Language',
      },
      'add_or_update_product': {
        'hinglish': 'Naya product add karein ya update karein',
        'hi': 'नया उत्पाद जोड़ें या अपडेट करें',
        'en': 'Add or update product',
      },
      'live_orders_subtitle': {
        'hinglish': 'Aaj ke active orders',
        'hi': 'आज के सक्रिय ऑर्डर',
        'en': "Today's active orders",
      },
      'today_sales': {
        'hinglish': 'Aaj Ki Kamai',
        'hi': 'आज की कमाई',
        'en': "Today's Sales",
      },
    };

    return translations[key]?[_currentLanguage] ?? key;
  }
}
