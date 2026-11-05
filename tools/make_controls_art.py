"""Paints the realistic steering wheel, shift knob and shifter gate used by the touch controls.

Run:  python3 tools/make_controls_art.py   (needs numpy + Pillow)
Writes art/wheel.png, art/knob.png, art/gate.png.

Everything is drawn procedurally with simple lighting (a light from the upper left), so the
controls look like real parts sitting on top of the pixel-art world.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "art")
os.makedirs(OUT, exist_ok=True)
LIGHT = np.array([-0.45, -0.6, 0.66])  # screen space, y down, z toward viewer
LIGHT = LIGHT / np.linalg.norm(LIGHT)
RNG = np.random.default_rng(86)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def grid(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    return x + 0.5, y + 0.5


def blur_noise(shape, sigma):
    img = Image.fromarray((RNG.random(shape) * 255).astype(np.uint8))
    img = img.filter(ImageFilter.GaussianBlur(sigma))
    a = np.asarray(img).astype(np.float32) / 255.0
    return (a - a.mean()) / (a.std() + 1e-6)


def streaks(coord, scale, n=8192):
    """Brushed-metal streaks: noise that only varies across `coord` (so lines run along it)."""
    line = RNG.random(n)
    line = np.convolve(line, np.ones(3) / 3, mode="same")
    idx = (np.abs(coord) * scale).astype(np.int64) % n
    s = line[idx]
    return (s - s.mean()) / (s.std() + 1e-6)


def softbox(nx, ny, nz):
    """Reflection of a soft rectangular studio light above-left, for glossy parts."""
    rx, ry, rz = 2 * nz * nx, 2 * nz * ny, 2 * nz * nz - 1
    band_y = np.clip(1 - np.abs(ry + 0.62) / 0.2, 0, 1)
    band_x = np.clip(1 - np.abs(rx + 0.2) / 0.75, 0, 1)
    return (band_x * band_y) ** 1.5 * (rz > 0)


def shade(nx, ny, nz, spec_power, spec_strength):
    ndl = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
    # Blinn-Phong with the viewer straight on.
    h = LIGHT + np.array([0, 0, 1.0])
    h = h / np.linalg.norm(h)
    ndh = np.clip(nx * h[0] + ny * h[1] + nz * h[2], 0, 1)
    return ndl, spec_strength * ndh ** spec_power


def to_rgba(rgb, alpha):
    rgb = np.clip(rgb, 0, 1)
    a = np.clip(alpha, 0, 1)
    return Image.fromarray((np.dstack([rgb, a[..., None]]) * 255).astype(np.uint8), "RGBA")


def drop_shadow(img, offset, blur, opacity):
    a = np.asarray(img.split()[3]).astype(np.float32) / 255.0
    sh = Image.fromarray((a * 255 * opacity).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    base = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 255))
    base.paste(shadow, offset, sh)
    base.alpha_composite(img)
    return base


# ---------------------------------------------------------------------------- wheel

def wheel(size=1024):
    S = size
    x, y = grid(S)
    cx = cy = S / 2
    dx, dy = x - cx, y - cy
    d = np.hypot(dx, dy)
    ux, uy = dx / np.maximum(d, 1e-3), dy / np.maximum(d, 1e-3)
    ang = np.arctan2(dy, dx)
    R = S * 0.44
    rgb = np.zeros((S, S, 3), np.float32)
    alpha = np.zeros((S, S), np.float32)

    def put(mask, color):
        nonlocal rgb, alpha
        m = np.clip(mask, 0, 1)[..., None]
        rgb = rgb * (1 - m) + color * m
        alpha = np.maximum(alpha, m[..., 0])

    # --- Spokes (brushed aluminium, satin), drawn first so the rim sits on top.
    brushed = blur_noise((S, S), 0.6)
    spoke_rgb = np.zeros_like(rgb)
    spoke_mask = np.zeros((S, S), np.float32)
    for a_deg in (180.0, 0.0, 90.0):  # left, right, down (screen)
        a = np.radians(a_deg)
        ax, ay = np.cos(a), np.sin(a)
        along = dx * ax + dy * ay
        across = -dx * ay + dy * ax
        half_w = np.interp(along, [0, R], [S * 0.075, S * 0.045])
        inside = (along > 0) & (along < R * 0.95) & (np.abs(across) < half_w)
        # Bevelled edges: normal tilts toward the edge.
        edge = np.clip((np.abs(across) - (half_w - S * 0.012)) / (S * 0.012), 0, 1)
        nx = -ay * np.sign(across) * edge * 0.8
        ny = ax * np.sign(across) * edge * 0.8
        nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
        diff, spec = shade(nx, ny, nz, 30, 0.35)
        # Brushing runs along the spoke.
        streak = streaks(across, 2.2) * 0.7 + blur_noise((S, S), 0.6) * 0.3
        base = 0.46 + 0.05 * streak
        col = np.dstack([base * 0.95, base * 0.97, base]) * (0.35 + 0.75 * diff[..., None]) + spec[..., None]
        # Lightening holes.
        for frac in (0.42, 0.66):
            hx, hy = cx + ax * R * frac, cy + ay * R * frac
            hd = np.hypot(x - hx, y - hy)
            hr = S * 0.022
            hole = hd < hr
            rim_hi = (hd >= hr) & (hd < hr + S * 0.006)
            col[hole] = col[hole] * 0.0 + 0.03
            col[rim_hi] *= 1.25
            inside &= ~(hd < hr * 0.85)
        spoke_rgb[inside] = col[inside]
        spoke_mask[inside] = 1
    rgb = spoke_rgb.copy()
    alpha = spoke_mask.copy()

    # --- Hub plate with bolts, then the horn button.
    plate = d < R * 0.36
    pn = np.clip((d - R * 0.33) / (R * 0.03), 0, 1)  # bevel at edge
    diff, spec = shade(ux * pn * 0.7, uy * pn * 0.7, np.sqrt(1 - (pn * 0.7) ** 2), 40, 0.4)
    pc = np.dstack([0.22 + 0 * d] * 3) * (0.4 + 0.7 * diff[..., None]) + spec[..., None]
    rgb[plate] = pc[plate]
    alpha[plate] = 1
    for i in range(6):
        a = np.radians(i * 60 + 30)
        bx, by = cx + np.cos(a) * R * 0.29, cy + np.sin(a) * R * 0.29
        bd = np.hypot(x - bx, y - by)
        br = S * 0.016
        m = bd < br
        bnx, bny = (x - bx) / br, (y - by) / br
        bnz = np.sqrt(np.clip(1 - bnx ** 2 - bny ** 2, 0, 1))
        diff, spec = shade(bnx, bny, bnz, 25, 0.8)
        bc = np.dstack([0.55 + 0 * d] * 3) * (0.3 + 0.7 * diff[..., None]) + spec[..., None]
        rgb[m] = bc[m]
    horn = d < R * 0.22
    hr = R * 0.22
    t = np.clip(d / hr, 0, 1)
    nz = np.sqrt(np.clip(1 - (t * 0.75) ** 2, 0, 1))
    diff, spec = shade(ux * t * 0.75, uy * t * 0.75, nz, 60, 0.9)
    hc = np.dstack([0.035 + 0 * d] * 3) * (0.5 + 0.8 * diff[..., None]) + spec[..., None]
    hc += 0.35 * softbox(ux * t * 0.75, uy * t * 0.75, nz)[..., None]
    ring = (d > hr * 0.8) & (d < hr * 0.84)
    hc[ring] = hc[ring] * 0.4 + 0.25
    rgb[horn] = hc[horn]

    # --- Rim: black suede torus with a 12 o'clock stripe and cross stitching.
    r_out, r_in = R, R * 0.79
    r_mid, tube = (r_out + r_in) / 2, (r_out - r_in) / 2
    t = (d - r_mid) / tube
    rim = np.abs(t) < 1
    nz = np.sqrt(np.clip(1 - t * t, 0, 1))
    diff, spec = shade(ux * t, uy * t, nz, 8, 0.07)  # suede: soft, barely any shine
    grain = 0.5 * blur_noise((S, S), 0.7) + 0.5 * blur_noise((S, S), 2.0)
    suede = (0.075 + 0.012 * grain)[..., None] * np.array([1.0, 0.98, 1.02])
    col = suede * (0.45 + 1.1 * diff[..., None]) + spec[..., None] + 0.03 * (1 - nz)[..., None]  # velvety sheen at edges
    stripe = np.abs((ang + np.pi / 2 + np.pi) % (2 * np.pi) - np.pi) < np.radians(3.2)
    stripe_col = np.array([1.0, 0.42, 0.08]) * (0.45 + 0.8 * diff[..., None]) + spec[..., None] * 2
    col = np.where((stripe & rim)[..., None], stripe_col, col)
    # Baseball stitch along the inner edge.
    st_t = -0.55
    near = np.abs(t - st_t) < 0.09
    seg = ((ang * r_in / (S * 0.016)) % 1.0) < 0.55
    stitch = rim & near & seg & ~stripe
    col[stitch] = np.array([0.5, 0.5, 0.52]) * (0.5 + 0.7 * diff[stitch][..., None])
    rgb[rim] = col[rim]
    alpha[rim] = 1
    # Soft anti-aliased outer edge.
    edge = np.clip((r_out - d) / 1.5, 0, 1)
    alpha = np.where(d > r_out - 1.5, np.minimum(alpha, edge), alpha)

    img = to_rgba(rgb, alpha)
    img = drop_shadow(img, (int(S * 0.012), int(S * 0.02)), S * 0.012, 0.6)
    return img.resize((512, 512), Image.LANCZOS)


# ---------------------------------------------------------------------------- knob

def knob(size=512):
    S = size
    x, y = grid(S)
    cx = cy = S / 2
    R = S * 0.42
    nx, ny = (x - cx) / R, (y - cy) / R
    rr = nx * nx + ny * ny
    m = rr < 1
    nz = np.sqrt(np.clip(1 - rr, 0, 1))
    diff, spec = shade(nx, ny, nz, 220, 0.9)
    _, broad = shade(nx, ny, nz, 14, 0.08)
    base = np.array([0.025, 0.025, 0.03])
    col = base * (0.4 + 0.9 * diff[..., None]) + (spec + broad)[..., None]
    col += 0.55 * softbox(nx, ny, nz)[..., None]
    col *= (0.75 + 0.25 * nz)[..., None]  # a little darker toward the silhouette
    rim_light = np.clip((np.sqrt(rr) - 0.82) / 0.18, 0, 1) * np.clip(ny + 0.3, 0, 1)
    col += 0.18 * rim_light[..., None]
    alpha = np.clip((1 - np.sqrt(rr)) * R / 1.5, 0, 1) * m
    img = to_rgba(col, alpha)

    # Engraved shift pattern on top.
    eng = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    g = ImageDraw.Draw(eng)
    u = S * 0.07
    w = max(2, int(S * 0.012))
    col_e = (200, 200, 205, 210)
    ox, oy = cx, cy + S * 0.1
    g.line([(ox - u, oy), (ox + u, oy)], fill=col_e, width=w)
    for c in (-1, 0, 1):
        g.line([(ox + c * u, oy - u), (ox + c * u, oy + u)], fill=col_e, width=w)
    f = ImageFont.truetype(FONT, int(S * 0.05))
    for c, (top, bot) in zip((-1, 0, 1), (("1", "2"), ("3", "4"), ("5", "R"))):
        g.text((ox + c * u, oy - u - S * 0.045), top, fill=col_e, font=f, anchor="mm")
        g.text((ox + c * u, oy + u + S * 0.045), bot, fill=col_e, font=f, anchor="mm")
    img.alpha_composite(eng)
    img = drop_shadow(img, (int(S * 0.03), int(S * 0.05)), S * 0.03, 0.7)
    return img.resize((256, 256), Image.LANCZOS)


# ---------------------------------------------------------------------------- gate

def gate(size=1024, units=3.8):
    """Brushed aluminium open gate. Gate unit = size / units pixels; centre is neutral."""
    S = size
    U = S / units
    x, y = grid(S)
    cx = cy = S / 2
    pad = S * 0.02
    corner = S * 0.06
    # Rounded-rect plate mask.
    qx = np.clip(np.abs(x - cx) - (S / 2 - pad - corner), 0, None)
    qy = np.clip(np.abs(y - cy) - (S / 2 - pad - corner), 0, None)
    plate = np.hypot(qx, qy) < corner
    # Horizontal brushing.
    streak = streaks(y, 1.0) * 0.75 + blur_noise((S, S), 0.5) * 0.25
    base = 0.5 + 0.035 * streak + 0.06 * (1 - y / S)  # a bit lighter at the top
    col = np.dstack([base * 0.96, base * 0.98, base]).astype(np.float32)
    # Bevel around the plate edge.
    edge_d = corner - np.hypot(qx, qy)
    bevel = np.clip(1 - edge_d / (S * 0.012), 0, 1) * plate
    h = np.maximum(np.hypot(qx, qy), 1e-3)
    enx, eny = np.sign(x - cx) * qx / h, np.sign(y - cy) * qy / h
    col += (bevel * -0.35 * (enx * LIGHT[0] + eny * LIGHT[1]))[..., None]

    # Gate slots: neutral row + three columns, cut into the plate with inner shadow.
    slot_w = U * 0.34
    def seg_dist(px, py, ax, ay, bx, by):
        vx, vy = bx - ax, by - ay
        t = np.clip(((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy + 1e-6), 0, 1)
        return np.hypot(px - (ax + t * vx), py - (ay + t * vy))
    dist = seg_dist(x, y, cx - U, cy, cx + U, cy)
    for c in (-1, 0, 1):
        dist = np.minimum(dist, seg_dist(x, y, cx + c * U, cy - U, cx + c * U, cy + U))
    slot = dist < slot_w / 2
    depth = np.clip(dist / (slot_w / 2), 0, 1)
    # Inside the slot: dark, lit a little on the lower lip, shadowed on the upper lip.
    inner = 0.03 + 0.05 * depth
    col[slot] = np.dstack([inner] * 3)[slot]
    lip = (dist >= slot_w / 2) & (dist < slot_w / 2 + S * 0.006)
    col[lip] *= 1.3
    alpha = plate.astype(np.float32)

    img = to_rgba(col, alpha)
    g = ImageDraw.Draw(img)
    # Screws in the corners.
    for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        px, py = cx + sx * (S / 2 - S * 0.08), cy + sy * (S / 2 - S * 0.08)
        r = S * 0.022
        g.ellipse([px - r, py - r, px + r, py + r], fill=(70, 70, 74, 255), outline=(150, 150, 155, 255), width=2)
        g.line([px - r * 0.7, py, px + r * 0.7, py], fill=(30, 30, 32, 255), width=4)
    # Engraved gear numbers next to each slot end.
    f = ImageFont.truetype(FONT, int(U * 0.36))
    labels = {(-1, -1): "1", (0, -1): "3", (1, -1): "5", (-1, 1): "2", (0, 1): "4", (1, 1): "R"}
    for (c, r), txt in labels.items():
        px = cx + c * U
        py = cy + r * (U + U * 0.38)
        g.text((px + 2, py + 2), txt, fill=(235, 235, 240, 140), font=f, anchor="mm")  # light lower edge
        g.text((px, py), txt, fill=(25, 25, 28, 230), font=f, anchor="mm")
    img = drop_shadow(img, (int(S * 0.01), int(S * 0.016)), S * 0.012, 0.55)
    return img.resize((512, 512), Image.LANCZOS)


if __name__ == "__main__":
    wheel().save(os.path.join(OUT, "wheel.png"))
    knob().save(os.path.join(OUT, "knob.png"))
    gate().save(os.path.join(OUT, "gate.png"))
    print("wrote art/wheel.png, art/knob.png, art/gate.png")
