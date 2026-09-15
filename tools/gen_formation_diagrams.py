#!/usr/bin/env python3
"""Generate formation slot diagram SVGs from layout .tscn files."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAYOUTS = ROOT / "formations" / "layouts"
OUT = ROOT / "docs" / "design" / "formations" / "sprites"

MAPPING = {
	"horizontal_formation.tscn": ("layout_horizontal", "Horizontal"),
	"diamond_formation.tscn": ("layout_diamond5", "Diamond5"),
	"diamond_formation_13.tscn": ("layout_diamond13", "Diamond13"),
	"v3_formation.tscn": ("layout_v3", "V3"),
	"v5_formation.tscn": ("layout_v5", "V5"),
	"v7_formation.tscn": ("layout_v7", "V7"),
	"v9_formation.tscn": ("layout_v9", "V9"),
	"inverted_v3_formation.tscn": ("layout_inverted_v3", "Inverted V3"),
	"inverted_v5_formation.tscn": ("layout_inverted_v5", "Inverted V5"),
	"inverted_v7_formation.tscn": ("layout_inverted_v7", "Inverted V7"),
	"x5_formation.tscn": ("layout_x5", "X5"),
	"x9_formation.tscn": ("layout_x9", "X9"),
	"triangle6_formation.tscn": ("layout_triangle6", "Triangle6"),
	"interceptor_pair_formation.tscn": ("layout_interceptor_pair", "Interceptor Pair"),
	"single_formation.tscn": ("layout_single", "Single"),
	"vertical_formation.tscn": ("layout_vertical", "Vertical"),
}


def parse_slots(path: Path) -> list[dict]:
	text = path.read_text(encoding="utf-8")
	slots: list[dict] = []
	pattern = re.compile(
		r'\[node name="([^"]+)" type="Marker2D"[^\]]*\](.*?)(?=\[node |\Z)',
		re.S,
	)
	for match in pattern.finditer(text):
		body = match.group(2)
		pos = re.search(r"position = Vector2\(([-\d.]+), ([-\d.]+)\)", body)
		x, y = (float(pos.group(1)), float(pos.group(2))) if pos else (0.0, 0.0)
		sid = re.search(r'slot_id = &"([^"]+)"', body)
		idx = re.search(r"slot_index = (\d+)", body)
		slots.append(
			{
				"name": match.group(1),
				"id": sid.group(1) if sid else match.group(1),
				"i": int(idx.group(1)) if idx else len(slots),
				"x": x,
				"y": y,
			}
		)
	slots.sort(key=lambda item: item["i"])
	return slots


def write_svg(stem: str, title: str, slots: list[dict]) -> None:
	xs = [slot["x"] for slot in slots]
	ys = [slot["y"] for slot in slots]
	pad = 28.0
	min_x, max_x = min(xs) - pad, max(xs) + pad
	min_y, max_y = min(ys) - pad, max(ys) + pad
	scale = 2.2
	width = (max_x - min_x) * scale
	height = (max_y - min_y) * scale

	def tx(x: float) -> float:
		return (x - min_x) * scale

	def ty(y: float) -> float:
		return (y - min_y) * scale

	parts: list[str] = []
	ox, oy = tx(0.0), ty(0.0)
	parts.append(
		f'<line x1="{ox:.1f}" y1="0" x2="{ox:.1f}" y2="{height:.1f}" '
		f'stroke="#1a3a55" stroke-width="1" stroke-dasharray="3 3"/>'
	)
	parts.append(
		f'<line x1="0" y1="{oy:.1f}" x2="{width:.1f}" y2="{oy:.1f}" '
		f'stroke="#1a3a55" stroke-width="1" stroke-dasharray="3 3"/>'
	)
	for slot in slots:
		cx, cy = tx(slot["x"]), ty(slot["y"])
		parts.append(
			f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="7" fill="#ff4d8d" '
			f'stroke="#ffb3d0" stroke-width="1.5"/>'
		)
		parts.append(
			f'<text x="{cx:.1f}" y="{cy + 3.5:.1f}" text-anchor="middle" '
			f'font-family="ui-monospace,Consolas,monospace" font-size="9" '
			f'fill="#1a0510">{slot["i"]}</text>'
		)

	svg = (
		f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width:.1f} {height:.1f}" '
		f'role="img" aria-label="{title}">\n'
		f'  <rect width="100%" height="100%" fill="#050b14"/>\n'
		f'  {"".join(parts)}\n'
		f"</svg>\n"
	)
	(OUT / f"{stem}.svg").write_text(svg, encoding="utf-8")
	print(f"{stem}: {len(slots)} slots")


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	for filename, (stem, title) in MAPPING.items():
		slots = parse_slots(LAYOUTS / filename)
		if not slots:
			raise SystemExit(f"no slots in {filename}")
		write_svg(stem, title, slots)


if __name__ == "__main__":
	main()
