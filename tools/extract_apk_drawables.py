#!/usr/bin/env python3
"""Extracts all 339 original game PNG drawables, TGA normal maps, GLSL shaders, and iOS AppIcon.appiconset from fishing181.apk."""
import io
import json
import os
import struct
import base64
import subprocess
import sys
import zipfile
import zlib

KLEV_M4A_B64 = "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"
TW_M4A_B64 = "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"


DRAWABLE_MAP = {
  "about_game": "res/Qp.png",
  "about_game150": "res/hW.png",
  "about_me": "res/Q3.png",
  "about_me150": "res/I4.png",
  "background": "res/3D.png",
  "background1": "res/0-.png",
  "backpack": "res/Tg.png",
  "backpack_small": "res/a81.png",
  "bait_1": "res/AK.png",
  "bait_10": "res/C8.png",
  "bait_11": "res/Vc.png",
  "bait_12": "res/mY.png",
  "bait_13": "res/N_1.png",
  "bait_14": "res/Fp.png",
  "bait_15": "res/vw1.png",
  "bait_16": "res/TG.png",
  "bait_17": "res/VM.png",
  "bait_18": "res/Gn1.png",
  "bait_19": "res/BC1.png",
  "bait_2": "res/ts1.png",
  "bait_20": "res/55.png",
  "bait_21": "res/rS.png",
  "bait_22": "res/sx.png",
  "bait_23": "res/RG.png",
  "bait_24": "res/N1.png",
  "bait_25": "res/BM.png",
  "bait_26": "res/1k.png",
  "bait_27": "res/1-.png",
  "bait_28": "res/CF.png",
  "bait_29": "res/_H.png",
  "bait_3": "res/PN.png",
  "bait_30": "res/pp.png",
  "bait_31": "res/Qb.png",
  "bait_32": "res/4D.png",
  "bait_33": "res/7K1.png",
  "bait_34": "res/f5.png",
  "bait_35": "res/xb.png",
  "bait_36": "res/Ie.png",
  "bait_37": "res/Hs.png",
  "bait_38": "res/Tt.png",
  "bait_39": "res/qY.png",
  "bait_4": "res/x7.png",
  "bait_40": "res/Ul.png",
  "bait_5": "res/2G.png",
  "bait_6": "res/Zg1.png",
  "bait_7": "res/L0.png",
  "bait_8": "res/EB.png",
  "bait_9": "res/H8.png",
  "bait_empty": "res/9V.png",
  "baits": "res/wj.png",
  "bobber": "res/ky.png",
  "bobber_hide": "res/uh1.png",
  "bronz": "res/8y.png",
  "btn_background": "res/Q8.png",
  "coil": "res/R_.png",
  "coupons": "res/gP1.png",
  "dbases": "res/_C.png",
  "drop_me": "res/8S.png",
  "evaluation": "res/_x.png",
  "exit": "res/VU.png",
  "fish_1": "res/hP.png",
  "fish_10": "res/du.png",
  "fish_100": "res/0_.png",
  "fish_101": "res/pC.png",
  "fish_102": "res/uH.png",
  "fish_103": "res/yJ.png",
  "fish_104": "res/6r.png",
  "fish_105": "res/Fe1.png",
  "fish_106": "res/7N1.png",
  "fish_107": "res/6t.png",
  "fish_108": "res/Bm.png",
  "fish_109": "res/5j.png",
  "fish_11": "res/eC.png",
  "fish_110": "res/UH.png",
  "fish_111": "res/Pq.png",
  "fish_112": "res/OU.png",
  "fish_113": "res/xw.png",
  "fish_114": "res/j21.png",
  "fish_115": "res/YP.png",
  "fish_116": "res/kt1.png",
  "fish_117": "res/zQ.png",
  "fish_118": "res/r2.png",
  "fish_119": "res/HQ1.png",
  "fish_12": "res/Z9.png",
  "fish_120": "res/lB.png",
  "fish_121": "res/ib.png",
  "fish_122": "res/5U.png",
  "fish_123": "res/CT.png",
  "fish_124": "res/dv.png",
  "fish_125": "res/O_.png",
  "fish_126": "res/yH.png",
  "fish_127": "res/jj.png",
  "fish_128": "res/qT.png",
  "fish_129": "res/4N.png",
  "fish_13": "res/-l.png",
  "fish_130": "res/Da.png",
  "fish_131": "res/LB.png",
  "fish_132": "res/ek.png",
  "fish_133": "res/2k.png",
  "fish_134": "res/S9.png",
  "fish_135": "res/F1.png",
  "fish_136": "res/09.png",
  "fish_137": "res/Jw1.png",
  "fish_138": "res/py.png",
  "fish_139": "res/hj.png",
  "fish_14": "res/PM.png",
  "fish_140": "res/ej.png",
  "fish_141": "res/lI.png",
  "fish_15": "res/Pd1.png",
  "fish_16": "res/rE.png",
  "fish_17": "res/GY1.png",
  "fish_18": "res/Os.png",
  "fish_19": "res/N_.png",
  "fish_2": "res/Rm.png",
  "fish_20": "res/ng1.png",
  "fish_21": "res/M-.png",
  "fish_22": "res/X0.png",
  "fish_23": "res/I0.png",
  "fish_24": "res/Wi.png",
  "fish_25": "res/ZW.png",
  "fish_26": "res/L5.png",
  "fish_27": "res/vd.png",
  "fish_28": "res/po1.png",
  "fish_29": "res/Yj.png",
  "fish_3": "res/7J.png",
  "fish_30": "res/OP.png",
  "fish_31": "res/CD.png",
  "fish_32": "res/f6.png",
  "fish_33": "res/0f.png",
  "fish_34": "res/zm.png",
  "fish_35": "res/1f.png",
  "fish_36": "res/m_.png",
  "fish_37": "res/tu.png",
  "fish_38": "res/AI.png",
  "fish_39": "res/Ov.png",
  "fish_4": "res/sN1.png",
  "fish_40": "res/_t.png",
  "fish_41": "res/po.png",
  "fish_42": "res/Ap.png",
  "fish_43": "res/8-.png",
  "fish_44": "res/sk.png",
  "fish_45": "res/Uq.png",
  "fish_46": "res/rK.png",
  "fish_47": "res/tA.png",
  "fish_48": "res/WN.png",
  "fish_49": "res/h1.png",
  "fish_5": "res/PJ.png",
  "fish_50": "res/hN.png",
  "fish_51": "res/99.png",
  "fish_52": "res/Fi1.png",
  "fish_53": "res/NF1.png",
  "fish_54": "res/gS.png",
  "fish_55": "res/ZC.png",
  "fish_56": "res/Zo.png",
  "fish_57": "res/G3.png",
  "fish_58": "res/kJ.png",
  "fish_59": "res/eE.png",
  "fish_6": "res/Ty.png",
  "fish_60": "res/6X.png",
  "fish_61": "res/O7.png",
  "fish_62": "res/ZU.png",
  "fish_63": "res/Fg1.png",
  "fish_64": "res/nr.png",
  "fish_65": "res/k3.png",
  "fish_66": "res/Z0.png",
  "fish_67": "res/pW.png",
  "fish_68": "res/-m.png",
  "fish_69": "res/Ck1.png",
  "fish_7": "res/vg.png",
  "fish_70": "res/2i.png",
  "fish_71": "res/Z_.png",
  "fish_72": "res/ud1.png",
  "fish_73": "res/AC2.png",
  "fish_74": "res/dV.png",
  "fish_75": "res/wA.png",
  "fish_76": "res/m1.png",
  "fish_77": "res/wc1.png",
  "fish_78": "res/jz.png",
  "fish_79": "res/s8.png",
  "fish_8": "res/Ye.png",
  "fish_80": "res/aX1.png",
  "fish_81": "res/An.png",
  "fish_82": "res/Fi.png",
  "fish_83": "res/AN.png",
  "fish_84": "res/BZ.png",
  "fish_85": "res/-0.png",
  "fish_86": "res/yb.png",
  "fish_87": "res/qD.png",
  "fish_88": "res/In1.png",
  "fish_89": "res/u0.png",
  "fish_9": "res/G_.png",
  "fish_90": "res/Wn.png",
  "fish_91": "res/QU.png",
  "fish_92": "res/Bi.png",
  "fish_93": "res/HC.png",
  "fish_94": "res/bZ.png",
  "fish_95": "res/qq.png",
  "fish_96": "res/sh.png",
  "fish_97": "res/ng.png",
  "fish_98": "res/e91.png",
  "fish_99": "res/Sx.png",
  "fishing_line": "res/4G.png",
  "fishing_rod_0": "res/sb.png",
  "fishing_rod_1": "res/Xq.png",
  "fishing_rod_10": "res/Rx.png",
  "fishing_rod_11": "res/11.png",
  "fishing_rod_12": "res/P9.png",
  "fishing_rod_13": "res/x1.png",
  "fishing_rod_14": "res/ge.png",
  "fishing_rod_15": "res/Us.png",
  "fishing_rod_2": "res/qt.png",
  "fishing_rod_3": "res/H2.png",
  "fishing_rod_4": "res/hO.png",
  "fishing_rod_5": "res/Hq.png",
  "fishing_rod_6": "res/Vy.png",
  "fishing_rod_7": "res/e9.png",
  "fishing_rod_8": "res/Vd1.png",
  "fishing_rod_9": "res/OT.png",
  "fishing_rods": "res/Gx.png",
  "fishpond": "res/7X.png",
  "fishpond_small": "res/aX.png",
  "fon_template": "res/XA.png",
  "gold": "res/Tr1.png",
  "hooks": "res/Oi.png",
  "ic_bobber_bar": "res/6N.png",
  "ic_launcher": "res/Gd.png",
  "ic_more_vert_white_24dp": "res/n0.png",
  "icon": "res/9T.png",
  "info": "res/5g.png",
  "info_background": "res/YL.png",
  "letter": "res/Ky.png",
  "md_achiv_1": "res/3Z.png",
  "md_achiv_10": "res/l7.png",
  "md_achiv_11": "res/mS.png",
  "md_achiv_12": "res/AC1.png",
  "md_achiv_13": "res/n7.png",
  "md_achiv_14": "res/0w.png",
  "md_achiv_2": "res/tJ.png",
  "md_achiv_3": "res/Bv.png",
  "md_achiv_4": "res/hf.png",
  "md_achiv_5": "res/qw.png",
  "md_achiv_6": "res/cK.png",
  "md_achiv_7": "res/9M.png",
  "md_achiv_8": "res/iz.png",
  "md_achiv_9": "res/cv.png",
  "minus_b": "res/Mg.png",
  "moder": "res/Uf.png",
  "money": "res/_E.png",
  "montv": "res/cw.png",
  "no_achiv": "res/T-.png",
  "no_fish": "res/bY.png",
  "notify_panel_notification_icon_bg": "res/5c.png",
  "off": "res/ir.png",
  "on": "res/eQ.png",
  "on_humans": "res/wJ.png",
  "on_humans_tr": "res/gj.png",
  "on_ok": "res/c7.png",
  "on_ok_tr": "res/mt.png",
  "on_shop": "res/mj.png",
  "on_shop150": "res/sN.png",
  "online": "res/ks.png",
  "online150": "res/Rw.png",
  "op25": "res/eF.png",
  "overflow_menu_button": "res/uR.png",
  "plus_b": "res/sE.png",
  "pond": "res/i6.png",
  "pond0": "res/jA1.png",
  "pond150": "res/E5.png",
  "pond_1": "res/bS.png",
  "pond_10": "res/a2.png",
  "pond_10_big": "res/8Y.png",
  "pond_11": "res/Jt.png",
  "pond_11_big": "res/tw.png",
  "pond_12": "res/UA.png",
  "pond_12_big": "res/CY.png",
  "pond_13": "res/gK.png",
  "pond_13_big": "res/-S.png",
  "pond_14": "res/3R.png",
  "pond_14_big": "res/XL.png",
  "pond_15": "res/ET1.png",
  "pond_15_big": "res/UZ.png",
  "pond_1_big": "res/Jk.png",
  "pond_2": "res/jA.png",
  "pond_2_big": "res/g61.png",
  "pond_3": "res/da.png",
  "pond_3_big": "res/C2.png",
  "pond_4": "res/qg.png",
  "pond_4_big": "res/Ra.png",
  "pond_5": "res/xy.png",
  "pond_5_big": "res/9g.png",
  "pond_6": "res/NF.png",
  "pond_6_big": "res/Hv.png",
  "pond_7": "res/DK.png",
  "pond_7_big": "res/j2.png",
  "pond_8": "res/jv.png",
  "pond_8_big": "res/fP.png",
  "pond_9": "res/zh.png",
  "pond_9_big": "res/a-.png",
  "pond_end": "res/NH.png",
  "pond_out": "res/zR1.png",
  "push_me": "res/_q.png",
  "push_me_on": "res/1s.png",
  "query": "res/Cr.png",
  "query_btn": "res/S7.png",
  "query_old": "res/S-.png",
  "real": "res/fK.png",
  "records": "res/tK.png",
  "rouble": "res/DX.png",
  "save": "res/7Y.png",
  "sback_p": "res/yW.png",
  "sback_r": "res/AV.png",
  "sbuy_off": "res/wR.png",
  "sbuy_on": "res/nY.png",
  "screansaver": "res/SX.png",
  "second_background": "res/ZG.png",
  "second_background_small": "res/l1.png",
  "settings": "res/le.png",
  "share": "res/w-.png",
  "share_btn": "res/zY.png",
  "shop": "res/_n.png",
  "silver": "res/Ip.png",
  "tadmin": "res/oD.png",
  "task_btn": "res/ET.png",
  "task_md_btn": "res/LC.png",
  "tban": "res/Km.png",
  "tban_en": "res/li.png",
  "tchat": "res/bE.png",
  "tchat_en": "res/Eo.png",
  "tchat_no_vip_back": "res/oI.png",
  "tchat_vip_back": "res/Go.png",
  "tcrown1": "res/c3.png",
  "tcrown2": "res/bH.png",
  "tcrown3": "res/yx.png",
  "tfisher_pay": "res/nG.png",
  "tick": "res/nv.png",
  "tick_empty": "res/Tl.png",
  "time_background": "res/A9.png",
  "tours_btn": "res/mN.png",
  "www_btn": "res/pe.png"
}


