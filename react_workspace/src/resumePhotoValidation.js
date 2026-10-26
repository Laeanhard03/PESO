const MAX_PHOTO_BYTES = 2_000_000;
const MIN_FACE_SCORE = 0.8;
let faceModelPromise;

export function validatePhotoFile(file) {
  if (!file) {
    return { valid: false, message: 'Choose a JPG or PNG photo.' };
  }
  if (!['image/jpeg', 'image/png'].includes(String(file.type || '').toLowerCase())) {
    return { valid: false, message: 'Choose a JPG or PNG photo, not a logo file or another image format.' };
  }
  if (!Number.isFinite(file.size) || file.size <= 0 || file.size > MAX_PHOTO_BYTES) {
    return { valid: false, message: 'Choose a JPG or PNG photo smaller than 2 MB.' };
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
