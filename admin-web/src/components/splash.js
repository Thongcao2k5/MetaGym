const WORD_CHARS = ['M', 'e', 't', 'a', 'G', 'y', 'm'];

function clamp(v, min = 0, max = 1) {
  return Math.max(min, Math.min(max, v));
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function easeOutCubic(t) {
  return 1 - Math.pow(1 - t, 3);
}

function easeInCubic(t) {
  return t * t * t;
}

function easeInQuad(t) {
  return t * t;
}

function easeInOutCubic(t) {
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
}

function easeInOutSine(t) {
  return -(Math.cos(Math.PI * t) - 1) / 2;
}

function easeOutBack(t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
}

function segment(t, start, end, curve) {
  if (t <= start) return 0;
  if (t >= end) return 1;
  const raw = (t - start) / (end - start);
  return curve ? curve(raw) : raw;
}

function mixColor(c1, c2, t) {
  const k = clamp(t);
  return `rgb(${Math.round(lerp(c1[0], c2[0], k))}, ${Math.round(lerp(c1[1], c2[1], k))}, ${Math.round(lerp(c1[2], c2[2], k))})`;
}

function drawRoundedRect(ctx, cx, cy, w, h, r) {
  const x = cx - w / 2;
  const y = cy - h / 2;
  const rad = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + rad, y);
  ctx.lineTo(x + w - rad, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + rad);
  ctx.lineTo(x + w, y + h - rad);
  ctx.quadraticCurveTo(x + w, y + h, x + w - rad, y + h);
  ctx.lineTo(x + rad, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - rad);
  ctx.lineTo(x, y + rad);
  ctx.quadraticCurveTo(x, y, x + rad, y);
  ctx.closePath();
}

function paintDirectionalCometDroplet(ctx, x, y, angle, length, radius) {
  if (length <= 0.5 || radius <= 0.3) return;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(angle);

  const aura = ctx.createRadialGradient(radius * 0.4, 0, 0, radius * 0.4, 0, radius * 2.8);
  aura.addColorStop(0, 'rgba(255, 184, 77, 0.4)');
  aura.addColorStop(0.55, 'rgba(255, 94, 54, 0.16)');
  aura.addColorStop(1, 'rgba(255, 94, 54, 0)');
  ctx.fillStyle = aura;
  ctx.beginPath();
  ctx.arc(radius * 0.4, 0, radius * 2.8, 0, Math.PI * 2);
  ctx.fill();

  ctx.beginPath();
  ctx.moveTo(-length, 0);
  ctx.bezierCurveTo(-length * 0.45, -radius * 0.38, -radius * 0.2, -radius, radius * 0.35, -radius);
  ctx.arc(radius * 0.35, 0, radius, -Math.PI / 2, Math.PI / 2, false);
  ctx.bezierCurveTo(-radius * 0.2, radius, -length * 0.45, radius * 0.38, -length, 0);
  ctx.closePath();

  const grad = ctx.createLinearGradient(radius * 1.35, 0, -length, 0);
  grad.addColorStop(0, '#FFF3D1');
  grad.addColorStop(0.38, '#FFB84D');
  grad.addColorStop(1, '#FF5E36');
  ctx.fillStyle = grad;
  ctx.fill();
  ctx.restore();
}

