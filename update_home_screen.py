import os

file_path = 'lib/home_screen.dart'

with open(file_path, 'r') as f:
    content = f.read()

# Add import at the top
import_str = "import 'customer_desktop_dashboard.dart';"
if import_str not in content:
    content = content.replace("import 'app_theme.dart';", "import 'app_theme.dart';\n" + import_str)

# Replace the desktop layout part
start_str = """        if (isDesktop) {
          // DESKTOP LAYOUT (Blinkit Style)"""
end_str = """        // MOBILE LAYOUT
        return Scaffold("""

start_idx = content.find(start_str)
end_idx = content.find(end_str, start_idx)

new_desktop_layout = """        if (isDesktop) {
          return DesktopCustomerDashboard(
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
                      child: IndexedStack(index: _selectedIndex, children: _tabs),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

"""

if start_idx != -1:
    content = content[:start_idx] + new_desktop_layout + content[end_idx:]

with open(file_path, 'w') as f:
    f.write(content)
print("done replacing")
