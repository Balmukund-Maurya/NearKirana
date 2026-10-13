import os

file_path = 'lib/admin_dashboard.dart'

with open(file_path, 'r') as f:
    content = f.read()

# Add import for admin_desktop_dashboard
if "import 'admin_desktop_dashboard.dart';" not in content:
    content = content.replace(
        "import 'package:near_kirana/firebase_utils.dart';",
        "import 'package:near_kirana/firebase_utils.dart';\nimport 'admin_desktop_dashboard.dart';"
    )

# Replace the Scaffold in _AdminDashboardState with LayoutBuilder
old_scaffold = """    return Scaffold(
      backgroundColor: AppColors.surface,
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      bottomNavigationBar: StreamBuilder<QuerySnapshot>("""

new_scaffold = """    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          // Map desktop 10-item index to our mobile tabs when needed
          // 0: AdminHomeTab (but desktop has its own Home)
          // 1: AdminOrdersTab
          // 2: ShopStockScreen
          // 3: Categories (mapped to 2 or 4)
          // 4: Customers (mapped to 4)
          // 5: KhataScreen (mapped to 3)
          // 6: Shop Boys
          // 7: Analytics
          // 8: Discounts
          // 9: AdminSettingsScreen (mapped to 4)
          
          int effectiveIndex = 0;
          if (_selectedIndex == 0) effectiveIndex = 0;
          else if (_selectedIndex == 1) effectiveIndex = 1;
          else if (_selectedIndex == 2) effectiveIndex = 2; // Products
          else if (_selectedIndex == 3) effectiveIndex = 2; // Categories -> Stock
          else if (_selectedIndex == 4) effectiveIndex = 4; // Customers -> More
          else if (_selectedIndex == 5) effectiveIndex = 3; // Khata
          else if (_selectedIndex == 6) effectiveIndex = 4; // Shop Boys -> More
          else if (_selectedIndex == 7) effectiveIndex = 0; // Analytics -> Home
          else if (_selectedIndex == 8) effectiveIndex = 4; // Discounts -> More
          else if (_selectedIndex == 9) effectiveIndex = 4; // Settings -> More

          return AdminDesktopDashboard(
            selectedIndex: _selectedIndex,
            onNavTap: _onNavTap,
            child: Scaffold(
              backgroundColor: const Color(0xFFF0F2F5),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Container(
                    margin: const EdgeInsets.only(top: 24, left: 24, right: 24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: IndexedStack(index: effectiveIndex, children: _tabs),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: IndexedStack(index: _selectedIndex, children: _tabs),
          bottomNavigationBar: StreamBuilder<QuerySnapshot>("""

content = content.replace(old_scaffold, new_scaffold)

# Need to close the LayoutBuilder parenthesis at the end
# The bottomNavigationBar ends with:
#             ),
#           ),
#         ),
#       );
#         },
#       ),
#     );
#   }
# }

# So it ends with:
#       ),
#     );
#   }
# }
old_end = """      ),
    );
  }
}"""
new_end = """      ),
        );
      },
    );
  }
}"""

content = content.replace(old_end, new_end)

with open(file_path, 'w') as f:
    f.write(content)
print("done")
