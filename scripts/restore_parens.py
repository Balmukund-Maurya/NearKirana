import os

file_path = 'lib/customer_desktop_dashboard.dart'

with open(file_path, 'r') as f:
    content = f.read()

bad_string = """          ),
        ],
      );
  }"""
good_string = """          ),
        ],
      ),
    );
  }"""

content = content.replace(bad_string, good_string)

# But wait, we DO want the one at the end of _buildPromoSection to be the bad_string?
# No! If we removed `IntrinsicHeight`, the original was:
# return IntrinsicHeight(child: Row(children: [..., ...],),);
# So removing `IntrinsicHeight` means it becomes:
# return Row(children: [..., ...],);
# Which is:
# return Row(
#   children: [
#     ...,
#     ...,
#   ],
# );
# So it still ends with `);`!
# Let's see:
# return IntrinsicHeight(
#   child: Row(
#     children: [
#       Expanded(...),
#       SizedBox(...),
#       Expanded(...),
#     ],
#   ),
# );
# If we remove IntrinsicHeight, we remove `IntrinsicHeight(` and `child: `, and the final `),`.
# So the end becomes:
#     ],
#   );
# }

# So my replacement for _buildPromoSection was correct, but it applied to EVERY Widget building method that returns a widget ending in `],),);`.
# Let's fix them all back to `],),);}`
content = content.replace(good_string, good_string) # Actually they are currently `bad_string`
content = content.replace(bad_string, good_string)

with open(file_path, 'w') as f:
    f.write(content)
print("restored parens")
