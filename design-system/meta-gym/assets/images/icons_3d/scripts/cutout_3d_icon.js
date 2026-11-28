#!/usr/bin/env node
/**
 * Meta Gym 3D Icon — Precision White-Background Cutout & Anti-Fringe Tool
 * ------------------------------------------------------------------------
 * Removes pure/near-white studio backgrounds (#FFFFFF) and upper binding-ring
 * interior holes while preserving bright silver rims, pearl-white checkmarks,
 * and eliminating white halos on dark obsidian / warm smoked glass surfaces.
 *
 * Usage:
 *   node design-system/meta-gym/assets/images/icons_3d/scripts/cutout_3d_icon.js "<input.png>" "<output.webp>" [--size=256] [--pad=0.06] [--audit="<audit.png>"] [--hole-y-max=0.35]
 */

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '../../../../../..');
const sharp = require(path.join(repoRoot, 'backend/node_modules/sharp'));

function parseArgs(argv) {
  const positional = [];
  const opts = {
    size: 256,
    pad: 0.06,
    audit: null,
    holeYMax: 0.35,
  };
  for (const arg of argv.slice(2)) {
    if (arg.startsWith('--size=')) {
      const v = parseInt(arg.slice(7), 10);
      opts.size = Math.max(32, Number.isFinite(v) ? v : 256);
    } else if (arg.startsWith('--pad=')) {
      const v = parseFloat(arg.slice(6));
      opts.pad = Math.min(0.3, Math.max(0, Number.isFinite(v) ? v : 0.06));
    } else if (arg.startsWith('--audit=')) {
      opts.audit = arg.slice(8);
    } else if (arg.startsWith('--hole-y-max=')) {
      const v = parseFloat(arg.slice(13));
      opts.holeYMax = Math.min(1, Math.max(0, Number.isFinite(v) ? v : 0.35));
    } else {
      positional.push(arg);
    }
  }
  return { positional, opts };
}

function clamp(v, lo, hi) {
  return v < lo ? lo : v > hi ? hi : v;
}

function isNearWhiteOuter(r, g, b) {
  const min = Math.min(r, g, b);
  const max = Math.max(r, g, b);
  return min >= 232 && (max - min) <= 16;
}

function isPureWhiteHole(r, g, b) {
  const min = Math.min(r, g, b);
  const max = Math.max(r, g, b);
  return min >= 242 && (max - min) <= 10;
}

function computeDistanceFromBg(bgMask, W, H, maxSteps = 5) {
  const N = W * H;
  const dist = new Uint8Array(N).fill(255);
  const queue = new Int32Array(N);
  let head = 0;
  let tail = 0;
  for (let i = 0; i < N; i++) {
    if (bgMask[i]) {
      dist[i] = 0;
      queue[tail++] = i;
    }
  }
  while (head < tail) {
    const cur = queue[head++];
    const d = dist[cur];
    if (d >= maxSteps) continue;
    const x = cur % W;
    const y = (cur - x) / W;
    const nextD = d + 1;
    const push = (ni) => {
      if (dist[ni] > nextD) {
        dist[ni] = nextD;
        queue[tail++] = ni;
      }
    };
    if (x > 0) push(cur - 1);
    if (x < W - 1) push(cur + 1);
    if (y > 0) push(cur - W);
    if (y < H - 1) push(cur + W);
  }
  return dist;
}

async function renderAuditImage(iconWebpBuffer, size, auditPath) {
  const panelSize = size;
  const width = panelSize * 4;
  const height = panelSize;

  // Build 4-panel background buffer
  const bg = Buffer.alloc(width * height * 4);
  const darkWarm = [0x2b, 0x26, 0x22, 0xff];
  const darkSolid = [0x18, 0x1b, 0x22, 0xff];
  const lightCard = [0xff, 0xff, 0xff, 0xff];

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const panel = Math.floor(x / panelSize);
      const p = (y * width + x) * 4;
      if (panel === 0) {
        const checker = ((Math.floor(x / 16) + Math.floor(y / 16)) % 2) === 0;
        const c = checker ? 210 : 170;
        bg[p] = c;
        bg[p + 1] = c;
        bg[p + 2] = c;
        bg[p + 3] = 255;
      } else if (panel === 1) {
        bg[p] = darkWarm[0];
        bg[p + 1] = darkWarm[1];
        bg[p + 2] = darkWarm[2];
        bg[p + 3] = darkWarm[3];
      } else if (panel === 2) {
        bg[p] = darkSolid[0];
        bg[p + 1] = darkSolid[1];
        bg[p + 2] = darkSolid[2];
        bg[p + 3] = darkSolid[3];
      } else {
        bg[p] = lightCard[0];
        bg[p + 1] = lightCard[1];
        bg[p + 2] = lightCard[2];
        bg[p + 3] = lightCard[3];
      }
    }
  }

  const miniIcon = await sharp(iconWebpBuffer)
    .resize(38, 38, { kernel: sharp.kernel.lanczos3 })
    .png()
    .toBuffer();

  fs.mkdirSync(path.dirname(auditPath), { recursive: true });
  await sharp(bg, { raw: { width, height, channels: 4 } })
    .composite([
      { input: iconWebpBuffer, left: 0, top: 0 },
      { input: iconWebpBuffer, left: panelSize, top: 0 },
      { input: iconWebpBuffer, left: panelSize * 2, top: 0 },
      { input: iconWebpBuffer, left: panelSize * 3, top: 0 },
      // 38x38 real-size corner previews on Dark Warm Glass & Light Card
      { input: miniIcon, left: panelSize + 8, top: 8 },
      { input: miniIcon, left: panelSize * 3 + 8, top: 8 },
    ])
    .png()
    .toFile(auditPath);
}