function paintFallingAndReboundingDroplet(ctx, cx, cy, progress) {
  const topY = cy - 78;
  const floorY = cy + 34;
  const restY = cy + 2;

  let currentY;
  let scaleX;
  let scaleY;
  let invertMorph;
  let warmMix;

  if (progress < 0.09) {
    const fallT = segment(progress, 0, 0.09, easeInQuad);
    currentY = lerp(topY, floorY, fallT);
    scaleX = lerp(0.42, 0.54, fallT);
    scaleY = lerp(0.55, 1.02, fallT);
    invertMorph = 0;
    warmMix = fallT * 0.25;
  } else if (progress < 0.12) {
    const squashT = segment(progress, 0.09, 0.12, easeOutCubic);
    const squashPulse = Math.sin(squashT * Math.PI);
    currentY = floorY + squashPulse * 3;
    scaleX = lerp(0.54, 0.84, squashPulse);
    scaleY = lerp(1.02, 0.54, squashPulse);
    invertMorph = squashT * 0.5;
    warmMix = 0.25 + squashT * 0.3;
  } else {
    const reboundT = segment(progress, 0.12, 0.16, easeOutCubic);
    currentY = lerp(floorY, restY, reboundT);
    scaleX = lerp(0.68, 1.0, reboundT);
    scaleY = lerp(0.68, 1.0, reboundT);
    invertMorph = 0.5 + reboundT * 0.5;
    warmMix = 0.55 + reboundT * 0.45;
  }

  ctx.save();
  ctx.translate(cx, currentY);
  ctx.scale(scaleX, scaleY);

  const aura = ctx.createRadialGradient(0, 0, 0, 0, 0, 26);
  aura.addColorStop(0, mixColor([255, 246, 224], [255, 140, 59], warmMix).replace('rgb', 'rgba').replace(')', ', 0.4)'));
  aura.addColorStop(1, 'rgba(255, 140, 59, 0)');
  ctx.fillStyle = aura;
  ctx.beginPath();
  ctx.arc(0, 0, 26, 0, Math.PI * 2);
  ctx.fill();

  let topShoulderX;
  let botBellyX;
  let topApexY;
  let botApexY;
  if (invertMorph <= 0.5) {
    const t = invertMorph / 0.5;
    topShoulderX = lerp(2.5, 14, t);
    botBellyX = lerp(15, 14, t);
    topApexY = lerp(-25, -14, t);
    botApexY = lerp(18, 14, t);
  } else {
    const t = (invertMorph - 0.5) / 0.5;
    topShoulderX = lerp(14, 16.5, t);
    botBellyX = lerp(14, 5.5, t);
    topApexY = lerp(-14, -18, t);
    botApexY = lerp(14, 22, t);
  }

  ctx.beginPath();
  ctx.moveTo(0, topApexY);
  ctx.bezierCurveTo(topShoulderX * 0.85, topApexY, topShoulderX, topApexY * 0.35, (topShoulderX + botBellyX) * 0.5, 0);
  ctx.bezierCurveTo(botBellyX, botApexY * 0.45, botBellyX * 0.75, botApexY, 0, botApexY);
  ctx.bezierCurveTo(-botBellyX * 0.75, botApexY, -botBellyX, botApexY * 0.45, -(topShoulderX + botBellyX) * 0.5, 0);
  ctx.bezierCurveTo(-topShoulderX, topApexY * 0.35, -topShoulderX * 0.85, topApexY, 0, topApexY);
  ctx.closePath();

  const fill = ctx.createLinearGradient(0, -24, 0, 24);
  fill.addColorStop(0, mixColor([255, 253, 247], [255, 94, 54], warmMix));
  fill.addColorStop(1, mixColor([255, 229, 180], [232, 78, 39], warmMix));
  ctx.fillStyle = fill;
  ctx.fill();
  ctx.restore();
}

