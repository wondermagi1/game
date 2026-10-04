"""Remove neighboring-cell fragments from generated 6x4 action atlases.

The generator can paint a long weapon a few pixels into the adjacent cell. Each
cell should contain one connected character-and-weapon silhouette, so retaining
its largest alpha component removes that bleed without repainting the asset.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image


CELL = 256
COLS = 6
ROWS = 4
ALPHA_THRESHOLD = 2
FOOT_LINE = 252


def largest_component(alpha: Image.Image) -> tuple[set[int], int, int]:
    width, height = alpha.size
    pixels = alpha.tobytes()
    visited = bytearray(width * height)
    biggest: list[int] = []
    opaque_total = 0

    for start, value in enumerate(pixels):
        if value <= ALPHA_THRESHOLD:
            visited[start] = 1
            continue
        opaque_total += 1

    for start, value in enumerate(pixels):
        if visited[start] or value <= ALPHA_THRESHOLD:
            continue
        visited[start] = 1
        queue: deque[int] = deque([start])
        component: list[int] = []
        while queue:
            index = queue.popleft()
            component.append(index)
            x = index % width
            y = index // width
            for ny in range(max(0, y - 1), min(height, y + 2)):
                row = ny * width
                for nx in range(max(0, x - 1), min(width, x + 2)):
                    neighbor = row + nx
                    if not visited[neighbor] and pixels[neighbor] > ALPHA_THRESHOLD:
                        visited[neighbor] = 1
                        queue.append(neighbor)
        if len(component) > len(biggest):
            biggest = component
    return set(biggest), opaque_total, len(biggest)


def sanitize(path: Path) -> None:
    image = Image.open(path).convert("RGBA")
    if image.size != (CELL * COLS, CELL * ROWS):
        raise ValueError(f"{path}: expected 1536x1024, got {image.size}")
    result = Image.new("RGBA", image.size)
    removed = 0
    for row in range(ROWS):
        for column in range(COLS):
            box = (column * CELL, row * CELL, (column + 1) * CELL, (row + 1) * CELL)
            cell = image.crop(box)
            keep, opaque_total, kept = largest_component(cell.getchannel("A"))
            removed += opaque_total - kept
            data = list(cell.get_flattened_data())
            clean = [pixel if index in keep else (0, 0, 0, 0) for index, pixel in enumerate(data)]
            cell.putdata(clean)
            bounds = cell.getchannel("A").getbbox()
            if bounds is not None and bounds[3] != FOOT_LINE:
                aligned = Image.new("RGBA", cell.size)
                aligned.paste(cell, (0, FOOT_LINE - bounds[3]))
                cell = aligned
            result.paste(cell, box)
    result.save(path, optimize=True)
    print(f"{path.name}: removed {removed} stray alpha pixels")


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    for atlas in sorted((root / "art" / "v9").glob("*-attack-keyframes-source.png")):
        sanitize(atlas)
