export const MAX_RESUME_PHOTO_UPLOAD_BYTES = 5 * 1024 * 1024;
export const MAX_RESUME_PHOTO_DATA_URI_LENGTH = 3_000_000;
const MAX_STORED_PHOTO_BYTES = 1_900_000;
const MAX_PHOTO_EDGE = 1600;
const MIN_FACE_SCORE = 0.8;
let faceModelPromise;

export function isVerifiedResumePhoto(photo, validationStatus) {
  return typeof photo === 'string' &&
    /^data:image\/(?:jpeg|png);base64,/i.test(photo) &&
    validationStatus === 'success';
}

export function validatePhotoFile(file) {
  if (!file) {
    return { valid: false, message: 'Choose a JPG or PNG photo.' };
  }
  if (!['image/jpeg', 'image/png'].includes(String(file.type || '').toLowerCase())) {
    return { valid: false, message: 'Choose a JPG or PNG photo, not a logo file or another image format.' };
  }
  if (!Number.isFinite(file.size) || file.size <= 0 || file.size > MAX_RESUME_PHOTO_UPLOAD_BYTES) {
    return { valid: false, message: 'Choose a JPG or PNG photo 5 MB or smaller.' };
  }
  return { valid: true, message: '' };
}

function loadImageFromFile(file) {
  return new Promise((resolve, reject) => {
    const objectUrl = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => resolve({
      image,
      dispose: () => URL.revokeObjectURL(objectUrl),
    });
    image.onerror = () => {
      URL.revokeObjectURL(objectUrl);
      reject(new Error('The selected file is not a decodable image.'));
    };
    image.src = objectUrl;
  });
}

function encodeJpeg(image, width, height, quality) {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d', { alpha: false });
  if (!context) throw new Error('Photo canvas is unavailable.');
  // Resume portraits are opaque; use white behind transparent PNG pixels.
  context.fillStyle = '#ffffff';
  context.fillRect(0, 0, width, height);
  context.drawImage(image, 0, 0, width, height);
  return new Promise((resolve, reject) => {
    canvas.toBlob(blob => blob
      ? resolve(blob)
      : reject(new Error('Photo compression failed.')), 'image/jpeg', quality);
  });
}

/**
 * Accepts photos up to 5 MiB, then stores a resized JPEG below 1.9 MB.
 * The compact data URI remains within the encrypted resume-draft payload
 * limit while the original image is verified before any lossy conversion.
 */
export async function optimizeResumePhoto(file, dependencies = {}) {
  const basic = validatePhotoFile(file);
  if (!basic.valid) return basic;

  const loadImage = dependencies.loadImage || loadImageFromFile;
  const encodeImage = dependencies.encodeImage || encodeJpeg;
  let decoded;
  try {
    decoded = await loadImage(file);
  } catch {
    return { valid: false, message: 'This photo could not be opened for optimization. Choose another JPG or PNG.' };
  }

  try {
    const image = decoded.image;
    const sourceWidth = Number(image?.naturalWidth || image?.width);
    const sourceHeight = Number(image?.naturalHeight || image?.height);
    if (!Number.isFinite(sourceWidth) || !Number.isFinite(sourceHeight) ||
        sourceWidth < 1 || sourceHeight < 1) {
      return { valid: false, message: 'This photo has invalid image dimensions. Choose another JPG or PNG.' };
    }

    const initialScale = Math.min(1, MAX_PHOTO_EDGE / Math.max(sourceWidth, sourceHeight));
    let width = Math.max(1, Math.round(sourceWidth * initialScale));
    let height = Math.max(1, Math.round(sourceHeight * initialScale));
    let quality = 0.9;

    for (let attempt = 0; attempt < 12; attempt += 1) {
      const blob = await encodeImage(image, width, height, quality);
      if (!blob || !Number.isFinite(blob.size) || blob.size <= 0) {
        throw new Error('Photo compression did not return an image.');
      }
      if (blob.size > 0 && blob.size <= MAX_STORED_PHOTO_BYTES) {
        return { valid: true, blob, message: 'Photo optimized for your resume.' };
      }

      if (quality > 0.68) {
        quality = Math.max(0.68, quality - 0.1);
        continue;
      }

      if (Math.max(width, height) <= 320) break;
      const reduction = Math.max(0.5, Math.min(
        0.88,
        Math.sqrt(MAX_STORED_PHOTO_BYTES / blob.size) * 0.92,
      ));
      const nextWidth = Math.max(1, Math.round(width * reduction));
      const nextHeight = Math.max(1, Math.round(height * reduction));
      if (nextWidth === width && nextHeight === height) break;
      width = nextWidth;
      height = nextHeight;
      quality = 0.9;
    }

    return {
      valid: false,
      message: 'This photo could not be optimized enough to save. Choose another JPG or PNG up to 5 MB.',
    };
  } catch {
    return {
      valid: false,
      message: 'This photo could not be optimized. Choose another valid JPG or PNG.',
    };
  } finally {
    if (typeof decoded?.dispose === 'function') decoded.dispose();
  }
}