function paintInvertedDropletAndAthlete(ctx, cx, cy, athleteMorph, flexWave, isLight = false) {
  ctx.save();
  ctx.translate(cx, cy);

  const m = clamp(athleteMorph, 0, 1);
  const overshoot = clamp(athleteMorph - 1, 0, 0.12);

  const fill = ctx.createLinearGradient(0, -56, 0, 44);
  fill.addColorStop(0, '#FF5E36');
  fill.addColorStop(0.68, '#FF5E36');
  fill.addColorStop(1, '#E84E27');
  ctx.fillStyle = fill;

  const topY = lerp(-18, -22, m);
  const botY = lerp(22, 40, m);
  const topW = lerp(16.5, 33 + flexWave * 1.6, m);
  const midW = lerp(13.5, 25 + flexWave * 1.0, m);

  ctx.beginPath();
  ctx.moveTo(0, topY);
  ctx.bezierCurveTo(topW * 0.58, topY, topW, topY + 3.5, topW * 0.96, topY + 15);
  ctx.bezierCurveTo(midW, 11, 10.5, botY - 6, 0, botY);
  ctx.bezierCurveTo(-10.5, botY - 6, -midW, 11, -topW * 0.96, topY + 15);
  ctx.bezierCurveTo(-topW, topY + 3.5, -topW * 0.58, topY, 0, topY);
  ctx.closePath();
  ctx.fill();

  if (m > 0.05) {
    const headT = segment(m, 0.05, 0.88, easeOutCubic);
    const headY = lerp(-10, -38.5 - overshoot * 14, headT);
    const headR = lerp(8, 12.5, headT);
    ctx.beginPath();
    ctx.arc(0, headY, headR, 0, Math.PI * 2);
    ctx.fill();
  }

  if (m > 0.04) {
    const spreadT = segment(m, 0.04, 0.55, easeOutCubic);
    const curlT = segment(m, 0.36, 1, easeOutBack);
    const curlClamped = clamp(curlT, 0, 1.15);

    for (const dir of [-1, 1]) {
      ctx.save();
      ctx.scale(dir, 1);

      const shoulderTopY = lerp(0, -20.5, spreadT);
      const shoulderBotY = lerp(12, -1.5, spreadT);
      const shoulderX = lerp(11, 23.5, spreadT);
      const elbowX = lerp(15, 55 + flexWave * 1.8, spreadT);
      const elbowY = lerp(12, lerp(6, -8 - flexWave * 1.2, curlT), spreadT);
      const wristX = lerp(lerp(17, 56, spreadT), 44 - flexWave * 1.2, curlClamped);
      const wristY = lerp(lerp(14, 2, spreadT), -34 - overshoot * 18 - flexWave * 1.8, curlClamped);
      const bicepPeakX = lerp(18, 37.5, spreadT);
      const bicepPeakY = lerp(4, -26 - flexWave * 2.4, clamp(curlT, 0, 1.1));

      // Muscular upper arm, bicep peak, and forearm tapering into wrist
      ctx.beginPath();
      ctx.moveTo(shoulderX, shoulderTopY);
      ctx.bezierCurveTo(bicepPeakX - 5, bicepPeakY, bicepPeakX + 4, bicepPeakY + 2, elbowX - 13, elbowY - 9.5);
      ctx.bezierCurveTo(elbowX - 12.5, lerp(elbowY - 3, wristY + 13, clamp(curlT)), wristX - 6.5, wristY + 4, wristX - 4.5, wristY);
      ctx.lineTo(wristX + 4.5, wristY + 1);
      ctx.bezierCurveTo(elbowX + 6.5, lerp(elbowY + 2, wristY + 18, clamp(curlT)), elbowX + 6, elbowY - 3, elbowX + 1.5, elbowY + 5);
      ctx.bezierCurveTo(elbowX - 6, elbowY + 11, shoulderX + 12, shoulderBotY + 3, shoulderX - 2, shoulderBotY);
      ctx.closePath();
      ctx.fill();

      // Clenched fist (nắm đấm)
      const fistScale = clamp(spreadT * 1.15, 0.25, 1);
      const fistAngle = lerp(0.15, -0.28, curlClamped);
      ctx.save();
      ctx.translate(wristX, wristY - 3.5 * fistScale);
      ctx.rotate(fistAngle);
      ctx.scale(fistScale, fistScale);

      // Fist silhouette with knuckle crown and tucked thumb
      ctx.beginPath();
      ctx.moveTo(-7.5, 4.5);
      ctx.bezierCurveTo(-9, 1.5, -9, -4.5, -6.5, -6.5);
      ctx.quadraticCurveTo(-4, -8.5, -1.5, -7);
      ctx.quadraticCurveTo(1, -8.5, 3.5, -7);
      ctx.quadraticCurveTo(6.5, -8.2, 8, -5.2);
      ctx.bezierCurveTo(9.5, -2.5, 9, 3, 6.5, 5.2);
      ctx.bezierCurveTo(4, 7, -3.5, 7, -7.5, 4.5);
      ctx.closePath();
      ctx.fill();

      // Subtle finger-curl & thumb crease so the fist reads clearly
      if (spreadT > 0.35) {
        ctx.strokeStyle = isLight ? 'rgba(245, 247, 250, 0.55)' : 'rgba(15, 17, 21, 0.48)';
        ctx.lineWidth = 1.5;
        ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.moveTo(-4.5, -1.5);
        ctx.quadraticCurveTo(0, -0.5, 4.5, -1.5);
        ctx.moveTo(-5.5, 2.2);
        ctx.quadraticCurveTo(-1.5, 3.8, 1.5, 1.2);
        ctx.stroke();
      }
      ctx.restore();

      ctx.restore();
    }
  }

  ctx.restore();
}

