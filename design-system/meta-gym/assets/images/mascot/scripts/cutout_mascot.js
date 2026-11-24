#!/usr/bin/env node
/**
 * Meta Kong Mascot — Precision Transparent Cutout Tool (v3 Spatial Watertight Outline)
 * ------------------------------------------------------------------------------------
 * Tách nền chuẩn cho ảnh linh vật Meta Kong nền tối + quầng sáng cam-nâu xuyên tâm,
 * giữ nguyên 100% viền mực đen đậm, bóng đổ đĩa tạ / đồ vật kim loại tối màu,
 * xóa sạch quầng nâu thừa, bóng đổ dưới đế giày và viền đen rác quanh tia sáng bay.
 *
 * Cách dùng:
 *   1) Tách nền 1 ảnh mới:
 *      node design-system/meta-gym/assets/images/mascot/scripts/cutout_mascot.js "<input.jpg>" "<output.webp>" [--audit] [--no-holes] [--protect-top-badge] [--seal-box=0.14,0.21,0.31,0.39] [--size=512]
 *
 *   2) Dựng lại bảng tổng quan Dark + Light Mode từ toàn bộ file *.webp trong thư mục mascot/:
 *      node design-system/meta-gym/assets/images/mascot/scripts/cutout_mascot.js --sheet
 */

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '../../../../../..');
const mascotDir = path.resolve(__dirname, '..');
const sharp = require(path.join(repoRoot, 'backend/node_modules/sharp'));

function distanceTransform(mask, W, H) {
  const N = W * H;
  const INF = 100000;
  const dist = new Int32Array(N).fill(INF);
  for (let i = 0; i < N; i++) if (mask[i]) dist[i] = 0;

  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = y * W + x;
      let d = dist[i];
      if (d === 0) continue;
      if (x > 0) d = Math.min(d, dist[i - 1] + 10);
      if (y > 0) {
        d = Math.min(d, dist[i - W] + 10);
        if (x > 0) d = Math.min(d, dist[i - W - 1] + 14);
        if (x < W - 1) d = Math.min(d, dist[i - W + 1] + 14);
      }
      dist[i] = d;
    }
  }
  for (let y = H - 1; y >= 0; y--) {
    for (let x = W - 1; x >= 0; x--) {
      const i = y * W + x;
      let d = dist[i];
      if (d === 0) continue;
      if (x < W - 1) d = Math.min(d, dist[i + 1] + 10);
      if (y < H - 1) {
        d = Math.min(d, dist[i + W] + 10);
        if (x < W - 1) d = Math.min(d, dist[i + W + 1] + 14);
        if (x > 0) d = Math.min(d, dist[i + W - 1] + 14);
      }
      dist[i] = d;
    }
  }
  return dist;
}

/**
 * Spatial + chromatic foreground classifier tailored to Meta Kong artworks
 * (Graphite/Cool-slate fur + Coral Orange accessories + White soles on obsidian/rust radial glow).
 */
function isForegroundPixel(r, g, b, x, y, W, H) {
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const lum = 0.299 * r + 0.587 * g + 0.114 * b;
  const rad = Math.hypot(x - W * 0.5, y - H * 0.52) / (W / 1024);

  // 1. Bright highlights, white soles, eyes, clipboard, sparks, wrench, flame
  if (lum > 118) return true;

  // 2. Cool slate / graphite fur / rim light / face / chest / abs / dark metal
  if (b >= r && b >= 28 && lum >= 23) return true;
  if (b >= r - 2 && b >= 34 && lum >= 28) return true;

  // 3. Mid-tone neutral grays (wrench, barbell bar, clipboard shadow)
  if (min >= 42 && (max - min) <= 22) return true;

  // 4. Warm cheek blush / tongue (higher B than rust glow)
  if (r > 135 && g > 60 && b > 48) return true;

  // 5. Vivid Coral Orange / Amber / Gold foreground anywhere
  if (r > 186 && (r - b) > 60) return true;
  if (r > 145 && g > 84 && (r - b) > 45) return true;

  // 6. Outer-zone shaded red-orange/bronze (barbell undersides, shoes, outer props — excludes dark brown glow R<138)
  if (rad > 325 && r > 138 && (r - b) > 58) return true;

  // 7. Mid-outer zone (background glow never exceeds R > 135 here)
  if (rad > 270 && r > 148 && (r - b) > 62) return true;

  return false;
}

