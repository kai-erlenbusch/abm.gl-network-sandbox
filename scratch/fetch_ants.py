import urllib.request
import json
import base64

url = "https://api.github.com/repos/NetLogo/models/git/trees/main?recursive=1"
try:
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        for file in data.get('tree', []):
            if 'Ants.nlogo' in file.get('path', ''):
                print(f"Found: {file['path']}")
                raw_url = f"https://raw.githubusercontent.com/NetLogo/models/main/{urllib.parse.quote(file['path'])}"
                print(f"URL: {raw_url}")
                try:
                    req_raw = urllib.request.Request(raw_url, headers={'User-Agent': 'Mozilla/5.0'})
                    with urllib.request.urlopen(req_raw) as res_raw:
                        code = res_raw.read().decode()
                        with open("ants_code.txt", "w") as f:
                            f.write(code)
                        print("Saved to ants_code.txt")
                except Exception as e:
                    print(f"Error fetching code: {e}")
                break
except Exception as e:
    print(f"Error fetching tree: {e}")
