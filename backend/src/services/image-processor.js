import { createHash } from 'node:crypto';

import sharp from 'sharp';

import { detectImageType, sanitizeSvg } from './image-validation.js';

const DEFAULT_ALLOWED = new Set(['jpeg', 'png', 'webp', 'avif', 'gif', 'svg']);

const FORMAT_META = {
  jpeg: { mimeType: 'image/jpeg', extension: 'jpg' },
  png: { mimeType: 'image/png', extension: 'png' },
  webp: { mimeType: 'image/webp', extension: 'webp' },
  avif: { mimeType: 'image/avif', extension: 'avif' },
  gif: { mimeType: 'image/gif', extension: 'gif' },
  svg: { mimeType: 'image/svg+xml', extension: 'svg' },
};

function parseSvgDimensions(svgString) {
  const widthMatch = /\bwidth\s*=\s*["']\s*(\d+(?:\.\d+)?)/i.exec(svgString);
  const heightMatch = /\bheight\s*=\s*["']\s*(\d+(?:\.\d+)?)/i.exec(svgString);
  const width = widthMatch ? Math.max(1, Math.round(Number(widthMatch[1]))) : null;
  const height = heightMatch ? Math.max(1, Math.round(Number(heightMatch[1]))) : null;
  if (width && height) return { width, height };
  const viewBox = /\bviewBox\s*=\s*["']\s*[\d.-]+\s+[\d.-]+\s+([\d.]+)\s+([\d.]+)/i.exec(svgString);
  if (viewBox) {
    return {
      width: Math.max(1, Math.round(Number(viewBox[1]))),
      height: Math.max(1, Math.round(Number(viewBox[2]))),
    };
  }
  return { width: null, height: null };
}

function extractSafeExif(metadata, stripGpsExif = false) {
  const exif = {
    format: metadata.format ?? null,
    space: metadata.space ?? null,
    channels: metadata.channels ?? null,
    depth: metadata.depth ?? null,
    density: metadata.density ?? null,
    hasAlpha: Boolean(metadata.hasAlpha),
    orientation: metadata.orientation ?? null,
    pages: metadata.pages ?? 1,
    hasIccProfile: Boolean(metadata.icc),
  };
  if (!stripGpsExif && metadata.exif) {
    exif.hasExifBuffer = true;
    exif.exifByteLength = metadata.exif.length;
  }
  return exif;
}

/**
 * Validates, hashes, extracts metadata, and generates thumbnail + optional optimized variants.
 */
export async function processUploadedImage(
  inputBuffer,
  {
    originalFilename = 'image',
    allowedFormats = DEFAULT_ALLOWED,
    maxFileSizeBytes = 10 * 1024 * 1024,
    thumbnailSize = 400,
    generateWebp = false,
    generateAvif = false,
    quality = 82,
    stripGpsExif = false,
  } = {},
) {
  if (!Buffer.isBuffer(inputBuffer) || inputBuffer.length === 0) {
    throw Object.assign(new Error('Tệp ảnh rỗng hoặc không hợp lệ.'), { code: 'VALIDATION_ERROR', status: 422 });
  }
  if (inputBuffer.length > maxFileSizeBytes) {
    throw Object.assign(new Error('Dung lượng ảnh vượt quá giới hạn cho phép.'), { code: 'PAYLOAD_TOO_LARGE', status: 413 });
  }

  const detected = detectImageType(inputBuffer);
  if (!detected) {
    throw Object.assign(new Error('Định dạng file không hợp lệ hoặc không phải ảnh được hỗ trợ.'), { code: 'INVALID_MIME_TYPE', status: 422 });
  }

  const allowedSet = allowedFormats instanceof Set
    ? allowedFormats
    : new Set((Array.isArray(allowedFormats) ? allowedFormats : [...DEFAULT_ALLOWED]).map((f) => String(f).toLowerCase()));

  if (!allowedSet.has(detected.format)) {
    throw Object.assign(new Error(`Định dạng ${detected.format.toUpperCase()} hiện không được phép tải lên.`), { code: 'INVALID_MIME_TYPE', status: 422 });
  }

  if (detected.format === 'svg') {
    const cleanSvg = sanitizeSvg(inputBuffer);
    const dims = parseSvgDimensions(cleanSvg.toString('utf8'));
    const sha256Hash = createHash('sha256').update(cleanSvg).digest('hex');

    let thumbnail = null;
    try {
      const thumbOut = await sharp(cleanSvg)
        .resize({ width: thumbnailSize, height: thumbnailSize, fit: 'inside', withoutEnlargement: true })
        .webp({ quality: 80 })
        .toBuffer({ resolveWithObject: true });
      thumbnail = {
        variantType: 'thumbnail',
        label: 'Thumbnail WebP',
        buffer: thumbOut.data,
        mimeType: 'image/webp',
        extension: 'webp',
        sizeBytes: thumbOut.data.length,
        width: thumbOut.info.width,
        height: thumbOut.info.height,
      };
    } catch {
      thumbnail = {
        variantType: 'thumbnail',
        label: 'Thumbnail SVG',
        buffer: cleanSvg,
        mimeType: 'image/svg+xml',
        extension: 'svg',
        sizeBytes: cleanSvg.length,
        width: dims.width,
        height: dims.height,
      };
    }

    return {
      originalFilename: String(originalFilename || 'image.svg').slice(0, 255),
      buffer: cleanSvg,
      mimeType: detected.mimeType,
      extension: detected.extension,
      format: detected.format,
      sizeBytes: cleanSvg.length,
      width: dims.width,
      height: dims.height,
      sha256Hash,
      exifData: { format: 'svg', sanitized: true },
      thumbnail,
      variants: [],
    };
  }

  let metadata;
  try {
    metadata = await sharp(inputBuffer, { limitInputPixels: 40000000 }).metadata();
  } catch {
    throw Object.assign(new Error('Không thể giải mã nội dung ảnh.'), { code: 'INVALID_IMAGE', status: 422 });
  }

  if (!metadata?.width || !metadata?.height) {
    throw Object.assign(new Error('Kích thước ảnh không hợp lệ.'), { code: 'INVALID_IMAGE', status: 422 });
  }

  let originalBuffer = inputBuffer;
  if (stripGpsExif && detected.format !== 'gif') {
    try {
      originalBuffer = await sharp(inputBuffer, { limitInputPixels: 40000000 }).rotate().toBuffer();
    } catch {
      originalBuffer = inputBuffer;
    }
  }

  const sha256Hash = createHash('sha256').update(originalBuffer).digest('hex');
  const exifData = extractSafeExif(metadata, stripGpsExif);

  const thumbOut = await sharp(originalBuffer, { limitInputPixels: 40000000 })
    .rotate()
    .resize({ width: thumbnailSize, height: thumbnailSize, fit: 'inside', withoutEnlargement: true })
    .webp({ quality: 80 })
    .toBuffer({ resolveWithObject: true });

  const thumbnail = {
    variantType: 'thumbnail',
    label: 'Thumbnail WebP',
    buffer: thumbOut.data,
    mimeType: 'image/webp',
    extension: 'webp',
    sizeBytes: thumbOut.data.length,
    width: thumbOut.info.width,
    height: thumbOut.info.height,
  };

  const variants = [];
  if (generateWebp && detected.format !== 'webp') {
    const webpOut = await sharp(originalBuffer, { limitInputPixels: 40000000 })
      .rotate()
      .webp({ quality })
      .toBuffer({ resolveWithObject: true });
    variants.push({
      variantType: 'webp',
      label: `Auto WebP (${quality}%)`,
      buffer: webpOut.data,
      mimeType: 'image/webp',
      extension: 'webp',
      sizeBytes: webpOut.data.length,
      width: webpOut.info.width,
      height: webpOut.info.height,
      transformParams: { format: 'webp', quality },
    });
  }

  if (generateAvif && detected.format !== 'avif') {
    try {
      const avifOut = await sharp(originalBuffer, { limitInputPixels: 40000000 })
        .rotate()
        .avif({ quality: Math.min(quality, 75) })
        .toBuffer({ resolveWithObject: true });
      variants.push({
        variantType: 'avif',
        label: `Auto AVIF (${Math.min(quality, 75)}%)`,
        buffer: avifOut.data,
        mimeType: 'image/avif',
        extension: 'avif',
        sizeBytes: avifOut.data.length,
        width: avifOut.info.width,
        height: avifOut.info.height,
        transformParams: { format: 'avif', quality: Math.min(quality, 75) },
      });
    } catch {
      // Graceful skip if AVIF encoder unavailable in runtime
    }
  }

  return {
    originalFilename: String(originalFilename || `image.${detected.extension}`).slice(0, 255),
    buffer: originalBuffer,
    mimeType: detected.mimeType,
    extension: detected.extension,
    format: detected.format,
    sizeBytes: originalBuffer.length,
    width: metadata.width,
    height: metadata.height,
    sha256Hash,
    exifData,
    thumbnail,
    variants,
  };
}

/**
 * Non-destructive sharp image transformation (crop, resize, rotate, flip, compress, convert format).
 */
export async function transformImage(
  sourceBuffer,
  {
    crop,
    resize,
    rotate,
    flipHorizontal = false,
    flipVertical = false,
    format = 'webp',
    quality = 82,
  } = {},
) {
  const targetFormat = String(format || 'webp').toLowerCase();
  const fmtInfo = FORMAT_META[targetFormat];
  if (!fmtInfo || targetFormat === 'svg' || targetFormat === 'gif') {
    throw Object.assign(new Error('Định dạng xuất hỗ trợ: jpeg, png, webp, avif.'), { code: 'VALIDATION_ERROR', status: 422 });
  }

  let pipeline = sharp(sourceBuffer, { limitInputPixels: 40000000 });
  const meta = await pipeline.metadata();

  if (crop && crop.width > 0 && crop.height > 0) {
    const left = Math.max(0, Math.min(Math.round(crop.left || 0), (meta.width || 1) - 1));
    const top = Math.max(0, Math.min(Math.round(crop.top || 0), (meta.height || 1) - 1));
    const width = Math.min(Math.round(crop.width), (meta.width || 1) - left);
    const height = Math.min(Math.round(crop.height), (meta.height || 1) - top);
    if (width < 1 || height < 1) {
      throw Object.assign(new Error('Vùng crop vượt quá kích thước ảnh gốc.'), { code: 'VALIDATION_ERROR', status: 422 });
    }
    pipeline = pipeline.extract({ left, top, width, height });
  }

  if (rotate !== undefined && rotate !== null && Number(rotate) !== 0) {
    pipeline = pipeline.rotate(Number(rotate));
  }

  if (flipVertical) pipeline = pipeline.flip();
  if (flipHorizontal) pipeline = pipeline.flop();

  if (resize && (resize.width || resize.height)) {
    pipeline = pipeline.resize({
      ...(resize.width ? { width: Math.round(resize.width) } : {}),
      ...(resize.height ? { height: Math.round(resize.height) } : {}),
      fit: resize.fit || 'inside',
      withoutEnlargement: true,
    });
  }

  const q = Math.max(1, Math.min(100, Math.round(Number(quality) || 82)));
  if (targetFormat === 'jpeg') pipeline = pipeline.jpeg({ quality: q, mozjpeg: true });
  else if (targetFormat === 'png') pipeline = pipeline.png({ quality: q, compressionLevel: 9 });
  else if (targetFormat === 'webp') pipeline = pipeline.webp({ quality: q });
  else if (targetFormat === 'avif') pipeline = pipeline.avif({ quality: q });

  const { data, info } = await pipeline.toBuffer({ resolveWithObject: true });
  return {
    data,
    mimeType: fmtInfo.mimeType,
    extension: fmtInfo.extension,
    width: info.width,
    height: info.height,
    sizeBytes: data.length,
  };
}