function isSmoothBgColor(r, g, b, x, y, W, H) {
  const rad = Math.hypot(x - W * 0.5, y - H * 0.52) / (W / 1024);
  if (r <= 25 && g <= 25 && b <= 33) return true;
  const maxRustR = rad < 290 ? 182 : (rad < 360 ? 128 : 68);
  const maxRustG = rad < 290 ? 80 : (rad < 360 ? 54 : 32);
  if (r > b + 5 && r <= maxRustR && g <= maxRustG && b <= 42) return true;
  return false;
}

async function cutoutMascot(inputPath, outputPath, opts = {}) {
  const {
    allowHoles = true,
    protectTopBadge = false,
    sealBox = null, // [x0, y0, x1, y1] normalized 0..1 for dark bronze/metal solid props
    size = 512,
    audit = false,
  } = opts;

  const { data, info } = await sharp(inputPath).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const W = info.width;
  const H = info.height;
  const N = W * H;
  const scale = W / 1024;

  // Step 1: Core foreground mask
  const fgRaw = new Uint8Array(N);
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = y * W + x;
      const p = i * 4;
      if (isForegroundPixel(data[p], data[p + 1], data[p + 2], x, y, W, H)) fgRaw[i] = 1;
    }
  }

  // Step 2: Denoise 1-2px JPEG specks
  const fgCore = new Uint8Array(N);
  for (let y = 1; y < H - 1; y++) {
    for (let x = 1; x < W - 1; x++) {
      const i = y * W + x;
      if (!fgRaw[i]) continue;
      let cnt = 0;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) cnt += fgRaw[(y + dy) * W + (x + dx)];
      }
      if (cnt >= 4) fgCore[i] = 1;
    }
  }

  // Step 3: Split connected components into Major Outlined Shapes vs Minor Floating Accents
  const compId = new Int32Array(N).fill(-1);
  const compSizes = [];
  const compBright = [];
  const q = new Int32Array(N);
  let nextComp = 0;

  for (let i = 0; i < N; i++) {
    if (!fgCore[i] || compId[i] !== -1) continue;
    let head = 0, tail = 0;
    let sumLum = 0, sumR = 0;
    compId[i] = nextComp;
    q[tail++] = i;
    while (head < tail) {
      const cur = q[head++];
      const p = cur * 4;
      sumR += data[p];
      sumLum += 0.299 * data[p] + 0.587 * data[p + 1] + 0.114 * data[p + 2];
      const x = cur % W, y = (cur - x) / W;
      const push = (ni) => {
        if (fgCore[ni] && compId[ni] === -1) {
          compId[ni] = nextComp;
          q[tail++] = ni;
        }
      };
      if (x > 0) push(cur - 1);
      if (x < W - 1) push(cur + 1);
      if (y > 0) push(cur - W);
      if (y < H - 1) push(cur + W);
    }
    compSizes.push(tail);
    compBright.push((sumLum / tail) >= 75 || (sumR / tail) >= 135);
    nextComp++;
  }

  const majorFg = new Uint8Array(N);
  const minorFg = new Uint8Array(N);
  const minMajorArea = Math.round(1200 * scale * scale);
  const minMinorArea = Math.round(25 * scale * scale);

  for (let i = 0; i < N; i++) {
    const cid = compId[i];
    if (cid === -1) continue;
    if (compSizes[cid] >= minMajorArea) majorFg[i] = 1;
    else if (compSizes[cid] >= minMinorArea && compBright[cid]) minorFg[i] = 1;
  }

  const distMajor = distanceTransform(majorFg, W, H);
  const distMinor = distanceTransform(minorFg, W, H);

  // Per-column white sneaker sole detection to cleanly strip flat ground shadow below soles
  const whiteSoleMaxY = new Int32Array(W).fill(0);
  let globalMaxSoleY = 0;
  for (let y = Math.floor(H * 0.78); y < H; y++) {
    for (let x = Math.floor(W * 0.14); x < Math.floor(W * 0.86); x++) {
      const p = (y * W + x) * 4;
      if (data[p] > 185 && data[p + 1] > 175 && data[p + 2] > 160) {
        if (y > whiteSoleMaxY[x]) whiteSoleMaxY[x] = y;
        if (y > globalMaxSoleY) globalMaxSoleY = y;
      }
    }
  }
  const soleColLimit = new Int32Array(W).fill(0);
  const soleSpread = Math.max(2, Math.round(4 * scale));
  for (let x = 0; x < W; x++) {
    let m = 0;
    for (let dx = -soleSpread; dx <= soleSpread; dx++) {
      const nx = x + dx;
      if (nx >= 0 && nx < W && whiteSoleMaxY[nx] > m) m = whiteSoleMaxY[nx];
    }
    soleColLimit[x] = m;
  }

  // Step 4: Build watertight barrier mask (keeps crisp dark-ink outline on Major shapes, zero black halo on Minor sparks)
  const isBarrier = new Uint8Array(N);
  const inkDist = Math.round(92 * scale);

  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = y * W + x;
      if (majorFg[i] || minorFg[i]) {
        if (globalMaxSoleY > 0 && y > globalMaxSoleY - Math.round(6 * scale) && soleColLimit[x] === 0) continue;
        isBarrier[i] = 1;
        continue;
      }
      const p = i * 4;
      const r = data[p], g = data[p + 1], b = data[p + 2];
      const isWarmRust = (r - b) > 7 && r > 24;
      const isBlackInk = (r < 35 && g < 37 && b < 47 && !isWarmRust);

      if (distMajor[i] <= inkDist && isBlackInk) {
        if (y > H * 0.84) {
          const colMax = soleColLimit[x];
          if (colMax === 0) continue;
          if (y > colMax + Math.round(4.5 * scale)) continue;
        }
        isBarrier[i] = 1;
      } else if (distMajor[i] <= Math.round(25 * scale) && !isWarmRust && !isSmoothBgColor(r, g, b, x, y, W, H)) {
        if (y > H * 0.84 && (soleColLimit[x] === 0 || y > soleColLimit[x] + Math.round(4.5 * scale))) continue;
        isBarrier[i] = 1;
      } else if (distMinor[i] <= Math.round(18 * scale) && !isSmoothBgColor(r, g, b, x, y, W, H) && (r > 35 || g > 35 || b > 38)) {
        isBarrier[i] = 1;
      }
    }
  }

  // Optional scanline seal for solid dark-bronze / metallic props (e.g. trophy cup)
  if (sealBox && sealBox.length === 4) {
    const x0 = Math.floor(W * sealBox[0]);
    const y0 = Math.floor(H * sealBox[1]);
    const x1 = Math.floor(W * sealBox[2]);
    const y1 = Math.floor(H * sealBox[3]);
    for (let y = y0; y <= y1; y++) {
      let minX = -1, maxX = -1;
      for (let x = x0; x <= x1; x++) {
        if (isBarrier[y * W + x]) {
          if (minX === -1) minX = x;
          maxX = x;
        }
      }
      if (minX !== -1 && maxX > minX + 10) {
        for (let x = minX; x <= maxX; x++) isBarrier[y * W + x] = 1;
      }
    }
  }

  // Step 5: Strict exterior flood-fill from all 4 edges
  const exterior = new Uint8Array(N);
  let head = 0, tail = 0;
  const enqueue = (idx) => {
    if (!exterior[idx] && !isBarrier[idx]) {
      exterior[idx] = 1;
      q[tail++] = idx;
    }
  };
  for (let x = 0; x < W; x++) { enqueue(x); enqueue((H - 1) * W + x); }
  for (let y = 0; y < H; y++) { enqueue(y * W); enqueue(y * W + (W - 1)); }

  while (head < tail) {
    const i = q[head++];
    const x = i % W, y = (i - x) / W;
    if (x > 0) enqueue(i - 1);
    if (x < W - 1) enqueue(i + 1);
    if (y > 0) enqueue(i - W);
    if (y < H - 1) enqueue(i + W);
  }

  // Step 6: Clear true enclosed background pockets (e.g. gap between arms/head/cables; >= 800px protects pupils/keyholes)
  if (allowHoles) {
    const visitedHole = new Uint8Array(N);
    const minHoleArea = Math.round(800 * scale * scale);
    for (let i = 0; i < N; i++) {
      if (exterior[i] || isBarrier[i] || visitedHole[i]) continue;
      head = 0; tail = 0;
      visitedHole[i] = 1;
      q[tail++] = i;
      let bgMatch = 0, sumX = 0, sumY = 0;
      while (head < tail) {
        const cur = q[head++];
        const x = cur % W, y = (cur - x) / W;
        sumX += x; sumY += y;
        const p = cur * 4;
        if (isSmoothBgColor(data[p], data[p + 1], data[p + 2], x, y, W, H)) bgMatch++;
        const push = (ni) => {
          if (!exterior[ni] && !isBarrier[ni] && !visitedHole[ni]) {
            visitedHole[ni] = 1;
            q[tail++] = ni;
          }
        };
        if (x > 0) push(cur - 1);
        if (x < W - 1) push(cur + 1);
        if (y > 0) push(cur - W);
        if (y < H - 1) push(cur + W);
      }
      const area = tail;
      const cxP = sumX / area, cyP = sumY / area;
      const isTopBadge = (protectTopBadge && cyP < H * 0.25 && cxP > W * 0.34 && cxP < W * 0.66);
      if (!isTopBadge && area >= minHoleArea && (bgMatch / area) >= 0.85) {
        for (let k = 0; k < tail; k++) exterior[q[k]] = 1;
      }
    }
  }

  // Step 7: Remove stray disconnected foreground specks (< 95px, or < 450px below shoes)
  const fgVis = new Uint8Array(N);
  const minKeepArea = Math.round(95 * scale * scale);
  const minShoeBottomArea = Math.round(450 * scale * scale);
  for (let i = 0; i < N; i++) {
    if (exterior[i] || fgVis[i]) continue;
    head = 0; tail = 0;
    fgVis[i] = 1;
    q[tail++] = i;
    let sumY = 0;
    while (head < tail) {
      const cur = q[head++];
      const x = cur % W, y = (cur - x) / W;
      sumY += y;
      const push = (ni) => {
        if (!exterior[ni] && !fgVis[ni]) {
          fgVis[ni] = 1;
          q[tail++] = ni;
        }
      };
      if (x > 0) push(cur - 1);
      if (x < W - 1) push(cur + 1);
      if (y > 0) push(cur - W);
      if (y < H - 1) push(cur + W);
    }
    const avgY = sumY / tail;
    const reqArea = avgY > H * 0.86 ? minShoeBottomArea : minKeepArea;
    if (tail < reqArea) {
      for (let k = 0; k < tail; k++) exterior[q[k]] = 1;
    }
  }

  // Step 8: 1px boundary anti-aliasing + edge rust decontamination
  const alphaRaw = new Uint8Array(N);
  for (let i = 0; i < N; i++) alphaRaw[i] = exterior[i] ? 0 : 255;

  const alphaSmooth = new Uint8Array(alphaRaw);
  for (let y = 1; y < H - 1; y++) {
    for (let x = 1; x < W - 1; x++) {
      const i = y * W + x;
      let sum = 0, has0 = false, has255 = false;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          const v = alphaRaw[(y + dy) * W + (x + dx)];
          sum += v;
          if (v === 0) has0 = true;
          if (v === 255) has255 = true;
        }
      }
      if (has0 && has255) alphaSmooth[i] = Math.round(sum / 9);
    }
  }

  const outBuf = Buffer.from(data);
  for (let i = 0; i < N; i++) {
    const p = i * 4;
    const a = alphaSmooth[i];
    outBuf[p + 3] = a;
    if (a > 0 && a < 245) {
      const r = outBuf[p], g = outBuf[p + 1], b = outBuf[p + 2];
      if (r < 70 && g < 46 && b < 46) {
        outBuf[p] = 13;
        outBuf[p + 1] = 17;
        outBuf[p + 2] = 25;
      }
    }
  }

  // Step 9: Trim & pad uniformly into square Transparent WebP (89.8% optical live area)
  const trimmed = await sharp(outBuf, { raw: { width: W, height: H, channels: 4 } })
    .trim({ threshold: 15 })
    .png()
    .toBuffer({ resolveWithObject: true });

  const tw = trimmed.info.width;
  const th = trimmed.info.height;
  const targetBox = Math.round(size * 0.898);
  const fitScale = Math.min(targetBox / tw, targetBox / th);
  const nw = Math.round(tw * fitScale);
  const nh = Math.round(th * fitScale);

  const resized = await sharp(trimmed.data)
    .resize(nw, nh, { kernel: 'lanczos3' })
    .png()
    .toBuffer();

  const left = Math.round((size - nw) / 2);
  const top = Math.round((size - nh) / 2);

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  await sharp({
    create: { width: size, height: size, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
  })
    .composite([{ input: resized, left, top }])
    .webp({ quality: 93, alphaQuality: 100, effort: 6 })
    .toFile(outputPath);

  const kb = (fs.statSync(outputPath).size / 1024).toFixed(1);
  console.log(`OK: ${path.basename(outputPath)} (${size}x${size}, ${kb} KB | trimmed ${tw}x${th} -> ${nw}x${nh})`);

  if (audit) {
    const auditPath = outputPath.replace(/\.webp$/i, '_audit.png');
    const chk = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="540" height="540">
      <defs><pattern id="c" width="24" height="24" patternUnits="userSpaceOnUse">
        <rect width="24" height="24" fill="#FFFFFF"/><rect width="12" height="12" fill="#E6ECF4"/><rect x="12" y="12" width="12" height="12" fill="#E6ECF4"/>
      </pattern></defs>
      <rect width="540" height="540" fill="url(#c)"/>
    </svg>`);
    const pngBuf = await sharp(outputPath).resize(512, 512).png().toBuffer();
    await sharp(chk).composite([{ input: pngBuf, left: 14, top: 14 }]).png().toFile(auditPath);
    console.log(`Audit checkerboard saved: ${auditPath}`);
  }
}

async function rebuildStudioSheet() {
  const webps = fs.readdirSync(mascotDir)
    .filter((f) => f.endsWith('.webp'))
    .sort((a, b) => {
      const order = ['hero', 'empty', 'offline', 'error', 'loading', 'streak'];
      const ia = order.findIndex((k) => a.includes(k));
      const ib = order.findIndex((k) => b.includes(k));
      return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib) || a.localeCompare(b);
    });

  if (!webps.length) {
    console.log('No .webp files found in', mascotDir);
    return;
  }

  const cardW = 280, cardH = 318, gap = 20, startX = 30;
  const W = Math.max(1200, startX * 2 + webps.length * cardW + (webps.length - 1) * gap);
  const H = 820;
  const darkY = 98, lightY = 462;

  const cardsSvg = webps.map((file, i) => {
    const x = startX + i * (cardW + gap);
    const label = `${i + 1}. ` + file.replace(/^meta_kong_/, '').replace(/\.webp$/, '').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
    return `
      <rect x="${x}" y="${darkY}" width="${cardW}" height="${cardH}" rx="24" fill="#181B22" stroke="#262A34" stroke-width="1.5"/>
      <text x="${x + cardW / 2}" y="${darkY + 272}" text-anchor="middle" fill="#FFFFFF" font-family="Segoe UI, Arial, sans-serif" font-size="15" font-weight="700">${label}</text>
      <text x="${x + cardW / 2}" y="${darkY + 294}" text-anchor="middle" fill="#8C95A6" font-family="Segoe UI, Arial, sans-serif" font-size="11.5">${file}</text>
      <rect x="${x}" y="${lightY}" width="${cardW}" height="${cardH}" rx="24" fill="#FFFFFF" stroke="#CFD9E8" stroke-width="1.5"/>
      <text x="${x + cardW / 2}" y="${lightY + 272}" text-anchor="middle" fill="#0F172A" font-family="Segoe UI, Arial, sans-serif" font-size="15" font-weight="700">${label}</text>
      <text x="${x + cardW / 2}" y="${lightY + 294}" text-anchor="middle" fill="#5A677C" font-family="Segoe UI, Arial, sans-serif" font-size="11.5">${file}</text>
    `;
  }).join('\n');

  const sheetBg = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
    <rect width="${W}" height="${H}" fill="#0F1115"/>
    <text x="30" y="44" fill="#FFFFFF" font-family="Segoe UI, Arial, sans-serif" font-size="24" font-weight="800">META KONG — Bộ Linh Vật Chính Thức (Studio WebP Nền Trong Suốt)</text>
    <text x="30" y="70" fill="#8C95A6" font-family="Segoe UI, Arial, sans-serif" font-size="13.5">Hàng trên: Dark Mode (#0F1115 / #181B22) · Hàng dưới: Light Mode (#DCE5F1 / #FFFFFF) · ${webps.length} tư thế · 512×512 Transparent WebP</text>
    <rect x="14" y="442" width="${W - 28}" height="358" rx="30" fill="#DCE5F1"/>
    ${cardsSvg}
  </svg>`);

  const comps = [];
  for (let i = 0; i < webps.length; i++) {
    const x = startX + i * (cardW + gap) + Math.round((cardW - 228) / 2);
    const png = await sharp(path.join(mascotDir, webps[i])).resize(228, 228).png().toBuffer();
    comps.push({ input: png, left: x, top: darkY + 16 });
    comps.push({ input: png, left: x, top: lightY + 16 });
  }

  const sheetPath = path.join(mascotDir, 'meta_kong_studio_sheet.png');
  await sharp(sheetBg).composite(comps).png().toFile(sheetPath);
  console.log(`Studio sheet updated (${webps.length} mascots): ${sheetPath}`);
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--sheet')) {
    await rebuildStudioSheet();
    return;
  }
  const positional = args.filter((a) => !a.startsWith('--'));
  if (positional.length < 2) {
    console.log('Usage:\n  node cutout_mascot.js <input.jpg> <output.webp> [--audit] [--no-holes] [--protect-top-badge] [--seal-box=x0,y0,x1,y1] [--size=512]\n  node cutout_mascot.js --sheet');
    process.exit(1);
  }
  const [inputPath, outputPath] = positional;
  const sizeArg = args.find((a) => a.startsWith('--size='));
  const sealArg = args.find((a) => a.startsWith('--seal-box='));
  await cutoutMascot(path.resolve(inputPath), path.resolve(outputPath), {
    allowHoles: !args.includes('--no-holes'),
    protectTopBadge: args.includes('--protect-top-badge'),
    sealBox: sealArg ? sealArg.split('=')[1].split(',').map(Number) : null,
    size: sizeArg ? parseInt(sizeArg.split('=')[1], 10) : 512,
    audit: args.includes('--audit'),
  });
}

module.exports = { cutoutMascot, rebuildStudioSheet };

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