function paintCometDiveAndOrbit(ctx, cx, cy, stemX, stemY, stemW, stemH, progress) {
  if (progress < 0.485) {
    const diveT = segment(progress, 0.45, 0.485, easeInCubic);
    const y = lerp(cy + 2, cy + 34, diveT);
    const scale = lerp(1, 0.28, diveT);
    ctx.save();
    ctx.translate(cx, y);
    ctx.scale(scale, scale);
    paintInvertedDropletAndAthlete(ctx, 0, 0, 0, 0);
    ctx.restore();
    return;
  }

  const orbitT = segment(progress, 0.485, 0.615, easeInOutSine);
  const orbitPos = (t) => {
    const theta = Math.PI * 0.5 + t * Math.PI * 2.05;
    const rx = lerp(96, 108, Math.sin(t * Math.PI));
    const ry = lerp(54, 68, Math.sin(t * Math.PI));
    const rawX = cx + rx * Math.cos(theta);
    const rawY = cy + ry * Math.sin(theta);
    const landBlend = segment(t, 0.78, 1, easeInOutCubic);
    return { x: lerp(rawX, stemX, landBlend), y: lerp(rawY, stemY, landBlend) };
  };

  if (progress < 0.615) {
    const pos = orbitPos(orbitT);
    const pPrev = orbitPos(clamp(orbitT - 0.015));
    const pNext = orbitPos(clamp(orbitT + 0.015));
    const dx = pNext.x - pPrev.x;
    const dy = pNext.y - pPrev.y;
    const angle = Math.hypot(dx, dy) > 0.001 ? Math.atan2(dy, dx) : -Math.PI / 2;
    const stretch = 1 + 0.35 * Math.sin(orbitT * Math.PI);
    paintDirectionalCometDroplet(ctx, pos.x, pos.y, angle, 22 * stretch, 5.6);
  }

  if (progress >= 0.6) {
    const barT = segment(progress, 0.6, 0.63, easeOutCubic);
    const h = lerp(14, stemH, barT);
    ctx.fillStyle = '#FF5E36';
    drawRoundedRect(ctx, stemX, stemY, stemW, h, stemW / 2);
    ctx.fill();
  }
}

function drawTrimmedMStroke(ctx, leftX, midX, rightX, topY, botY, frac, alpha, stemW) {
  if (frac <= 0.001) return;
  const segments = [
    { x1: leftX, y1: topY + 1.5, x2: midX, y2: botY - 3 },
    { x1: midX, y1: botY - 3, x2: rightX, y2: topY + 1.5 },
    { x1: rightX, y1: topY + 1.5, x2: rightX, y2: botY },
  ];
  const lens = segments.map((s) => Math.hypot(s.x2 - s.x1, s.y2 - s.y1));
  const total = lens.reduce((a, b) => a + b, 0);
  const target = total * clamp(frac);

  ctx.save();
  ctx.strokeStyle = `rgba(255, 94, 54, ${alpha})`;
  ctx.lineWidth = stemW;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(segments[0].x1, segments[0].y1);

  let acc = 0;
  let tipX = segments[0].x1;
  let tipY = segments[0].y1;
  let tipAngle = 0;

  for (let i = 0; i < segments.length; i += 1) {
    const seg = segments[i];
    const len = lens[i];
    if (acc >= target) break;
    const remain = target - acc;
    const t = clamp(remain / len);
    const nx = lerp(seg.x1, seg.x2, t);
    const ny = lerp(seg.y1, seg.y2, t);
    ctx.lineTo(nx, ny);
    tipX = nx;
    tipY = ny;
    tipAngle = Math.atan2(seg.y2 - seg.y1, seg.x2 - seg.x1);
    acc += len;
  }
  ctx.stroke();
  ctx.restore();

  if (frac < 0.98 && frac > 0.02) {
    paintDirectionalCometDroplet(ctx, tipX, tipY, tipAngle, 14, 4.4);
  }
}