async function loadFaceModel() {
  if (!faceModelPromise) {
    faceModelPromise = (async () => {
      const tf = await import('@tensorflow/tfjs-core');
      let backendReady = false;
      try {
        await import('@tensorflow/tfjs-backend-webgl');
        backendReady = await tf.setBackend('webgl');
      } catch {
        // Keep the initial false value and fall back to the CPU backend below.
      }
      if (!backendReady) {
        await import('@tensorflow/tfjs-backend-cpu');
        backendReady = await tf.setBackend('cpu');
      }
      if (!backendReady) {
        throw new Error('No supported image-processing backend is available.');
      }
      await tf.ready();
      const blazeface = await import('@tensorflow-models/blazeface');
      return blazeface.load({ maxFaces: 5, scoreThreshold: 0.75 });
    })();
  }
  try {
    return await faceModelPromise;
  } catch (error) {
    faceModelPromise = null;
    throw error;
  }
}

function pointPair(value) {
  if (Array.isArray(value) || ArrayBuffer.isView(value)) {
    return [Number(value[0]), Number(value[1])];
  }
  if (value && typeof value.arraySync === 'function') {
    const result = value.arraySync();
    return [Number(result[0]), Number(result[1])];
  }
  return null;
}

export function hasSuitablePortraitFace(predictions, imageWidth, imageHeight) {
  if (!Array.isArray(predictions) || imageWidth < 1 || imageHeight < 1) {
    return false;
  }
  // Any additional detected face makes this a group image, even if one face
  // is much larger than the others.
  if (predictions.length !== 1) return false;
  const suitable = predictions.filter((face) => {
    const score = Number(
      Array.isArray(face?.probability) || ArrayBuffer.isView(face?.probability)
        ? face.probability[0]
        : face?.probability,
    );
    const topLeft = pointPair(face?.topLeft);
    const bottomRight = pointPair(face?.bottomRight);
    if (!Number.isFinite(score) || score < MIN_FACE_SCORE || !topLeft || !bottomRight) {
      return false;
    }
    const width = bottomRight[0] - topLeft[0];
    const height = bottomRight[1] - topLeft[1];
    if (width <= 0 || height <= 0) return false;
    const widthRatio = width / imageWidth;
    const heightRatio = height / imageHeight;
    const areaRatio = (width * height) / (imageWidth * imageHeight);
    return width >= Math.max(48, imageWidth * 0.12) &&
      height >= Math.max(48, imageHeight * 0.12) &&
      widthRatio >= 0.12 &&
      heightRatio >= 0.12 &&
      areaRatio >= 0.015;
  });
  // Resume photos should show one clear, prominent face rather than a crowd.
  return suitable.length === 1;
}

export async function validateResumePhoto(file, dependencies = {}) {
  const basic = validatePhotoFile(file);
  if (!basic.valid) return basic;

  const loadImage = dependencies.loadImage || loadImageFromFile;
  const getModel = dependencies.loadModel || loadFaceModel;
  let decoded;
  try {
    decoded = await loadImage(file);
  } catch {
    return {
      valid: false,
      message: 'This file could not be opened as a photo. Choose a valid JPG or PNG.',
    };
  }

  try {
    const model = await getModel();
    const predictions = await model.estimateFaces(decoded.image, false);
    if (!hasSuitablePortraitFace(
      predictions,
      decoded.image.naturalWidth || decoded.image.width,
      decoded.image.naturalHeight || decoded.image.height,
    )) {
      return {
        valid: false,
        message: 'Choose a clear photo of one person. Logos, mascots, cartoons, and group photos are not accepted.',
      };
    }
    return { valid: true, message: 'Photo verified.' };
  } catch {
    // Fail closed when the on-device detector cannot run; never replace a
    // previously accepted photo with an image that was not verified.
    return {
      valid: false,
      message: 'Photo verification is temporarily unavailable. Your previous photo was kept; please try again in a moment.',
    };
  } finally {
    if (typeof decoded.dispose === 'function') decoded.dispose();
  }
}