async function run() {
  const { positional, opts } = parseArgs(process.argv);
  if (positional.length < 2) {
    console.error('Usage: node cutout_3d_icon.js "<input.png>" "<output.webp>" [--size=256] [--pad=0.06] [--audit="<audit.png>"] [--hole-y-max=0.35]');
    process.exit(1);
  }

  const inputPath = path.resolve(positional[0]);
  const outputPath = path.resolve(positional[1]);
  const { data, info } = await sharp(inputPath)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });

  const W = info.width;
  const H = info.height;
  const N = W * H;

  // 1. Outer background flood-fill from all 4 borders
  const bgMask = new Uint8Array(N);
  const queue = new Int32Array(N);
  let head = 0;
  let tail = 0;

  const trySeed = (i) => {
    if (bgMask[i]) return;
    const p = i * 4;
    if (isNearWhiteOuter(data[p], data[p + 1], data[p + 2])) {
      bgMask[i] = 1;
      queue[tail++] = i;
    }
  };

  for (let x = 0; x < W; x++) {
    trySeed(x);
    trySeed((H - 1) * W + x);
  }
  for (let y = 0; y < H; y++) {
    trySeed(y * W);
    trySeed(y * W + (W - 1));
  }

  while (head < tail) {
    const cur = queue[head++];
    const x = cur % W;
    const y = (cur - x) / W;
    if (x > 0) trySeed(cur - 1);
    if (x < W - 1) trySeed(cur + 1);
    if (y > 0) trySeed(cur - W);
    if (y < H - 1) trySeed(cur + W);
  }

  // 2. Interior upper white hole removal (e.g., inside top calendar binding rings)
  const visited = new Uint8Array(N);
  const holeQueue = new Int32Array(N);
  for (let i = 0; i < N; i++) {
    if (bgMask[i] || visited[i]) continue;
    const p = i * 4;
    if (!isPureWhiteHole(data[p], data[p + 1], data[p + 2])) continue;

    let h = 0;
    let t = 0;
    visited[i] = 1;
    holeQueue[t++] = i;
    let sumY = 0;
    let maxY = 0;
    while (h < t) {
      const cur = holeQueue[h++];
      const x = cur % W;
      const y = (cur - x) / W;
      sumY += y;
      if (y > maxY) maxY = y;
      const pushHole = (ni) => {
        if (bgMask[ni] || visited[ni]) return;
        const np = ni * 4;
        if (isPureWhiteHole(data[np], data[np + 1], data[np + 2])) {
          visited[ni] = 1;
          holeQueue[t++] = ni;
        }
      };
      if (x > 0) pushHole(cur - 1);
      if (x < W - 1) pushHole(cur + 1);
      if (y > 0) pushHole(cur - W);
      if (y < H - 1) pushHole(cur + W);
    }

    const centroidY = sumY / t;
    if (t >= 64 && centroidY <= opts.holeYMax * H && maxY <= (opts.holeYMax + 0.08) * H) {
      // Distinguish true background holes (surrounded by darker inner ring/body edges)
      // from smooth specular highlights on bright silver surfaces (surrounded by lum ~235+).
      const inComp = new Set(holeQueue.subarray(0, t));
      const step = Math.max(2, Math.round(3 * (W / 2048)));
      let bLumSum = 0;
      let bCount = 0;
      let darkCount = 0;
      for (let k = 0; k < t; k++) {
        const c = holeQueue[k];
        const cx = c % W;
        const cy = (c - cx) / W;
        const neighbors = [
          cx >= step ? c - step : -1,
          cx + step < W ? c + step : -1,
          cy >= step ? c - step * W : -1,
          cy + step < H ? c + step * W : -1,
        ];
        for (const ni of neighbors) {
          if (ni >= 0 && !inComp.has(ni) && !bgMask[ni]) {
            const np = ni * 4;
            const lum = 0.299 * data[np] + 0.587 * data[np + 1] + 0.114 * data[np + 2];
            bLumSum += lum;
            bCount++;
            if (lum < 155) darkCount++;
          }
        }
      }
      const avgBorderLum = bCount > 0 ? bLumSum / bCount : 255;
      const darkFrac = bCount > 0 ? darkCount / bCount : 0;
      if (avgBorderLum < 215 && darkFrac >= 0.1) {
        for (let k = 0; k < t; k++) {
          bgMask[holeQueue[k]] = 1;
        }
      }
    }
  }

  // 3. Edge anti-fringe & white un-premultiplication
  const distFromBg = computeDistanceFromBg(bgMask, W, H, 4);
  const out = Buffer.from(data);

  for (let i = 0; i < N; i++) {
    const p = i * 4;
    if (bgMask[i]) {
      out[p + 3] = 0;
      continue;
    }

    const d = distFromBg[i];
    if (d <= 2) {
      const r = data[p];
      const g = data[p + 1];
      const b = data[p + 2];
      const minC = Math.min(r, g, b);
      const maxC = Math.max(r, g, b);
      const sat = maxC - minC;

      // Check local neighborhood luminance (excluding bg) to distinguish dark edges from bright silver rings
      const x = i % W;
      const y = (i - x) / W;
      let innerLumSum = 0;
      let innerCount = 0;
      for (let dy = -2; dy <= 2; dy++) {
        const ny = y + dy;
        if (ny < 0 || ny >= H) continue;
        for (let dx = -2; dx <= 2; dx++) {
          const nx = x + dx;
          if (nx < 0 || nx >= W) continue;
          const ni = ny * W + nx;
          if (!bgMask[ni] && distFromBg[ni] >= 2) {
            const np = ni * 4;
            innerLumSum += 0.299 * data[np] + 0.587 * data[np + 1] + 0.114 * data[np + 2];
            innerCount++;
          }
        }
      }
      const neighborLum = innerCount > 0 ? innerLumSum / innerCount : 128;
      const isBrightSilverZone = neighborLum > 165;

      let alpha = 1.0;
      if (d === 1) {
        if (isBrightSilverZone) {
          if (minC >= 235 && sat <= 14) {
            alpha = clamp((248 - minC) / 28, 0.08, 0.82);
          } else {
            alpha = clamp((252 - minC) / 50, 0.45, 0.96);
          }
        } else {
          if (minC >= 200 && sat <= 20) {
            alpha = clamp((238 - minC) / 56, 0.0, 0.65);
          } else {
            // Blended edge between dark/colored object and white background
            const whiteness = minC / 255;
            alpha = clamp(1.0 - Math.max(0, (whiteness - 0.35) * 1.15), 0.18, 0.95);
          }
        }
      } else if (d === 2 && !isBrightSilverZone && minC >= 210 && sat <= 18) {
        alpha = clamp((242 - minC) / 48, 0.15, 0.85);
      }

      if (alpha < 0.99) {
        const denom = Math.max(alpha, 0.15);
        out[p] = clamp(Math.round((r - (1 - alpha) * 255) / denom), 0, 255);
        out[p + 1] = clamp(Math.round((g - (1 - alpha) * 255) / denom), 0, 255);
        out[p + 2] = clamp(Math.round((b - (1 - alpha) * 255) / denom), 0, 255);
        out[p + 3] = clamp(Math.round(alpha * 255), 0, 255);
      }
    }
  }

  // 4. Tight bounding box of foreground (alpha > 20)
  let minX = W;
  let minY = H;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (out[(y * W + x) * 4 + 3] > 20) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (maxX < minX || maxY < minY) {
    throw new Error('Cutout produced empty foreground');
  }

  const bw = maxX - minX + 1;
  const bh = maxY - minY + 1;
  const side = Math.ceil(Math.max(bw, bh) / (1 - 2 * opts.pad));
  const left = Math.floor((side - bw) / 2);
  const top = Math.floor((side - bh) / 2);

  const cropped = await sharp(out, { raw: { width: W, height: H, channels: 4 } })
    .extract({ left: minX, top: minY, width: bw, height: bh })
    .png()
    .toBuffer();

  const compositedBuf = await sharp({
    create: {
      width: side,
      height: side,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .composite([{ input: cropped, left, top }])
    .png()
    .toBuffer();

  const squared = await sharp(compositedBuf)
    .resize(opts.size, opts.size, { kernel: sharp.kernel.lanczos3 })
    .webp({ quality: 92, alphaQuality: 100, effort: 6 })
    .toBuffer();

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, squared);

  if (opts.audit) {
    const auditPath = path.resolve(opts.audit);
    await renderAuditImage(squared, opts.size, auditPath);
    console.log(`Audit written: ${auditPath}`);
  }

  console.log(`Cutout written: ${outputPath} (${(squared.length / 1024).toFixed(2)} KB, ${opts.size}x${opts.size})`);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
