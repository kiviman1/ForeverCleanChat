#!/usr/bin/env python3
"""Draw a design preview from the actual addon Lua frame tree.

Production Lua creates and refreshes the controls in tests/harness_ui.lua. This
tool consumes those frames' anchors, text, colors, fonts, and local TGA assets.
Pillow draws the result; this is not a screenshot from WoW and does not establish
native renderer/client compatibility. Blizzard font/tooltip/circle resources are
approximated locally, with substitutions recorded in the JSON snapshot.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re

from PIL import Image, ImageDraw, ImageFont
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent


def plain(value):
    if hasattr(value, "items"):
        items = dict(value.items())
        if items and set(items) == set(range(1, len(items) + 1)):
            return [plain(items[i]) for i in range(1, len(items) + 1)]
        return {str(key): plain(item) for key, item in items.items()}
    return value


def snapshot(tab: str, count: int, paused: bool, mode: str, sample: str | None = None):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().arg = lua.table_from({1: ROOT.as_posix()})
    harness = lua.execute((ROOT / "tests/harness_ui.lua").read_text(encoding="utf-8"))
    env, ns = harness.uiGame("modern")
    env.boot(env)
    for index in range(count):
        assert env.chat(env, "mythicstore.com", f"Example Seller {index + 1}-Realm", 20000 + index)
    ns.Settings.SetMode(mode)
    ns.Settings.SetEnabled(not paused)
    if not ns.UI.Show(tab):
        raise RuntimeError(ns.UI.lastError or "Production panel failed to open")
    if tab == "test":
        sample = sample or "mythicstore.com\nWTS Copper Bar 2g per stack\nLFM WC need healer"
        box = ns.UI.controls.testInput
        box.SetText(box, sample)
        ns.UI.RunLocalTest()
        box.SetCursorPosition(box, 0)
    frame = ns.UI.frame
    return {
        "source": "Actual production Lua frame tree on stateful native-frame doubles",
        "limitations": ["Not a WoW screenshot", "Local serif font substitutes for Blizzard Friz Quadrata",
                        "Tooltip borders and portrait-mask circles approximated by Pillow"],
        "tab": tab, "mode": mode, "enabled": not paused, "hidden_this_session": count,
        "width": frame.GetWidth(frame), "height": frame.GetHeight(frame),
        "production_scale": frame.GetScale(frame),
        "regions": plain(env.snapshot(env, frame)),
    }


def rgba(values, alpha=1.0, default=(1, 1, 1, 1)):
    values = values or default
    if isinstance(values, dict):
        values = [values[str(index)] for index in range(1, len(values) + 1)]
    values = list(values)
    values += [1] * (4 - len(values))
    return tuple(round(max(0, min(1, value)) * 255) for value in values[:3]) + (round(values[3] * alpha * 255),)


def font(pixels: float, native: str | None, scale: float):
    serif = native and ("FRIZ" in native.upper() or "MORPHEUS" in native.upper())
    choices = ["georgia.ttf", "cambria.ttc", "times.ttf"] if serif else ["arial.ttf", "segoeui.ttf"]
    for filename in choices:
        path = Path("C:/Windows/Fonts") / filename
        if path.exists():
            return ImageFont.truetype(str(path), max(1, round(pixels * scale)))
    return ImageFont.load_default(size=max(1, round(pixels * scale)))


def wrap(draw, text, face, width, should_wrap):
    lines = []
    for paragraph in text.split("\n"):
        if not should_wrap:
            lines.append(paragraph)
            continue
        words = paragraph.split(" ")
        line = ""
        for word in words:
            trial = f"{line} {word}" if line else word
            if line and draw.textlength(trial, font=face) > width:
                lines.append(line)
                line = word
            else:
                line = trial
        lines.append(line)
    return lines


def render(data, target: Path, scale: float):
    scale *= data["production_scale"]
    margin = round(18 * scale)
    image = Image.new("RGBA", (round(data["width"] * scale) + margin * 2,
                               round(data["height"] * scale) + margin * 2), (18, 19, 23, 255))
    for region in data["regions"]:
        x, y = region["x"] * scale + margin, region["y"] * scale + margin
        width, height = region["width"] * scale, region["height"] * scale
        if (width <= 0 or height <= 0) and region["kind"] != "Line":
            continue
        box = (round(x), round(y), round(x + width), round(y + height))
        alpha = region.get("alpha", 1)
        overlay = Image.new("RGBA", image.size)
        draw = ImageDraw.Draw(overlay)
        if region.get("backdrop"):
            fill = rgba(region.get("backdropColor"), alpha, default=(.04, .04, .04, 1))
            border = rgba(region.get("backdropBorderColor"), alpha, default=(.3, .3, .3, 1))
            draw.rounded_rectangle(box, radius=round(5 * scale), fill=fill, outline=border, width=max(1, round(scale)))
        if region["kind"] == "Texture":
            texture = region.get("texture", "")
            local_prefix = "Interface\\AddOns\\ForeverCleanChat\\"
            if texture.startswith(local_prefix):
                path = ROOT / texture[len(local_prefix):].replace("\\", "/")
                asset = Image.open(path).convert("RGBA")
                coordinates = region.get("texCoord")
                if coordinates and len(coordinates) == 4:
                    left, right, top, bottom = coordinates
                    asset = asset.crop((round(left * asset.width), round(top * asset.height),
                                        round(right * asset.width), round(bottom * asset.height)))
                asset = asset.resize((max(1, round(width)), max(1, round(height))), Image.Resampling.LANCZOS)
                if alpha < 1:
                    asset.putalpha(asset.getchannel("A").point(lambda value: round(value * alpha)))
                overlay.alpha_composite(asset, (round(x), round(y)))
                draw = ImageDraw.Draw(overlay)
            elif texture and "PortraitAlphaMask" in texture:
                shade = rgba(region.get("vertexColor"), alpha)
                draw.ellipse(box, fill=shade)
                # A native circular region; local lighting is an approximation.
                if min(width, height) >= 12 * scale:
                    inset = max(1, round(3 * scale))
                    draw.ellipse((box[0]+inset, box[1]+inset, box[2]-inset, box[3]-inset),
                                 outline=tuple(min(255, color+24) for color in shade[:3])+(shade[3],), width=max(1, round(scale)))
            elif texture and "UI-Panel-MinimizeButton" in texture:
                inset=min(width,height)*.28
                draw.line((x+inset,y+inset,x+width-inset,y+height-inset),fill=rgba(region.get("vertexColor"),alpha),width=max(2,round(3*scale)))
                draw.line((x+width-inset,y+inset,x+inset,y+height-inset),fill=rgba(region.get("vertexColor"),alpha),width=max(2,round(3*scale)))
            elif region.get("colorTexture") or texture == "Interface\\Buttons\\WHITE8X8":
                color = rgba(region.get("colorTexture") or region.get("vertexColor"), alpha)
                if region.get("rotation"):
                    asset=Image.new("RGBA", (max(1,round(width)), max(1,round(height))), color)
                    asset=asset.rotate(math.degrees(region["rotation"]), expand=True, resample=Image.Resampling.BICUBIC)
                    overlay.alpha_composite(asset, (round(x+width/2-asset.width/2), round(y+height/2-asset.height/2)))
                else:
                    draw.rectangle(box, fill=color)
        if region["kind"] == "Line" and region.get("lineStart") and region.get("lineEnd"):
            points=[tuple(value*scale+margin for value in region[key]) for key in ("lineStart","lineEnd")]
            draw.line(points, fill=rgba(region.get("colorTexture") or region.get("vertexColor"),alpha), width=max(1,round(region.get("thickness",2)*scale)))
        if region.get("normalTexture") and "UI-Panel-MinimizeButton" in region["normalTexture"]:
            inset=min(width,height)*.28
            draw.line((x+inset,y+inset,x+width-inset,y+height-inset),fill=(245,189,84,255),width=max(2,round(3*scale)))
            draw.line((x+width-inset,y+inset,x+inset,y+height-inset),fill=(245,189,84,255),width=max(2,round(3*scale)))
        if region.get("text") is not None:
            if region.get("textInsets"):
                left,right,top,bottom=region["textInsets"]
                x,y=x+left*scale,y+top*scale
                width,height=width-(left+right)*scale,height-(top+bottom)*scale
            text = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", region["text"]).replace("||", "|")
            face = font(region.get("fontSize", 12), region.get("font"), scale)
            lines = wrap(draw, text, face, width, region.get("wordWrap", True))
            if region.get("maxLines"):
                lines = lines[:region["maxLines"]]
            spacing = region.get("fontSize", 12) * scale * 1.2
            total_height = len(lines) * spacing
            ty = y
            if region.get("justifyV") in {"CENTER", "MIDDLE"}:
                ty = y + max(0, (height-total_height)/2)
            elif region.get("justifyV") == "BOTTOM":
                ty = y + max(0, height-total_height)
            for index, line in enumerate(lines):
                if index * spacing >= height:
                    break
                tx = x
                if region.get("justifyH") == "CENTER":
                    tx += (width-draw.textlength(line, font=face))/2
                elif region.get("justifyH") == "RIGHT":
                    tx += width-draw.textlength(line, font=face)
                baseline = ty + index * spacing
                if region.get("shadowColor"):
                    offset = region.get("shadowOffset") or [1, -1]
                    draw.text((tx+offset[0]*scale, baseline-offset[1]*scale), line, font=face,
                              fill=rgba(region["shadowColor"], alpha), anchor="lt")
                draw.text((tx, baseline), line, font=face, fill=rgba(region.get("textColor"), alpha), anchor="lt")
        clip=region.get("clip")
        if clip:
            left,top,right,bottom=[round(value*scale+margin) for value in clip]
            left,top=max(0,left),max(0,top)
            right,bottom=min(image.width,right),min(image.height,bottom)
            if right>left and bottom>top:
                image.alpha_composite(overlay, dest=(left,top), source=(left,top,right,bottom))
        else:
            image.alpha_composite(overlay)
    if target is not None:
        target.parent.mkdir(parents=True, exist_ok=True)
        image.convert("RGB").save(target)
    return image


def animation_preview(target: Path, scale: float):
    """Animate the production widget by clicking actual controls and advancing ticks."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().arg = lua.table_from({1: ROOT.as_posix()})
    harness = lua.execute((ROOT / "tests/harness_ui.lua").read_text(encoding="utf-8"))
    env, ns = harness.uiGame("modern", lua.table_from({"schema": 2, "enabled": False, "mode": "strict"}))
    env.boot(env)
    assert ns.UI.Show("overview")
    frame, lock = ns.UI.frame, ns.UI.controls.protectionLock
    card = ns.UI.panels.overview.protectionCard
    x, y, width, height = env.bounds(env, card, frame)
    native_scale = frame.GetScale(frame)
    pixels = scale * native_scale
    margin = round(18 * pixels)
    padding = round(8 * pixels)
    crop = (round(x * pixels) + margin - padding, round(y * pixels) + margin - padding,
            round((x + width) * pixels) + margin + padding,
            round((y + height) * pixels) + margin + padding)
    frames, trace = [], []
    elapsed = 0.0

    def capture():
        data = {
            "width": frame.GetWidth(frame), "height": frame.GetHeight(frame),
            "production_scale": native_scale, "regions": plain(env.snapshot(env, frame)),
        }
        frames.append(render(data, None, scale).crop(crop).convert("RGB"))
        trace.append({"seconds": round(elapsed, 3), "enabled": bool(ns.db.enabled),
                      "phase": lock.phase, "visual_alpha": lock.visualAlpha,
                      "open_amount": lock.openAmount, "glow_alpha": lock.glow.GetAlpha(lock.glow),
                      "animating": bool(lock.animating)})

    def advance(seconds):
        nonlocal elapsed
        for _ in range(round(seconds * 20)):
            env.advance(env, .05)
            elapsed += .05
            capture()

    capture()
    advance(.3)
    env.click(env, ns.UI.controls.overviewToggle)
    capture()
    advance(1.35)
    env.click(env, ns.UI.controls.overviewToggle)
    capture()
    advance(.9)
    target = target.with_suffix(".gif")
    target.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(target, save_all=True, append_images=frames[1:], duration=50, loop=0, disposal=2)
    target.with_suffix(".json").write_text(json.dumps({
        "source": "Production Lua protection toggle callbacks and deterministic finite OnUpdate ticks",
        "limitations": ["Pillow preview, not a live WoW screenshot", "Local font substitutes for Blizzard Friz Quadrata"],
        "fps": 20, "production_scale": native_scale, "native_rendering": "not_run", "frames": trace,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tab", choices=["overview", "settings", "log", "lists", "test"], default="overview")
    parser.add_argument("--messages", type=int, default=0)
    parser.add_argument("--paused", action="store_true")
    parser.add_argument("--mode", choices=["balanced", "strict"], default="strict")
    parser.add_argument("--sample", help="Optional local-test text; never sends chat")
    parser.add_argument("--animation-preview", action="store_true", help="Render the production protection-lock ON/OFF sequence as a compact GIF")
    parser.add_argument("--scale", type=float, default=1.4)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/previews/home.png")
    args = parser.parse_args()
    if args.messages < 0 or args.messages > 50:
        parser.error("--messages must be 0..50")
    if args.animation_preview:
        print(animation_preview(args.output, args.scale))
        return 0
    data = snapshot(args.tab, args.messages, args.paused, args.mode, args.sample)
    render(data, args.output, args.scale)
    args.output.with_suffix(".json").write_text(json.dumps(data, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
