# AlwaysPro Kirana StoreBuilder

AlwaysPro Kirana StoreBuilder is a Flutter-based multi-shop grocery delivery application designed for kirana shops to manage customers, orders, inventory, and delivery operations from a single mobile app experience.

## Features

- Multi-shop support with shop selection and registration
- Customer storefront with product browsing and cart
- Order placement and order history
- Admin dashboard for managing products, orders, and customers
- Shop-specific settings such as delivery fee, minimum order, and support contact
- Admin login with PIN protection and lockout handling
- Firebase backend integration for shops, products, orders, and user data
- GPS-based shop registration with address and coordinates capture

## Tech Stack

- Flutter & Dart
- Firebase Firestore
- Firebase Authentication / Messaging / Storage (used by the app flow)
- Provider for state management
- SharedPreferences for local persistence
- Geolocator and Geocoding for location support

## Project Structure

- `lib/` contains the main application screens and business logic
- `android/`, `ios/`, `web/`, `linux/`, `macos/`, and `windows/` contain platform-specific project files
- `assets/` contains images, sounds, and Lottie assets
- `test/` contains application tests

## Getting Started

### Prerequisites

- Flutter SDK installed
- Android Studio / Xcode (for mobile build)
- Firebase project configured

### Installation

1. Clone the repository
   ```bash
   git clone https://github.com/Balmukund-Maurya/AlwaysPro_Kirana_StoreBuilder.git
   ```
2. Navigate into the project directory
   ```bash
   cd AlwaysPro_Kirana_StoreBuilder
   ```
3. Install dependencies
   ```bash
   flutter pub get
   ```
4. Run the app
   ```bash
   flutter run
   ```

### Firebase Setup

Make sure your Firebase project is configured properly and the generated `google-services.json` / `GoogleService-Info.plist` files are present for the platform you are building for.

## Notes

This project is currently being expanded as a shop-oriented delivery and management platform for kirana businesses. It includes both customer-facing and admin-facing workflows for a complete local retail experience.
