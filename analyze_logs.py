log_file = r'c:\Users\dawse\Desktop\pfa\logcat_live.txt'
print(f"Analyzing {log_file}...")

try:
    with open(log_file, 'r', encoding='utf-16') as f:
        lines = f.readlines()
except UnicodeError:
    try:
        with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading file: {e}")
        lines = []

with open(r'c:\Users\dawse\Desktop\pfa\analysis_live_utf8.txt', 'w', encoding='utf-8') as out_f:
    for line in lines:
        out_f.write(line)
