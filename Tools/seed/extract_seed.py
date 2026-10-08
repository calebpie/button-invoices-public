"""Builds the app's starting catalog from an invoice workbook's Reference sheet.

Writes, into --out (default App/Resources/Seed):
  catalog.json   every button: description parts, SKU, price, photo file name
  Photos/*.png   one photo per button; the high-resolution edited PNG where one exists in
                 --photos, otherwise the small copy embedded in the workbook
  business.json  seller, bill-to, routing and account from the Invoice sheet (gitignored:
                 it holds bank details)

Standard library only. Usage (from the repo root; `make seed` runs this):
  python3 Tools/seed/extract_seed.py [--xlsx <workbook>] [--photos <dir>] [--out <dir>]
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path, PurePosixPath

M = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
SIZES = {"Mini", "Small", "Medium", "Large", "Extra Large"}
EXAMPLES = Path("Examples")
DEFAULT_XLSX = EXAMPLES / "Invoice Excel and Output PDFs" / "Daphné Verley Invoice - AOB 0260903.xlsx"
DEFAULT_PHOTOS = EXAMPLES / "Images" / "Edited"


class Workbook:
    def __init__(self, path):
        self.zip = zipfile.ZipFile(path)
        self.strings = []
        if "xl/sharedStrings.xml" in self.zip.namelist():
            for si in self.xml("xl/sharedStrings.xml").findall(M + "si"):
                self.strings.append("".join(t.text or "" for t in si.iter(M + "t")))
        rels = self.rels("xl/workbook.xml")
        self.sheets = {s.get("name"): "xl/" + rels[s.get(R + "id")]
                       for s in self.xml("xl/workbook.xml").find(M + "sheets")}
        self.cell_images = self.load_cell_images()

    def xml(self, name):
        return ET.fromstring(self.zip.read(name))

    def rels(self, part):
        p = PurePosixPath(part)
        name = str(p.parent / "_rels" / (p.name + ".rels"))
        return {r.get("Id"): r.get("Target") for r in self.xml(name)}

    def load_cell_images(self):
        """Pictures placed in cells (Excel's IMAGE-in-cell): cell vm index → media path."""
        try:
            md = self.xml("xl/metadata.xml")
            rv = [[v.text for v in r] for r in self.xml("xl/richData/rdrichvalue.xml")]
            rel_ids = [r.get(R + "id") for r in self.xml("xl/richData/richValueRel.xml")]
            targets = self.rels("xl/richData/richValueRel.xml")
        except KeyError:
            return {}
        future = [next(e for e in bk.iter() if e.tag.endswith("rvb")).get("i")
                  for bk in md.find(M + "futureMetadata").findall(M + "bk")]
        values = [bk.find(M + "rc").get("v") for bk in md.find(M + "valueMetadata").findall(M + "bk")]
        images = {}
        for i, v in enumerate(values, 1):
            rel = rel_ids[int(rv[int(future[int(v)])][0])]
            images[str(i)] = str(PurePosixPath("xl/richData") / targets[rel])
        return {k: str(PurePosixPath(p).as_posix()).replace("xl/richData/../", "xl/") for k, p in images.items()}

    def cells(self, sheet):
        """{"A1": (value, image path or None)}"""
        out = {}
        for c in self.xml(self.sheets[sheet]).iter(M + "c"):
            v = c.find(M + "v")
            value = v.text if v is not None else None
            if c.get("t") == "s" and value is not None:
                value = self.strings[int(value)]
            out[c.get("r")] = (value, self.cell_images.get(c.get("vm")))
        return out


def split_description(text):
    parts = [p.strip() for p in text.split(",")]
    design, rest, size = parts[0], parts[1:], ""
    if rest and (len(rest) >= 2 or rest[-1] in SIZES):
        size = rest.pop()
    colors = [c.strip() for part in rest for c in part.split("/") if c.strip()]
    return design, colors, size


def loose(word):
    """Spelling-tolerant key: "Pineapple" and "Pineaple" both → "pineaple"."""
    return re.sub(r"(.)\1", r"\1", re.sub(r"[^a-z]", "", word.lower()))


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--xlsx", type=Path, default=DEFAULT_XLSX)
    ap.add_argument("--photos", type=Path, default=DEFAULT_PHOTOS)
    ap.add_argument("--out", type=Path, default=Path("App/Resources/Seed"))
    args = ap.parse_args()
    if not args.xlsx.exists():
        sys.exit(f"Workbook not found: {args.xlsx}")

    wb = Workbook(args.xlsx)
    ref = wb.cells("Reference")
    photos_dir = args.out / "Photos"
    if photos_dir.exists():
        shutil.rmtree(photos_dir)
    photos_dir.mkdir(parents=True)

    variants = []
    row = 1
    while f"A{row}" in ref and ref[f"A{row}"][0]:
        name = ref[f"A{row}"][0].strip()
        sku = (ref.get(f"B{row}", (None, None))[0] or "").strip()
        price = ref.get(f"D{row}", (None, None))[0]
        image = ref.get(f"C{row}", (None, None))[1]
        design, colors, size = split_description(name)
        photo = None
        if image:
            photo = slug(name) + ".png"
            (photos_dir / photo).write_bytes(wb.zip.read(image))
        variants.append({
            "design": design, "colors": colors, "size": size, "sku": sku,
            "priceCents": round(float(price) * 100) if price else None,
            "photo": photo,
        })
        row += 1

    # Higher-resolution edited photos, named like "Rose, White : Blue.png", replace the
    # thumbnails embedded in the workbook. Matched on design and first color.
    if args.photos.is_dir():
        for png in sorted(args.photos.glob("*.png")):
            design, colors, _ = split_description(png.stem.replace(":", "/"))
            matches = [v for v in variants if loose(v["design"]) == loose(design)
                       and v["colors"][:1] and colors[:1] and loose(v["colors"][0]) == loose(colors[0])]
            if len(matches) != 1:
                print(f"  edited photo not matched to one button: {png.name} ({len(matches)} matches)")
                continue
            v = matches[0]
            v["photo"] = v["photo"] or slug(v["design"] + " " + " ".join(v["colors"])) + ".png"
            subprocess.run(["sips", "-Z", "800", str(png), "--out", str(photos_dir / v["photo"])],
                           check=True, capture_output=True)
            print(f"  {png.name} → {v['sku']} ({v['design']}, {' / '.join(v['colors'])})")

    catalog = {"source": args.xlsx.name, "variants": variants}
    (args.out / "catalog.json").write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")

    inv = wb.cells("Invoice")
    def text(ref_):
        return (inv.get(ref_, (None, None))[0] or "").strip()
    def beside(label):
        for r, (v, _) in inv.items():
            if v == label:
                row_ = re.sub(r"[A-Z]+", "", r)
                return text("D" + row_)
        return ""
    business = {
        "sellerName": text("A4"),
        "sellerLines": [text(f"A{r}") for r in (5, 6, 7) if text(f"A{r}")],
        "billToName": text("A10"),
        "billToLines": [text(f"A{r}") for r in (11, 12, 13) if text(f"A{r}")],
        "routing": beside("Routing:"),
        "account": beside("Account:"),
    }
    (args.out / "business.json").write_text(json.dumps(business, indent=2, ensure_ascii=False) + "\n")

    priced = sum(1 for v in variants if v["priceCents"])
    print(f"{len(variants)} buttons ({priced} with prices) from {args.xlsx.name} → {args.out}")
    skus = [v["sku"] for v in variants]
    for s in sorted({s for s in skus if skus.count(s) > 1}):
        names = [", ".join([v["design"], " / ".join(v["colors"])]) for v in variants if v["sku"] == s]
        print(f"  note: SKU {s} is used by {' and '.join(names)}")


if __name__ == "__main__":
    main()
