# 🛍️ NearKirana - Hyperlocal Kirana Delivery & Enterprise ERP Platform

<p align="center">
  <img src="assets/images/logo.png" alt="NearKirana Logo" width="120" onerror="this.style.display='none'"/>
</p>

<p align="center">
  <strong>Next-Generation Multi-Tenant Quick-Commerce & Store Digitization Engine for Neighborhood Retail</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.12+-02569B?logo=flutter&logoColor=white" alt="Flutter Version" />
  <img src="https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart&logoColor=white" alt="Dart Version" />
  <img src="https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Storage-FFCA28?logo=firebase&logoColor=black" alt="Firebase Stack" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20macOS-4CAF50" alt="Cross Platform" />
  <img src="https://img.shields.io/badge/License-Proprietary-blue.svg" alt="License" />
</p>

---

## 📑 Table of Contents

1. [Executive Summary & Problem Statement](#-executive-summary--problem-statement)
2. [Complete Visual Tour & Screenshot Gallery](#-complete-visual-tour--screenshot-gallery)
   - [Customer Onboarding & Role Architecture](#1-customer-onboarding--role-architecture)
   - [Hyperlocal Store Discovery & Catalog Browsing](#2-hyperlocal-store-discovery--catalog-browsing)
   - [Customer Ordering, PIN Verification & Smart Lists](#3-customer-ordering-pin-verification--smart-lists)
   - [Merchant Control Center & Fulfillment Pipeline](#4-merchant-control-center--fulfillment-pipeline)
   - [Store Inventory, Barcode Scanner & Batch Tracking](#5-store-inventory-barcode-scanner--batch-tracking)
   - [Digital Khata Ledger & Financial Recovery](#6-digital-khata-ledger--financial-recovery)
   - [Sales, COGS & Net Profit Analytics](#7-sales-cogs--net-profit-analytics)
   - [Delivery Fleet Operations & Doorstep PIN Verification](#8-delivery-fleet-operations--doorstep-pin-verification)
   - [Customer Support, Disputes & Loyalty Coins](#9-customer-support-disputes--loyalty-coins)
   - [Enterprise Governance, Staff Audit & CA Data Export](#10-enterprise-governance-staff-audit--ca-data-export)
3. [System Architecture & Core Engineering](#-system-architecture--core-engineering)
   - [ACID Atomic Transaction Processing](#acid-atomic-transaction-processing)
   - [Deterministic Order State Machine](#deterministic-order-state-machine)
   - [Bilingual Voice-to-Cart NLP Engine](#bilingual-voice-to-cart-nlp-engine)
   - [Live Road Navigation & Polyline Tracking](#live-road-navigation--polyline-tracking)
   - [FIFO Inventory Valuation & COGS Margin Engine](#fifo-inventory-valuation--cogs-margin-engine)
   - [Thermal ESC/POS & PDF Invoice System](#thermal-escpos--pdf-invoice-system)
4. [Firestore Database Schema](#-firestore-database-schema)
5. [Role-Based Access Control & Security Model](#-role-based-access-control--security-model)
6. [Project Directory Structure](#-project-directory-structure)
7. [Installation & Local Setup](#-installation--local-setup)
8. [Configuration & Environment Flags](#-configuration--environment-flags)
9. [Testing & Quality Assurance](#-testing--quality-assurance)
10. [License & Production Guidelines](#-license--production-guidelines)

---

## 🌟 Executive Summary & Problem Statement

In the traditional Indian retail landscape, over 12 million neighborhood grocery shops (**Kirana stores**) handle more than 85% of everyday grocery purchases. However, traditional kirana merchants face severe structural vulnerabilities:
1. **Loss of Market Share to Dark Stores**: Centralized 10-minute quick-commerce players deplete local footfall with instant mobile app convenience.
2. **Bookkeeping Losses in Credit (Udhar/Khata)**: Informal customer credit ledgers written in paper diaries result in forgotten payments, disputes, and unrecoverable cash flow.
3. **Delivery Disconnect & Leakage**: Dispatched store deliveries lack GPS tracking, delivery proof, or cash-on-delivery settlement reconciliation.
4. **Inventory & Expiry Blindspots**: Absence of automated barcode tracking causes stockouts of high-velocity goods while perishable products quietly expire on shelves.

**NearKirana** bridges this divide by delivering an **enterprise-grade, multi-tenant digital ERP and hyperlocal commerce platform**. It equips neighborhood stores with the speed and technology of modern quick-commerce operators while preserving the community trust, personalized service, and credit lines of local kirana merchants.

---

## 📸 Complete Visual Tour & Screenshot Gallery

Every screenshot below is captured directly from the live NearKirana production application across its four integrated role portals: **Customer**, **Kirana Merchant**, **Delivery Partner**, and **Super Admin**.

---

### 1. Customer Onboarding & Role Architecture

| Authentication Gateway | Multi-Role Portal Selection |
| :---: | :---: |
| <img src="docs/screenshots/app_login_gateway.png" width="360" alt="Customer Authentication Gateway" /> | <img src="docs/screenshots/app_role_selection.png" width="360" alt="Multi-Role Portal Selection" /> |
| **Mobile Authentication Gateway**: Ultra-clean mobile OTP entry with country code selection, dynamic 10-25 mins instant delivery value proposition, trilingual language switcher (English, Hindi, Hinglish), and discreet access to Super Admin governance. | **Multi-Tenant Role Selector**: Dynamic entry point allowing authenticated phone numbers to seamlessly transition between Customer (Grahak), Kirana Merchant (Dukandar), and Delivery Partner roles based on granular Firestore privileges. |

---

### 2. Hyperlocal Store Discovery & Catalog Browsing

| Hyperlocal Store Discovery | Branded Storefront Landing |
| :---: | :---: |
| <img src="docs/screenshots/app_shop_selector.png" width="360" alt="Hyperlocal Store Discovery" /> | <img src="docs/screenshots/app_customer_storefront.png" width="360" alt="Branded Storefront Landing" /> |
| **GPS Hyperlocal Store Selector**: Calculates exact distance and estimated delivery window (e.g. 25-35 mins) within the store's geofenced radius. Supports area search and physical in-store QR code scanner for instant binding. | **Individual Storefront Branding**: Displays custom merchant banner, verified store badge, operating hours, delivery radius, and direct WhatsApp / phone contact hotline. |

| Customer Catalog & Search | Interactive Empty Cart & Voice Ordering |
| :---: | :---: |
| <img src="docs/screenshots/app_customer_home.png" width="360" alt="Customer Shopping Catalog" /> | <img src="docs/screenshots/app_customer_cart_empty.png" width="360" alt="Empty Cart Screen" /> |
| **Customer Shopping Experience**: Address delivery header, category chip carousels (Atta, Rice, Spices, Snacks, Soap), substring keyword search, bilingual voice mic, and product cards with MRP, sale price, and unit steppers. | **Interactive Cart Gateway**: Frictionless cart interface featuring one-tap bilingual voice order dictation and contextual shortcuts back to the merchant's catalog. |

---

### 3. Customer Ordering, PIN Verification & Smart Lists

| Customer Live Orders & PIN Handover | Smart Shopping Lists & Reorder |
| :---: | :---: |
| <img src="docs/screenshots/app_customer_orders.png" width="360" alt="Customer Live Orders & PIN" /> | <img src="docs/screenshots/app_customer_shopping_lists.png" width="360" alt="Smart Shopping Lists & Reorder" /> |
| **Active Orders Pipeline**: Multi-stage fulfillment stepper (Placed → Packing → On the way → Delivered), dynamic ETA countdown, downloadable PDF bill, and a confidential **4-digit doorstep delivery PIN** required for order completion. | **Recurring Grocery Lists**: Lets households create custom monthly lists or generate instant 1-tap reorders directly from previous order history with estimated basket pricing. |

| Customer Profile & Saved Addresses | Merchant Store Onboarding |
| :---: | :---: |
| <img src="docs/screenshots/app_customer_profile.png" width="360" alt="Customer Profile & Addresses" /> | <img src="docs/screenshots/app_shop_registration.png" width="360" alt="Merchant Store Onboarding" /> |
| **Customer Profile & Account Hub**: Displays verified phone badge, active store switch, saved address manager with GPS pin mapping, loyalty reward coin balance, and language preferences. | **Zepto/Blinkit-Inspired Store Onboarding**: Multi-step registration wizard capturing shop name, merchant legal identity (GSTIN/FSSAI), GPS coordinates, delivery radius, and minimum order rules. |

---

### 4. Merchant Control Center & Fulfillment Pipeline

| Merchant Partner Dashboard | Live Order Processing Pipeline |
| :---: | :---: |
| <img src="docs/screenshots/app_merchant_dashboard.png" width="360" alt="Merchant Partner Dashboard" /> | <img src="docs/screenshots/app_merchant_orders_pipeline.png" width="360" alt="Merchant Orders Pipeline" /> |
| **Executive Store Hub**: Real-time KPI summary (Today's Sales, Active Orders, Low Stock Alerts, Collectable Khata Dues) alongside an interactive **Weekly Revenue Trend** line chart powered by `fl_chart`. | **Live Order Dispatch Queue**: Pipeline tabs (All Active, Ready/Pack, Out for Delivery, Store Pickup). Features one-tap Accept/Reject, itemized picker lists, invoice printing, and smart out-of-stock item substitution. |

---

### 5. Store Inventory, Barcode Scanner & Batch Tracking

| Barcode Inventory & Stock Stepper | Staff Accounts & Audit Trail |
| :---: | :---: |
| <img src="docs/screenshots/app_merchant_inventory_stock.png" width="360" alt="Store Inventory & Stock" /> | <img src="docs/screenshots/app_merchant_staff_audit.png" width="360" alt="Staff Accounts & Audit Trail" /> |
| **Live Catalog & Barcode Inventory**: Fast search by title, category, or barcode scan. Immediate inline stock increment/decrement steppers, low-stock threshold triggers, and new item creation. | **Staff Management & Audit Trail**: Granular employee roles (Cashier, Packer, Delivery Rider) paired with an immutable audit log recording who modified stock, prices, or discounts. |

---

### 6. Digital Khata Ledger & Financial Recovery

| Digital Khata Ledger (Udhaar Book) | Customer Accounts & Outstanding Dues |
| :---: | :---: |
| <img src="docs/screenshots/app_merchant_khata_ledger.png" width="360" alt="Digital Khata Ledger" /> | <img src="docs/screenshots/app_customers.png" width="360" alt="Customer Directory" /> |
| **Digital Udhaar & Balance Ledger**: Tracks overall market dues, pending collections, and advance payments. Deep-links directly to WhatsApp with automated, localized payment reminder messages. | **Customer Directory & Credit Limits**: Unified ledger for both app users and walk-in offline customers. One-tap payment receipt recording and instant ledger transaction statements. |

---

### 7. Sales, COGS & Net Profit Analytics

| Sales, COGS & Net Profit Analytics | CA Tax & Accounting Data Export |
| :---: | :---: |
| <img src="docs/screenshots/app_merchant_analytics_profit.png" width="360" alt="Sales & Profit Analytics" /> | <img src="docs/screenshots/app_merchant_data_export.png" width="360" alt="Data Export & CA Backup" /> |
| **Executive Financial Analytics**: True profitability tracking combining Total Revenue, Cost of Goods Sold (COGS), Gross Profit, Operating Store Expenses, Net Profit, and Average Order Value (AOV). | **Accounting & CA Compliance Exporter**: One-click generation of month-end CSV spreadsheets and printable PDF financial statements for Chartered Accountant audit and GST tax filing. |

---

### 8. Delivery Fleet Operations & Doorstep PIN Verification

| Delivery Fleet Management | Doorstep 4-Digit Handover PIN Verification |
| :---: | :---: |
| <img src="docs/screenshots/app_merchant_fleet_dispatch.png" width="360" alt="Delivery Fleet Management" /> | <img src="docs/screenshots/app_delivery_pin_verification.png" width="360" alt="Delivery PIN Verification" /> |
| **Delivery Fleet Roster**: Live rider duty toggles, current delivery assignments, vehicle registration, and direct calling hotline for real-time dispatch coordination. | **Anti-Fraud Delivery Handover**: Delivery partner verifies package delivery by submitting the customer's secret 4-digit PIN, simultaneously logging Cash on Delivery (COD) collection. |

| Delivery Partner Dispatch Portal | Platform Super Admin Governance |
| :---: | :---: |
| <img src="docs/screenshots/app_delivery_partner.png" width="360" alt="Delivery Partner Portal" /> | <img src="docs/screenshots/app_super_admin.png" width="360" alt="Super Admin Governance" /> |
| **Delivery Rider Operating Mode**: Duty on/off toggle switch, assigned delivery tasks with item breakdowns, customer phone calling, and turn-by-turn road navigation via Google Maps. | **Platform Super Admin Governance**: Ecosystem-wide store verification, KYC document approvals, merchant suspension toggles, and multi-tenant performance analytics. |

---

### 9. Customer Support, Disputes & Loyalty Coins

| Customer Complaints & Dispute Resolution | Tiered Loyalty Coins & Referrals |
| :---: | :---: |
| <img src="docs/screenshots/app_merchant_disputes_returns.png" width="360" alt="Complaints & Returns Desk" /> | <img src="docs/screenshots/app_merchant_loyalty_referrals.png" width="360" alt="Loyalty Coins & Referrals" /> |
| **Merchant Dispute Desk**: Real-time management of customer complaints, missing or damaged item inspection with photographic proof, and direct refund authorization. | **Tiered Loyalty Program (Gold / Silver / Bronze)**: Customer coin passbook tracking earned and redeemed points, custom referral codes, and automated cart discount redemption. |

---

## 🏗️ System Architecture & Core Engineering

```
┌────────────────────────────────────────────────────────────────────────┐
│                        NearKirana Presentation Layer                   │
│   ┌──────────────────┐ ┌───────────────────┐ ┌──────────────────────┐  │
│   │ Customer App     │ │ Merchant ERP Hub  │ │ Delivery Partner     │  │
│   │ (Catalog, Voice, │ │ (Orders, Stock,   │ │ (Tasks, Nav,         │  │
│   │ Cart, Live Nav)  │ │ Khata, Analytics) │ │ PIN Handover)        │  │
│   └─────────┬────────┘ └─────────┬─────────┘ └──────────┬───────────┘  │
└─────────────┼────────────────────┼──────────────────────┼──────────────┘
              ▼                    ▼                      ▼
┌────────────────────────────────────────────────────────────────────────┐
│               Business Logic & Reactive Providers (ChangeNotifier)     │
│  UserProvider  •  ShopProvider  •  CartProvider  •  LanguageProvider   │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Core Platform Services                          │
│ ┌─────────────────────────┐ ┌─────────────────────────┐ ┌────────────┐ │
│ │ AtomicOrderService      │ │ OrderStateMachine       │ │ VoiceOrder │ │
│ │ (ACID Transactions)     │ │ (Deterministic FSM)     │ │ (Bilingual)│ │
│ └─────────────────────────┘ └─────────────────────────┘ └────────────┘ │
│ ┌─────────────────────────┐ ┌─────────────────────────┐ ┌────────────┐ │
│ │ RoadRoutingService      │ │ AnalyticsService        │ │ Invoice    │ │
│ │ (OSRM Polyline + ETA)   │ │ (COGS + Net Profit)     │ │ (ESC/POS)  │ │
│ └─────────────────────────┘ └─────────────────────────┘ └────────────┘ │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                    Cloud Infrastructure (Google Firebase)              │
│  Cloud Firestore  •  Firebase Auth  •  Cloud Storage  •  Cloud Messaging│
└────────────────────────────────────────────────────────────────────────┘
```

---

### ACID Atomic Transaction Processing

High-concurrency order placement and stock deduction cannot rely on simple client-side updates. NearKirana implements **ACID-compliant atomic transactions** in `lib/atomic_order_service.dart`:
- **Inventory Reservation**: Inside `FirebaseFirestore.instance.runTransaction`, stock counts for all basket line items are verified and decremented simultaneously.
- **Race Condition Prevention**: If another customer buys the last packet of milk while checkout is processing, the transaction aborts with a graceful out-of-stock warning.
- **Rollback on Cancellation**: If an order is rejected by the merchant or cancelled, stock units are atomically restored to the inventory catalog.
- **PIN Handover Verification**: The 4-digit PIN is verified atomically inside the completion transaction before transitioning status to `delivered`.

---

### Deterministic Order State Machine

Order lifecycle progression is strictly enforced by `lib/order_state_machine.dart` to prevent illegal state jumps:

```
[ pending ] ──(Merchant Accepts)──► [ accepted ] ──(Packing Done)──► [ packing ]
     │                                                                      │
     ├──(Merchant Rejects)──► [ rejected ]                                  ▼
     │                                                             [ out_for_delivery ]
     └──(Customer Cancels)──► [ cancelled ]                                 │
                                                                   (PIN Verification)
                                                                            │
                                                                            ▼
                                                                      [ delivered ]
```

Invalid transitions (such as jumping directly from `pending` to `delivered` without packing) throw state machine exceptions and are rejected both client-side and at the Firestore security rule level.

---

### Bilingual Voice-to-Cart NLP Engine

To serve non-tech-savvy customers and senior citizens, `lib/voice_order_parser.dart` implements an offline natural language parsing algorithm supporting Hindi, English, and Hinglish:
1. **Phonetic Normalization**: Cleans conversational speech patterns (e.g. converting *"do kilo"*, *"do packet"*, *"aadha kilo"*, *"2 kg"*).
2. **Entity Extraction**: Recognizes numbers (Hindi numerics *"ek"*, *"do"*, *"teen"*, *"paanch"*), metric units (*kg, g, packet, litre, piece, pouch*), and product keywords.
3. **Fuzzy Product Resolution**: Matches the extracted product token against substring tokens in the active merchant's Firestore catalog (`searchKeywords`).
4. **Instant Cart Insertion**: Directly populates `CartProvider` with the exact requested quantity and unit price.

---

### Live Road Navigation & Polyline Tracking

Live delivery tracking (`lib/customer_live_tracking_screen.dart` and `lib/road_routing_service.dart`) integrates Open Source Routing Machine (OSRM) polylines with `flutter_map`:
- Calculates accurate real-world road geometries rather than straight-line Euclidean distances.
- Dynamically estimates arrival time (ETA) based on rider speed, distance, and current traffic conditions.
- Smoothly animates rider motorcycle markers across route coordinates with automatic camera bearing adjustments.

---

### FIFO Inventory Valuation & COGS Margin Engine

Traditional store software only calculates total revenue. `lib/analytics_service.dart` introduces **true retail profit accounting**:
- **COGS Tracking**: Tracks wholesale purchase prices (`purchase_price`) for every inventory SKU.
- **Gross Profit**: `Gross Profit = Total Revenue - COGS`.
- **Operating Expense Ledger**: Merchants log daily store overheads (electricity, shop rent, delivery fuel, staff wages) via `AddExpenseDialog`.
- **Net Profit**: `Net Profit = Gross Profit - Total Expenses`.
- **Intelligent Fallback**: If an item lacks a recorded wholesale price, the system applies a configurable 15% kirana gross margin baseline with clear transparency notices.

---

### Thermal ESC/POS & PDF Invoice System

`lib/invoice_service.dart` generates professional, tax-compliant documentation:
- **Thermal Bluetooth Printing**: Formats lightweight 58mm / 80mm ESC/POS commands for standard portable receipt printers used at kirana counters.
- **A4 PDF Invoicing**: Produces crisp vector PDF invoices with store logo, GSTIN, customer details, itemized HSN/SAC codes, CGST/SGST breakdowns, and a verification QR code.

---

## 🗄️ Firestore Database Schema

The database architecture is structured around complete multi-tenant tenant isolation indexed by `shop_id`:

```
firestore/
├── shops/{shopId}
│   ├── shop_name: string
│   ├── owner_name: string
│   ├── mobile: string
│   ├── address: string
│   ├── location: geopoint (lat, lng)
│   ├── delivery_radius_km: number (e.g. 3.0)
│   ├── min_order_amount: number (e.g. 99)
│   ├── is_active: boolean
│   ├── upi_id: string
│   └── created_at: timestamp
│
├── products/{productId}
│   ├── shop_id: string (foreign key -> shops)
│   ├── name: string
│   ├── category: string (Atta, Rice, Spices, Dairy, Snacks)
│   ├── price: number (Retail Sale Price)
│   ├── mrp: number (Maximum Retail Price)
│   ├── purchase_price: number (Wholesale COGS)
│   ├── stock_qty: number
│   ├── unit: string (kg, g, packet, litre, pc)
│   ├── barcode: string
│   ├── search_keywords: array<string>
│   └── image_url: string
│
├── orders/{orderId}
│   ├── shop_id: string
│   ├── customer_phone: string
│   ├── customer_name: string
│   ├── delivery_address: map (house_no, locality, lat, lng)
│   ├── items: array<map> (product_id, name, price, qty, unit)
│   ├── total_amount: number
│   ├── payment_method: string (COD, UPI, RAZORPAY)
│   ├── payment_status: string (pending, paid)
│   ├── status: string (pending, accepted, packing, out_for_delivery, delivered, cancelled)
│   ├── delivery_pin: string (4-digit secret, e.g. "9616")
│   ├── delivery_partner_id: string
│   └── created_at: timestamp
│
├── users/{phone}
│   ├── name: string
│   ├── phone: string
│   ├── role: string (customer, shop_owner, delivery_partner, super_admin)
│   ├── saved_addresses: array<map>
│   ├── loyalty_coins: number
│   └── referral_code: string
│
├── khata/{khataId}
│   ├── shop_id: string
│   ├── customer_phone: string
│   ├── customer_name: string
│   ├── balance: number (positive = due, negative = advance)
│   ├── transactions: subcollection
│   │   ├── amount: number
│   │   ├── type: string (credit / debit)
│   │   ├── note: string
│   │   └── timestamp: timestamp
│
├── complaints/{complaintId}
│   ├── order_id: string
│   ├── shop_id: string
│   ├── customer_phone: string
│   ├── reason: string (Damaged, Missing, Wrong Item)
│   ├── status: string (pending, in_review, refunded, rejected)
│   ├── proof_image_url: string
│   └── resolution_notes: string
│
└── staff/{staffId}
    ├── shop_id: string
    ├── name: string
    ├── phone: string
    ├── role: string (cashier, packer, rider)
    ├── permissions: array<string>
    └── pin_hash: string
```

---

## 🔒 Role-Based Access Control & Security Model

NearKirana enforces strict tenant isolation using enterprise `firestore.rules`:
1. **Multi-Tenant Boundary**: A merchant or staff member authenticated under `SHOP_A` cannot read, query, or mutate catalog, khata, or order documents belonging to `SHOP_B`.
2. **PIN Protection**: The secret 4-digit order `delivery_pin` is strictly readable only by the ordering customer and the atomic verification function; it is hidden from delivery partner listings until doorstep submission.
3. **Privilege Escalation Barriers**: User roles (`super_admin`, `shop_owner`) can only be assigned through authorized elevation endpoints or verified Super Admin PIN tokens.
4. **Immutable Audit Logs**: Records in the `staff_audit` collection have create-only permissions; no staff member or merchant can update or delete historical audit entries.

---

## 📂 Project Directory Structure

```text
Kirana_Store_Builder/
├── android/                             # Native Android configuration & Gradle builds
├── ios/                                 # Native iOS workspace & CocoaPods
├── web/                                 # Web entrypoint and manifest assets
├── assets/
│   ├── images/                          # Branding, placeholding & category icons
│   ├── lottie/                          # High-performance animated illustrations
│   └── sounds/                          # Order alert chimes (sound_service.dart)
├── docs/
│   └── screenshots/                     # 23 authentic high-resolution app screenshots
├── lib/
│   ├── l10n/                            # Trilingual localization (EN, HI, Hinglish)
│   ├── widgets/                         # Modular reusable UI components
│   │   ├── add_expense_dialog.dart      # Merchant store expense logging
│   │   ├── complaint_status_card.dart   # Customer dispute resolution widget
│   │   ├── record_purchase_dialog.dart  # Supplier procurement logging
│   │   └── ...
│   ├── address_selection_bottom_sheet.dart # GPS map address picker
│   ├── admin_analytics_screen.dart      # COGS, Revenue, Net Profit analytics
│   ├── admin_batch_expiry_screen.dart   # Batch tracking & expiry date manager
│   ├── admin_complaints_screen.dart     # Dispute resolution desk
│   ├── admin_dashboard.dart             # Merchant mobile ERP control center
│   ├── admin_desktop_dashboard.dart     # Desktop responsive management view
│   ├── admin_home_tab.dart              # Merchant KPI cards & weekly chart
│   ├── admin_inventory_stock.dart       # Barcode inventory management
│   ├── admin_loyalty_screen.dart        # Customer rewards & referral rules
│   ├── admin_order_card.dart            # Live order card with state actions
│   ├── admin_orders_tab.dart            # Order fulfillment pipeline
│   ├── admin_shop_boys_screen.dart      # Staff accounts & permissions
│   ├── admin_staff_audit_screen.dart    # Immutable activity audit logs
│   ├── admin_whatsapp_reminder_screen.dart # WhatsApp automated Udhaar reminders
│   ├── analytics_service.dart           # Financial profit calculations
│   ├── atomic_order_service.dart        # ACID-compliant Firestore order processor
│   ├── cart_provider.dart               # Cart reactive state & dynamic fees
│   ├── cart_screen.dart                 # Checkout & payment selector
│   ├── customer_live_tracking_screen.dart # Real-time OSRM GPS road tracking
│   ├── customer_shop_tab.dart           # Customer storefront & catalog view
│   ├── delivery_partner_screen.dart     # Delivery rider portal & PIN input
│   ├── gateway_screen.dart              # Authentication gateway & role selector
│   ├── invoice_service.dart             # Thermal ESC/POS & PDF invoice engine
│   ├── khata_screen.dart                # Digital credit (Udhaar) ledger
│   ├── main.dart                        # Application bootstrap, routing & providers
│   ├── order_state_machine.dart         # Deterministic order transition FSM
│   ├── product_substitution_service.dart# Out-of-stock item substitution logic
│   ├── razorpay_service.dart            # Online payment gateway SDK bridge
│   ├── road_routing_service.dart        # OSRM road geometry & ETA calculations
│   ├── shopping_lists_screen.dart       # Smart recurring grocery lists
│   ├── super_admin_screen.dart          # Platform-wide governance & KYC desk
│   └── voice_order_parser.dart          # Bilingual Hindi/English voice NLP parser
├── test/                                # Comprehensive unit & integration tests
│   ├── atomic_order_service_test.dart
│   ├── role_audit_fixes_test.dart
│   └── shopping_lists_reorder_test.dart
├── firestore.rules                      # Production multi-tenant security rules
├── storage.rules                        # Cloud Storage asset protection rules
└── pubspec.yaml                         # Package dependencies and asset manifests
```

---

## 🚀 Installation & Local Setup

### Prerequisites

- **Flutter SDK**: `v3.12.2` or higher (compatible with Flutter 3.24+)
- **Dart SDK**: `v3.0.0` or higher
- **Android Studio / Xcode**: Configured with Android API 34+ or iOS 15+ SDK
- **Firebase Project**: Cloud Firestore, Firebase Authentication, and Cloud Storage enabled

### Step-by-Step Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/Balmukund-Maurya/NearKirana.git
   cd NearKirana
   ```

2. **Install Flutter Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Generate Localization Files**:
   ```bash
   flutter gen-l10n
   ```

4. **Verify Connected Devices**:
   ```bash
   flutter devices
   ```

5. **Run the Application**:
   ```bash
   # Run on connected Android Emulator or Physical Device
   flutter run -d emulator-5554

   # Run on macOS Desktop
   flutter run -d macos

   # Run on Chrome Web
   flutter run -d chrome
   ```

---

## ⚙️ Configuration & Environment Flags

For production deployments, inject runtime credentials using compile-time `--dart-define` parameters:

```bash
flutter run \
  --dart-define=RAZORPAY_KEY_ID="rzp_live_xxxxxxxxxxxx" \
  --dart-define=RAZORPAY_KEY_SECRET="xxxxxxxxxxxxxxxx" \
  --dart-define=SUPER_ADMIN_PIN="8899" \
  --dart-define=ENABLE_MAP_LOGS="false"
```

---

## 🧪 Testing & Quality Assurance

NearKirana includes an extensive test suite covering atomic order transactions, role permissions, and shopping list operations:

```bash
# Run all unit and widget tests
flutter test

# Run specific atomic transaction regression tests
flutter test test/role_audit_fixes_test.dart

# Run shopping list and reorder test suite
flutter test test/shopping_lists_reorder_test.dart

# Perform static code analysis
flutter analyze
```

---

## 📄 License & Production Guidelines

- **Proprietary & Commercial Use**: This software is engineered specifically for hyperlocal grocery networks, kirana store digitization, and neighborhood commerce networks.
- **Data Protection**: Store transactional data, customer phone numbers, and Khata financial ledgers are strictly governed under Firestore tenant boundary rules.
- **Disclaimer**: Brand logos, FMCG packaging artwork, and third-party trademarks (e.g., Aashirvaad, Maggi, Lays, Tata Salt) displayed in screenshots belong to their respective manufacturers and are utilized solely for illustrative retail catalog demonstrations.

---

<p align="center">
  Crafted with ❤️ for India's 12 Million Neighborhood Kirana Merchants.
</p>
