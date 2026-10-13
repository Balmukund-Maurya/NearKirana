import re

file_path = 'lib/main.dart'

with open(file_path, 'r') as f:
    content = f.read()

content = re.sub(r'\.withOpacity\((.*?)\)', r'.withValues(alpha: \1)', content)

with open(file_path, 'w') as f:
    f.write(content)
print("done")
