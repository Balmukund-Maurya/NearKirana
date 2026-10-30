import json

new_translations = """
      'cat_all': {'hinglish': 'Sabhi', 'hi': 'सभी', 'en': 'All'},
      'cat_dal': {'hinglish': 'Dal', 'hi': 'दाल', 'en': 'Dal'},
      'cat_rice': {'hinglish': 'Chawal', 'hi': 'चावल', 'en': 'Rice'},
      'cat_spices': {'hinglish': 'Masale', 'hi': 'मसाले', 'en': 'Spices'},
      'cat_oil': {'hinglish': 'Tel', 'hi': 'तेल', 'en': 'Oil'},
      'cat_snacks': {'hinglish': 'Snacks', 'hi': 'नमकीन/स्नैक्स', 'en': 'Snacks'},
      'cat_soap': {'hinglish': 'Sabun', 'hi': 'साबुन', 'en': 'Soap'},
      'cat_loose': {'hinglish': 'Khula Saman', 'hi': 'खुला सामान', 'en': 'Loose'},
      'fix_btn': {'hinglish': 'Theek Karein', 'hi': 'ठीक करें', 'en': 'Fix'},
      'max_stock': {'hinglish': 'Maximum limit pahunch gayi!', 'hi': 'अधिकतम सीमा तक पहुँच गए!', 'en': 'Maximum stock reached!'},
      'qty_exceeds': {'hinglish': 'Jitna manga hai, utna stock nahi hai.', 'hi': 'मांगी गई मात्रा उपलब्ध स्टॉक से अधिक है।', 'en': 'Requested quantity exceeds available stock.'},
      'adjust_location': {'hinglish': 'Map par location set karein 📍', 'hi': 'मैप पर स्थान सेट करें 📍', 'en': 'Adjust Location on Map 📍'},
      'enter_house_no': {'hinglish': 'Kripya apna House/Flat No daalein.', 'hi': 'कृपया अपना मकान/फ्लैट नंबर दर्ज करें।', 'en': 'Please enter your House/Flat No.'},
      'wait_3_min': {'hinglish': 'Agla order karne se pehle 3 minute rukein.', 'hi': 'कृपया अगला ऑर्डर देने से पहले 3 मिनट प्रतीक्षा करें।', 'en': 'Please wait 3 minutes before placing another order.'},
      'order_placed': {'hinglish': 'Order Safaltapurvak Ho Gaya.', 'hi': 'ऑर्डर सफलतापूर्वक प्राप्त हुआ।', 'en': 'Order Placed Successfully.'},
      'thank_you_order': {'hinglish': 'Dhanyawad! Aapka order mil gaya hai.', 'hi': 'धन्यवाद! आपका ऑर्डर प्राप्त हो गया है।', 'en': 'Thank you! Your order has been received.'},
      'ok_btn': {'hinglish': 'Theek Hai', 'hi': 'ठीक है', 'en': 'OK'},
      'confirm_order': {'hinglish': 'Order Confirm Karein', 'hi': 'ऑर्डर की पुष्टि करें', 'en': 'Confirm Order'},
      'cancel_order_q': {'hinglish': 'Order Cancel Karein?', 'hi': 'ऑर्डर रद्द करें?', 'en': 'Cancel Order?'},
      'cancel_order_sure': {'hinglish': 'Kya aap sach mein ye order cancel karna chahte hain?', 'hi': 'क्या आप वाकई यह ऑर्डर रद्द करना चाहते हैं?', 'en': 'Are you sure you want to cancel this order?'},
      'no_btn': {'hinglish': 'Nahi', 'hi': 'नहीं', 'en': 'No'},
      'yes_cancel': {'hinglish': 'Haan, Cancel karein', 'hi': 'हाँ, रद्द करें', 'en': 'Yes, Cancel'},
      'order_cancelled': {'hinglish': 'Order Cancel Ho Gaya.', 'hi': 'ऑर्डर सफलतापूर्वक रद्द कर दिया गया।', 'en': 'Order Cancelled Successfully.'},
      'cancel_order_btn': {'hinglish': 'Order Cancel Karein', 'hi': 'ऑर्डर रद्द करें', 'en': 'Cancel Order'},
"""

with open('lib/language_provider.dart', 'r') as f:
    content = f.read()

target = "    };\n\n    return translations[key]?[_currentLanguage] ?? key;"
if target in content:
    content = content.replace(target, new_translations + target)
    with open('lib/language_provider.dart', 'w') as f:
        f.write(content)
    print("Success")
else:
    print("Target not found")
