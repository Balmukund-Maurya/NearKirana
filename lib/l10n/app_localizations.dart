import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'),
  ];

  /// No description provided for @or_divider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or_divider;

  /// No description provided for @app_name.
  ///
  /// In en, this message translates to:
  /// **'My Store'**
  String get app_name;

  /// No description provided for @subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your Digital Store'**
  String get subtitle;

  /// No description provided for @name_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter Your Name'**
  String get name_hint;

  /// No description provided for @mobile_hint.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobile_hint;

  /// No description provided for @enter_button.
  ///
  /// In en, this message translates to:
  /// **'Enter Store'**
  String get enter_button;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our Terms & Conditions'**
  String get terms;

  /// No description provided for @owner_login.
  ///
  /// In en, this message translates to:
  /// **'Owner Login / Admin Access'**
  String get owner_login;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get language;

  /// No description provided for @error_loading.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get error_loading;

  /// No description provided for @no_product.
  ///
  /// In en, this message translates to:
  /// **'No products available.'**
  String get no_product;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'+ Add'**
  String get add;

  /// No description provided for @added_to_cart.
  ///
  /// In en, this message translates to:
  /// **'Added to cart!'**
  String get added_to_cart;

  /// No description provided for @admin_dashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get admin_dashboard;

  /// No description provided for @scan_barcode.
  ///
  /// In en, this message translates to:
  /// **'Scan Barcode / New Bill'**
  String get scan_barcode;

  /// No description provided for @quick_add.
  ///
  /// In en, this message translates to:
  /// **'Loose Items (Quick Add)'**
  String get quick_add;

  /// No description provided for @shop_stock.
  ///
  /// In en, this message translates to:
  /// **'Store Inventory'**
  String get shop_stock;

  /// No description provided for @customer_ledger.
  ///
  /// In en, this message translates to:
  /// **'Customer Ledger'**
  String get customer_ledger;

  /// No description provided for @live_orders.
  ///
  /// In en, this message translates to:
  /// **'New Orders (Live)'**
  String get live_orders;

  /// No description provided for @cart_title.
  ///
  /// In en, this message translates to:
  /// **'Your Cart'**
  String get cart_title;

  /// No description provided for @total_amount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get total_amount;

  /// No description provided for @place_order.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get place_order;

  /// No description provided for @home_delivery.
  ///
  /// In en, this message translates to:
  /// **'Home Delivery'**
  String get home_delivery;

  /// No description provided for @store_pickup.
  ///
  /// In en, this message translates to:
  /// **'Store Pickup'**
  String get store_pickup;

  /// No description provided for @add_new_item.
  ///
  /// In en, this message translates to:
  /// **'Add New Item'**
  String get add_new_item;

  /// No description provided for @store_closed_error.
  ///
  /// In en, this message translates to:
  /// **'The store is currently closed. Please try again later.'**
  String get store_closed_error;

  /// No description provided for @ghost_cart_error.
  ///
  /// In en, this message translates to:
  /// **'Some items in your cart are no longer available and were removed.'**
  String get ghost_cart_error;

  /// No description provided for @out_of_stock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get out_of_stock;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @my_profile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get my_profile;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @delivery_address.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get delivery_address;

  /// No description provided for @app_language.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get app_language;

  /// No description provided for @help_support.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get help_support;

  /// No description provided for @call_shop.
  ///
  /// In en, this message translates to:
  /// **'Call Store Owner'**
  String get call_shop;

  /// No description provided for @whatsapp_support.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Support'**
  String get whatsapp_support;

  /// No description provided for @chat_with_us.
  ///
  /// In en, this message translates to:
  /// **'Chat with us'**
  String get chat_with_us;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logout_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout? Your cart will be cleared.'**
  String get logout_confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @no_address.
  ///
  /// In en, this message translates to:
  /// **'No address saved. It will be added during your first order.'**
  String get no_address;

  /// No description provided for @house_no.
  ///
  /// In en, this message translates to:
  /// **'House/Flat No:'**
  String get house_no;

  /// No description provided for @landmark_txt.
  ///
  /// In en, this message translates to:
  /// **'Landmark:'**
  String get landmark_txt;

  /// No description provided for @shop_tab.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get shop_tab;

  /// No description provided for @cart_tab.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart_tab;

  /// No description provided for @orders_tab.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders_tab;

  /// No description provided for @my_orders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get my_orders;

  /// No description provided for @please_login.
  ///
  /// In en, this message translates to:
  /// **'Please login to view orders.'**
  String get please_login;

  /// No description provided for @cart_empty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty.'**
  String get cart_empty;

  /// No description provided for @search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get search_hint;

  /// No description provided for @cat_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get cat_all;

  /// No description provided for @cat_dal.
  ///
  /// In en, this message translates to:
  /// **'Dal'**
  String get cat_dal;

  /// No description provided for @cat_rice.
  ///
  /// In en, this message translates to:
  /// **'Rice'**
  String get cat_rice;

  /// No description provided for @cat_spices.
  ///
  /// In en, this message translates to:
  /// **'Spices'**
  String get cat_spices;

  /// No description provided for @cat_oil.
  ///
  /// In en, this message translates to:
  /// **'Oil'**
  String get cat_oil;

  /// No description provided for @cat_snacks.
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get cat_snacks;

  /// No description provided for @cat_soap.
  ///
  /// In en, this message translates to:
  /// **'Soap'**
  String get cat_soap;

  /// No description provided for @cat_loose.
  ///
  /// In en, this message translates to:
  /// **'Loose'**
  String get cat_loose;

  /// No description provided for @fix_btn.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get fix_btn;

  /// No description provided for @max_stock.
  ///
  /// In en, this message translates to:
  /// **'Maximum stock reached!'**
  String get max_stock;

  /// No description provided for @qty_exceeds.
  ///
  /// In en, this message translates to:
  /// **'Requested quantity exceeds available stock.'**
  String get qty_exceeds;

  /// No description provided for @adjust_location.
  ///
  /// In en, this message translates to:
  /// **'Adjust Location on Map 📍'**
  String get adjust_location;

  /// No description provided for @enter_house_no.
  ///
  /// In en, this message translates to:
  /// **'Please enter your House/Flat No.'**
  String get enter_house_no;

  /// No description provided for @wait_3_min.
  ///
  /// In en, this message translates to:
  /// **'Please wait 3 minutes before placing another order.'**
  String get wait_3_min;

  /// No description provided for @order_placed.
  ///
  /// In en, this message translates to:
  /// **'Order Placed Successfully.'**
  String get order_placed;

  /// No description provided for @thank_you_order.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your order has been received.'**
  String get thank_you_order;

  /// No description provided for @thank_you_order_pickup.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your order has been received. Please collect your order from the store.'**
  String get thank_you_order_pickup;

  /// No description provided for @ok_btn.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok_btn;

  /// No description provided for @confirm_order.
  ///
  /// In en, this message translates to:
  /// **'Confirm Order'**
  String get confirm_order;

  /// No description provided for @cancel_order_q.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order?'**
  String get cancel_order_q;

  /// No description provided for @cancel_order_sure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this order?'**
  String get cancel_order_sure;

  /// No description provided for @no_btn.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no_btn;

  /// No description provided for @yes_cancel.
  ///
  /// In en, this message translates to:
  /// **'Yes, Cancel'**
  String get yes_cancel;

  /// No description provided for @order_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Order Cancelled Successfully.'**
  String get order_cancelled;

  /// No description provided for @cancel_order_btn.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancel_order_btn;

  /// No description provided for @name_lbl.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name_lbl;

  /// No description provided for @mobile_lbl.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get mobile_lbl;

  /// No description provided for @address_lbl.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address_lbl;

  /// No description provided for @edit_profile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get edit_profile;

  /// No description provided for @save_profile.
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get save_profile;

  /// No description provided for @contact_no.
  ///
  /// In en, this message translates to:
  /// **'Contact Number'**
  String get contact_no;

  /// No description provided for @personal_info.
  ///
  /// In en, this message translates to:
  /// **'Personal Info'**
  String get personal_info;

  /// No description provided for @account_settings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get account_settings;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @delivery_fee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get delivery_fee;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @order_no.
  ///
  /// In en, this message translates to:
  /// **'Order #'**
  String get order_no;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @out_for_delivery.
  ///
  /// In en, this message translates to:
  /// **'Out for delivery by'**
  String get out_for_delivery;

  /// No description provided for @delivery_pin.
  ///
  /// In en, this message translates to:
  /// **'Delivery PIN'**
  String get delivery_pin;

  /// No description provided for @delivery_mode.
  ///
  /// In en, this message translates to:
  /// **'Delivery Mode'**
  String get delivery_mode;

  /// No description provided for @no_orders.
  ///
  /// In en, this message translates to:
  /// **'No orders found.'**
  String get no_orders;

  /// No description provided for @view_history.
  ///
  /// In en, this message translates to:
  /// **'View History'**
  String get view_history;

  /// No description provided for @khata.
  ///
  /// In en, this message translates to:
  /// **'Khata'**
  String get khata;

  /// No description provided for @view_ledger.
  ///
  /// In en, this message translates to:
  /// **'View Ledger'**
  String get view_ledger;

  /// No description provided for @admin_user.
  ///
  /// In en, this message translates to:
  /// **'Admin User'**
  String get admin_user;

  /// No description provided for @admin_role.
  ///
  /// In en, this message translates to:
  /// **'Store Owner'**
  String get admin_role;

  /// No description provided for @store_management.
  ///
  /// In en, this message translates to:
  /// **'Store Management'**
  String get store_management;

  /// No description provided for @admin_customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get admin_customers;

  /// No description provided for @admin_customers_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage all customer profiles'**
  String get admin_customers_subtitle;

  /// No description provided for @store_settings.
  ///
  /// In en, this message translates to:
  /// **'Delivery & Setup'**
  String get store_settings;

  /// No description provided for @store_settings_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery fees, timings & rules'**
  String get store_settings_subtitle;

  /// No description provided for @app_settings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get app_settings;

  /// No description provided for @language_setting.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language_setting;

  /// No description provided for @language_setting_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Change app language'**
  String get language_setting_subtitle;

  /// No description provided for @admin_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get admin_logout;

  /// No description provided for @admin_logout_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of the admin panel?'**
  String get admin_logout_confirm;

  /// No description provided for @admin_version.
  ///
  /// In en, this message translates to:
  /// **'Shop Admin - Version 1.0.0'**
  String get admin_version;

  /// No description provided for @select_language.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get select_language;

  /// No description provided for @add_or_update_product.
  ///
  /// In en, this message translates to:
  /// **'Add or update product'**
  String get add_or_update_product;

  /// No description provided for @live_orders_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'\'s active orders'**
  String get live_orders_subtitle;

  /// No description provided for @today_sales.
  ///
  /// In en, this message translates to:
  /// **'Today\'\'s Sales'**
  String get today_sales;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get greeting;

  /// No description provided for @error_no_shop_found.
  ///
  /// In en, this message translates to:
  /// **'No shops found in your area.'**
  String get error_no_shop_found;

  /// No description provided for @scan_shop_qr.
  ///
  /// In en, this message translates to:
  /// **'Scan Shop QR Code'**
  String get scan_shop_qr;

  /// No description provided for @delete_product.
  ///
  /// In en, this message translates to:
  /// **'Delete Product?'**
  String get delete_product;

  /// No description provided for @add_new_category.
  ///
  /// In en, this message translates to:
  /// **'Add New Category'**
  String get add_new_category;

  /// No description provided for @add_btn.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add_btn;

  /// No description provided for @food_item_veg_nonveg.
  ///
  /// In en, this message translates to:
  /// **'Food Item (Show Veg/Non-Veg dot)'**
  String get food_item_veg_nonveg;

  /// No description provided for @veg_product.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian Product'**
  String get veg_product;

  /// No description provided for @loose_item.
  ///
  /// In en, this message translates to:
  /// **'Loose Item'**
  String get loose_item;

  /// No description provided for @dukan_badlein_title.
  ///
  /// In en, this message translates to:
  /// **'Change Store?'**
  String get dukan_badlein_title;

  /// No description provided for @dukan_badlein_desc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to change the selected store?'**
  String get dukan_badlein_desc;

  /// No description provided for @yes_change.
  ///
  /// In en, this message translates to:
  /// **'Yes, Change'**
  String get yes_change;

  /// No description provided for @change_shop_btn.
  ///
  /// In en, this message translates to:
  /// **'Change Store'**
  String get change_shop_btn;

  /// No description provided for @error_connecting.
  ///
  /// In en, this message translates to:
  /// **'Error connecting to server. Try again.'**
  String get error_connecting;

  /// No description provided for @invalid_khata_entry.
  ///
  /// In en, this message translates to:
  /// **'Enter valid 10-digit phone and amount > 0.'**
  String get invalid_khata_entry;

  /// No description provided for @name_required_khata.
  ///
  /// In en, this message translates to:
  /// **'Name is required for new customers!'**
  String get name_required_khata;

  /// No description provided for @khata_entry_success.
  ///
  /// In en, this message translates to:
  /// **'Khata Entry Added Successfully!'**
  String get khata_entry_success;

  /// No description provided for @add_entry.
  ///
  /// In en, this message translates to:
  /// **'Add Entry'**
  String get add_entry;

  /// No description provided for @add_offline_khata.
  ///
  /// In en, this message translates to:
  /// **'Add Offline Khata'**
  String get add_offline_khata;

  /// No description provided for @settings_saved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully!'**
  String get settings_saved;

  /// No description provided for @negative_values_error.
  ///
  /// In en, this message translates to:
  /// **'Values cannot be negative!'**
  String get negative_values_error;

  /// No description provided for @pick_on_map.
  ///
  /// In en, this message translates to:
  /// **'Pick on\nMap'**
  String get pick_on_map;

  /// No description provided for @welcome_title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to NearKirana'**
  String get welcome_title;

  /// No description provided for @search_shop_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Find shops near you or scan their QR Code.'**
  String get search_shop_subtitle;

  /// No description provided for @search_shop_hint.
  ///
  /// In en, this message translates to:
  /// **'Search shop name...'**
  String get search_shop_hint;

  /// No description provided for @type_to_search_shops.
  ///
  /// In en, this message translates to:
  /// **'Type to search shops'**
  String get type_to_search_shops;

  /// No description provided for @find_stores_near_you.
  ///
  /// In en, this message translates to:
  /// **'Find stores near you'**
  String get find_stores_near_you;

  /// No description provided for @turn_on_gps.
  ///
  /// In en, this message translates to:
  /// **'Turn on GPS to find stores around you.'**
  String get turn_on_gps;

  /// No description provided for @searching_stores.
  ///
  /// In en, this message translates to:
  /// **'Searching for stores nearby...'**
  String get searching_stores;

  /// No description provided for @are_you_shop_owner.
  ///
  /// In en, this message translates to:
  /// **'Are you a shop owner?'**
  String get are_you_shop_owner;

  /// No description provided for @register_your_shop.
  ///
  /// In en, this message translates to:
  /// **'Register Your Shop'**
  String get register_your_shop;

  /// No description provided for @move_map_adjust.
  ///
  /// In en, this message translates to:
  /// **'Move map to adjust location'**
  String get move_map_adjust;

  /// No description provided for @enter_complete_address.
  ///
  /// In en, this message translates to:
  /// **'Enter Complete Address'**
  String get enter_complete_address;

  /// No description provided for @locality_area.
  ///
  /// In en, this message translates to:
  /// **'Locality / Area'**
  String get locality_area;

  /// No description provided for @house_flat_no.
  ///
  /// In en, this message translates to:
  /// **'House / Flat / Block No.'**
  String get house_flat_no;

  /// No description provided for @landmark_optional.
  ///
  /// In en, this message translates to:
  /// **'Landmark (Optional)'**
  String get landmark_optional;

  /// No description provided for @save_address_as.
  ///
  /// In en, this message translates to:
  /// **'Save address as'**
  String get save_address_as;

  /// No description provided for @save_address_btn.
  ///
  /// In en, this message translates to:
  /// **'Save Address'**
  String get save_address_btn;

  /// No description provided for @confirm_location.
  ///
  /// In en, this message translates to:
  /// **'Confirm Location'**
  String get confirm_location;

  /// No description provided for @confirm_delivery_loc.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delivery Location'**
  String get confirm_delivery_loc;

  /// No description provided for @out_of_delivery_area.
  ///
  /// In en, this message translates to:
  /// **'Out of Delivery Area'**
  String get out_of_delivery_area;

  /// No description provided for @selected_loc_outside.
  ///
  /// In en, this message translates to:
  /// **'Selected location is outside the delivery area!'**
  String get selected_loc_outside;

  /// No description provided for @search_area_hint.
  ///
  /// In en, this message translates to:
  /// **'Search area, landmark or city...'**
  String get search_area_hint;

  /// No description provided for @error_cant_deliver.
  ///
  /// In en, this message translates to:
  /// **'Oops! We don\'\'t deliver to your selected location.'**
  String get error_cant_deliver;

  /// No description provided for @please_enable_gps.
  ///
  /// In en, this message translates to:
  /// **'Please enable GPS'**
  String get please_enable_gps;

  /// No description provided for @register_shop_title.
  ///
  /// In en, this message translates to:
  /// **'Register Shop'**
  String get register_shop_title;

  /// No description provided for @shop_setting_up.
  ///
  /// In en, this message translates to:
  /// **'Your shop is being set up...'**
  String get shop_setting_up;

  /// No description provided for @product_found.
  ///
  /// In en, this message translates to:
  /// **'Product Found'**
  String get product_found;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @stock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stock;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @manage_customers.
  ///
  /// In en, this message translates to:
  /// **'Manage Customers'**
  String get manage_customers;

  /// No description provided for @record_payment.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get record_payment;

  /// No description provided for @invalid_amount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount.'**
  String get invalid_amount;

  /// No description provided for @cannot_collect_more.
  ///
  /// In en, this message translates to:
  /// **'Cannot collect more than the outstanding balance.'**
  String get cannot_collect_more;

  /// No description provided for @payment_received.
  ///
  /// In en, this message translates to:
  /// **'Payment received.'**
  String get payment_received;

  /// No description provided for @profile_updated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully.'**
  String get profile_updated;

  /// No description provided for @save_btn.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save_btn;

  /// No description provided for @more_options.
  ///
  /// In en, this message translates to:
  /// **'More Options'**
  String get more_options;

  /// No description provided for @store_is_open.
  ///
  /// In en, this message translates to:
  /// **'Store is Open'**
  String get store_is_open;

  /// No description provided for @financial_rules.
  ///
  /// In en, this message translates to:
  /// **'Financial Rules'**
  String get financial_rules;

  /// No description provided for @delivery_options.
  ///
  /// In en, this message translates to:
  /// **'Delivery Options'**
  String get delivery_options;

  /// No description provided for @store_location.
  ///
  /// In en, this message translates to:
  /// **'Store Location'**
  String get store_location;

  /// No description provided for @product_deleted.
  ///
  /// In en, this message translates to:
  /// **'Product deleted successfully.'**
  String get product_deleted;

  /// No description provided for @err_deleting_product.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete product.'**
  String get err_deleting_product;

  /// No description provided for @item_exists_update.
  ///
  /// In en, this message translates to:
  /// **'Item already exists! You can update its details.'**
  String get item_exists_update;

  /// No description provided for @product_fetched.
  ///
  /// In en, this message translates to:
  /// **'Product details fetched!'**
  String get product_fetched;

  /// No description provided for @barcode_not_found.
  ///
  /// In en, this message translates to:
  /// **'Barcode not found in database. Please enter manually.'**
  String get barcode_not_found;

  /// No description provided for @err_network_fetch.
  ///
  /// In en, this message translates to:
  /// **'Network error. Could not fetch product.'**
  String get err_network_fetch;

  /// No description provided for @err_price_stock.
  ///
  /// In en, this message translates to:
  /// **'Error: Price must be > 0 and Stock must be >= 0'**
  String get err_price_stock;

  /// No description provided for @err_name_price.
  ///
  /// In en, this message translates to:
  /// **'Please fill Name and Price'**
  String get err_name_price;

  /// No description provided for @select_shop_first.
  ///
  /// In en, this message translates to:
  /// **'Please select your shop from the gateway screen first.'**
  String get select_shop_first;

  /// No description provided for @shop_data_not_found.
  ///
  /// In en, this message translates to:
  /// **'Shop data not found.'**
  String get shop_data_not_found;

  /// No description provided for @login_blocked_1_hour.
  ///
  /// In en, this message translates to:
  /// **'3 wrong PINs! Admin login is blocked for 1 hour.'**
  String get login_blocked_1_hour;

  /// No description provided for @err_product_name.
  ///
  /// In en, this message translates to:
  /// **'Please enter product name'**
  String get err_product_name;

  /// No description provided for @err_category.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get err_category;

  /// No description provided for @err_image.
  ///
  /// In en, this message translates to:
  /// **'Please upload a product image'**
  String get err_image;

  /// No description provided for @err_price_mrp.
  ///
  /// In en, this message translates to:
  /// **'Please fill in price and MRP'**
  String get err_price_mrp;

  /// No description provided for @err_mrp_less.
  ///
  /// In en, this message translates to:
  /// **'MRP cannot be less than selling price'**
  String get err_mrp_less;

  /// No description provided for @product_added.
  ///
  /// In en, this message translates to:
  /// **'Product added successfully!'**
  String get product_added;

  /// No description provided for @product_updated.
  ///
  /// In en, this message translates to:
  /// **'Product updated successfully!'**
  String get product_updated;

  /// No description provided for @transaction_deleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted and balance updated.'**
  String get transaction_deleted;

  /// No description provided for @udhaar_added.
  ///
  /// In en, this message translates to:
  /// **'Udhaar Added'**
  String get udhaar_added;

  /// No description provided for @payment_received_short.
  ///
  /// In en, this message translates to:
  /// **'Payment Received'**
  String get payment_received_short;

  /// No description provided for @customer_unblocked.
  ///
  /// In en, this message translates to:
  /// **'Customer unblocked'**
  String get customer_unblocked;

  /// No description provided for @customer_blocked.
  ///
  /// In en, this message translates to:
  /// **'Customer blocked'**
  String get customer_blocked;

  /// No description provided for @err_negative_values.
  ///
  /// In en, this message translates to:
  /// **'Values cannot be negative!'**
  String get err_negative_values;

  /// No description provided for @location_picked.
  ///
  /// In en, this message translates to:
  /// **'Location picked successfully!'**
  String get location_picked;

  /// No description provided for @err_no_location.
  ///
  /// In en, this message translates to:
  /// **'No location was selected.'**
  String get err_no_location;

  /// No description provided for @bill_details.
  ///
  /// In en, this message translates to:
  /// **'Bill Details'**
  String get bill_details;

  /// No description provided for @item_total.
  ///
  /// In en, this message translates to:
  /// **'Item Total'**
  String get item_total;

  /// No description provided for @delivery_charges.
  ///
  /// In en, this message translates to:
  /// **'Delivery Charges'**
  String get delivery_charges;

  /// No description provided for @free_delivery_label.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get free_delivery_label;

  /// No description provided for @platform_fee.
  ///
  /// In en, this message translates to:
  /// **'Platform Fee'**
  String get platform_fee;

  /// No description provided for @handling_fee.
  ///
  /// In en, this message translates to:
  /// **'Handling Fee'**
  String get handling_fee;

  /// No description provided for @coupon_discount.
  ///
  /// In en, this message translates to:
  /// **'Coupon Discount'**
  String get coupon_discount;

  /// No description provided for @total_savings.
  ///
  /// In en, this message translates to:
  /// **'Your Total Savings'**
  String get total_savings;

  /// No description provided for @to_pay.
  ///
  /// In en, this message translates to:
  /// **'To Pay'**
  String get to_pay;

  /// No description provided for @payment_method.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get payment_method;

  /// No description provided for @cash_on_delivery.
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery (COD)'**
  String get cash_on_delivery;

  /// No description provided for @pay_online_upi.
  ///
  /// In en, this message translates to:
  /// **'Pay Online / UPI'**
  String get pay_online_upi;

  /// No description provided for @khata_pay.
  ///
  /// In en, this message translates to:
  /// **'Pay with Khata (Udhaar)'**
  String get khata_pay;

  /// No description provided for @deliver_to.
  ///
  /// In en, this message translates to:
  /// **'Deliver To'**
  String get deliver_to;

  /// No description provided for @change_address_btn.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change_address_btn;

  /// No description provided for @add_address_btn.
  ///
  /// In en, this message translates to:
  /// **'Add Address'**
  String get add_address_btn;

  /// No description provided for @est_delivery_time.
  ///
  /// In en, this message translates to:
  /// **'Estimated Delivery in 15-30 Mins'**
  String get est_delivery_time;

  /// No description provided for @delivery_instructions_hint.
  ///
  /// In en, this message translates to:
  /// **'Add delivery instructions (optional)'**
  String get delivery_instructions_hint;

  /// No description provided for @apply_coupon.
  ///
  /// In en, this message translates to:
  /// **'Apply Coupon'**
  String get apply_coupon;

  /// No description provided for @coupon_applied.
  ///
  /// In en, this message translates to:
  /// **'Coupon applied successfully!'**
  String get coupon_applied;

  /// No description provided for @remove_coupon.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove_coupon;

  /// No description provided for @enter_coupon_code.
  ///
  /// In en, this message translates to:
  /// **'Enter coupon code'**
  String get enter_coupon_code;

  /// No description provided for @order_processing.
  ///
  /// In en, this message translates to:
  /// **'Processing your order...'**
  String get order_processing;

  /// No description provided for @back_to_cart.
  ///
  /// In en, this message translates to:
  /// **'Back to Cart'**
  String get back_to_cart;

  /// No description provided for @order_confirmed.
  ///
  /// In en, this message translates to:
  /// **'Order Confirmed!'**
  String get order_confirmed;

  /// No description provided for @err_invalid_phone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 10-digit mobile number'**
  String get err_invalid_phone;

  /// No description provided for @err_name_required.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get err_name_required;

  /// No description provided for @err_enter_address.
  ///
  /// In en, this message translates to:
  /// **'Please enter complete address'**
  String get err_enter_address;

  /// No description provided for @err_invalid_pin.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid PIN'**
  String get err_invalid_pin;

  /// No description provided for @err_min_amount.
  ///
  /// In en, this message translates to:
  /// **'Minimum order amount is required'**
  String get err_min_amount;

  /// No description provided for @err_stock_negative.
  ///
  /// In en, this message translates to:
  /// **'Stock cannot be negative'**
  String get err_stock_negative;

  /// No description provided for @err_price_zero.
  ///
  /// In en, this message translates to:
  /// **'Price must be greater than zero'**
  String get err_price_zero;

  /// No description provided for @err_enter_quantity.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid quantity'**
  String get err_enter_quantity;

  /// No description provided for @err_select_payment.
  ///
  /// In en, this message translates to:
  /// **'Please select a payment method'**
  String get err_select_payment;

  /// No description provided for @err_empty_cart_checkout.
  ///
  /// In en, this message translates to:
  /// **'Cannot checkout with an empty cart'**
  String get err_empty_cart_checkout;

  /// No description provided for @order_status_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get order_status_pending;

  /// No description provided for @order_status_accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get order_status_accepted;

  /// No description provided for @order_status_packing.
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get order_status_packing;

  /// No description provided for @order_status_ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get order_status_ready;

  /// No description provided for @order_status_out.
  ///
  /// In en, this message translates to:
  /// **'Out for Delivery'**
  String get order_status_out;

  /// No description provided for @order_status_delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get order_status_delivered;

  /// No description provided for @order_status_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get order_status_cancelled;

  /// No description provided for @order_status_rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get order_status_rejected;

  /// No description provided for @notif_order_placed_title.
  ///
  /// In en, this message translates to:
  /// **'Order Placed!'**
  String get notif_order_placed_title;

  /// No description provided for @notif_order_placed_body.
  ///
  /// In en, this message translates to:
  /// **'Your order has been placed successfully.'**
  String get notif_order_placed_body;

  /// No description provided for @notif_out_for_delivery_body.
  ///
  /// In en, this message translates to:
  /// **'Your order is on the way!'**
  String get notif_out_for_delivery_body;

  /// No description provided for @notif_delivered_body.
  ///
  /// In en, this message translates to:
  /// **'Your order has been delivered. Thank you!'**
  String get notif_delivered_body;

  /// No description provided for @item_added_snack.
  ///
  /// In en, this message translates to:
  /// **'Item added to cart'**
  String get item_added_snack;

  /// No description provided for @item_removed_snack.
  ///
  /// In en, this message translates to:
  /// **'Item removed from cart'**
  String get item_removed_snack;

  /// No description provided for @cart_cleared_snack.
  ///
  /// In en, this message translates to:
  /// **'Cart cleared'**
  String get cart_cleared_snack;

  /// No description provided for @tax_invoice_title.
  ///
  /// In en, this message translates to:
  /// **'Tax Invoice / Bill'**
  String get tax_invoice_title;

  /// No description provided for @invoice_no_lbl.
  ///
  /// In en, this message translates to:
  /// **'Invoice No'**
  String get invoice_no_lbl;

  /// No description provided for @invoice_date_lbl.
  ///
  /// In en, this message translates to:
  /// **'Invoice Date'**
  String get invoice_date_lbl;

  /// No description provided for @billed_to_lbl.
  ///
  /// In en, this message translates to:
  /// **'Billed To'**
  String get billed_to_lbl;

  /// No description provided for @item_col.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get item_col;

  /// No description provided for @qty_col.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get qty_col;

  /// No description provided for @rate_col.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate_col;

  /// No description provided for @amt_col.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amt_col;

  /// No description provided for @grand_total_lbl.
  ///
  /// In en, this message translates to:
  /// **'Grand Total'**
  String get grand_total_lbl;

  /// No description provided for @thank_you_shopping.
  ///
  /// In en, this message translates to:
  /// **'Thank you for shopping with us!'**
  String get thank_you_shopping;

  /// No description provided for @download_pdf_btn.
  ///
  /// In en, this message translates to:
  /// **'Download Invoice PDF'**
  String get download_pdf_btn;

  /// No description provided for @print_receipt_btn.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get print_receipt_btn;

  /// No description provided for @share_invoice_btn.
  ///
  /// In en, this message translates to:
  /// **'Share Invoice'**
  String get share_invoice_btn;

  /// No description provided for @order_summary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get order_summary;

  /// No description provided for @taxes_included.
  ///
  /// In en, this message translates to:
  /// **'Taxes included'**
  String get taxes_included;

  /// No description provided for @empty_cart_title.
  ///
  /// In en, this message translates to:
  /// **'Your Cart is Empty'**
  String get empty_cart_title;

  /// No description provided for @empty_cart_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Looks like you haven\'\'t added anything yet.'**
  String get empty_cart_subtitle;

  /// No description provided for @start_shopping_btn.
  ///
  /// In en, this message translates to:
  /// **'Start Shopping'**
  String get start_shopping_btn;

  /// No description provided for @order_by_voice_btn.
  ///
  /// In en, this message translates to:
  /// **'Order by Voice'**
  String get order_by_voice_btn;

  /// No description provided for @no_orders_title.
  ///
  /// In en, this message translates to:
  /// **'No Orders Placed Yet'**
  String get no_orders_title;

  /// No description provided for @no_orders_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your past orders and live tracking will appear here.'**
  String get no_orders_subtitle;

  /// No description provided for @no_products_found_title.
  ///
  /// In en, this message translates to:
  /// **'No Products Found'**
  String get no_products_found_title;

  /// No description provided for @no_products_found_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Try searching with a different name or category.'**
  String get no_products_found_subtitle;

  /// No description provided for @no_notifications_title.
  ///
  /// In en, this message translates to:
  /// **'No Notifications'**
  String get no_notifications_title;

  /// No description provided for @no_notifications_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Updates about your orders will show up here.'**
  String get no_notifications_subtitle;

  /// No description provided for @admin_overview.
  ///
  /// In en, this message translates to:
  /// **'Store Overview'**
  String get admin_overview;

  /// No description provided for @admin_inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory & Stock'**
  String get admin_inventory;

  /// No description provided for @admin_orders.
  ///
  /// In en, this message translates to:
  /// **'Orders & Billing'**
  String get admin_orders;

  /// No description provided for @admin_khata.
  ///
  /// In en, this message translates to:
  /// **'Customer Khata'**
  String get admin_khata;

  /// No description provided for @admin_analytics.
  ///
  /// In en, this message translates to:
  /// **'Sales & Analytics'**
  String get admin_analytics;

  /// No description provided for @admin_settings.
  ///
  /// In en, this message translates to:
  /// **'Store Settings'**
  String get admin_settings;

  /// No description provided for @mark_as_packed.
  ///
  /// In en, this message translates to:
  /// **'Mark as Packed'**
  String get mark_as_packed;

  /// No description provided for @mark_as_delivered.
  ///
  /// In en, this message translates to:
  /// **'Mark as Delivered'**
  String get mark_as_delivered;

  /// No description provided for @assign_delivery_boy.
  ///
  /// In en, this message translates to:
  /// **'Assign Delivery Boy'**
  String get assign_delivery_boy;

  /// No description provided for @out_for_delivery_btn.
  ///
  /// In en, this message translates to:
  /// **'Send Out for Delivery'**
  String get out_for_delivery_btn;

  /// No description provided for @confirm_payment_btn.
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get confirm_payment_btn;

  /// No description provided for @stock_updated_snack.
  ///
  /// In en, this message translates to:
  /// **'Stock updated successfully'**
  String get stock_updated_snack;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'hi':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return AppLocalizationsHiLatn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
