"""Builds the app's starting catalog from an invoice workbook's Reference sheet.

Writes, into --out (default App/Resources/Seed):
  catalog.json   every button: description parts, SKU, price, photo file name; the
                 Reference sheet's buttons, then EXTRA_BUTTONS
  Photos/*.png   one photo per button, at most 600 px; the edited PNG from --photos where
                 there is one, otherwise the small copy embedded in the workbook
  business.json  seller, bill-to, routing and account from the Invoice sheet (gitignored:
                 it holds bank details)
  invoices.json  every invoice workbook in the same folder as --xlsx ("… Invoice - AOB
                 <number>.xlsx"), as sent: number, date, lines, shipping, printed total.
                 Loaded as paid invoices on first launch (gitignored: real sales)

Standard library only. Usage (from the repo root; `make seed` runs this):
  python3 Tools/seed/extract_seed.py [--xlsx <workbook>] [--photos <dir>] [--out <dir>]
"""

import argparse
import datetime
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


# Typos in the workbook, corrected on the way into the app (SPEC.md, "Data"). Keys are
# the workbook's text.
NAME_FIXES = {
    "Pineaple": "Pineapple",
    "Celedon": "Celadon",
    "Elipse": "Ellipse",
}
# Whole descriptions: the ladybug is red and white (edited photo "Ladybug, Red : White",
# SKU 26LRW).
DESCRIPTION_FIXES = {
    "Ladybug, Red": "Ladybug, Red / White",
}
# SKUs that contradict the SKU rules and aren't on any example invoice: the crab had the
# clover's SKU (two buttons can't share one), and the yellow shell had W for yellow.
SKU_FIXES = {
    ("Crab, Blue", "26CBLW"): "26CBL",
    ("Shell, Yellow", "26SW"): "26SY",
}
ADDRESS_FIXES = {"Suit 100": "Suite 100"}

# Longest side of the bundled photos. The app shows them at up to 450 px and the PDF at 300.
PHOTO_SIZE = 600

# Buttons she makes that aren't on the Reference sheet (Caleb, Oct 8, 2026). Each takes its
# size and price from the button named in "like", and is listed right after it.
EXTRA_BUTTONS = [
    {"design": "Crab", "colors": ["Red"], "sku": "26CR", "like": "26CBL"},
]

# Edited photo file name (without .png) → the SKUs it shows. Two buttons share a photo in
# the workbook: Nautilus Brown / Brown Large, and Matte White / Unglazed.
EDITED_PHOTOS = {
    "Bunny, Black : White": ["26BBW"],
    "Cowrie Shell, Black": ["26CSB"],
    "Cowrie Shell, Pale Pink": ["26CSPP"],
    "Crab, Blue": ["26CBL"],
    "Crab, Red": ["26CR"],  # cut out with the app's cutout from her photo IMG_4709
    "Daisy, Black : White, Large": ["26DBWL"],
    "Daisy, Black : White, Small": ["26DBWS"],
    "Daisy, Red : White, Large": ["26DRWS"],  # invoiced as Small
    "Dogwood Flower, Celedon": ["26DC"],
    "Dogwood Flower, Ivory": ["26DI"],
    "Elipse, Lilac": ["26ELM"],  # invoiced as Ellipse, Lavender, Mini
    "Flower Burst, Burgundy : White, Medium": ["26FBBW"],
    "Flower, Bue : White, Large": ["26CBLW"],  # invoiced as Clover, Blue / White
    "Heart, Burgundy, Medium": ["26HBM"],
    "Heart, Navy": ["26HNM"],
    "Heart, Red": ["26HRM"],
    "Ladybug, Red : White": ["26LRW"],
    "Lips, Red": ["26LR"],
    "Mushroom, Blue : White": ["26MBLW"],
    "Mushroom, Burgundy : White": ["26MBW"],
    "Mushroom, Navy : White": ["26MNW"],
    "Mushroom, Red : White": ["26MRW"],
    "Natuilus, Green": ["26NG"],
    "Nautilus, Black": ["26NB"],
    "Nautilus, Brown": ["26NBR", "26NBRL"],
    "Nautilus, Cotton Tail": ["26NW"],  # invoiced as Nautilus, White
    "Nautilus, Matte Pink": ["26NMP"],
    "Nautilus, Matte White": ["26NMW", "26NUG"],
    "Nautilus, Pale Pink": ["26NPP"],
    "Pineapple, Yellow : Brown": ["26PYB"],
    "Rose, White : Blue": ["26RWG"],
    "Sailboat, Black : White": ["26SBW"],
    "Shell, Yellow": ["26SY"],
    "Star, Burgundy, Mini": ["26SBS"],  # invoiced as Small
    "Star, Navy, Mini": ["26SNM"],
    "Strawberry, Red : Green": ["26SRG"],
}


def fix_name(text):
    text = DESCRIPTION_FIXES.get(text, text)
    for wrong, right in NAME_FIXES.items():
        text = re.sub(rf"\b{wrong}\b", right, text)
    return text


def fix_address(text):
    for wrong, right in ADDRESS_FIXES.items():
        text = text.replace(wrong, right)
    return text


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


def cents(text):
    return round(float(text) * 100) if text not in (None, "") else 0


