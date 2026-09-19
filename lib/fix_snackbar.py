import re

with open('/Users/balmukund/Documents/flutterProject/Aditya_Kirana/lib/admin_product_forms.dart', 'r') as f:
    content = f.read()

# Add _showTopSnackBar method
top_snackbar_code = """
  static void _showTopSnackBar(BuildContext context, String message, {bool isError = false}) {
    final margin = MediaQuery.of(context).size.height - 150;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: margin > 0 ? margin : 0, left: 20, right: 20),
        backgroundColor: isError ? Colors.red : Colors.green,
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
"""

# Insert right after class AdminProductForms {
content = content.replace("class AdminProductForms {", "class AdminProductForms {" + top_snackbar_code)

# Replace fetching success
content = content.replace("""                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Product details fetched!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );""", "                                _showTopSnackBar(context, 'Product details fetched!');")

# Replace fetching error
content = content.replace("""                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                      'Barcode not found in database. Please enter manually.',
                                    ),
                                    duration: Duration(seconds: 3),
                                  ),
                                );""", "                                _showTopSnackBar(context, 'Barcode not found in database. Please enter manually.', isError: true);")

# Replace validation errors (price > 0)
validation_error = """                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                      'Error: Price must be > 0 and Stock must be >= 0',
                                    ),
                                  ),
                                );"""
content = content.replace(validation_error, "                                _showTopSnackBar(context, 'Error: Price must be > 0 and Stock must be >= 0', isError: true);")

# Delete success
delete_success = """                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                                'Product deleted successfully.',
                                              ),
                                            ),
                                          );"""
content = content.replace(delete_success, "                                          _showTopSnackBar(context, 'Product deleted successfully.');")

# Delete error
delete_error = """                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                                'Failed to delete product.',
                                              ),
                                            ),
                                          );"""
content = content.replace(delete_error, "                                          _showTopSnackBar(context, 'Failed to delete product.', isError: true);")


with open('/Users/balmukund/Documents/flutterProject/Aditya_Kirana/lib/admin_product_forms.dart', 'w') as f:
    f.write(content)
