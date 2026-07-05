import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = 'en'; // 'hi', 'en'
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
        // Fallback to 'en' if 'hinglish' was saved previously
        if (savedLang == 'hinglish') {
          _currentLanguage = 'en';
          prefs.setString('app_language', 'en');
        } else {
          _currentLanguage = savedLang;
        }
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
      'or_divider': {
        'hi': 'या',
        'en': 'or',
      },
      'app_name': {
        'hi': 'मेरा स्टोर',
        'en': 'My Store',
      },
      'subtitle': {
        'hi': 'आपका अपना डिजिटल स्टोर',
        'en': 'Your Digital Store',
      },
      'name_hint': {
        'hi': 'अपना नाम दर्ज करें',
        'en': 'Enter Your Name',
      },
      'mobile_hint': {
        'hi': 'मोबाइल नंबर',
        'en': 'Mobile Number',
      },
      'enter_button': {
        'hi': 'स्टोर में प्रवेश करें',
        'en': 'Enter Store',
      },
      'terms': {
        'hi': 'आगे बढ़कर, आप हमारे नियम और शर्तों से सहमत होते हैं',
        'en': 'By continuing, you agree to our Terms & Conditions',
      },
      'owner_login': {
        'hi': 'मालिक लॉग इन / एडमिन एक्सेस',
        'en': 'Owner Login / Admin Access',
      },
      'language': {
        'hi': 'भाषा बदलें',
        'en': 'Change Language',
      },
      'error_loading': {
        'hi': 'कुछ गलत हो गया।',
        'en': 'Something went wrong.',
      },
      'no_product': {
        'hi': 'कोई उत्पाद उपलब्ध नहीं है।',
        'en': 'No products available.',
      },
      'add': {'hi': '+ जोड़ें', 'en': '+ Add'},
      'added_to_cart': {
        'hi': 'कार्ट में जोड़ा गया!',
        'en': 'Added to cart!',
      },
      'admin_dashboard': {
        'hi': 'एडमिन डैशबोर्ड',
        'en': 'Admin Dashboard',
      },
      'scan_barcode': {
        'hi': 'स्कैन बारकोड / नया बिल',
        'en': 'Scan Barcode / New Bill',
      },
      'quick_add': {
        'hi': 'खुला आइटम (क्विक ऐड)',
        'en': 'Loose Items (Quick Add)',
      },
      'shop_stock': {
        'hi': 'स्टोर इन्वेंट्री',
        'en': 'Store Inventory',
      },
      'customer_ledger': {
        'hi': 'ग्राहक खाता',
        'en': 'Customer Ledger',
      },
      'live_orders': {
        'hi': 'नए ऑर्डर्स (लाइव)',
        'en': 'New Orders (Live)',
      },
      'cart_title': {
        'hi': 'आपका कार्ट',
        'en': 'Your Cart',
      },
      'total_amount': {
        'hi': 'कुल राशि',
        'en': 'Total Amount',
      },
      'place_order': {
        'hi': 'ऑर्डर करें',
        'en': 'Place Order',
      },
      'home_delivery': {
        'hi': 'होम डिलीवरी',
        'en': 'Home Delivery',
      },
      'store_pickup': {
        'hi': 'स्टोर से पिकअप',
        'en': 'Store Pickup',
      },
      'add_new_item': {
        'hi': 'नया आइटम जोड़ें',
        'en': 'Add New Item',
      },
      'store_closed_error': {
        'hi': 'अभी स्टोर बंद है। कृपया बाद में प्रयास करें।',
        'en': 'The store is currently closed. Please try again later.',
      },
      'khata_limit_exceeded': {
        'hi': 'खाता सीमा पार हो गई! अधिकतम उधार ₹{limit} है। कृपया अपना पिछला बकाया चुकाएं।',
        'en': 'Khata Limit Exceeded! Maximum allowed udhaar is ₹{limit}. Please pay your previous dues.',
      },
      'ghost_cart_error': {
        'hi': 'आपके कार्ट में कुछ आइटम अब उपलब्ध नहीं हैं और उन्हें हटा दिया गया है।',
        'en': 'Some items in your cart are no longer available and were removed.',
      },
      'out_of_stock': {
        'hi': 'स्टॉक समाप्त',
        'en': 'Out of Stock',
      },
      'profile': {'hi': 'प्रोफ़ाइल', 'en': 'Profile'},
      'my_profile': {
        'hi': 'मेरी प्रोफ़ाइल',
        'en': 'My Profile',
      },
      'guest': {'hi': 'अतिथि', 'en': 'Guest'},
      'delivery_address': {
        'hi': 'डिलीवरी का पता',
        'en': 'Delivery Address',
      },
      'app_language': {
        'hi': 'ऐप की भाषा',
        'en': 'App Language',
      },
      'help_support': {
        'hi': 'सहायता और सपोर्ट',
        'en': 'Help & Support',
      },
      'call_shop': {
        'hi': 'स्टोर मालिक को कॉल करें',
        'en': 'Call Store Owner',
      },
      'whatsapp_support': {
        'hi': 'व्हाट्सएप सपोर्ट',
        'en': 'WhatsApp Support',
      },
      'chat_with_us': {
        'hi': 'हमसे बात करें',
        'en': 'Chat with us',
      },
      'logout': {'hi': 'लॉग आउट', 'en': 'Logout'},
      'logout_confirm': {
        'hi': 'क्या आप वाकई लॉग आउट करना चाहते हैं? आपका कार्ट खाली हो जाएगा।',
        'en': 'Are you sure you want to logout? Your cart will be cleared.',
      },
      'cancel': {'hi': 'रद्द करें', 'en': 'Cancel'},
      'no_address': {
        'hi': 'कोई पता सेव नहीं है। पहले ऑर्डर के दौरान जुड़ जाएगा।',
        'en': 'No address saved. It will be added during your first order.',
      },
      'house_no': {
        'hi': 'मकान/फ्लैट नंबर:',
        'en': 'House/Flat No:',
      },
      'landmark_txt': {
        'hi': 'लैंडमार्क:',
        'en': 'Landmark:',
      },
      'shop_tab': {'hi': 'स्टोर', 'en': 'Store'},
      'cart_tab': {'hi': 'कार्ट', 'en': 'Cart'},
      'orders_tab': {'hi': 'ऑर्डर्स', 'en': 'Orders'},
      'my_orders': {
        'hi': 'मेरे ऑर्डर्स',
        'en': 'My Orders',
      },
      'please_login': {
        'hi': 'ऑर्डर देखने के लिए कृपया लॉग इन करें।',
        'en': 'Please login to view orders.',
      },
      'cart_empty': {
        'hi': 'आपका कार्ट खाली है।',
        'en': 'Your cart is empty.',
      },
      'search_hint': {
        'hi': 'उत्पाद खोजें...',
        'en': 'Search products...',
      },
      'cat_all': {'hi': 'सभी', 'en': 'All'},
      'cat_dal': {'hi': 'दाल', 'en': 'Dal'},
      'cat_rice': {'hi': 'चावल', 'en': 'Rice'},
      'cat_spices': {'hi': 'मसाले', 'en': 'Spices'},
      'cat_oil': {'hi': 'तेल', 'en': 'Oil'},
      'cat_snacks': {
        'hi': 'नमकीन/स्नैक्स',
        'en': 'Snacks',
      },
      'cat_soap': {'hi': 'साबुन', 'en': 'Soap'},
      'cat_loose': {
        'hi': 'खुला सामान',
        'en': 'Loose',
      },
      'fix_btn': {'hi': 'ठीक करें', 'en': 'Fix'},
      'max_stock': {
        'hi': 'अधिकतम सीमा तक पहुँच गए!',
        'en': 'Maximum stock reached!',
      },
      'qty_exceeds': {
        'hi': 'मांगी गई मात्रा उपलब्ध स्टॉक से अधिक है।',
        'en': 'Requested quantity exceeds available stock.',
      },
      'adjust_location': {
        'hi': 'मैप पर स्थान सेट करें 📍',
        'en': 'Adjust Location on Map 📍',
      },
      'enter_house_no': {
        'hi': 'कृपया अपना मकान/फ्लैट नंबर दर्ज करें।',
        'en': 'Please enter your House/Flat No.',
      },
      'wait_3_min': {
        'hi': 'कृपया अगला ऑर्डर देने से पहले 3 मिनट प्रतीक्षा करें।',
        'en': 'Please wait 3 minutes before placing another order.',
      },
      'order_placed': {
        'hi': 'ऑर्डर सफलतापूर्वक प्राप्त हुआ।',
        'en': 'Order Placed Successfully.',
      },
      'thank_you_order': {
        'hi': 'धन्यवाद! आपका ऑर्डर प्राप्त हो गया है।',
        'en': 'Thank you! Your order has been received.',
      },
      'thank_you_order_pickup': {
        'hi': 'धन्यवाद! आपका ऑर्डर प्राप्त हो गया है। कृपया अपना ऑर्डर स्टोर से ले लें।',
        'en': 'Thank you! Your order has been received. Please collect your order from the store.',
      },
      'ok_btn': {'hi': 'ठीक है', 'en': 'OK'},
      'confirm_order': {
        'hi': 'ऑर्डर की पुष्टि करें',
        'en': 'Confirm Order',
      },
      'cancel_order_q': {
        'hi': 'ऑर्डर रद्द करें?',
        'en': 'Cancel Order?',
      },
      'cancel_order_sure': {
        'hi': 'क्या आप वाकई यह ऑर्डर रद्द करना चाहते हैं?',
        'en': 'Are you sure you want to cancel this order?',
      },
      'no_btn': {'hi': 'नहीं', 'en': 'No'},
      'yes_cancel': {
        'hi': 'हाँ, रद्द करें',
        'en': 'Yes, Cancel',
      },
      'order_cancelled': {
        'hi': 'ऑर्डर सफलतापूर्वक रद्द कर दिया गया।',
        'en': 'Order Cancelled Successfully.',
      },
      'cancel_order_btn': {
        'hi': 'ऑर्डर रद्द करें',
        'en': 'Cancel Order',
      },
      'name_lbl': {'hi': 'नाम', 'en': 'Name'},
      'mobile_lbl': {'hi': 'मोबाइल', 'en': 'Mobile'},
      'address_lbl': {
        'hi': 'पता',
        'en': 'Address',
      },
      'edit_profile': {
        'hi': 'प्रोफ़ाइल संपादित करें',
        'en': 'Edit Profile',
      },
      'save_profile': {
        'hi': 'सेव करें',
        'en': 'Save Profile',
      },
      'contact_no': {
        'hi': 'संपर्क नंबर',
        'en': 'Contact Number',
      },
      'personal_info': {
        'hi': 'व्यक्तिगत जानकारी',
        'en': 'Personal Info',
      },
      'account_settings': {
        'hi': 'अकाउंट सेटिंग्स',
        'en': 'Account Settings',
      },
      'subtotal': {
        'hi': 'सामान का मूल्य',
        'en': 'Subtotal',
      },
      'delivery_fee': {
        'hi': 'डिलीवरी शुल्क',
        'en': 'Delivery Fee',
      },
      'checkout': {'hi': 'चेकआउट', 'en': 'Checkout'},
      'order_no': {'hi': 'ऑर्डर #', 'en': 'Order #'},
      'date': {'hi': 'तारीख', 'en': 'Date'},
      'status': {'hi': 'स्थिति', 'en': 'Status'},
      'items': {'hi': 'आइटम्स', 'en': 'Items'},
      'out_for_delivery': {
        'hi': 'डिलीवरी के लिए निकला:',
        'en': 'Out for delivery by',
      },
      'delivery_pin': {
        'hi': 'डिलीवरी पिन',
        'en': 'Delivery PIN',
      },
      'delivery_mode': {
        'hi': 'डिलीवरी मोड',
        'en': 'Delivery Mode',
      },
      'no_orders': {
        'hi': 'आपका कोई ऑर्डर नहीं है।',
        'en': 'No orders found.',
      },
      'view_history': {
        'hi': 'हिस्ट्री देखें',
        'en': 'View History',
      },
      'khata': {'hi': 'खाता', 'en': 'Khata'},
      'view_ledger': {
        'hi': 'लेजर देखें',
        'en': 'View Ledger',
      },
      // ---- ADMIN PANEL TRANSLATIONS ----
      'admin_user': {
        'hi': 'एडमिन यूज़र',
        'en': 'Admin User',
      },
      'admin_role': {
        'hi': 'स्टोर मालिक',
        'en': 'Store Owner',
      },
      'store_management': {
        'hi': 'दुकान प्रबंधन',
        'en': 'Store Management',
      },
      'admin_customers': {
        'hi': 'ग्राहक',
        'en': 'Customers',
      },
      'admin_customers_subtitle': {
        'hi': 'सभी ग्राहक प्रोफ़ाइल प्रबंधित करें',
        'en': 'Manage all customer profiles',
      },
      'store_settings': {
        'hi': 'डिलीवरी और सेटिंग्स',
        'en': 'Delivery & Setup',
      },
      'store_settings_subtitle': {
        'hi': 'डिलीवरी शुल्क, समय और नियम',
        'en': 'Delivery fees, timings & rules',
      },
      'app_settings': {
        'hi': 'ऐप सेटिंग्स',
        'en': 'App Settings',
      },
      'language_setting': {
        'hi': 'भाषा',
        'en': 'Language',
      },
      'language_setting_subtitle': {
        'hi': 'ऐप की भाषा बदलें',
        'en': 'Change app language',
      },
      'admin_logout': {
        'hi': 'लॉग आउट',
        'en': 'Logout',
      },
      'admin_logout_confirm': {
        'hi': 'क्या आप एडमिन पैनल से लॉग आउट करना चाहते हैं?',
        'en': 'Are you sure you want to log out of the admin panel?',
      },
      'admin_version': {
        'hi': 'शॉप एडमिन - संस्करण 1.0.0',
        'en': 'Shop Admin - Version 1.0.0',
      },
      'select_language': {
        'hi': 'भाषा चुनें',
        'en': 'Select Language',
      },
      'add_or_update_product': {
        'hi': 'नया उत्पाद जोड़ें या अपडेट करें',
        'en': 'Add or update product',
      },
      'live_orders_subtitle': {
        'hi': 'आज के सक्रिय ऑर्डर',
        'en': "Today's active orders",
      },
      'today_sales': {
        'hi': 'आज की बिक्री',
        'en': "Today's Sales",
      },
      'greeting': {
        'hi': 'नमस्ते',
        'en': 'Hello',
      },
      // ---- NEW ADMIN & SYSTEM STRINGS ----
      'error_no_shop_found': {
        'hi': 'आपके क्षेत्र में कोई स्टोर नहीं मिला।',
        'en': 'No shops found in your area.',
      },
      'scan_shop_qr': {
        'hi': 'स्टोर का QR कोड स्कैन करें',
        'en': 'Scan Shop QR Code',
      },
      'delete_product': {
        'hi': 'उत्पाद हटाएं?',
        'en': 'Delete Product?',
      },
      'add_new_category': {
        'hi': 'नई श्रेणी जोड़ें',
        'en': 'Add New Category',
      },
      'add_btn': {
        'hi': 'जोड़ें',
        'en': 'Add',
      },
      'food_item_veg_nonveg': {
        'hi': 'खाद्य पदार्थ (शाकाहारी/मांसाहारी डॉट दिखाएं)',
        'en': 'Food Item (Show Veg/Non-Veg dot)',
      },
      'veg_product': {
        'hi': 'शाकाहारी उत्पाद',
        'en': 'Vegetarian Product',
      },
      'loose_item': {
        'hi': 'खुला सामान (Loose Item)',
        'en': 'Loose Item',
      },
      'dukan_badlein_title': {
        'hi': 'स्टोर बदलें?',
        'en': 'Change Store?',
      },
      'dukan_badlein_desc': {
        'hi': 'क्या आप इस स्टोर से बाहर आकर दूसरा स्टोर चुनना चाहते हैं?',
        'en': 'Are you sure you want to change the selected store?',
      },
      'yes_change': {
        'hi': 'हाँ, बदलें',
        'en': 'Yes, Change',
      },
      'change_shop_btn': {
        'hi': 'स्टोर बदलें',
        'en': 'Change Store',
      },
      'error_connecting': {
        'hi': 'सर्वर से कनेक्ट करने में त्रुटि। पुनः प्रयास करें।',
        'en': 'Error connecting to server. Try again.',
      },
      'invalid_khata_entry': {
        'hi': 'कृपया मान्य 10-अंकीय फोन नंबर और राशि 0 से अधिक दर्ज करें।',
        'en': 'Enter valid 10-digit phone and amount > 0.',
      },
      'name_required_khata': {
        'hi': 'नए ग्राहकों के लिए नाम आवश्यक है!',
        'en': 'Name is required for new customers!',
      },
      'khata_entry_success': {
        'hi': 'खाता प्रविष्टि सफलतापूर्वक जुड़ गई!',
        'en': 'Khata Entry Added Successfully!',
      },
      'add_entry': {
        'hi': 'प्रविष्टि जोड़ें',
        'en': 'Add Entry',
      },
      'add_offline_khata': {
        'hi': 'ऑफ़लाइन खाता जोड़ें',
        'en': 'Add Offline Khata',
      },
      'settings_saved': {
        'hi': 'सेटिंग्स सफलतापूर्वक सहेजी गईं!',
        'en': 'Settings saved successfully!',
      },
      'negative_values_error': {
        'hi': 'मान ऋणात्मक (negative) नहीं हो सकते!',
        'en': 'Values cannot be negative!',
      },
      'pick_on_map': {
        'hi': 'मैप पर चुनें',
        'en': 'Pick on\nMap',
      },
      // ---- NEW MAP & SHOP SELECTOR TRANSLATIONS ----
      'welcome_title': {
        'hi': 'AlwaysPro में आपका स्वागत है',
        'en': 'Welcome to AlwaysPro',
      },
      'search_shop_subtitle': {
        'hi': 'अपने आस-पास की दुकान खोजें या उनका QR कोड स्कैन करें।',
        'en': 'Find shops near you or scan their QR Code.',
      },
      'search_shop_hint': {
        'hi': 'दुकान का नाम खोजें...',
        'en': 'Search shop name...',
      },
      'type_to_search_shops': {
        'hi': 'दुकान का नाम टाइप करें',
        'en': 'Type to search shops',
      },
      'find_stores_near_you': {
        'hi': 'दुकान ढूंढें',
        'en': 'Find stores near you',
      },
      'turn_on_gps': {
        'hi': 'अपने आस-पास की दुकानें खोजने के लिए GPS चालू करें।',
        'en': 'Turn on GPS to find stores around you.',
      },
      'searching_stores': {
        'hi': 'आस-पास की दुकानें खोजी जा रही हैं...',
        'en': 'Searching for stores nearby...',
      },
      'are_you_shop_owner': {
        'hi': 'दुकानदार हैं?',
        'en': 'Are you a shop owner?',
      },
      'register_your_shop': {
        'hi': 'अपनी दुकान रजिस्टर करें',
        'en': 'Register Your Shop',
      },
      'move_map_adjust': {
        'hi': 'लोकेशन सेट करने के लिए मैप को खिसकाएं',
        'en': 'Move map to adjust location',
      },
      'enter_complete_address': {
        'hi': 'पूरा पता दर्ज करें',
        'en': 'Enter Complete Address',
      },
      'locality_area': {
        'hi': 'मोहल्ला / इलाका',
        'en': 'Locality / Area',
      },
      'house_flat_no': {
        'hi': 'मकान / फ्लैट / ब्लॉक नं.',
        'en': 'House / Flat / Block No.',
      },
      'landmark_optional': {
        'hi': 'लैंडमार्क (वैकल्पिक)',
        'en': 'Landmark (Optional)',
      },
      'save_address_as': {
        'hi': 'पता सेव करें',
        'en': 'Save address as',
      },
      'save_address_btn': {
        'hi': 'पता सेव करें',
        'en': 'Save Address',
      },
      'confirm_location': {
        'hi': 'लोकेशन पक्की करें',
        'en': 'Confirm Location',
      },
      'confirm_delivery_loc': {
        'hi': 'डिलीवरी लोकेशन पक्की करें',
        'en': 'Confirm Delivery Location',
      },
      'out_of_delivery_area': {
        'hi': 'डिलीवरी क्षेत्र से बाहर',
        'en': 'Out of Delivery Area',
      },
      'selected_loc_outside': {
        'hi': 'चुना गया स्थान डिलीवरी क्षेत्र से बाहर है!',
        'en': 'Selected location is outside the delivery area!',
      },
      'search_area_hint': {
        'hi': 'इलाका, लैंडमार्क या शहर खोजें...',
        'en': 'Search area, landmark or city...',
      },
      'error_cant_deliver': {
        'hi': 'क्षमा करें! हम आपके चुने हुए स्थान पर डिलीवरी नहीं करते हैं।',
        'en': "Oops! We don't deliver to your selected location.",
      },
      'please_enable_gps': {
        'hi': 'कृपया GPS चालू करें',
        'en': 'Please enable GPS',
      },
      // ---- PHASE 2: ADMIN & REGISTRATION TRANSLATIONS ----
      'register_shop_title': {
        'hi': 'दुकान रजिस्टर करें',
        'en': 'Register Shop',
      },
      'shop_setting_up': {
        'hi': 'आपकी दुकान सेट अप हो रही है...',
        'en': 'Your shop is being set up...',
      },
      'product_found': {
        'hi': 'उत्पाद मिला',
        'en': 'Product Found',
      },
      'price': {
        'hi': 'कीमत',
        'en': 'Price',
      },
      'stock': {
        'hi': 'स्टॉक',
        'en': 'Stock',
      },
      'edit': {
        'hi': 'संपादित करें',
        'en': 'Edit',
      },
      'manage_customers': {
        'hi': 'ग्राहक प्रबंधित करें',
        'en': 'Manage Customers',
      },
      'record_payment': {
        'hi': 'भुगतान दर्ज करें',
        'en': 'Record Payment',
      },
      'invalid_amount': {
        'hi': 'कृपया एक वैध राशि दर्ज करें।',
        'en': 'Please enter a valid amount.',
      },
      'cannot_collect_more': {
        'hi': 'बकाया शेष राशि से अधिक एकत्र नहीं किया जा सकता।',
        'en': 'Cannot collect more than the outstanding balance.',
      },
      'payment_received': {
        'hi': 'भुगतान प्राप्त हुआ।',
        'en': 'Payment received.',
      },
      'profile_updated': {
        'hi': 'प्रोफ़ाइल सफलतापूर्वक अपडेट की गई।',
        'en': 'Profile updated successfully.',
      },
      'save_btn': {
        'hi': 'सेव करें',
        'en': 'Save',
      },
      'more_options': {
        'hi': 'अधिक विकल्प',
        'en': 'More Options',
      },
      'store_is_open': {
        'hi': 'दुकान खुली है',
        'en': 'Store is Open',
      },
      'financial_rules': {
        'hi': 'वित्तीय नियम',
        'en': 'Financial Rules',
      },
      'delivery_options': {
        'hi': 'डिलीवरी विकल्प',
        'en': 'Delivery Options',
      },
      'store_location': {
        'hi': 'दुकान का स्थान',
        'en': 'Store Location',
      },
      'product_deleted': {
        'hi': 'उत्पाद सफलतापूर्वक हटा दिया गया।',
        'en': 'Product deleted successfully.',
      },
      'err_deleting_product': {
        'hi': 'उत्पाद हटाने में विफल।',
        'en': 'Failed to delete product.',
      },
      'item_exists_update': {
        'hi': 'आइटम पहले से मौजूद है! आप इसका विवरण अपडेट कर सकते हैं।',
        'en': 'Item already exists! You can update its details.',
      },
      'product_fetched': {
        'hi': 'उत्पाद विवरण प्राप्त किया गया!',
        'en': 'Product details fetched!',
      },
      'barcode_not_found': {
        'hi': 'डेटाबेस में बारकोड नहीं मिला। कृपया मैन्युअल रूप से दर्ज करें।',
        'en': 'Barcode not found in database. Please enter manually.',
      },
      'err_network_fetch': {
        'hi': 'नेटवर्क त्रुटि। उत्पाद प्राप्त नहीं किया जा सका।',
        'en': 'Network error. Could not fetch product.',
      },
      'err_price_stock': {
        'hi': 'त्रुटि: मूल्य > 0 और स्टॉक >= 0 होना चाहिए',
        'en': 'Error: Price must be > 0 and Stock must be >= 0',
      },
      'err_name_price': {
        'hi': 'कृपया नाम और मूल्य भरें',
        'en': 'Please fill Name and Price',
      },
      // ---- PHASE 3: SNACKBARS & ERRORS ----
      'login_blocked': {
        'hi': 'आपका लॉगिन ब्लॉक है! कृपया {minutes} मिनट बाद कोशिश करें।',
        'en': 'Your login is blocked! Please try again in {minutes} minute(s).',
      },
      'select_shop_first': {
        'hi': 'पहले गेटवे स्क्रीन से अपनी दुकान चुनें।',
        'en': 'Please select your shop from the gateway screen first.',
      },
      'shop_data_not_found': {
        'hi': 'दुकान का डेटा नहीं मिला।',
        'en': 'Shop data not found.',
      },
      'login_blocked_1_hour': {
        'hi': '3 बार गलत PIN! एडमिन लॉगिन 1 घंटे के लिए ब्लॉक कर दिया गया है।',
        'en': '3 wrong PINs! Admin login is blocked for 1 hour.',
      },
      'wrong_pin_attempts': {
        'hi': 'गलत एडमिन PIN! आपके पास सिर्फ {attempts} प्रयास बचे हैं।',
        'en': 'Wrong Admin PIN! You have only {attempts} attempt(s) left.',
      },
      'network_error': {
        'hi': 'नेटवर्क त्रुटि: {error}',
        'en': 'Network Error: {error}',
      },
      'err_product_name': {
        'hi': 'कृपया उत्पाद का नाम दर्ज करें',
        'en': 'Please enter product name',
      },
      'err_category': {
        'hi': 'कृपया एक श्रेणी चुनें',
        'en': 'Please select a category',
      },
      'err_image': {
        'hi': 'कृपया उत्पाद की छवि अपलोड करें',
        'en': 'Please upload a product image',
      },
      'err_price_mrp': {
        'hi': 'कृपया कीमत और MRP भरें',
        'en': 'Please fill in price and MRP',
      },
      'err_mrp_less': {
        'hi': 'MRP बिक्री मूल्य से कम नहीं हो सकती',
        'en': 'MRP cannot be less than selling price',
      },
      'product_added': {
        'hi': 'उत्पाद सफलतापूर्वक जोड़ा गया!',
        'en': 'Product added successfully!',
      },
      'product_updated': {
        'hi': 'उत्पाद सफलतापूर्वक अपडेट किया गया!',
        'en': 'Product updated successfully!',
      },
      'err_saving_product': {
        'hi': 'उत्पाद सहेजने में त्रुटि: {error}',
        'en': 'Error saving product: {error}',
      },
      'err_uploading_image': {
        'hi': 'छवि अपलोड करने में त्रुटि: {error}',
        'en': 'Error uploading image: {error}',
      },
      'transaction_deleted': {
        'hi': 'लेन-देन हटा दिया गया और शेष राशि अपडेट की गई।',
        'en': 'Transaction deleted and balance updated.',
      },
      'udhaar_added': {
        'hi': 'उधार जोड़ा गया',
        'en': 'Udhaar Added',
      },
      'payment_received_short': {
        'hi': 'भुगतान प्राप्त हुआ',
        'en': 'Payment Received',
      },
      'customer_unblocked': {
        'hi': 'ग्राहक अनब्लॉक किया गया',
        'en': 'Customer unblocked',
      },
      'customer_blocked': {
        'hi': 'ग्राहक ब्लॉक किया गया',
        'en': 'Customer blocked',
      },
      'err_loading_settings': {
        'hi': 'सेटिंग्स लोड करने में त्रुटि: {error}',
        'en': 'Error loading settings: {error}',
      },
      'err_negative_values': {
        'hi': 'मान नकारात्मक नहीं हो सकते!',
        'en': 'Values cannot be negative!',
      },

      'err_saving_settings': {
        'hi': 'सेटिंग्स सहेजने में त्रुटि: {error}',
        'en': 'Error saving settings: {error}',
      },
      'location_picked': {
        'hi': 'स्थान सफलतापूर्वक चुना गया!',
        'en': 'Location picked successfully!',
      },
      'err_reading_location': {
        'hi': 'स्थान पढ़ने में त्रुटि: {error}',
        'en': 'Error reading location: {error}',
      },
      'err_no_location': {
        'hi': 'कोई स्थान नहीं चुना गया था।',
        'en': 'No location was selected.',
      },
      'generic_error': {
        'hi': 'त्रुटि: {error}',
        'en': 'Error: {error}',
      }
    };

    return translations[key]?[_currentLanguage] ?? key;
  }
}