function renderMorphFrame(ctx, w, h, progress, pulse, isLight) {
  ctx.clearRect(0, 0, w, h);
  const cx = w / 2;
  const cy = h / 2 + 4;

  const auraRadius = lerp(52, 126, progress) + pulse * 6;
  const aura = ctx.createRadialGradient(cx, cy, 0, cx, cy, auraRadius);
  aura.addColorStop(0, 'rgba(255, 94, 54, 0.22)');
  aura.addColorStop(0.56, 'rgba(245, 176, 65, 0.08)');
  aura.addColorStop(1, 'rgba(255, 94, 54, 0)');
  ctx.fillStyle = aura;
  ctx.beginPath();
  ctx.arc(cx, cy, auraRadius, 0, Math.PI * 2);
  ctx.fill();

  ctx.font = '800 45px "Be Vietnam Pro", system-ui, -apple-system, "Segoe UI", sans-serif';
  ctx.textBaseline = 'middle';
  const charWidths = WORD_CHARS.map((ch) => ctx.measureText(ch).width);
  const totalWordWidth = charWidths.reduce((sum, cw, i) => sum + cw + (i < WORD_CHARS.length - 1 ? 1.2 : 0), 0);
  const wordStartX = cx - totalWordWidth / 2;
  const charXs = [];
  let cursorX = wordStartX;
  for (const cw of charWidths) {
    charXs.push(cursorX);
    cursorX += cw + 1.2;
  }

  const mLeftStemX = charXs[0] + 4.5;
  const mRightStemX = charXs[0] + charWidths[0] - 4.5;
  const mMidX = charXs[0] + charWidths[0] / 2;
  const mTopY = cy - 17.5;
  const mBotY = cy + 17.5;
  const stemW = 7.4;

  if (progress < 0.16) {
    paintFallingAndReboundingDroplet(ctx, cx, cy, progress);
  }

  if (progress >= 0.16 && progress < 0.45) {
    const sproutT = segment(progress, 0.16, 0.26, easeOutBack);
    const collapseT = segment(progress, 0.37, 0.45, easeInOutCubic);
    const athleteMorph = clamp(sproutT * (1 - collapseT), 0, 1.08);
    const flexWave = progress >= 0.26 && progress < 0.37 ? Math.sin(segment(progress, 0.26, 0.37) * Math.PI) : 0;
    paintInvertedDropletAndAthlete(ctx, cx, cy + 2 - flexWave * 2.5, athleteMorph, flexWave, isLight);
  }

  if (progress >= 0.45 && progress < 0.635) {
    paintCometDiveAndOrbit(ctx, cx, cy, mLeftStemX, cy, stemW, mBotY - mTopY, progress);
  }

  if (progress >= 0.62) {
    const mDrawProg = segment(progress, 0.62, 0.74, easeInOutCubic);
    const mCrossfade = segment(progress, 0.7, 0.78, easeOutCubic);

    if (mCrossfade < 0.99) {
      const strokeAlpha = 1 - mCrossfade * 0.85;
      ctx.fillStyle = `rgba(255, 94, 54, ${strokeAlpha})`;
      drawRoundedRect(ctx, mLeftStemX, cy, stemW, mBotY - mTopY, stemW / 2);
      ctx.fill();
      drawTrimmedMStroke(ctx, mLeftStemX, mMidX, mRightStemX, mTopY, mBotY, mDrawProg, strokeAlpha, stemW);
    }

    if (mCrossfade > 0.01) {
      ctx.fillStyle = `rgba(255, 94, 54, ${mCrossfade})`;
      ctx.fillText('M', charXs[0], cy);
    }

    const timings = [
      [0.7, 0.78],
      [0.73, 0.81],
      [0.76, 0.84],
      [0.8, 0.89],
      [0.84, 0.92],
      [0.88, 0.96],
    ];

    for (let i = 1; i < WORD_CHARS.length; i += 1) {
      const [startT, endT] = timings[i - 1];
      const t = segment(progress, startT, endT, easeOutCubic);
      if (t <= 0.001) continue;

      const ch = WORD_CHARS[i];
      const isG = ch === 'G';
      const baseRgb = isG ? [255, 94, 54] : (isLight ? [17, 21, 26] : [247, 249, 252]);
      const cw = charWidths[i];
      const slideX = (1 - t) * -8;
      const slideY = (1 - t) * 8;
      const scale = 0.86 + 0.14 * easeOutBack(t);
      const charCx = charXs[i] + cw / 2 + slideX;
      const charCy = cy + slideY;

      ctx.save();
      ctx.translate(charCx, charCy);
      ctx.scale(scale, scale);
      ctx.fillStyle = `rgba(${baseRgb[0]}, ${baseRgb[1]}, ${baseRgb[2]}, ${clamp(t)})`;
      ctx.fillText(ch, -cw / 2, 0);
      ctx.restore();

      if (t > 0.04 && t < 0.92) {
        const tipAngle = -Math.PI * 0.75 + t * Math.PI * 1.35;
        const tipX = charCx + Math.cos(tipAngle) * (cw * 0.36);
        const tipY = charCy + Math.sin(tipAngle) * 12;
        paintDirectionalCometDroplet(ctx, tipX, tipY, tipAngle + Math.PI * 0.5, 11 * Math.sin(t * Math.PI), 4.2 * Math.sin(t * Math.PI));
      }
    }

    const underlineProg = segment(progress, 0.86, 0.98, easeOutCubic);
    if (underlineProg > 0.01) {
      const lineStart = wordStartX;
      const lineEnd = wordStartX + totalWordWidth * underlineProg;
      const lineY = cy + 32;
      const uGrad = ctx.createLinearGradient(lineStart, lineY, lineEnd, lineY);
      uGrad.addColorStop(0, '#FF5E36');
      uGrad.addColorStop(0.72, '#F5B041');
      uGrad.addColorStop(1, 'rgba(255, 94, 54, 0)');
      ctx.save();
      ctx.strokeStyle = uGrad;
      ctx.lineWidth = 2.6;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(lineStart, lineY);
      ctx.lineTo(lineEnd, lineY);
      ctx.stroke();
      ctx.restore();
    }
  }
}