def _make_png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(chunk_type + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", crc)


def _write_solid_rgb_png(out_path: str, width: int = 1024, height: int = 1024, rgb=(16, 32, 44)) -> None:
    raw_row = b"\x00" + bytes(rgb) * width
    compressed = zlib.compress(raw_row * height, level=6)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png_bytes = (
        b"\x89PNG\r\n\x1a\n"
        + _make_png_chunk(b"IHDR", ihdr)
        + _make_png_chunk(b"IDAT", compressed)
        + _make_png_chunk(b"IEND", b"")
    )
    with open(out_path, "wb") as f:
        f.write(png_bytes)


def generate_ios_appiconset(ic_launcher_png_bytes: bytes, resources_root_dir: str) -> None:
    """Generates App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png (opaque RGB) + Contents.json."""
    xcassets_dir = os.path.join(resources_root_dir, "Assets.xcassets")
    appicon_dir = os.path.join(xcassets_dir, "AppIcon.appiconset")
    os.makedirs(appicon_dir, exist_ok=True)

    with open(os.path.join(xcassets_dir, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

    appicon_contents = {
        "images": [
            {
                "filename": "AppIcon-1024.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    with open(os.path.join(appicon_dir, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump(appicon_contents, f, indent=2)

    target_png = os.path.join(appicon_dir, "AppIcon-1024.png")

    # 1. Try Pillow (PIL) first for high-quality Lanczos upscaling onto an opaque dark-water background
    try:
        from PIL import Image
        src = Image.open(io.BytesIO(ic_launcher_png_bytes)).convert("RGBA")
        bg = Image.new("RGBA", (1024, 1024), (16, 32, 44, 255))
        resized = src.resize((1024, 1024), getattr(Image, "Resampling", Image).LANCZOS)
        composited = Image.alpha_composite(bg, resized).convert("RGB")
        composited.save(target_png, format="PNG")
        return
    except Exception:
        pass

    # 2. On macOS runners without Pillow, use built-in `/usr/bin/sips`
    if os.path.exists("/usr/bin/sips"):
        tmp_src = os.path.join(appicon_dir, "_tmp_ic_launcher.png")
        with open(tmp_src, "wb") as f:
            f.write(ic_launcher_png_bytes)
        try:
            subprocess.run(
                ["/usr/bin/sips", "-z", "1024", "1024", "-s", "format", "png", tmp_src, "--out", target_png],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            os.remove(tmp_src)
            return
        except Exception:
            if os.path.exists(tmp_src):
                os.remove(tmp_src)

    # 3. Pure-Python fallback
    _write_solid_rgb_png(target_png, 1024, 1024)


def main():
    if len(sys.argv) < 3:
        print("Usage: extract_apk_drawables.py <path_to_fishing181.apk> <path_to_GameData_dir>")
        sys.exit(1)
    apk_path = sys.argv[1]
    game_data_dir = sys.argv[2]
    drawables_dir = os.path.join(game_data_dir, "Drawables")
    textures_dir = os.path.join(game_data_dir, "Textures")
    shaders_dir = os.path.join(game_data_dir, "Shaders")
    os.makedirs(drawables_dir, exist_ok=True)
    os.makedirs(textures_dir, exist_ok=True)
    os.makedirs(shaders_dir, exist_ok=True)

    with zipfile.ZipFile(apk_path, "r") as zf:
        names = set(zf.namelist())
        count = 0
        for canonical_name, apk_rel in DRAWABLE_MAP.items():
            if apk_rel in names:
                with open(os.path.join(drawables_dir, f"{canonical_name}.png"), "wb") as out:
                    out.write(zf.read(apk_rel))
                count += 1
        for member in names:
            if member.startswith("assets/Textures/") and member.endswith(".tga"):
                with open(os.path.join(textures_dir, os.path.basename(member)), "wb") as out:
                    out.write(zf.read(member))
            elif member.startswith("assets/Shaders/") and member.endswith(".glsl"):
                with open(os.path.join(shaders_dir, os.path.basename(member)), "wb") as out:
                    out.write(zf.read(member))

        # Generate App/Resources/Assets.xcassets/AppIcon.appiconset from ic_launcher (`res/Gd.png`)
        if "res/Gd.png" in names:
            resources_root = os.path.dirname(os.path.abspath(game_data_dir))
            generate_ios_appiconset(zf.read("res/Gd.png"), resources_root)

        # Write original APK bite & tournament sounds (`res/ac.ogg` -> `klev.m4a`, `res/JG.ogg` -> `tw.m4a`)
        sounds_dir = os.path.join(game_data_dir, "Sounds")
        os.makedirs(sounds_dir, exist_ok=True)
        with open(os.path.join(sounds_dir, "klev.m4a"), "wb") as f:
            f.write(base64.b64decode(KLEV_M4A_B64))
        with open(os.path.join(sounds_dir, "tw.m4a"), "wb") as f:
            f.write(base64.b64decode(TW_M4A_B64))
        if "res/ac.ogg" in names:
            with open(os.path.join(sounds_dir, "klev.ogg"), "wb") as f:
                f.write(zf.read("res/ac.ogg"))
        if "res/JG.ogg" in names:
            with open(os.path.join(sounds_dir, "tw.ogg"), "wb") as f:
                f.write(zf.read("res/JG.ogg"))

    print(f"Extracted {count} PNG drawables + TGA textures + GLSL shaders + Sounds + AppIcon.appiconset into {game_data_dir}")


if __name__ == "__main__":
    main()
