import os
import re

filepath = '/Users/macbook/Desktop/Kirana_Store_Builder/lib/customer_desktop_dashboard.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Replace build method
old_build = """  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT: Fixed dark-green customer sidebar
          _buildSidebar(context),
          
          // CENTER & RIGHT
          Expanded(
            child: widget.selectedIndex == 0
                ? _buildDashboardContent(context)
                : widget.child,
          ),
        ],
      ),
    );
  }"""

new_build = """  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT: Fixed dark-green customer sidebar
          _buildSidebar(context),
          
          // CENTER & RIGHT
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(context),
                Expanded(
                  child: widget.selectedIndex == 0
                      ? _buildDashboardContentBody(context)
                      : widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }"""

content = content.replace(old_build, new_build)

# Replace _buildDashboardContent with _buildDashboardContentBody
old_content_method = """  Widget _buildDashboardContent(BuildContext context) {
    return Column(
      children: [
        // TOP: Full-width content header
        _buildTopHeader(context),
        
        // MAIN SPLIT (CENTER & RIGHT)
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CENTER COLUMN
              Expanded(
                flex: 7,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeSection(context),
                      const SizedBox(height: 32),
                      _buildSummaryCards(context),
                      const SizedBox(height: 32),
                      _buildPromoSection(context),
                      const SizedBox(height: 32),
                      _buildCategoriesSection(context),
                      const SizedBox(height: 32),
                      _buildRecommendedSection(context),
                    ],
                  ),
                ),
              ),
              
              // RIGHT COLUMN
              Container(
                width: 320,
                color: Colors.white,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMyCartRightCol(context),
                      const SizedBox(height: 24),
                      _buildRecentOrdersRightCol(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }"""

new_content_method = """  Widget _buildDashboardContentBody(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CENTER COLUMN
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeSection(context),
                const SizedBox(height: 32),
                _buildSummaryCards(context),
                const SizedBox(height: 32),
                _buildPromoSection(context),
                const SizedBox(height: 32),
                _buildCategoriesSection(context),
                const SizedBox(height: 32),
                _buildRecommendedSection(context),
              ],
            ),
          ),
        ),
        
        // RIGHT COLUMN
        Container(
          width: 320,
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMyCartRightCol(context),
                const SizedBox(height: 24),
                _buildRecentOrdersRightCol(context),
              ],
            ),
          ),
        ),
      ],
    );
  }"""

content = content.replace(old_content_method, new_content_method)

with open(filepath, 'w') as f:
    f.write(content)
print("Updated customer_desktop_dashboard.dart layout")