export function playAppSplash(onDone) {
  const splashEl = document.querySelector('#app .app-splash');
  const canvas = splashEl?.querySelector('#splash-canvas');
  const subEl = splashEl?.querySelector('.app-splash-sub');
  const trackEl = splashEl?.querySelector('.app-splash-track');
  const reducedMotion = globalThis.window?.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches;

  if (!splashEl || !canvas || reducedMotion) {
    onDone();
    return;
  }

  const width = 310;
  const height = 204;
  const displayWidth = 480;
  const displayHeight = 316;
  const dpr = Math.min(globalThis.window?.devicePixelRatio || 1, 2);
  canvas.width = displayWidth * dpr;
  canvas.height = displayHeight * dpr;
  const ctx = canvas.getContext('2d');
  if (!ctx) {
    onDone();
    return;
  }
  ctx.scale((displayWidth / width) * dpr, (displayHeight / height) * dpr);

  const isLight = document.documentElement.getAttribute('data-bs-theme') === 'light';
  const durationMs = 3600;
  const holdMs = 550;
  const startTime = performance.now();

  const frame = (now) => {
    const elapsed = now - startTime;
    const progress = clamp(elapsed / durationMs);
    const pulse = 0.5 - 0.5 * Math.cos(((elapsed % 2000) / 2000) * Math.PI * 2);

    renderMorphFrame(ctx, width, height, progress, pulse, isLight);

    const subOpacity = segment(progress, 0.74, 0.96, easeOutCubic);
    const barOpacity = segment(progress, 0.8, 1, easeOutCubic);
    if (subEl) {
      subEl.style.opacity = String(subOpacity);
      subEl.style.transform = `translateY(${(1 - subOpacity) * 10}px)`;
    }
    if (trackEl) {
      trackEl.style.opacity = String(barOpacity);
      trackEl.style.transform = `translateY(${(1 - barOpacity) * 8}px)`;
    }

    if (elapsed < durationMs + holdMs) {
      requestAnimationFrame(frame);
    } else {
      onDone();
    }
  };

  requestAnimationFrame(frame);
}