def extract_invoices(folder):
    """The sent invoices, from the cached values Excel saved in each workbook."""
    invoices = []
    # Glob without the "é": macOS file names may store it decomposed.
    for path in sorted(folder.glob("*Invoice - AOB *.xlsx")):
        cells = Workbook(path).cells("Invoice")
        value = lambda ref: (cells.get(ref, (None, None))[0] or "").strip()
        serial = value("H8")  # =TODAY(), as last calculated: the date printed on the PDF
        date = datetime.date(1899, 12, 30) + datetime.timedelta(days=int(float(serial)))
        lines = []
        for row in range(16, 400, 5):  # one 5-row block per button
            description = value(f"C{row + 2}")
            if not description:
                continue
            lines.append({
                "sku": value(f"A{row}"), "description": description,
                "quantity": int(float(value(f"F{row}"))),
                "unitPriceCents": cents(value(f"G{row}")), "discountCents": cents(value(f"H{row}")),
            })
        rows = sorted(cells.items(), key=lambda kv: (int(re.sub(r"[A-Z]+", "", kv[0])), kv[0]))
        shipping = [cents(value("I" + re.sub(r"[A-Z]+", "", ref))) for ref, (v, _) in rows if v == "SHIPPING:"]
        total = next(cents(value("I" + re.sub(r"[A-Z]+", "", ref))) for ref, (v, _) in rows if v == "TOTAL:")
        computed = sum((l["unitPriceCents"] - l["discountCents"]) * l["quantity"] for l in lines) + sum(shipping)
        if computed != total:
            sys.exit(f"{path.name}: lines and shipping add up to {computed} cents, the invoice says {total}")
        invoices.append({
            "number": value("F8"), "date": date.isoformat(), "lines": lines,
            "shippingCents": [c for c in shipping if c], "printedTotalCents": total, "source": path.name,
        })
    return invoices


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
        original = ref[f"A{row}"][0].strip()
        name = fix_name(original)
        sku = (ref.get(f"B{row}", (None, None))[0] or "").strip()
        sku = SKU_FIXES.get((original, sku), sku)
        if name != original or sku != (ref.get(f"B{row}", (None, None))[0] or "").strip():
            print(f"  corrected: {original} {ref[f'B{row}'][0]} → {name} {sku}")
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

    for extra in EXTRA_BUTTONS:
        i = next(i for i, v in enumerate(variants) if v["sku"] == extra["like"])
        like = variants[i]
        variants.insert(i + 1, {
            "design": extra["design"], "colors": extra["colors"], "size": like["size"], "sku": extra["sku"],
            "priceCents": like["priceCents"], "photo": None,
        })
        print(f"  added, not on the Reference sheet: {extra['design']}, {' / '.join(extra['colors'])} {extra['sku']}")

    # Caleb's edited photos replace the small copies embedded in the workbook. Their file
    # names don't always match the invoice names, so known files are mapped to SKUs
    # explicitly (each pair checked by eye against the workbook thumbnail, Oct 8, 2026);
    # other files are matched on design and first color.
    by_sku = {v["sku"]: v for v in variants}
    used = set()
    if args.photos.is_dir():
        for png in sorted(args.photos.glob("*.png")):
            skus = EDITED_PHOTOS.get(png.stem)
            if skus is None:
                design, colors, _ = split_description(png.stem.replace(":", "/"))
                matches = [v["sku"] for v in variants if loose(v["design"]) == loose(design)
                           and v["colors"][:1] and colors[:1] and loose(v["colors"][0]) == loose(colors[0])]
                if len(matches) != 1:
                    print(f"  edited photo not matched to one button: {png.name} ({len(matches)} matches)")
                    continue
                skus = matches
            for sku in skus:
                v = by_sku.get(sku)
                if v is None:
                    print(f"  edited photo {png.name}: no button with SKU {sku}")
                    continue
                v["photo"] = v["photo"] or slug(v["design"] + " " + " ".join(v["colors"]) + " " + v["size"]) + ".png"
                subprocess.run(["sips", "-Z", str(PHOTO_SIZE), str(png), "--out", str(photos_dir / v["photo"])],
                               check=True, capture_output=True)
                used.add(sku)
        print(f"  {len(used)} of {len(variants)} buttons have an edited photo")
        for v in variants:
            if v["sku"] not in used:
                print(f"  still the workbook's small photo: {v['sku']} {v['design']}, {' / '.join(v['colors'])}")

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
        "sellerLines": [fix_address(text(f"A{r}")) for r in (5, 6, 7) if text(f"A{r}")],
        "billToName": text("A10"),
        "billToLines": [text(f"A{r}") for r in (11, 12, 13) if text(f"A{r}")],
        "routing": beside("Routing:"),
        "account": beside("Account:"),
    }
    (args.out / "business.json").write_text(json.dumps(business, indent=2, ensure_ascii=False) + "\n")

    invoices = extract_invoices(args.xlsx.parent)
    (args.out / "invoices.json").write_text(json.dumps({"invoices": invoices}, indent=2, ensure_ascii=False) + "\n")
    print(f"{len(invoices)} sent invoices: " + ", ".join(f"{i['number']} ${i['printedTotalCents'] / 100:,.2f}" for i in invoices))
    unknown = sorted({l["sku"] for i in invoices for l in i["lines"]} - {v["sku"] for v in variants})
    if unknown:
        print(f"  note: invoiced SKUs not in the catalog: {', '.join(unknown)}")

    priced = sum(1 for v in variants if v["priceCents"])
    print(f"{len(variants)} buttons ({priced} with prices) from {args.xlsx.name} → {args.out}")
    skus = [v["sku"] for v in variants]
    for s in sorted({s for s in skus if skus.count(s) > 1}):
        names = [", ".join([v["design"], " / ".join(v["colors"])]) for v in variants if v["sku"] == s]
        print(f"  note: SKU {s} is used by {' and '.join(names)}")


if __name__ == "__main__":
    main()
