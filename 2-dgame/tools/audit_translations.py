# -*- coding: utf-8 -*-
"""Yerelleştirme denetimi (Story 2D-119).

Scriptlerde oyuncuya gösterilen sabit metinleri ve tr("ANAHTAR") çağrılarını tarar;
data/translations/translations.json içinde karşılığı olmayanları raporlar.
Ayrıca JSON ile CSV'nin aynı anahtarları içerdiğini doğrular.

Çalıştırma (2-dgame klasöründen):  python tools/audit_translations.py
Çıkış kodu: 0 = eksik yok, 1 = eksik var.
"""
import csv
import glob
import io
import json
import re
import sys

JSON_PATH = "data/translations/translations.json"
CSV_PATH = "data/translations/translations.csv"

STRING = r'"((?:[^"\\]|\\.)*)"'
HAS_WORD = re.compile(r"[A-Za-zçğıöşüÇĞİÖŞÜ]{3}")
KEY_ONLY = re.compile(r"[A-Z0-9_]+")
# Oyuncuya gösterilmeyen sabitler (düğüm adı, sinyal, yol vb.)
IGNORE = re.compile(r"^(res://|user://|/root/|%|\[ FAZ)|^[a-z0-9_./%:]+$")


def unescape(text):
    return text.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def collect_literals(source):
    """(tür, metin) çiftleri: HUD ipuçları, etiket metinleri ve tr() anahtarları."""
    found = []
    for match in re.finditer(r"set_tutorial\((.*?)\)\s*\n", source, flags=re.S):
        for literal in re.findall(STRING, match.group(1)):
            found.append(("hud", unescape(literal)))
    for match in re.finditer(r"\.text\s*=\s*" + STRING, source):
        found.append(("label", unescape(match.group(1))))
    for match in re.finditer(r"\btr\(" + STRING + r"\)", source):
        found.append(("tr", unescape(match.group(1))))
    return found


def main():
    out = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    with io.open(JSON_PATH, encoding="utf-8") as handle:
        table = json.load(handle)

    problems = 0
    incomplete = [k for k, v in table.items() if not isinstance(v, dict) or not v.get("tr") or not v.get("en")]
    if incomplete:
        problems += len(incomplete)
        out.write("JSON'da tr/en alanı eksik anahtarlar: %d\n" % len(incomplete))
        for key in incomplete:
            out.write("    %s\n" % key[:100])

    with io.open(CSV_PATH, encoding="utf-8", newline="") as handle:
        csv_keys = {row[0] for row in csv.reader(handle) if row}
    csv_keys.discard("id")
    csv_keys.discard("keys")
    only_json = sorted(set(table) - csv_keys)
    if only_json:
        problems += len(only_json)
        out.write("JSON'da olup CSV'de olmayan anahtarlar: %d\n" % len(only_json))
        for key in only_json:
            out.write("    %s\n" % key[:100])

    missing = {}
    for path in sorted(glob.glob("scripts/**/*.gd", recursive=True)):
        with io.open(path, encoding="utf-8") as handle:
            source = handle.read()
        for kind, literal in collect_literals(source):
            if not literal or literal in table:
                continue
            if kind != "tr":
                if not HAS_WORD.search(literal) or KEY_ONLY.fullmatch(literal) or IGNORE.search(literal):
                    continue
            missing.setdefault(path.replace("\\", "/"), {})[literal] = kind

    for path, literals in missing.items():
        out.write("## %s\n" % path)
        for literal, kind in literals.items():
            problems += 1
            out.write("    [%s] %s\n" % (kind, literal[:120].replace("\n", " / ")))

    out.write("TOPLAM EKSİK: %d (çeviri tablosu: %d anahtar)\n" % (problems, len(table)))
    out.flush()
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
