"""把 design/sheets 里的 Excel XML（.xls）展开合并单元格，导出为 JSON。

用法（在 code 目录下）：
    python tools/import_sheets.py

你继续用「序号 / 模块 / 内容 / 详细 / 备注」写表。
游戏真正读的数值在 content/balance.json，这个脚本只同步设计大纲。
"""

from __future__ import annotations

import json
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {"ss": "urn:schemas-microsoft-com:office:spreadsheet"}
ROOT = Path(__file__).resolve().parents[1]
SHEETS_DIR = ROOT / "design" / "sheets"
OUT_PATH = ROOT / "content" / "design_notes.json"


def cell_text(cell: ET.Element) -> str:
    data = cell.find("ss:Data", NS)
    if data is None or data.text is None:
        return ""
    return data.text.replace("\r\n", "\n").strip()


def parse_sheet(path: Path) -> list[dict]:
    tree = ET.parse(path)
    table = tree.find(".//ss:Worksheet/ss:Table", NS)
    if table is None:
        return []

    grid: list[list[str]] = []
    pending: dict[int, tuple[str, int]] = {}

    for row_el in table.findall("ss:Row", NS):
        row: list[str] = []
        new_merges: dict[int, tuple[str, int]] = {}
        col = 0
        for cell in row_el.findall("ss:Cell", NS):
            index = cell.get("{urn:schemas-microsoft-com:office:spreadsheet}Index")
            if index:
                col = int(index) - 1
            while len(row) < col:
                row.append("")
            text = cell_text(cell)
            merge_down = int(
                cell.get("{urn:schemas-microsoft-com:office:spreadsheet}MergeDown") or 0
            )
            while len(row) <= col:
                row.append("")
            row[col] = text
            if merge_down > 0:
                new_merges[col] = (text, merge_down)
            col += 1

        for c, (text, left) in pending.items():
            while len(row) <= c:
                row.append("")
            if not row[c]:
                row[c] = text

        next_pending: dict[int, tuple[str, int]] = {}
        for c, (text, left) in pending.items():
            if left > 1:
                next_pending[c] = (text, left - 1)
        next_pending.update(new_merges)
        pending = next_pending
        grid.append(row)

    if not grid:
        return []

    headers = [h.strip() or f"col_{i}" for i, h in enumerate(grid[0])]
    notes: list[dict] = []
    for raw in grid[1:]:
        item = {}
        empty = True
        for i, key in enumerate(headers):
            value = raw[i].strip() if i < len(raw) else ""
            item[key] = value
            if value:
                empty = False
        if not empty:
            notes.append(item)
    return notes


def main() -> None:
    workbook = {}
    for path in sorted(SHEETS_DIR.glob("*.xls")):
        workbook[path.stem] = parse_sheet(path)
    OUT_PATH.write_text(
        json.dumps(workbook, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
