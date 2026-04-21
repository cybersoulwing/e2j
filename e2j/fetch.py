import requests
import csv
import os
import io

URL = "https://docs.google.com/spreadsheets/d/XXXXXXXXXX/export?format=csv&gid=0"


def fetch_sheet():
    r = requests.get(URL, timeout=10)
    r.raise_for_status()
    r.encoding = "utf-8"
    return r.text


def parse_csv(csv_text):
    f = io.StringIO(csv_text)
    reader = csv.reader(f)

    pairs = []

    for row in reader:
        if len(row) < 2:
            continue

        eng = row[0].strip()
        jpn = row[1].strip()

        if eng and jpn:
            pairs.append((eng, jpn))

    return pairs


def lua_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def write_lua(pairs):
    base = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(base, "dict.lua")

    with open(out, "w", encoding="utf-8") as f:
        f.write("return {\n")

        for eng, jpn in pairs:
            eng = lua_escape(eng)
            jpn = lua_escape(jpn)
            f.write(f'    ["{eng}"] = "{jpn}",\n')

        f.write("}\n")


def main():
    try:
        print("[E2J] fetching...")
        csv_text = fetch_sheet()

        print("[E2J] parsing...")
        pairs = parse_csv(csv_text)

        print("[E2J] entries:", len(pairs))

        print("[E2J] writing lua...")
        write_lua(pairs)

        print("[E2J] done")

    except Exception as e:
        print("[E2J ERROR]", e)


if __name__ == "__main__":
    main()
