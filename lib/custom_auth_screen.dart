import 'package:flutter/material.dart';
import 'package:phone_email_auth/phone_email_auth.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'app_theme.dart';

class CustomAuthScreen extends StatefulWidget {
  const CustomAuthScreen({super.key});

  @override
  State<CustomAuthScreen> createState() => _CustomAuthScreenState();
}

class _CustomAuthScreenState extends State<CustomAuthScreen> {
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;
  late String authenticationUrl;
  String? deviceId;

  @override
  void initState() {
    super.initState();
  }

  Future<void> inAppWebViewConfiguration(InAppWebViewController controller) async {
    final phoneEmail = PhoneEmail();

    if (phoneEmail.deviceId != null && phoneEmail.deviceId!.isNotEmpty) {
      deviceId = phoneEmail.deviceId;
    } else {
      deviceId = await PhoneEmail.getUDID();
    }

    authenticationUrl = "${AppConstant.authUrl}?"
        "${AppConstant.clientId}=${phoneEmail.clientId}"
        "&${AppConstant.device}=${deviceId ?? ""}"
        "&${AppConstant.authType}=5";

    webViewController!.loadUrl(
      urlRequest: URLRequest(url: WebUri(authenticationUrl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            AppConstant.authViewTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            color: Colors.white,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          backgroundColor: AppColors.primaryDark,
          centerTitle: true,
          elevation: 0,
        ),
        body: InAppWebView(
          key: webViewKey,
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            cacheEnabled: true,
            allowsInlineMediaPlayback: true,
          ),
          onWebViewCreated: (controller) async {
            webViewController = controller;
            inAppWebViewConfiguration(controller);
          },
          onLoadStart: (controller, url) {
            webViewController!.addJavaScriptHandler(
              handlerName: AppConstant.sendTokenToApp,
              callback: (arguments) {
                if (arguments.isNotEmpty) {
                  Navigator.pop(
                    context,
                    {
                      AppConstant.authResponse: LoginModel.fromJson(arguments.first),
                    },
                  );
                }
              },
            );
          },
          onReceivedError: (controller, request, error) {
            debugPrint("WebView Error: ${error.description}");
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
