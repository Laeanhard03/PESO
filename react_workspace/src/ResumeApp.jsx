import { useEffect, useState, useRef } from "react";
import * as htmlToImage from "html-to-image";
import { jsPDF } from "jspdf";
import { sendToFlutter } from './flutterBridge.js';
import { applicantCareerEntries, educationChoices, experienceChoices, skillsChoices, validateApplicantEssentials } from './applicantEssentials.js';

// Registration values inherited from the Flutter shell (URL query string).
// They replace the per-template sample name/contact text so applicants start
// from their own registered details; sample text remains the fallback.
const readInheritedProfile = () => {
  const values = { firstName: '', lastName: '', fullName: '', email: '', phone: '' };
  try {
    const params = new URLSearchParams(window.location.search);
    for (const key of ['firstName', 'lastName', 'email', 'phone']) {
      values[key] = (params.get(key) || '').replace(/\s+/g, ' ').trim();
    }
  } catch {
    // Query strings are optional; fall back to the template samples.
  }
  values.fullName = [values.firstName, values.lastName].filter(Boolean).join(' ');
  return values;
};

const INHERITED_PROFILE = readInheritedProfile();

// --- SVG Icons ---
const PhoneIcon = () => (
  <svg className="w-3.5 h-3.5 inline mr-2 shrink-0" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
    <path strokeLinecap="round" strokeLinejoin="round" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
  </svg>
);
const MailIcon = () => (
  <svg className="w-3.5 h-3.5 inline mr-2 shrink-0" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
    <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
  </svg>
);
const PinIcon = () => (
  <svg className="w-3.5 h-3.5 inline mr-2 shrink-0" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
    <path strokeLinecap="round" strokeLinejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
    <path strokeLinecap="round" strokeLinejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
  </svg>
);
const GlobeIcon = () => (
  <svg className="w-3.5 h-3.5 inline mr-2 shrink-0" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
    <path strokeLinecap="round" strokeLinejoin="round" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
  </svg>
);
const CheckIcon = () => (
  <span className="mr-2 text-teal-600 font-bold">✓</span>
);

// --- Reusable Editable Field ---
// `prefillKey` pulls an inherited registration value into the field.
// `data-template-default` keeps the untouched sample text so the completion
// extractor only reports the field once it differs from the sample.
const Editable = ({ defaultText, className = "", prefillKey, ...props }) => {
  const inherited = prefillKey ? INHERITED_PROFILE[prefillKey] : '';
  return (
    <span
      contentEditable
      suppressContentEditableWarning
      data-template-default={typeof defaultText === 'string' ? defaultText : ''}
      data-prefill-key={prefillKey || undefined}
      className={`outline-none hover:bg-amber-50 focus:bg-amber-100 transition-colors rounded px-0.5 ${className}`}
      {...props}
    >
      {inherited || defaultText}
    </span>
  );
};

export default function ResumeApp() {
  const [activeTemplate, setActiveTemplate] = useState("sally");
  const [zoom, setZoom] = useState(1);
  const [fitScale, setFitScale] = useState(1);
  const [canvasHeight, setCanvasHeight] = useState(1123);
  const [photo, setPhoto] = useState(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [careerEducation, setCareerEducation] = useState('');
  const [experienceStatus, setExperienceStatus] = useState('');
  const [skillsStage, setSkillsStage] = useState('');
  const [careerSkills, setCareerSkills] = useState('');
  const [missingEssentials, setMissingEssentials] = useState([]);
  const fileInputRef = useRef(null);
  const [draftStatus, setDraftStatus] = useState('Offline Draft');
  const ownerUidRef = useRef('');
  const draftTimerRef = useRef(null);
  const lastDraftRef = useRef(null);
  const pendingRestoreRef = useRef(null);
  const restoringRef = useRef(false);
  const draftFieldsRef = useRef({});
  useEffect(() => {
    draftFieldsRef.current = {
      activeTemplate, photo, careerEducation, experienceStatus, skillsStage, careerSkills,
    };
  }, [activeTemplate, photo, careerEducation, experienceStatus, skillsStage, careerSkills]);

  const snapshotDraft = () => {
    const state = draftFieldsRef.current;
    const editables = Array.from(document.querySelectorAll('#resume-node [contenteditable]'));
    return {
      draftUpdatedAt: new Date().toISOString(),
      template: state.activeTemplate,
      editedText: editables.map(node => String(node.innerText || '').slice(0, 5000)),
      photoDataUri: state.photo?.startsWith('data:image/') ? state.photo : null,
      applicantEssentials: {
        education: state.careerEducation, experience: state.experienceStatus,
        skillsStage: state.skillsStage, skills: state.careerSkills,
      },
    };
  };

  useEffect(() => {
    const schedule = () => {
      if (restoringRef.current || !ownerUidRef.current) return;
      setDraftStatus('Saving');
      if (draftTimerRef.current) clearTimeout(draftTimerRef.current);
      draftTimerRef.current = window.setTimeout(() => {
        const draft = snapshotDraft();
        lastDraftRef.current = draft;
        if (!sendToFlutter({ status: 'draft', kind: 'resume_builder', formData: draft })) {
          setDraftStatus('Sync Failed');
        }
      }, 900);
    };
    const onMessage = event => {
      if (event.source !== window.parent && event.source !== window) return;
      let data;
      try { data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data; }
      catch { return; }
      if (data?.source !== 'peso-flutter') return;
      if (data.event === 'draft-sync-status') {
        if (['Saving', 'Saved', 'Offline Draft', 'Sync Failed'].includes(data.state)) {
          setDraftStatus(data.state);
        }
        return;
      }
      if (data.event !== 'resume-prefill') return;
      if (typeof data.ownerUid === 'string' && data.ownerUid) ownerUidRef.current = data.ownerUid;
      const draft = data.formData;
      if (!draft?.draftUpdatedAt || !Array.isArray(draft.editedText)) return;
      restoringRef.current = true;
      pendingRestoreRef.current = draft;
      setActiveTemplate(['sally', 'emily', 'richard', 'dian'].includes(draft.template)
        ? draft.template : 'sally');
      window.setTimeout(() => {
        const nodes = Array.from(document.querySelectorAll('#resume-node [contenteditable]'));
        nodes.forEach((node, index) => {
          if (typeof draft.editedText[index] === 'string') {
            node.textContent = draft.editedText[index];
          }
        });
        pendingRestoreRef.current = null;
        restoringRef.current = false;
      }, 190);
      setCareerEducation(educationChoices.includes(draft.applicantEssentials?.education)
        ? draft.applicantEssentials.education : '');
      setExperienceStatus(experienceChoices.includes(draft.applicantEssentials?.experience)
        ? draft.applicantEssentials.experience : '');
      setSkillsStage(skillsChoices.includes(draft.applicantEssentials?.skillsStage)
        ? draft.applicantEssentials.skillsStage : '');
      setCareerSkills(draft.applicantEssentials?.skills || '');
      if (typeof draft.photoDataUri === 'string' &&
          draft.photoDataUri.startsWith('data:image/') &&
          draft.photoDataUri.length < 3000000) setPhoto(draft.photoDataUri);
    };
    const goOnline = () => {
      if (ownerUidRef.current && lastDraftRef.current) {
        setDraftStatus('Saving');
        sendToFlutter({ status: 'draft', kind: 'resume_builder',
          formData: lastDraftRef.current });
      }
    };
    document.addEventListener('input', schedule, true);
    document.addEventListener('change', schedule, true);
    window.addEventListener('message', onMessage);
    window.addEventListener('online', goOnline);
    sendToFlutter({ status: 'ready', kind: 'resume_builder' });
    return () => {
      document.removeEventListener('input', schedule, true);
      document.removeEventListener('change', schedule, true);
      window.removeEventListener('message', onMessage);
      window.removeEventListener('online', goOnline);
      if (draftTimerRef.current) clearTimeout(draftTimerRef.current);
    };
  // Current controlled values are read through draftFieldsRef after debounce.
  }, []);

  useEffect(() => {
    const pending = pendingRestoreRef.current;
    if (!pending || pending.template !== activeTemplate) return;
    const id = window.setTimeout(() => {
      const nodes = Array.from(document.querySelectorAll('#resume-node [contenteditable]'));
      nodes.forEach((node, i) => {
        if (typeof pending.editedText[i] === 'string') {
          // textContent, never innerHTML: drafts cannot inject executable DOM.
          node.textContent = pending.editedText[i];
        }
      });
      pendingRestoreRef.current = null;
      restoringRef.current = false;
    }, 120);
    return () => clearTimeout(id);
  }, [activeTemplate]);


  useEffect(() => {
    let delayedCheck = 0;
    const updateCanvasFit = () => {
      const viewportWidth = document.documentElement.clientWidth || window.innerWidth;
      const wrapper = document.getElementById("zoom-wrapper");
      setFitScale(Math.min(1, Math.max(0.25, (viewportWidth - 48) / 794)));
      if (wrapper && wrapper.scrollHeight > 0) setCanvasHeight(wrapper.scrollHeight);
    };

    updateCanvasFit();
    window.addEventListener("resize", updateCanvasFit);
    const root = document.getElementById("root");
    const observer = typeof ResizeObserver === "function"
      ? new ResizeObserver(updateCanvasFit)
      : null;
    if (root && observer) observer.observe(root);
    delayedCheck = window.setTimeout(updateCanvasFit, 120);

    return () => {
      window.removeEventListener("resize", updateCanvasFit);
      if (observer) observer.disconnect();
      if (delayedCheck) window.clearTimeout(delayedCheck);
    };
  }, []);

  const handlePhotoUpload = (e) => {
    const file = e.target.files[0];
    if (!file) return;
    if (!file.type.startsWith('image/') || file.size > 2000000) {
      alert('Select a JPG or PNG under 2 MB.');
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === 'string') setPhoto(reader.result);
    };
    reader.readAsDataURL(file);
  };

  // Generate the PDF, extract editable resume content, and return both to Flutter.
  const handleCompleteResume = async () => {
    // Unedited resume-template examples do not constitute applicant facts.
    const readRealValue = key => {
      const node = document.querySelector(`#resume-node [data-prefill-key="${key}"]`);
      const value = String(node?.innerText || '').trim();
      const template = String(node?.getAttribute('data-template-default') || '').trim();
      return value && value !== template ? value : '';
    };
    const essentialSnapshot = {
      firstName: readRealValue('firstName'),
      lastName: readRealValue('lastName'),
      fullName: readRealValue('fullName'),
      email: readRealValue('email'),
      phone: readRealValue('phone'),
      education: careerEducation,
      experience: experienceStatus,
      skillsStage,
      skills: careerSkills.trim(),
    };
    const missing = validateApplicantEssentials(essentialSnapshot, { nsrp: false });
    if (missing.length) {
      setMissingEssentials(missing);
      document.getElementById('resume-applicant-essentials')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      return;
    }
    setMissingEssentials([]);
    setIsProcessing(true);
    const zoomWrapper = document.getElementById('zoom-wrapper');
    const originalTransform = zoomWrapper?.style.transform ?? '';
    if (zoomWrapper) zoomWrapper.style.transform = 'scale(1)';

    try {
      const element = document.getElementById('resume-node');
      if (!element) throw new Error('Resume canvas was not found.');

      let resumePdfBase64 = '';
      let pdfWarning = '';
      const exportOptions = {
        quality: 0.96,
        backgroundColor: '#ffffff',
        pixelRatio: 1.5,
      };

      // Try rendering the live DOM first. If a remote image cannot be fetched
      // by html-to-image, inline the loaded image via canvas and retry.
      let renderedImage;
      try {
        renderedImage = await htmlToImage.toJpeg(element, exportOptions);
      } catch (firstRenderError) {
        const images = Array.from(element.querySelectorAll('img'));
        const originals = images.map((img) => ({
          img,
          src: img.getAttribute('src'),
          srcset: img.getAttribute('srcset'),
          sizes: img.getAttribute('sizes'),
          crossOrigin: img.getAttribute('crossorigin'),
        }));
        const placeholderSvg =
          '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400">' +
          '<rect width="400" height="400" fill="#e5eee8"/>' +
          '<circle cx="200" cy="140" r="65" fill="#2e7d32"/>' +
          '<rect x="95" y="225" width="210" height="175" rx="65" fill="#2e7d32"/>' +
          '</svg>';
        const placeholder = 'data:image/svg+xml;charset=utf-8,' +
          encodeURIComponent(placeholderSvg);

        try {
          if (images.length === 0) throw firstRenderError;
          for (const img of images) {
            let localSource = placeholder;
            if (img.complete && img.naturalWidth > 0 && img.naturalHeight > 0) {
              try {
                const canvas = document.createElement('canvas');
                canvas.width = img.naturalWidth;
                canvas.height = img.naturalHeight;
                const canvasContext = canvas.getContext('2d');
                if (canvasContext) {
                  canvasContext.drawImage(img, 0, 0);
                  localSource = canvas.toDataURL('image/png');
                }
              } catch {
                // A cross-origin-tainted image gets a local placeholder.
              }
            }
            img.removeAttribute('srcset');
            img.removeAttribute('sizes');
            img.removeAttribute('crossorigin');
            img.src = localSource;
          }

          await Promise.all(images.map((img) =>
            typeof img.decode === 'function'
              ? img.decode().catch(() => {})
              : Promise.resolve(),
          ));
          renderedImage = await htmlToImage.toJpeg(element, exportOptions);
        } catch (fallbackError) {
          pdfWarning = 'the PDF image render failed (' +
            (fallbackError instanceof Error ? fallbackError.message : String(fallbackError)) + ')';
          console.warn('[RESUME] PDF render failed; continuing with editable fields:', fallbackError);
        } finally {
          for (const original of originals) {
            const restore = (name, value) => {
              if (value == null) original.img.removeAttribute(name);
              else original.img.setAttribute(name, value);
            };
            restore('src', original.src);
            restore('srcset', original.srcset);
            restore('sizes', original.sizes);
            restore('crossorigin', original.crossOrigin);
          }
        }
      }

      if (renderedImage) {
        try {
          const pdf = new jsPDF('p', 'mm', 'a4');
          const pdfWidth = pdf.internal.pageSize.getWidth();
          const pdfPageHeight = pdf.internal.pageSize.getHeight();
          const raster = new Image();
          raster.src = renderedImage;
          await raster.decode();
          const width = raster.naturalWidth;
          const height = raster.naturalHeight;
          const maxSlice = Math.floor(width * pdfPageHeight / pdfWidth);
          for (let top = 0; top < height; top += maxSlice) {
            const portion = Math.min(maxSlice, height - top);
            const slice = document.createElement('canvas');
            slice.width = width;
            slice.height = portion;
            slice.getContext('2d').drawImage(raster, 0, top, width, portion,
              0, 0, width, portion);
            if (top > 0) pdf.addPage();
            pdf.addImage(slice.toDataURL('image/jpeg', 0.9), 'JPEG',
              0, 0, pdfWidth, portion * pdfWidth / width);
          }
          const dataUri = pdf.output('datauristring');
          resumePdfBase64 = dataUri.includes(',')
            ? dataUri.substring(dataUri.indexOf(',') + 1)
            : '';
          try {
            pdf.save('JobKonek_Resume.pdf');
          } catch (downloadError) {
            pdfWarning = 'the PDF was rendered but the browser could not download it';
            console.warn('[RESUME] PDF download failed:', downloadError);
          }
        } catch (pdfError) {
          pdfWarning = 'the PDF could not be assembled (' +
            (pdfError instanceof Error ? pdfError.message : String(pdfError)) + ')';
          console.error('[RESUME] PDF assembly failed; continuing with editable fields:', pdfError);
        }
      }

      const normalize = (value) => String(value ?? '').replace(/\s+/g, ' ').trim();
      const editables = Array.from(document.querySelectorAll('[contenteditable="true"]'));
      const extractedFields = editables.map((node, index) => {
        const section = node.closest('section');
        const sectionTitle = normalize(section?.querySelector('h3')?.innerText) || 'Resume details';
        const value = normalize(node.innerText);
        const templateDefault = normalize(node.getAttribute('data-template-default'));
        const parent = node.parentElement;
        const siblingText = normalize(Array.from(parent?.childNodes || [])
          .filter((child) => child !== node)
          .map((child) => child.textContent || '')
          .join(' '));
        const label = value.includes('@')
          ? 'Email'
          : (/\+?\d[\d ()-]{6,}/.test(value) ? 'Phone / contact number'
            : (siblingText && siblingText.length <= 100 ? siblingText : `Resume detail ${index + 1}`));
        return { index: index + 1, section: sectionTitle, label, value, context: normalize(parent?.innerText), templateDefault };
      }).filter((field) => field.value !== '' && field.value !== field.templateDefault);
      // Template-default sample text is used only to detect unchanged examples;
      // it is not saved to Firestore or sent to the AI.
      const fields = extractedFields.map((field) => {
        const savedField = { ...field };
        delete savedField.templateDefault;
        delete savedField.context;
        return savedField;
      });
      fields.push(...applicantCareerEntries(essentialSnapshot).map(entry => ({
        section: 'Applicant career details',
        label: entry.label,
        value: entry.value,
        fieldKey: entry.fieldKey,
      })));
      const plainText = fields.map((field) => `${field.section} — ${field.label}: ${field.value}`).join('\n');
      const resumeData = {
        documentType: 'Resume Builder',
        template: activeTemplate,
        fields,
        applicantEssentials: {
          education: careerEducation,
          experience: experienceStatus,
          skillsStage,
          skills: skillsStage === skillsChoices[0] ? careerSkills.trim() : '',
        },
        plainText,
        aiText: plainText,
        completedAt: new Date().toISOString(),
      };
      const delivered = sendToFlutter({        status: 'completed',
        kind: 'resume_builder',
        data: plainText,
        aiText: plainText,
        resumeData,
        artifact: resumePdfBase64 ? {
          fileName: 'JobKonek_Resume.pdf',
          category: 'resume_builder',
          mimeType: 'application/pdf',
          base64: resumePdfBase64,
        } : null,
      });

      if (!delivered) {
        const missingBridgeMessage = resumePdfBase64
          ? 'The resume PDF was generated, but no Flutter app was detected to save the resume data. Open the resume builder from PESO JobKonek to sync it to your profile.'
          : 'The resume details were extracted, but no Flutter app was detected to save them. Open the resume builder from PESO JobKonek to sync it to your profile.';
        alert(pdfWarning ? missingBridgeMessage + '\\n' + pdfWarning : missingBridgeMessage);
      } else if (pdfWarning) {
        alert('Your resume details were sent to PESO JobKonek, but ' +
          pdfWarning + '. The saved resume fields can still be processed by AI.');
      }
    } catch (error) {
      console.error('Resume PDF or data extraction failed:', error);
      alert('Could not generate your resume. Please check the browser console and try again.');
    } finally {
      if (zoomWrapper) zoomWrapper.style.transform = originalTransform;
      setIsProcessing(false);
    }
  };

  const defaultPhotos = {
    sally: "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&q=80",
    emily: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&q=80",
    richard: "https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&q=80",
    dian: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&q=80",
  };

  const currentPhoto = photo || defaultPhotos[activeTemplate];

  return (
    <div className="min-h-screen bg-neutral-100 text-neutral-800 flex flex-col font-sans">
      {/* Top Toolbar */}
      <header className="print:hidden sticky top-0 z-50 bg-white border-b border-neutral-200 px-6 py-3 flex flex-wrap items-center justify-between shadow-sm gap-4">
        {/* Template Selectors */}
        <div className="flex flex-wrap items-center gap-2 min-w-0">
          <span className="text-xs font-bold uppercase tracking-wider text-neutral-400 mr-1">Design:</span>
          {[
            { id: "sally", label: "1. Teal Wave" },
            { id: "emily", label: "2. Warm Editorial" },
            { id: "richard", label: "3. Slate Timeline" },
            { id: "dian", label: "4. Organic Pastel" },
          ].map((t) => (
            <button
              key={t.id}
              onClick={() => {
                if (ownerUidRef.current) {
                  const draft = snapshotDraft();
                  lastDraftRef.current = draft;
                  sendToFlutter({ status: 'draft', kind: 'resume_builder', formData: draft });
                }
                setActiveTemplate(t.id);
              }}
              className={`px-3 py-1.5 rounded-md text-xs font-semibold transition-all ${
                activeTemplate === t.id
                  ? "bg-neutral-900 text-white shadow-sm"
                  : "bg-neutral-100 text-neutral-600 hover:bg-neutral-200"
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>

        {/* Zoom Controls & Actions */}
        <div className="flex flex-wrap items-center gap-3">
          <span data-testid="resume-draft-status" role="status"
            className="text-xs font-semibold text-green-900">
            Draft: {draftStatus}
            {draftStatus === 'Sync Failed' && (
              <button className="ml-2 underline" type="button"
                onClick={() => sendToFlutter({ status: 'draft', kind: 'resume_builder',
                  formData: lastDraftRef.current || snapshotDraft() })}>Retry</button>
            )}
          </span>
          <div className="flex items-center bg-neutral-100 rounded-lg p-1 border border-neutral-200 text-xs">
            <button
              onClick={() => setZoom((prev) => Math.max(0.4, prev - 0.1))}
              className="px-2.5 py-1 rounded hover:bg-white text-neutral-700 font-bold"
              title="Zoom Out"
            >
              -
            </button>
            <span className="px-2 font-mono text-neutral-600">{Math.round(zoom * 100)}%</span>
            <button
              onClick={() => setZoom((prev) => Math.min(1.8, prev + 0.1))}
              className="px-2.5 py-1 rounded hover:bg-white text-neutral-700 font-bold"
              title="Zoom In"
            >
              +
            </button>
            <button
              onClick={() => setZoom(1)}
              className="px-2 py-1 ml-1 text-neutral-500 hover:text-neutral-900 border-l border-neutral-300"
            >
              Reset
            </button>
          </div>

          <button
            onClick={() => fileInputRef.current.click()}
            className="px-3 py-1.5 bg-neutral-100 hover:bg-neutral-200 text-neutral-700 text-xs font-semibold rounded-md border border-neutral-300"
          >
            Change Photo
          </button>
          <input
            type="file"
            ref={fileInputRef}
            onChange={handlePhotoUpload}
            accept="image/*"
            className="hidden"
          />

          <button
            onClick={handleCompleteResume}
            disabled={isProcessing}
            className="px-4 py-1.5 bg-green-600 hover:bg-green-700 text-white text-xs font-bold rounded-md shadow transition-colors flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isProcessing ? (
              <span>Preparing PDF & continuing...</span>
            ) : (
              <>
                <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path></svg>
                Download PDF & Continue
              </>
            )}
          </button>
        </div>
      </header>

      {/* Required applicant-owned background, separate from editable sample
          template text. New entrants can truthfully select no experience. */}
      <section id="resume-applicant-essentials" className="mx-auto mt-4 mb-3 w-[min(94vw,900px)] rounded-2xl border border-emerald-200 bg-white shadow p-5">
        <h2 className="font-extrabold text-lg text-emerald-950">Complete your real resume basics</h2>
        <p className="text-sm text-slate-600 mt-2">
          Replace the sample name and contact on your resume, then add your actual education and career background.
          No prior job, certification, TIN, SSS or other government number is required.
          If you are starting out, select the new entrant options—do not claim skills you do not have.
        </p>
        {missingEssentials.length > 0 && (
          <div role="alert" data-testid="resume-missing" className="bg-amber-50 border border-amber-400 text-amber-950 p-3 mt-3 rounded-lg">
            <strong>Complete these details before continuing:</strong>
            <ul className="text-sm list-disc pl-5 mt-1">
              {missingEssentials.map(item => <li key={item.key}>{item.label}</li>)}
            </ul>
          </div>
        )}
        <div className="grid sm:grid-cols-2 gap-3 mt-4">
          <label className="text-sm font-semibold">Highest schooling
            <select aria-label="Resume highest education" value={careerEducation}
              onChange={event => { setCareerEducation(event.target.value); setMissingEssentials([]); }}
              className="mt-1 w-full border border-gray-300 rounded-lg p-3 bg-white">
              <option value="">Choose your education</option>
              {educationChoices.map(v => <option key={v} value={v}>{v}</option>)}
            </select>
          </label>
          <label className="text-sm font-semibold">Work experience
            <select aria-label="Resume work experience" value={experienceStatus}
              onChange={event => { setExperienceStatus(event.target.value); setMissingEssentials([]); }}
              className="mt-1 w-full border border-gray-300 rounded-lg p-3 bg-white">
              <option value="">Select your situation</option>
              {experienceChoices.map(v => <option key={v} value={v}>{v}</option>)}
            </select>
          </label>
          <label className="text-sm font-semibold sm:col-span-2">Skills and training
            <select aria-label="Resume skills stage" value={skillsStage}
              onChange={event => { setSkillsStage(event.target.value); setMissingEssentials([]); }}
              className="mt-1 w-full border border-gray-300 rounded-lg p-3 bg-white">
              <option value="">Select your situation</option>
              {skillsChoices.map(v => <option key={v} value={v}>{v}</option>)}
            </select>
          </label>
          {skillsStage === skillsChoices[0] && (
            <label className="text-sm font-semibold sm:col-span-2">Skills you can honestly describe
              <textarea aria-label="Resume applicant skills" rows={2} value={careerSkills}
                onChange={event => { setCareerSkills(event.target.value); setMissingEssentials([]); }}
                className="mt-1 w-full border border-gray-300 rounded-lg p-3"
                placeholder="e.g. Customer service, basic carpentry or computer skills" />
            </label>
          )}
        </div>
      </section>

      {/* Canvas Workspace */}
      <main className="flex-1 overflow-auto p-2 sm:p-6 flex justify-center items-start bg-neutral-200/70">
        <div
          id="zoom-wrapper"
          style={{
            transform: `scale(${zoom * fitScale})`,
            transformOrigin: "top center",
            marginBottom: `${canvasHeight * (zoom * fitScale - 1)}px`,
            transition: "transform 0.15s ease-out",
          }}
        >
          {/* 210mm x 297mm standard sheet container */}
          <div id="resume-node" className="w-[794px] min-h-[1123px] bg-white shadow-2xl relative overflow-hidden">
            {activeTemplate === "sally" && <TemplateSally photo={currentPhoto} />}
            {activeTemplate === "emily" && <TemplateEmily photo={currentPhoto} />}
            {activeTemplate === "richard" && <TemplateRichard photo={currentPhoto} />}
            {activeTemplate === "dian" && <TemplateDian photo={currentPhoto} />}
          </div>
        </div>
      </main>
    </div>
  );
}

// ==========================================
// 1. TEMPLATE: SALLY BRANDERS (Teal Wave)
// ==========================================
function TemplateSally({ photo }) {
  return (
    <div className="w-full h-full flex flex-col bg-white text-neutral-800 text-[13px] leading-relaxed">
      {/* Header with diagonal wave */}
      <div className="relative h-48 w-full overflow-hidden bg-white">
        {/* Teal Header Accent Bar */}
        <div className="absolute top-0 right-0 w-full h-24 bg-[#0a8296]" />
        
        {/* Angular decorative cut */}
        <svg className="absolute top-0 left-0 w-80 h-48" viewBox="0 0 320 192" fill="none">
          <path d="M0 0 L300 0 L230 192 L0 192 Z" fill="#0a8296" />
        </svg>

        {/* Photo Container */}
        <div className="absolute top-5 left-10 w-36 h-36 rounded-full border-4 border-white overflow-hidden shadow-md z-10">
          <img src={photo} alt="Avatar" className="w-full h-full object-cover" crossOrigin="anonymous" />
        </div>

        {/* Name and Title */}
        <div className="absolute top-4 left-56 pl-6 z-10">
          <h1 className="text-3xl font-bold text-neutral-900 tracking-tight">
            <Editable defaultText="Sally" prefillKey="firstName" />
          </h1>
          <h2 className="text-4xl font-extrabold text-neutral-900 tracking-tight leading-none mb-3">
            <Editable defaultText="Branders" prefillKey="lastName" />
          </h2>
          <div className="bg-[#0a8296] text-white font-semibold text-xs tracking-wider uppercase px-4 py-1.5 inline-block">
            <Editable defaultText="JOB TITLE" />
          </div>
        </div>
      </div>

      {/* Two Column Layout */}
      <div className="grid grid-cols-12 gap-8 px-10 py-4 flex-1">
        {/* Left Column (4 cols) */}
        <div className="col-span-4 space-y-6">
          {/* Contact */}
          <section>
            <h3 className="font-extrabold text-neutral-900 text-sm tracking-wide uppercase border-b-2 border-[#0a8296] pb-1 mb-3">
              <Editable defaultText="CONTACTO" />
            </h3>
            <ul className="space-y-2 text-neutral-700 text-xs">
              <li className="flex items-center"><MailIcon /> <Editable defaultText="sally.branders@gmail.com" prefillKey="email" /></li>
              <li className="flex items-center"><PhoneIcon /> <Editable defaultText="+1 232 555 55 55" prefillKey="phone" /></li>
              <li className="flex items-center"><PinIcon /> <Editable defaultText="NY, USA" /></li>
              <li className="flex items-center"><GlobeIcon /> <Editable defaultText="linkedin/sally.branders" /></li>
            </ul>
          </section>

          {/* Profile Summary */}
          <section>
            <h3 className="font-extrabold text-neutral-900 text-sm tracking-wide uppercase border-b-2 border-[#0a8296] pb-1 mb-2">
              <Editable defaultText="PROFILE SUMMARY" />
            </h3>
            <p className="text-neutral-600 text-xs leading-normal">
              <Editable defaultText="Business development manager looking to obtain a challenging position in an organization, utilizing my proven track record in driving revenue growth and forging strategic partnerships to achieve business objectives." />
            </p>
          </section>

          {/* Skills */}
          <section>
            <h3 className="font-extrabold text-neutral-900 text-sm tracking-wide uppercase border-b-2 border-[#0a8296] pb-1 mb-2">
              <Editable defaultText="SKILLS" />
            </h3>
            <ul className="space-y-1.5 text-xs text-neutral-700">
              <li><CheckIcon /><Editable defaultText="Excel" /></li>
              <li><CheckIcon /><Editable defaultText="PowerPoint" /></li>
              <li><CheckIcon /><Editable defaultText="CRM" /></li>
              <li><CheckIcon /><Editable defaultText="Problem-Solving" /></li>
              <li><CheckIcon /><Editable defaultText="Team Leadership" /></li>
            </ul>
          </section>

          {/* Languages */}
          <section>
            <h3 className="font-extrabold text-neutral-900 text-sm tracking-wide uppercase border-b-2 border-[#0a8296] pb-1 mb-2">
              <Editable defaultText="LANGUAGES" />
            </h3>
            <ul className="space-y-1.5 text-xs text-neutral-700">
              <li><CheckIcon /><Editable defaultText="English: Native" /></li>
              <li><CheckIcon /><Editable defaultText="Spanish: Intermediate" /></li>
              <li><CheckIcon /><Editable defaultText="French: Beginner" /></li>
            </ul>
          </section>
        </div>

        {/* Right Column (8 cols) */}
        <div className="col-span-8 space-y-6">
          {/* Experience */}
          <section>
            <h3 className="font-extrabold text-neutral-900 text-sm tracking-wide uppercase border-b-2 border-[#0a8296] pb-1 mb-4">
              <Editable defaultText="PROFESSIONAL EXPERIENCE" />
            </h3>

            <div className="space-y-4 text-xs">
              <div>
                <div className="font-bold text-neutral-900 uppercase"><Editable defaultText="XYZ CONSULTING FIRM" /></div>
                <div className="text-neutral-500 italic"><Editable defaultText="Business Development Manager" /></div>
                <div className="text-neutral-400 mb-1"><Editable defaultText="NY, USA | 00/0000 - 00/0000" /></div>
                <ul className="list-disc list-inside space-y-1 text-neutral-600 pl-1">
                  <li><Editable defaultText="Developed and executed a comprehensive sales strategy, resulting in a 40% increase in annual revenue within one year." /></li>
                  <li><Editable defaultText="Identified and pursued new business opportunities through market research." /></li>
                </ul>
              </div>

              <div>
                <div className="font-bold text-neutral-900 uppercase"><Editable defaultText="ABC CORPORATION" /></div>
                <div className="text-neutral-500 italic"><Editable defaultText="Sales Representative" /></div>
                <div className="text-neutral-400 mb-1"><Editable defaultText="NY, USA | 00/0000 - 00/0000" /></div>
                <ul className="list-disc list-inside space-y-1 text-neutral-600 pl-1">
                  <li><Editable defaultText="Achieved consistent sales targets by successfully prospecting and closing new business opportunities in a competitive market." /></li>
                  <li><Editable defaultText="Conducted product demonstrations and presentations to potential clients." /></li>
                </ul>
              </div>

              <div>
                <div className="font-bold text-neutral-900 uppercase"><Editable defaultText="DEF RESEARCH AGENCY" /></div>
                <div className="text-neutral-500 italic"><Editable defaultText="Market Research Analyst" /></div>
                <div className="text-neutral-400 mb-1"><Editable defaultText="NY, USA | 00/0000 - 00/0000" /></div>
                <ul className="list-disc list-inside space-y-1 text-neutral-600 pl-1">
                  <li><Editable defaultText="Conducted in-depth market research and competitor analysis, providing valuable insights to guide strategic decision-making." /></li>
                  <li><Editable defaultText="Developed comprehensive market reports." /></li>
                </ul>
              </div>
            </div>
          </section>

          {/* Education */}
          <section>
            <h3 className="font-extrabold text-neutral-900 text-sm tracking-wide uppercase border-b-2 border-[#0a8296] pb-1 mb-4">
              <Editable defaultText="EDUCATION" />
            </h3>
            <div className="space-y-3 text-xs">
              <div>
                <div className="font-bold text-neutral-900 uppercase"><Editable defaultText="MASTER OF BUSINESS ADMINISTRATION" /></div>
                <div className="text-neutral-600"><Editable defaultText="NYU" /></div>
                <div className="text-neutral-400"><Editable defaultText="NY, USA | 20XX - 20XX" /></div>
              </div>
              <div>
                <div className="font-bold text-neutral-900 uppercase"><Editable defaultText="BACHELOR OF COMMERCE IN MARKETING" /></div>
                <div className="text-neutral-600"><Editable defaultText="NYU" /></div>
                <div className="text-neutral-400"><Editable defaultText="NY, USA | 20XX - 20XX" /></div>
              </div>
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}

// ==========================================
// 2. TEMPLATE: EMILY CARTER (Minimalist / Blush)
// ==========================================
function TemplateEmily({ photo }) {
  return (
    <div className="w-full h-full flex bg-white text-neutral-800 text-[12px]">
      {/* Left Column (Warm Sand/Blush) */}
      <div className="w-[36%] bg-[#ddc8bc] p-8 flex flex-col items-center text-left">
        <div className="w-36 h-36 rounded-full overflow-hidden mb-8 border-2 border-white shadow-sm">
          <img src={photo} alt="Avatar" className="w-full h-full object-cover" crossOrigin="anonymous" />
        </div>

        <div className="w-full space-y-6">
          <section>
            <h3 className="font-bold text-base text-neutral-900 mb-2">
              <Editable defaultText="About Me" />
            </h3>
            <p className="text-neutral-700 leading-snug">
              <Editable defaultText="Donec in nunc elementum, posuere nisl sit amet, tincidunt nulla. Duis nec commodo leo." />
            </p>
          </section>

          <section className="space-y-2 text-neutral-800">
            <div className="flex items-start"><PinIcon /><Editable defaultText="450 Sunrise Avenue, Solaris City, Mars" /></div>
            <div className="flex items-start"><PhoneIcon /><Editable defaultText="+1 234 567 8900" prefillKey="phone" /></div>
            <div className="flex items-start"><MailIcon /><Editable defaultText="emily.carter@futuremail.com" prefillKey="email" /></div>
            <div className="flex items-start"><GlobeIcon /><Editable defaultText="linkedin.com/in/emily-carter" /></div>
          </section>

          <section>
            <h3 className="font-bold text-base text-neutral-900 mb-1.5">
              <Editable defaultText="Objective" />
            </h3>
            <p className="text-neutral-700 leading-snug">
              <Editable defaultText="A highly motivated and forward-thinking software engineer with a strong background in AI development, seeking to leverage my expertise in a dynamic tech environment." />
            </p>
          </section>

          <section>
            <h3 className="font-bold text-base text-neutral-900 mb-1.5">
              <Editable defaultText="Education" />
            </h3>
            <div className="font-semibold text-neutral-900"><Editable defaultText="Masters in Computer Science" /></div>
            <div className="text-neutral-700"><Editable defaultText="Mars University, Solaris City" /></div>
            <div className="text-neutral-600 mb-1"><Editable defaultText="Graduated: 2064" /></div>
            <p className="text-neutral-700 text-[11px] leading-tight">
              <Editable defaultText="Focus on Artificial Intelligence and Quantum Computing. Completed a thesis on Next-Generation Neural Networks." />
            </p>
          </section>

          <section>
            <h3 className="font-bold text-base text-neutral-900 mb-1">
              <Editable defaultText="Language" />
            </h3>
            <p className="text-neutral-700"><Editable defaultText="Fluent in English and Spanish." /></p>
            <p className="text-neutral-600 text-[11px]"><Editable defaultText="Basic proficiency in Martian Standard Language." /></p>
          </section>

          <section>
            <h3 className="font-bold text-base text-neutral-900 mb-1">
              <Editable defaultText="Reference" />
            </h3>
            <p className="text-neutral-700"><Editable defaultText="Available upon request." /></p>
          </section>
        </div>
      </div>

      {/* Right Column (Clean White) */}
      <div className="w-[64%] p-10 flex flex-col justify-between">
        {/* Name Title Block */}
        <div>
          <h1 className="text-4xl tracking-widest font-light text-neutral-900 leading-none mb-1">
            <Editable defaultText="EMILY" prefillKey="firstName" />
          </h1>
          <h1 className="text-5xl tracking-widest font-extralight text-neutral-800 leading-none mb-3">
            <Editable defaultText="CARTER" prefillKey="lastName" />
          </h1>
          <h2 className="text-xl font-medium text-neutral-800 mb-8 tracking-wide">
            <Editable defaultText="Software Engineer" />
          </h2>
        </div>

        {/* Content sections with thin divider lines */}
        <div className="space-y-6">
          {/* Experience */}
          <section>
            <div className="flex items-center gap-3 mb-2">
              <h3 className="font-bold text-sm tracking-wide text-neutral-900 uppercase">
                <Editable defaultText="Experience" />
              </h3>
              <div className="flex-1 border-b border-neutral-400" />
            </div>

            <div className="space-y-3">
              <div>
                <div className="flex justify-between font-bold text-neutral-900">
                  <Editable defaultText="Senior Software Engineer" />
                </div>
                <div className="flex justify-between text-neutral-600 text-[11px] mb-1">
                  <Editable defaultText="Innovatech Solutions, Earth Orbit" />
                  <Editable defaultText="July 2065 – Present" />
                </div>
                <p className="text-neutral-700 text-[11px] leading-normal">
                  <Editable defaultText="Leading a team of 10 in developing cutting-edge AI algorithms for space exploration. Successfully deployed AI systems in three interstellar missions." />
                </p>
              </div>

              <div>
                <div className="flex justify-between font-bold text-neutral-900">
                  <Editable defaultText="Software Engineer" />
                </div>
                <div className="flex justify-between text-neutral-600 text-[11px] mb-1">
                  <Editable defaultText="TechPioneers, Mars Colony" />
                  <Editable defaultText="June 2064 – June 2065" />
                </div>
                <p className="text-neutral-700 text-[11px] leading-normal">
                  <Editable defaultText="Developed and maintained AI-driven climate control systems for Martian habitats, improving energy efficiency by 30%." />
                </p>
              </div>
            </div>
          </section>

          {/* Skills */}
          <section>
            <div className="flex items-center gap-3 mb-2">
              <h3 className="font-bold text-sm tracking-wide text-neutral-900 uppercase">
                <Editable defaultText="Skills" />
              </h3>
              <div className="flex-1 border-b border-neutral-400" />
            </div>
            <ul className="list-disc list-inside space-y-1 text-neutral-700 text-[11px]">
              <li><strong className="text-neutral-900">Programming Languages:</strong> <Editable defaultText="Proficient in Python, Java, and C++." /></li>
              <li><strong className="text-neutral-900">Technologies:</strong> <Editable defaultText="Experienced in AI, Machine Learning, Quantum Computing." /></li>
              <li><strong className="text-neutral-900">Soft Skills:</strong> <Editable defaultText="Strong leadership abilities, excellent communication skills." /></li>
            </ul>
          </section>

          {/* Projects */}
          <section>
            <div className="flex items-center gap-3 mb-2">
              <h3 className="font-bold text-sm tracking-wide text-neutral-900 uppercase">
                <Editable defaultText="Projects" />
              </h3>
              <div className="flex-1 border-b border-neutral-400" />
            </div>
            <div className="space-y-2 text-[11px]">
              <div>
                <div className="font-bold text-neutral-900"><Editable defaultText="Martian Weather Prediction Model" /></div>
                <p className="text-neutral-700"><Editable defaultText="Developed a highly accurate weather prediction model for Mars using machine learning techniques." /></p>
              </div>
              <div>
                <div className="font-bold text-neutral-900"><Editable defaultText="Quantum Encryption Algorithm" /></div>
                <p className="text-neutral-700"><Editable defaultText="Created a quantum-resistant encryption algorithm, enhancing data security for interplanetary communications." /></p>
              </div>
            </div>
          </section>

          {/* Certifications */}
          <section>
            <div className="flex items-center gap-3 mb-1">
              <h3 className="font-bold text-sm tracking-wide text-neutral-900 uppercase">
                <Editable defaultText="Certifications" />
              </h3>
              <div className="flex-1 border-b border-neutral-400" />
            </div>
            <p className="text-neutral-700 text-[11px]"><Editable defaultText="Certified AI Professional, AI Institute, Earth (2066)" /></p>
            <p className="text-neutral-700 text-[11px]"><Editable defaultText="Quantum Computing Fundamentals, Quantum Tech Academy (2065)" /></p>
          </section>

          {/* Interests */}
          <section>
            <div className="flex items-center gap-3 mb-1">
              <h3 className="font-bold text-sm tracking-wide text-neutral-900 uppercase">
                <Editable defaultText="Interests" />
              </h3>
              <div className="flex-1 border-b border-neutral-400" />
            </div>
            <p className="text-neutral-700 text-[11px]"><Editable defaultText="Participating in hackathons and tech talks. Volunteering in STEM education programs." /></p>
          </section>
        </div>
      </div>
    </div>
  );
}

// ==========================================
// 3. TEMPLATE: RICHARD SANCHEZ (Slate Timeline)
// ==========================================
function TemplateRichard({ photo }) {
  return (
    <div className="w-full h-full flex flex-col bg-white text-neutral-800 text-[12px]">
      {/* Dark Slate Top Bar */}
      <div className="h-44 bg-[#323b49] text-white flex items-center justify-end px-12 relative">
        <div className="absolute -bottom-12 left-10 w-36 h-36 rounded-full border-4 border-white overflow-hidden shadow-lg z-10 bg-white">
          <img src={photo} alt="Avatar" className="w-full h-full object-cover" crossOrigin="anonymous" />
        </div>
        <div className="text-left w-3/5">
          <h1 className="text-3xl font-extrabold tracking-wider uppercase mb-1">
            <Editable defaultText="RICHARD SANCHEZ" prefillKey="fullName" />
          </h1>
          <h2 className="text-xs tracking-widest text-neutral-300 uppercase font-light">
            <Editable defaultText="MARKETING MANAGER" />
          </h2>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex flex-1 pt-16">
        {/* Left Sidebar (Light Gray) */}
        <div className="w-[35%] bg-[#edf0f2] px-8 py-4 space-y-6">
          <section>
            <h3 className="font-extrabold text-neutral-900 text-xs tracking-widest uppercase border-b border-neutral-300 pb-1 mb-3">
              <Editable defaultText="CONTACT" />
            </h3>
            <ul className="space-y-2 text-neutral-600 text-xs">
              <li className="flex items-center"><PhoneIcon /><Editable defaultText="+123-456-7890" prefillKey="phone" /></li>
              <li className="flex items-center"><MailIcon /><Editable defaultText="hello@reallygreatsite.com" prefillKey="email" /></li>
              <li className="flex items-center"><PinIcon /><Editable defaultText="123 Anywhere St., Any City" /></li>
              <li className="flex items-center"><GlobeIcon /><Editable defaultText="www.reallygreatsite.com" /></li>
            </ul>
          </section>

          <section>
            <h3 className="font-extrabold text-neutral-900 text-xs tracking-widest uppercase border-b border-neutral-300 pb-1 mb-3">
              <Editable defaultText="SKILLS" />
            </h3>
            <ul className="list-disc list-inside space-y-1 text-neutral-700 text-xs">
              <li><Editable defaultText="Project Management" /></li>
              <li><Editable defaultText="Public Relations" /></li>
              <li><Editable defaultText="Teamwork" /></li>
              <li><Editable defaultText="Time Management" /></li>
              <li><Editable defaultText="Leadership" /></li>
              <li><Editable defaultText="Effective Communication" /></li>
              <li><Editable defaultText="Critical Thinking" /></li>
              <li><Editable defaultText="Digital Marketing" /></li>
            </ul>
          </section>

          <section>
            <h3 className="font-extrabold text-neutral-900 text-xs tracking-widest uppercase border-b border-neutral-300 pb-1 mb-3">
              <Editable defaultText="LANGUAGES" />
            </h3>
            <ul className="list-disc list-inside space-y-1 text-neutral-700 text-xs">
              <li><Editable defaultText="English (Fluent)" /></li>
              <li><Editable defaultText="French (Fluent)" /></li>
              <li><Editable defaultText="German (Basic)" /></li>
              <li><Editable defaultText="Spanish (Intermediate)" /></li>
            </ul>
          </section>

          <section>
            <h3 className="font-extrabold text-neutral-900 text-xs tracking-widest uppercase border-b border-neutral-300 pb-1 mb-3">
              <Editable defaultText="REFERENCE" />
            </h3>
            <div className="text-xs">
              <div className="font-bold text-neutral-800"><Editable defaultText="Estelle Darcy" /></div>
              <div className="text-neutral-500 text-[11px]"><Editable defaultText="Wardiere Inc. / CTO" /></div>
              <div className="text-neutral-600 text-[11px] mt-1"><Editable defaultText="Phone: 123-456-7890" /></div>
              <div className="text-neutral-600 text-[11px]"><Editable defaultText="Email: hello@reallygreatsite.com" /></div>
            </div>
          </section>
        </div>

        {/* Right Main Column (Timeline Style) */}
        <div className="w-[65%] px-10 py-4 relative">
          {/* Vertical timeline line */}
          <div className="absolute left-14 top-8 bottom-12 w-0.5 bg-neutral-300" />

          {/* Profile Section */}
          <div className="relative pl-12 mb-8">
            <div className="absolute -left-[14px] top-0 w-7 h-7 rounded-full bg-[#323b49] text-white flex items-center justify-center text-xs shadow">
              ●
            </div>
            <h3 className="font-extrabold text-neutral-900 text-xs tracking-wider uppercase mb-2">
              <Editable defaultText="PROFILE" />
            </h3>
            <p className="text-neutral-600 text-xs leading-relaxed">
              <Editable defaultText="Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam quis nostrud exercitation ullamco laboris." />
            </p>
          </div>

          {/* Work Experience Section */}
          <div className="relative pl-12 mb-8">
            <div className="absolute -left-[14px] top-0 w-7 h-7 rounded-full bg-[#323b49] text-white flex items-center justify-center text-xs shadow">
              ■
            </div>
            <h3 className="font-extrabold text-neutral-900 text-xs tracking-wider uppercase mb-3">
              <Editable defaultText="WORK EXPERIENCE" />
            </h3>

            <div className="space-y-4 text-xs">
              <div>
                <div className="flex justify-between font-bold text-neutral-900">
                  <Editable defaultText="Borcelle Studio" />
                  <span className="text-neutral-500 font-normal"><Editable defaultText="2030 - PRESENT" /></span>
                </div>
                <div className="text-neutral-600 italic mb-1.5"><Editable defaultText="Marketing Manager & Specialist" /></div>
                <ul className="list-disc list-inside space-y-1 text-neutral-600 text-[11px]">
                  <li><Editable defaultText="Develop and execute comprehensive marketing strategies and campaigns." /></li>
                  <li><Editable defaultText="Lead, mentor, and manage a high-performing marketing team." /></li>
                  <li><Editable defaultText="Monitor brand consistency across marketing channels and materials." /></li>
                </ul>
              </div>

              <div>
                <div className="flex justify-between font-bold text-neutral-900">
                  <Editable defaultText="Fauget Studio" />
                  <span className="text-neutral-500 font-normal"><Editable defaultText="2025 - 2029" /></span>
                </div>
                <div className="text-neutral-600 italic mb-1.5"><Editable defaultText="Marketing Manager & Specialist" /></div>
                <ul className="list-disc list-inside space-y-1 text-neutral-600 text-[11px]">
                  <li><Editable defaultText="Create and manage the marketing budget, ensuring efficient allocation." /></li>
                  <li><Editable defaultText="Oversee market research to identify emerging trends and customer needs." /></li>
                </ul>
              </div>
            </div>
          </div>

          {/* Education Section */}
          <div className="relative pl-12">
            <div className="absolute -left-[14px] top-0 w-7 h-7 rounded-full bg-[#323b49] text-white flex items-center justify-center text-xs shadow">
              🎓
            </div>
            <h3 className="font-extrabold text-neutral-900 text-xs tracking-wider uppercase mb-3">
              <Editable defaultText="EDUCATION" />
            </h3>

            <div className="space-y-3 text-xs">
              <div>
                <div className="flex justify-between font-bold text-neutral-900">
                  <Editable defaultText="Master of Business Management" />
                  <span className="text-neutral-500 font-normal"><Editable defaultText="2029 - 2031" /></span>
                </div>
                <div className="text-neutral-600"><Editable defaultText="School of business | Wardiere University" /></div>
                <div className="text-neutral-500 text-[11px]"><Editable defaultText="GPA: 3.8 / 4.0" /></div>
              </div>

              <div>
                <div className="flex justify-between font-bold text-neutral-900">
                  <Editable defaultText="Bachelor of Business Management" />
                  <span className="text-neutral-500 font-normal"><Editable defaultText="2025 - 2029" /></span>
                </div>
                <div className="text-neutral-600"><Editable defaultText="School of business | Wardiere University" /></div>
                <div className="text-neutral-500 text-[11px]"><Editable defaultText="GPA: 3.8 / 4.0" /></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ==========================================
// 4. TEMPLATE: DIAN NUGRAHA (Organic Pastel Wave)
// ==========================================
function TemplateDian({ photo }) {
  return (
    <div className="w-full h-full flex bg-white text-neutral-800 text-[12px] relative overflow-hidden">
      {/* Left Sidebar with SVG wave shapes */}
      <div className="w-[38%] bg-[#122e43] text-white flex flex-col justify-between relative overflow-hidden">
        {/* Soft Lavender Top block holding the photo */}
        <div className="bg-[#ddd5e8] p-8 flex justify-center items-center">
          <div className="w-36 h-36 rounded-full overflow-hidden border-4 border-white shadow">
            <img src={photo} alt="Avatar" className="w-full h-full object-cover" crossOrigin="anonymous" />
          </div>
        </div>

        {/* Contact & Objective */}
        <div className="p-8 space-y-6 z-10">
          <ul className="space-y-3 text-xs text-neutral-200">
            <li className="flex items-start">
              <PinIcon />
              <span><Editable defaultText="210 Stars Ave, Berkeley, CA 78910" /></span>
            </li>
            <li className="flex items-center">
              <PhoneIcon />
              <span><Editable defaultText="808.555.0118" prefillKey="phone" /></span>
            </li>
            <li className="flex items-center">
              <MailIcon />
              <span><Editable defaultText="dian@example.com" prefillKey="email" /></span>
            </li>
            <li className="flex items-center">
              <GlobeIcon />
              <span><Editable defaultText="www.greatsiteaddress.com" /></span>
            </li>
          </ul>

          <section>
            <h3 className="font-extrabold text-sm uppercase tracking-wider mb-2 text-white">
              <Editable defaultText="OBJECTIVE" />
            </h3>
            <p className="text-neutral-300 text-[11px] leading-relaxed">
              <Editable defaultText="Office Manager with 5 years of experience in managing administrative tasks, seeking a challenging position to leverage organizational, communication, and leadership skills." />
            </p>
          </section>
        </div>

        {/* Decorative Colorful Organic Waves at bottom */}
        <div className="relative w-full h-40 mt-auto">
          <svg className="absolute bottom-0 left-0 w-full h-full" preserveAspectRatio="none" viewBox="0 0 300 200">
            <path d="M 0 120 C 70 80, 120 180, 200 130 C 260 90, 290 120, 300 110 L 300 200 L 0 200 Z" fill="#eedff5" />
            <path d="M 0 140 C 50 110, 100 190, 170 140 C 220 110, 260 170, 300 150 L 300 200 L 0 200 Z" fill="#ffd454" />
            <path d="M 0 170 C 80 140, 130 190, 210 160 C 260 140, 280 180, 300 170 L 300 200 L 0 200 Z" fill="#ffb8cc" />
          </svg>
        </div>
      </div>

      {/* Right Column */}
      <div className="w-[62%] p-10 space-y-6">
        <h1 className="text-3xl font-extrabold tracking-tight uppercase text-neutral-900 border-b pb-4">
          <Editable defaultText="DIAN NUGRAHA" prefillKey="fullName" />
        </h1>

        {/* Experience */}
        <section>
          <h3 className="font-extrabold text-sm text-[#5d4177] uppercase tracking-wider mb-2">
            <Editable defaultText="EXPERIENCE" />
          </h3>
          <div className="space-y-3 text-xs">
            <div>
              <div className="font-bold text-neutral-900"><Editable defaultText="Dec 20XX–Jan 20XX" /></div>
              <div className="text-neutral-600"><Editable defaultText="Office Manager • Northwind Traders" /></div>
            </div>
            <div>
              <div className="font-bold text-neutral-900"><Editable defaultText="Feb 20XX–Dec 20XX" /></div>
              <div className="text-neutral-600"><Editable defaultText="Administrative Assistant • Wide World Importers" /></div>
            </div>
            <div>
              <div className="font-bold text-neutral-900"><Editable defaultText="Mar 20XX–Feb 20XX" /></div>
              <div className="text-neutral-600"><Editable defaultText="Office Intern • Olson Harris, Ltd." /></div>
            </div>
            <p className="text-neutral-600 text-[11px] mt-1">
              <Editable defaultText="Developed and implemented office policies and procedures to improve office efficiency and reduce costs." />
            </p>
          </div>
        </section>

        {/* Education */}
        <section>
          <h3 className="font-extrabold text-sm text-[#5d4177] uppercase tracking-wider mb-2">
            <Editable defaultText="EDUCATION" />
          </h3>
          <div className="text-xs">
            <div className="font-bold text-neutral-900"><Editable defaultText="Bellows College, Berkeley, CA" /></div>
            <div className="text-neutral-600"><Editable defaultText="• Bachelor of Science in Business Administration, 20XX" /></div>
          </div>
        </section>

        {/* Communication */}
        <section>
          <h3 className="font-extrabold text-sm text-[#5d4177] uppercase tracking-wider mb-1">
            <Editable defaultText="COMMUNICATION" />
          </h3>
          <p className="text-neutral-600 text-[11px] leading-relaxed">
            <Editable defaultText="As an office manager, I have honed my communication skills through years of experience in verbal and written communication with clients, vendors, and team members. I have extensive experience in creating and delivering presentations, preparing and responding to business correspondence." />
          </p>
        </section>

        {/* Leadership */}
        <section>
          <h3 className="font-extrabold text-sm text-[#5d4177] uppercase tracking-wider mb-1">
            <Editable defaultText="LEADERSHIP" />
          </h3>
          <p className="text-neutral-600 text-[11px] leading-relaxed">
            <Editable defaultText="I have demonstrated strong leadership skills in managing a team of administrative staff and supervising daily office operations. I have experience in providing guidance and support to staff, setting performance expectations." />
          </p>
        </section>

        {/* References */}
        <section>
          <h3 className="font-extrabold text-sm text-[#5d4177] uppercase tracking-wider mb-1">
            <Editable defaultText="REFERENCES" />
          </h3>
          <p className="text-neutral-600 text-xs"><Editable defaultText="Available upon request." /></p>
        </section>
      </div>
    </div>
  );
}