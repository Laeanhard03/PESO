import { useEffect, useRef, useState } from 'react';
import * as htmlToImage from "html-to-image";
import { jsPDF } from "jspdf";
import { sendToFlutter } from './flutterBridge.js';
import { applicantCareerEntries, educationChoices, experienceChoices, skillsChoices } from './applicantEssentials.js';
import { collectMissingNsrpFields } from './nsrpRequiredFields.js';
import pesoformicon from './assets/pesoformicon.png';

const GreenLabel = ({ children, className = '', required = false }) => (
  <span className={(required ? 'bg-green-200/60 ' : '') + 'px-1 font-bold ' + className}>
    {children}
    {required && <span aria-hidden="true" className="ml-0.5 font-black text-red-600">*</span>}
  </span>
);
export default function App() {
  const [zoomLevel, setZoomLevel] = useState(1);
  const [fitScale, setFitScale] = useState(1);
  const [contentHeight, setContentHeight] = useState(2400);
  const [isProcessing, setIsProcessing] = useState(false);
  const [careerEducation, setCareerEducation] = useState('');
  const [experienceStatus, setExperienceStatus] = useState('');
  const [skillsStage, setSkillsStage] = useState('');
  const [careerSkills, setCareerSkills] = useState('');
  const [missingEssentials, setMissingEssentials] = useState([]);
  const [validationOpen, setValidationOpen] = useState(false);
  const signatureCanvasRef = useRef(null);
  const [isSigning, setIsSigning] = useState(false);
  const [hasSignature, setHasSignature] = useState(false);
  const zoomRef = useRef(1);
  const fitScaleRef = useRef(1);
  const heightRef = useRef(2400);
  const pinchRef = useRef(null);
  const previewScale = zoomLevel * fitScale;
  const [dateOfBirth, setDateOfBirth] = useState('');
  const [sex, setSex] = useState('');
  const [religion, setReligion] = useState('');
  const manualDobRef = useRef(null);
  const [draftStatus, setDraftStatus] = useState('Offline Draft');
  const ownerUidRef = useRef('');
  const draftTimerRef = useRef(null);
  const lastDraftRef = useRef(null);
  const restoringRef = useRef(false);
  const draftFieldsRef = useRef({});
  useEffect(() => {
    draftFieldsRef.current = { dateOfBirth, sex, religion,
      careerEducation, experienceStatus, skillsStage, careerSkills, hasSignature };
  }, [dateOfBirth, sex, religion, careerEducation,
    experienceStatus, skillsStage, careerSkills, hasSignature]);

  const dobAsText = iso => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(iso || '')) return '';
    const [year, month, day] = iso.split('-');
    return month + '/' + day + '/' + year;
  };
  const changeTypedDob = value => {
    const match = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(value.trim());
    if (!match) { setDateOfBirth(''); return; }
    const [, m, d, y] = match;
    const iso = y + '-' + m.padStart(2, '0') + '-' + d.padStart(2, '0');
    const parsed = new Date(iso + 'T12:00:00');
    const valid = !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === iso;
    setDateOfBirth(valid ? iso : '');
    if (valid) setMissingEssentials(previous => previous.filter(item => item.key !== 'dateOfBirth'));
  };

  const snapshotDraft = () => {
    const fields = draftFieldsRef.current;
    const controls = Array.from(document.querySelectorAll(
      '#zoom-wrapper input, #zoom-wrapper select, #zoom-wrapper textarea',
    )).filter(node => !['hidden', 'submit', 'button', 'reset', 'file'].includes(
      (node.type || '').toLowerCase()));
    return {
      documentType: 'NSRP Form 1 Draft',
      draftUpdatedAt: new Date().toISOString(),
      entries: controls.map((node, index) => {
        const type = (node.type || node.tagName || '').toLowerCase();
        const checked = type === 'checkbox' || type === 'radio' ? node.checked : undefined;
        return {
          index: index + 1, type, value: checked === undefined
            ? String(node.value || '').slice(0, 5000) : checked ? 'Selected' : '',
          ...(checked === undefined ? {} : { checked }),
        };
      }),
      applicantEssentials: {
        education: fields.careerEducation, experience: fields.experienceStatus,
        skillsStage: fields.skillsStage,
        skills: fields.skillsStage === skillsChoices[0] ? fields.careerSkills : '',
      },
      dateOfBirth: fields.dateOfBirth, sex: fields.sex, religion: fields.religion,
      signatureDataUrl: fields.hasSignature && signatureCanvasRef.current
        ? signatureCanvasRef.current.toDataURL('image/png') : null,
    };
  };

  const age = (() => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateOfBirth)) return '';
    const born = new Date(`${dateOfBirth}T12:00:00`);
    if (Number.isNaN(born.getTime()) || born.toISOString().slice(0, 10) !== dateOfBirth) return '';
    const today = new Date();
    let years = today.getFullYear() - born.getFullYear();
    if (today.getMonth() < born.getMonth() ||
        (today.getMonth() === born.getMonth() && today.getDate() < born.getDate())) years--;
    return years >= 0 && years <= 120 ? String(years) : '';
  })();

  useEffect(() => { zoomRef.current = zoomLevel; }, [zoomLevel]);

  // Debounced encrypted draft persistence is performed in the authenticated
  // Flutter parent. Never put applicant fields in ordinary cookies/localStorage.
  useEffect(() => {
    const schedule = () => {
      if (restoringRef.current || !ownerUidRef.current) return;
      setDraftStatus('Saving');
      if (draftTimerRef.current) clearTimeout(draftTimerRef.current);
      draftTimerRef.current = window.setTimeout(() => {
        const draft = snapshotDraft();
        lastDraftRef.current = draft;
        if (!sendToFlutter({ status: 'draft', kind: 'nsrp_form', formData: draft })) {
          setDraftStatus('Sync Failed');
        }
      }, 900);
    };
    const goOnline = () => {
      if (lastDraftRef.current && ownerUidRef.current) {
        setDraftStatus('Saving');
        sendToFlutter({ status: 'draft', kind: 'nsrp_form',
          formData: lastDraftRef.current });
      }
    };
    document.addEventListener('input', schedule, true);
    document.addEventListener('change', schedule, true);
    window.addEventListener('online', goOnline);
    return () => {
      document.removeEventListener('input', schedule, true);
      document.removeEventListener('change', schedule, true);
      window.removeEventListener('online', goOnline);
      if (draftTimerRef.current) clearTimeout(draftTimerRef.current);
    };
  // snapshotDraft reads the current controlled fields through draftFieldsRef.
  }, []);


  const beginSignature = event => {
    const canvas = signatureCanvasRef.current;
    if (!canvas) return;
    event.preventDefault();
    const bounds = canvas.getBoundingClientRect();
    const context = canvas.getContext('2d');
    if (!context) return;
    const x = (event.clientX - bounds.left) * canvas.width / bounds.width;
    const y = (event.clientY - bounds.top) * canvas.height / bounds.height;
    canvas.setPointerCapture(event.pointerId);
    context.lineCap = 'round';
    context.lineJoin = 'round';
    context.fillStyle = '#17352b';
    context.beginPath();
    context.arc(x, y, 1.5, 0, Math.PI * 2);
    context.fill();
    context.beginPath();
    context.moveTo(x, y);
    setHasSignature(true);
    setMissingEssentials(previous => previous.filter(item => item.key !== 'signature'));
    setIsSigning(true);
  };

  const drawSignature = event => {
    const canvas = signatureCanvasRef.current;
    if (!isSigning || !canvas) return;
    const bounds = canvas.getBoundingClientRect();
    const context = canvas.getContext('2d');
    if (!context) return;
    const x = (event.clientX - bounds.left) * canvas.width / bounds.width;
    const y = (event.clientY - bounds.top) * canvas.height / bounds.height;
    context.lineWidth = 3;
    context.lineCap = 'round';
    context.lineJoin = 'round';
    context.strokeStyle = '#17352b';
    context.lineTo(x, y);
    context.stroke();
    setHasSignature(true);
    setMissingEssentials(previous => previous.filter(item => item.key !== 'signature'));
  };

  const clearSignature = () => {
    const canvas = signatureCanvasRef.current;
    if (!canvas) return;
    canvas.getContext('2d')?.clearRect(0, 0, canvas.width, canvas.height);
    setHasSignature(false);
    setIsSigning(false);
    if (validationOpen) {
      setMissingEssentials(previous => previous.some(item => item.key === 'signature')
        ? previous : [...previous, { key: 'signature', label: 'Applicant signature' }]);
    }
  };

  // Only mark fields invalid after a submit attempt, never on initial load.
  useEffect(() => {
    const invalidKeys = new Set(missingEssentials.map(item => item.key));

    document.querySelectorAll('[data-applicant-field], [data-nsrp-required], [data-nsrp-group]').forEach(control => {
      const directKey = control.getAttribute('data-applicant-field') ||
        control.getAttribute('data-nsrp-required');
      const groupKey = control.getAttribute('data-nsrp-group');
      // A green-highlighted group requires at least one answer, not every
      // optional checkbox/cell within the group. Highlight its first entry
      // rather than painting dozens of unrelated subfields red.
      const groupEntry = groupKey && control === document.querySelector(
        '[data-nsrp-group="' + groupKey + '"]',
      );
      const invalid = invalidKeys.has(directKey) ||
        Boolean(groupEntry && invalidKeys.has(groupKey));
      if (invalid) {
        control.setAttribute('data-validation-error', '');
        control.setAttribute('aria-invalid', 'true');
      } else {
        control.removeAttribute('data-validation-error');
        control.removeAttribute('aria-invalid');
      }
    });
    // The alert already disappears when missingEssentials becomes empty.
    // Do not synchronously update React state inside this DOM-sync effect.
  }, [missingEssentials]);

  // The printable NSRP fields are intentionally uncontrolled. Track edits at
  // the document level so the red highlight clears as each item is corrected.
  useEffect(() => {
    const handleFieldChange = event => {
      const target = event.target;
      const key = target?.getAttribute?.('data-applicant-field');
      const requiredKey = target?.getAttribute?.('data-nsrp-required');
      const groupKey = target?.getAttribute?.('data-nsrp-group');
      if (!key && !requiredKey && !groupKey) return;
      if (key === 'dateOfBirth' || requiredKey === 'dateOfBirth') return; // Controlled date parser owns validity.
      // These fields are controlled by React. Updating state during a native
      // select's capture-phase input event resets its DOM value before React's
      // onChange can commit the user's keyboard/mouse choice.
      if (['education', 'experience', 'skillsStage', 'skills'].includes(key)) return;

      const groupHasValue = group => Array.from(document.querySelectorAll(
        '[data-nsrp-group="' + group + '"]',
      )).some(control => {
        const type = (control.type || '').toLowerCase();
        return type === 'checkbox' || type === 'radio'
          ? control.checked
          : String(control.value || '').trim().length > 0;
      });
      setMissingEssentials(previous => {
        if (previous.length === 0) return previous;
        const remaining = previous.filter(item => {

        if (requiredKey && item.key === requiredKey) {
          return !String(target.value || '').trim();
        }
        if (groupKey && item.key === groupKey) {
          return !groupHasValue(groupKey);
        }
        return item.key !== key || !String(target.value || '').trim();
        });
        return remaining.length === previous.length ? previous : remaining;
      });
    };
    document.addEventListener('input', handleFieldChange, true);
    document.addEventListener('change', handleFieldChange, true);
    return () => {
      document.removeEventListener('input', handleFieldChange, true);
      document.removeEventListener('change', handleFieldChange, true);
    };
  }, []);

  useEffect(() => {
    let delayedCheck = 0;
    const updatePreviewFit = () => {
      const viewportWidth = document.documentElement.clientWidth || window.innerWidth;
      const wrapper = document.getElementById('zoom-wrapper');
      const nextFit = Math.min(1, Math.max(0.25, (viewportWidth - 32) / 850));
      fitScaleRef.current = nextFit;
      setFitScale(previous => Math.abs(previous - nextFit) > 0.001 ? nextFit : previous);
      if (wrapper && wrapper.scrollHeight > 0) {
        const nextHeight = wrapper.scrollHeight;
        heightRef.current = nextHeight;
        setContentHeight(previous => Math.abs(previous - nextHeight) > 1
          ? nextHeight : previous);
      }
    };

    updatePreviewFit();
    window.addEventListener('resize', updatePreviewFit);
    const wrapper = document.getElementById('zoom-wrapper');
    const observer = typeof ResizeObserver === 'function'
      ? new ResizeObserver(updatePreviewFit)
      : null;
    if (wrapper && observer) observer.observe(wrapper);
    delayedCheck = window.setTimeout(updatePreviewFit, 120);

    return () => {
      window.removeEventListener('resize', updatePreviewFit);
      if (observer) observer.disconnect();
      if (delayedCheck) window.clearTimeout(delayedCheck);
    };
  }, []);

  // Two-finger zoom is applied to the form itself, not the browser viewport.
  // The shell takes the *scaled layout size* while the inner form stays 850px.
  // On every pinch, recompute the focal position and keep it under the fingers.
  // Single-finger scrolling, text inputs, and signature drawing still work.
  useEffect(() => {
    const viewport = document.getElementById('nsrp-preview-viewport');
    const form = document.getElementById('zoom-wrapper');
    const shell = document.getElementById('nsrp-zoom-shell');
    if (!viewport || !form || !shell) return;
    const midpoint = touches => ({
      x: (touches[0].clientX + touches[1].clientX) / 2,
      y: (touches[0].clientY + touches[1].clientY) / 2,
      distance: Math.hypot(
        touches[0].clientX - touches[1].clientX,
        touches[0].clientY - touches[1].clientY,
      ),
    });
    const onTouchStart = event => {
      if (event.touches.length !== 2) return;
      pinchRef.current = midpoint(event.touches);
      event.preventDefault();
    };
    const onTouchMove = event => {
      if (event.touches.length !== 2 || !pinchRef.current) return;
      event.preventDefault();
      const next = midpoint(event.touches);
      if (next.distance < 10 || pinchRef.current.distance < 10) return;
      const oldScale = zoomRef.current * fitScaleRef.current;
      const oldRect = form.getBoundingClientRect();
      const anchorX = (next.x - oldRect.left) / oldScale;
      const anchorY = (next.y - oldRect.top) / oldScale;
      const ratio = next.distance / pinchRef.current.distance;
      const nextZoom = Math.min(3, Math.max(0.5, zoomRef.current * ratio));
      pinchRef.current = next;
      zoomRef.current = nextZoom;
      const scale = nextZoom * fitScaleRef.current;
      shell.style.width = (850 * scale) + 'px';
      shell.style.height = (heightRef.current * scale) + 'px';
      form.style.transform = 'scale(' + scale + ')';
      const moved = form.getBoundingClientRect();
      viewport.scrollLeft += moved.left + anchorX * scale - next.x;
      window.scrollBy(0, moved.top + anchorY * scale - next.y);
    };
    const onTouchEnd = event => {
      if (event.touches.length >= 2 || !pinchRef.current) return;
      pinchRef.current = null;
      setZoomLevel(zoomRef.current);
    };
    viewport.addEventListener('touchstart', onTouchStart, { passive: false });
    viewport.addEventListener('touchmove', onTouchMove, { passive: false });
    viewport.addEventListener('touchend', onTouchEnd);
    viewport.addEventListener('touchcancel', onTouchEnd);
    return () => {
      viewport.removeEventListener('touchstart', onTouchStart);
      viewport.removeEventListener('touchmove', onTouchMove);
      viewport.removeEventListener('touchend', onTouchEnd);
      viewport.removeEventListener('touchcancel', onTouchEnd);
    };
  }, []);

  // Inherit the registration values passed by the Flutter shell as query
  // parameters into the matching NSRP Form 1 fields.
  useEffect(() => {
    let params;
    try {
      params = new URLSearchParams(window.location.search);
    } catch {
      return;
    }
    const inherited = {
      lastName: (params.get('lastName') || '').trim(),
      firstName: (params.get('firstName') || '').trim(),
      middleName: (params.get('middleName') || '').trim(),
      email: (params.get('email') || '').trim(),
      phone: (params.get('phone') || '').trim(),
    };
    document.querySelectorAll('[data-prefill]').forEach((element) => {
      const value = inherited[element.getAttribute('data-prefill')];
      if (value && !element.value) element.value = value;
    });
  }, []);

  // Rehydrate saved NSRP form controls on editing. Data stays in the
  // authenticated parent iframe exchange, never in a query string.
  useEffect(() => {
    const prefill = event => {
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
      if (data.event !== 'nsrp-prefill') return;
      if (typeof data.ownerUid === 'string' && data.ownerUid.length > 0) {
        ownerUidRef.current = data.ownerUid;
      }
      const entries = data.formData?.entries;
      if (!Array.isArray(entries)) return;
      restoringRef.current = true;
      // Match the exact control set and ordering used when serializing NSRP.
      // Applicant-career selects live outside the printable zoom wrapper and
      // must NOT shift saved index 1 (surname) onto the education dropdown.
      const controls = Array.from(document.querySelectorAll(
        '#zoom-wrapper input, #zoom-wrapper select, #zoom-wrapper textarea',
      )).filter(control => !['hidden', 'submit', 'button', 'reset', 'file']
        .includes((control.type || '').toLowerCase()));
      entries.slice(0, 400).forEach(entry => {
        const i = Number(entry?.index) - 1;
        if (!Number.isInteger(i) || i < 0 || i >= controls.length) return;
        const input = controls[i];
        const type = (input.type || '').toLowerCase();
        if (entry.type && type !== entry.type &&
            !(['text', 'date'].includes(type) && ['text', 'date'].includes(entry.type))) return;
        if (type === 'checkbox' || type === 'radio') {
          input.checked = entry.checked === true || entry.value === 'Selected';
        } else if (typeof entry.value === 'string') {
          const proto = input instanceof HTMLTextAreaElement
            ? HTMLTextAreaElement.prototype : input instanceof HTMLSelectElement
              ? HTMLSelectElement.prototype : HTMLInputElement.prototype;
          const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
          if (setter) setter.call(input, entry.value.slice(0, 5000));
          else input.value = entry.value.slice(0, 5000);
        }
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
      });
      // Career choices are controlled by React state and serialized separately
      // from the numbered printable controls. Restore them by named keys.
      const restoredDob = data.formData?.dateOfBirth || '';
      setDateOfBirth(restoredDob);
      if (manualDobRef.current) manualDobRef.current.value = dobAsText(restoredDob);
      setSex(['Male', 'Female', 'Other'].includes(data.formData?.sex)
        ? data.formData.sex : (data.verifiedResumeSex || ''));
      setReligion(data.formData?.religion || '');
      const career = data.formData?.applicantEssentials || {};
      const legacyValue = label => entries.find(entry =>
        entry?.type === 'applicant_essential' && entry.label === label)?.value || '';
      const choose = (choices, value, legacy) => choices.includes(value)
        ? value : choices.includes(legacy) ? legacy : '';
      const education = choose(educationChoices, career.education, legacyValue('Highest education attained'));
      const experience = choose(experienceChoices, career.experience, legacyValue('Work experience status'));
      const stage = choose(skillsChoices, career.skillsStage, legacyValue('Career readiness stage'));
      const savedSkills = typeof career.skills === 'string'
        ? career.skills : legacyValue('Other skills acquired');
      setCareerEducation(education);
      setExperienceStatus(experience);
      setSkillsStage(stage);
      setCareerSkills(stage === skillsChoices[0] ? savedSkills.slice(0, 5000) : '');

      // Preserve an applicant's drawn signature when they reopen the form.
      window.setTimeout(() => { restoringRef.current = false; }, 150);
      const signature = data.formData?.signatureDataUrl;
      if (typeof signature === 'string' && /^data:image\/png;base64,/.test(signature)
          && signature.length < 200000) {
        const canvas = signatureCanvasRef.current;
        const image = new Image();
        image.onload = () => {
          if (!canvas) return;
          const context = canvas.getContext('2d');
          if (!context) return;
          context.clearRect(0, 0, canvas.width, canvas.height);
          context.drawImage(image, 0, 0, canvas.width, canvas.height);
          setHasSignature(true);
        };
        image.src = signature;
      }
    };
    window.addEventListener('message', prefill);
    sendToFlutter({ status: 'ready', kind: 'nsrp_form' });
    return () => window.removeEventListener('message', prefill);
  }, []);

  // Commit native selects exclusively through their React handlers, after
  // Chrome has finished changing the selected option.
  const commitCareerChoice = (key, value, updateState) => {
    updateState(value);
    if (!value.trim()) return;
    setMissingEssentials(previous => {
      if (!previous.some(item => item.key === key ||
        (key === 'skillsStage' && value !== skillsChoices[0] && item.key === 'skills')))
        return previous;
      return previous.filter(item => item.key !== key &&
        !(key === 'skillsStage' && value !== skillsChoices[0] && item.key === 'skills'));
    });
  };

  const handleZoomIn = () => setZoomLevel(prev => Math.min(prev + 0.1, 2));
  const handleZoomOut = () => setZoomLevel(prev => Math.max(prev - 0.1, 0.5));
  const handleResetZoom = () => setZoomLevel(1);

  const handleCompleteRegistration = async () => {
    const readField = key => document.querySelector(`[data-applicant-field="${key}"]`)?.value?.trim() || '';
    const applicantEssentials = {
      firstName: readField('firstName'),
      lastName: readField('lastName'),
      email: readField('email'),
      phone: readField('phone'),
      city: readField('city'),
      preferredOccupation: readField('preferredOccupation'),
      education: careerEducation,
      experience: experienceStatus,
      skillsStage,
      skills: careerSkills.trim(),
    };
    // Only green-highlighted NSRP fields/sections block completion; career-summary controls are optional.
    const readNsrpValue = key => document.querySelector(
      '[data-nsrp-required="' + key + '"]',
    )?.value?.trim() || '';
    const nsrpGroupHasValue = key => Array.from(document.querySelectorAll(
      '[data-nsrp-group="' + key + '"]',
    )).some(control => {
      const type = (control.type || '').toLowerCase();
      return type === 'checkbox' || type === 'radio'
        ? control.checked
        : String(control.value || '').trim().length > 0;
    });
    const officialMissing = collectMissingNsrpFields({
      lastName: readField('lastName'),
      firstName: readField('firstName'),
      dateOfBirth: dateOfBirth ? true : '',
      sex: sex ? true : '',
      middleName: readNsrpValue('middleName'),
      suffix: readNsrpValue('suffix'),
      placeOfBirth: readNsrpValue('placeOfBirth'),
      presentAddress: nsrpGroupHasValue('presentAddress') ? true : '',
      city: readField('city'),
      religion: religion,
      height: readNsrpValue('height'),
      email: readField('email'),
      landline: readNsrpValue('landline'),
      phone: readField('phone'),
      civilStatus: nsrpGroupHasValue('civilStatus') ? true : '',
      employmentStatus: nsrpGroupHasValue('employmentStatus') ? true : '',
      preferredOccupation: readField('preferredOccupation'),
      preferredWorkLocation: nsrpGroupHasValue('preferredWorkLocation') ? true : '',
      languageProficiency: nsrpGroupHasValue('languageProficiency') ? true : '',
      educationBackground: nsrpGroupHasValue('educationBackground') ? true : '',
      workExperience: nsrpGroupHasValue('workExperience') ? true : '',
      otherSkills: nsrpGroupHasValue('otherSkills') ? true : '',
      signature: hasSignature ? true : '',
      signatureDate: readNsrpValue('signatureDate'),
    });
    if (officialMissing.length) {
      setMissingEssentials(officialMissing);
      setValidationOpen(true);

      const first = officialMissing[0];
      const target = document.querySelector(
        '[data-nsrp-required="' + first.key + '"], ' +
        '[data-nsrp-group="' + first.key + '"], ' +
        '[data-applicant-field="' + first.key + '"]',
      );
      if (target) {
        target.scrollIntoView({ behavior: 'smooth', block: 'center' });
        target.focus?.({ preventScroll: true });
      } else {
        document.getElementById('zoom-wrapper')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
      return;
    }
    setMissingEssentials([]);
    setValidationOpen(false);
    setIsProcessing(true);

    const zoomWrapper = document.getElementById('zoom-wrapper');
    const originalTransform = zoomWrapper?.style.transform ?? '';
    if (zoomWrapper) zoomWrapper.style.transform = 'scale(1)';

    try {
      // Mirror current control values into the DOM before rendering the PDF.
      document.querySelectorAll('#zoom-wrapper input, #zoom-wrapper textarea, #zoom-wrapper select').forEach(control => {
        if (control.type !== 'checkbox' && control.type !== 'radio') {
          control.style.fontSize = control.value.length > 70 ? '8px' : control.value.length > 35 ? '10px' : '12px';
          control.style.minWidth = '0';
        }
      });
      document.querySelectorAll('input').forEach((input) => {
        if (input.type === 'checkbox' || input.type === 'radio') {
          if (input.checked) input.setAttribute('checked', 'checked');
          else input.removeAttribute('checked');
        } else {
          input.setAttribute('value', input.value);
        }
      });

      const pdf = new jsPDF('p', 'mm', 'a4');
      const pdfWidth = pdf.internal.pageSize.getWidth();
      const pdfHeight = pdf.internal.pageSize.getHeight();
      let pdfPageCount = 0;
      const formPageTwo = document.getElementById('peso-page-2');
      const pageTwoChildren = formPageTwo ? Array.from(formPageTwo.children) : [];
      const careerSummaryIndex = pageTwoChildren.findIndex((element) =>
        (element.innerText || '').trim().startsWith('APPLICANT CAREER INFORMATION'),
      );
      const pageSpecs = [{ id: 'peso-page-1' }];
      if (formPageTwo && careerSummaryIndex > 0) {
        // Keep official data sections intact and begin certification on its own page.
        pageSpecs.push({ id: 'peso-page-2', start: 0, end: careerSummaryIndex, paddingBottom: '8px' });
        pageSpecs.push({ id: 'peso-page-2', start: careerSummaryIndex, end: pageTwoChildren.length, paddingTop: '16px' });
      } else {
        pageSpecs.push({ id: 'peso-page-2' });
      }
      for (const spec of pageSpecs) {
        const page = document.getElementById(spec.id);
        if (!page) continue;
        // A print-only DOM copy expands long text into wrapped, full-height
        // lines. Live editable inputs stay untouched and keep keyboard access.
        const printPage = page.cloneNode(true);
        printPage.removeAttribute('id');
        printPage.style.position = 'absolute';
        // html-to-image needs the print source inside the visible render surface.
        // Keep the clone behind the app while rasterizing, then remove it.
        printPage.style.left = '0';
        printPage.style.top = '0';
        printPage.style.zIndex = '-1';
        printPage.style.pointerEvents = 'none';
        printPage.style.width = page.offsetWidth + 'px';
        printPage.style.height = 'auto';
        printPage.style.transform = 'none';
        if (spec.paddingBottom) printPage.style.paddingBottom = spec.paddingBottom;
        if (spec.paddingTop) printPage.style.paddingTop = spec.paddingTop;
        const originals = Array.from(page.querySelectorAll('input, select, textarea'));
        const copies = Array.from(printPage.querySelectorAll('input, select, textarea'));
        originals.forEach((source, index) => {
          const target = copies[index];
          if (!target) return;
          const type = (source.type || '').toLowerCase();
          let visibleValue;
          if (type === 'checkbox' || type === 'radio') {
            visibleValue = source.checked ? 'X' : '';
          } else if (source.tagName === 'SELECT') {
            visibleValue = source.selectedOptions[0]?.textContent || '';
          } else if (type === 'date' && source.value) {
            const parts = source.value.split('-');
            visibleValue = parts.length === 3 ? [parts[1], parts[2], parts[0]].join('/') : source.value;
          } else {
            visibleValue = source.value || '';
          }
          const replacement = document.createElement('span');
          if (type === 'checkbox' || type === 'radio') {
            // Do not rasterize native form controls: some mobile PDF viewers
            // render their fallback glyph as a question mark. Draw the control
            // in CSS so empty boxes remain empty and checked boxes show a clear X.
            replacement.textContent = source.checked ? 'X' : '';
            replacement.style.cssText =
              'display:inline-flex;align-items:center;justify-content:center;' +
              'flex:0 0 9px;width:9px;height:9px;box-sizing:border-box;' +
              'border:1px solid #222;background:#fff;margin:0 3px 0 0;padding:0;' +
              'font-family:Arial,sans-serif;font-size:7px;line-height:1;vertical-align:middle;';
            replacement.style.borderRadius = type === 'radio' ? '50%' : '0';
          } else {
            replacement.textContent = visibleValue;
            // Fit each saved value to its original field width and height so long
            // names wrap at a smaller readable size without moving the official grid.
            const fieldHeight = Math.max(14, source.offsetHeight || 14);
            const fieldWidth = Math.max(24, (source.clientWidth || source.offsetWidth || 80) - 4);
            const measureCanvas = document.createElement('canvas');
            const measureContext = measureCanvas.getContext('2d');
            const sourceLines = String(visibleValue || '').split(/\r?\n/);
            const wrappedLineCount = size => {
              if (!measureContext) return Math.ceil(String(visibleValue || '').length / 18);
              measureContext.font = size + 'px Arial';
              let lines = 0;
              for (const sourceLine of sourceLines) {
                if (!sourceLine) { lines += 1; continue; }
                let current = '';
                for (const word of sourceLine.split(/\s+/).filter(Boolean)) {
                  const candidate = current ? current + ' ' + word : word;
                  if (measureContext.measureText(candidate).width <= fieldWidth) {
                    current = candidate;
                    continue;
                  }
                  if (measureContext.measureText(word).width <= fieldWidth) {
                    lines += 1;
                    current = word;
                    continue;
                  }
                  if (current) { lines += 1; current = ''; }
                  for (const character of word) {
                    if (current && measureContext.measureText(current + character).width > fieldWidth) {
                      lines += 1;
                      current = '';
                    }
                    current += character;
                  }
                }
                lines += 1;
              }
              return Math.max(1, lines);
            };
            let fontSize = 10;
            while (fontSize > 3 && wrappedLineCount(fontSize) * fontSize * 1.05 > fieldHeight) {
              fontSize -= 0.5;
            }
            replacement.style.cssText = 'display:block;flex:1;min-width:0;width:100%;max-width:100%;' +
              'white-space:pre-wrap;overflow:hidden;overflow-wrap:anywhere;word-break:break-word;' +
              'box-sizing:border-box;height:' + fieldHeight + 'px;max-height:' + fieldHeight + 'px;' +
              'font-family:Arial,sans-serif;font-size:' + fontSize + 'px;line-height:1.05;padding:0;';
          }
          target.replaceWith(replacement);
        });
        const originalCanvases = page.querySelectorAll('canvas');
        const cloneCanvases = printPage.querySelectorAll('canvas');
        originalCanvases.forEach((canvas, index) => {
          const copy = cloneCanvases[index];
          if (copy) copy.getContext('2d')?.drawImage(canvas, 0, 0);
        });
        if (spec.start != null || spec.end != null) {
          Array.from(printPage.children).forEach((child, index) => {
            if ((spec.start != null && index < spec.start) ||
                (spec.end != null && index >= spec.end)) child.remove();
          });
        }
        // Number the physical pages after final pagination is known.
        printPage.querySelectorAll('div').forEach(element => {
          if (element.children.length === 0 &&
              /^Page\s+\d+\s+of\s+\d+$/.test(element.textContent.trim())) {
            element.remove();
          }
        });
        printPage.querySelectorAll('.h-1\\/2').forEach(element => {
          element.style.height = 'auto';
        });
        document.body.appendChild(printPage);
        try {
          const image = await htmlToImage.toCanvas(printPage, {
            backgroundColor: '#ffffff', pixelRatio: 1.25,
          });
          const sliceHeight = Math.floor(image.width * pdfHeight / pdfWidth);
          for (let top = 0; top < image.height; top += sliceHeight) {
            const segmentHeight = Math.min(sliceHeight, image.height - top);
            const segment = document.createElement('canvas');
            segment.width = image.width;
            segment.height = segmentHeight;
            segment.getContext('2d').drawImage(
              image, 0, top, image.width, segmentHeight,
              0, 0, image.width, segmentHeight,
            );
            if (pdfPageCount > 0) pdf.addPage();
            pdf.addImage(segment.toDataURL('image/jpeg', 0.89), 'JPEG',
              0, 0, pdfWidth, segmentHeight * pdfWidth / image.width);
            pdfPageCount++;
          }
        } finally {
          printPage.remove();
        }
      }
      if (pdfPageCount === 0) throw new Error('NSRP pages could not be rendered.');
      for (let pageNumber = 1; pageNumber <= pdfPageCount; pageNumber++) {
        pdf.setPage(pageNumber);
        pdf.setFont('helvetica', 'bold');
        pdf.setFontSize(8);
        pdf.text(`Page ${pageNumber} of ${pdfPageCount}`, pdfWidth - 8, pdfHeight - 8, {
          align: 'right',
        });
      }
      pdf.save('NSRP_Form1.pdf');

      const normalize = (value) => String(value ?? '').replace(/\s+/g, ' ').trim();
      const getFieldLabel = (input, index) => {
        const explicit = input.dataset.field || input.name || input.id || input.getAttribute('aria-label');
        if (explicit) return normalize(explicit);

        const tableCell = input.closest('td');
        const tableRow = input.closest('tr');
        if (tableCell && tableRow) {
          const columnIndex = Array.from(tableRow.cells).indexOf(tableCell);
          const table = input.closest('table');
          const headings = table?.querySelector('thead tr');
          const heading = headings?.cells?.[columnIndex]?.innerText;
          const rowLabel = tableRow.cells?.[0]?.innerText;
          const combined = [normalize(rowLabel), normalize(heading)].filter(Boolean).join(' — ');
          if (combined) return combined;
        }

        const label = input.closest('label');
        if (label) {
          const text = normalize(label.innerText);
          if (text) return text;
        }

        const previous = input.previousElementSibling;
        if (previous && normalize(previous.innerText)) return normalize(previous.innerText);

        // Handles rows where the label is text immediately before the input.
        const parent = input.parentElement;
        if (parent) {
          const childNodes = Array.from(parent.childNodes);
          const inputIndex = childNodes.indexOf(input);
          const prefix = normalize(childNodes.slice(0, inputIndex).map((node) => node.textContent || '').join(' '));
          if (prefix && prefix.length <= 120) return prefix;
        }

        // Walk up one or two layout rows to include nearby question text.
        let branch = input;
        for (let depth = 0; depth < 5 && branch.parentElement; depth++) {
          const parentNode = branch.parentElement;
          const previousElement = branch.previousElementSibling;
          if (previousElement) {
            const candidate = normalize(previousElement.innerText);
            if (candidate && candidate.length <= 100) return candidate;
          }
          if (parentNode.classList.contains('p-1') || parentNode.tagName === 'TR') {
            const candidate = normalize(parentNode.innerText);
            if (candidate && candidate.length <= 150 && parentNode.querySelectorAll('input').length <= 3) {
              return candidate;
            }
          }
          branch = parentNode;
        }

        return `Form field ${index + 1}`;
      };

      const controls = Array.from(document.querySelectorAll('#zoom-wrapper input, #zoom-wrapper select, #zoom-wrapper textarea')).filter((control) => {
        const type = (control.type || '').toLowerCase();
        return !['hidden', 'submit', 'button', 'reset', 'file'].includes(type);
      });
      const entries = controls.map((input, index) => {
        const type = (input.type || input.tagName || 'text').toLowerCase();
        const label = getFieldLabel(input, index);
        const checked = type === 'checkbox' || type === 'radio' ? input.checked : undefined;
        const value = checked === true ? 'Selected' : (checked === false ? '' : normalize(input.value));
        const fieldKey = [input.name, input.id, input.placeholder, input.getAttribute('aria-label')].filter(Boolean).join(' ');
        const contextNode = input.closest('tr') || input.closest('label') || input.parentElement;
        const context = normalize(contextNode?.innerText || contextNode?.textContent || '');
        return { index: index + 1, label, fieldKey, context, type, value, ...(checked === undefined ? {} : { checked }) };
      }).filter((entry) => entry.value !== '' || entry.checked === true);

      // Save the full form privately for the user, but omit identity numbers
      // and nearby labels that may identify them before sending text to Gemini.
      const sensitiveLabel = /\b(tin|sss|gsis|philhealth|pag-?ibig|passport|household\s*id|tax\s*id|government\s*id|national\s*id|voter'?s?\s*id|driver'?s?\s*license|umid)\b/i;
      const careerEntries = applicantCareerEntries(applicantEssentials).map(
        (entry, index) => ({ ...entry, index: controls.length + index + 1, type: 'applicant_essential' }),
      );
      const allEntries = [...entries, ...careerEntries];
      const aiEntries = allEntries.filter((entry) => !sensitiveLabel.test(`${entry.label} ${entry.fieldKey} ${entry.context || ''}`));
      const aiText = [
        'NSRP FORM 1 - COMPLETED VALUES',
        ...aiEntries.map((entry) => `${entry.label}: ${entry.value}`),
      ].join('\n');
      const storedEntries = allEntries.map((entry) => {
        const storedEntry = { ...entry };
        delete storedEntry.fieldKey;
        delete storedEntry.context;
        return storedEntry;
      });
      const formData = {
        documentType: 'NSRP Form 1',
        entries: storedEntries,
        applicantEssentials: {
          education: careerEducation,
          experience: experienceStatus,
          skillsStage,
          skills: skillsStage === skillsChoices[0] ? careerSkills.trim() : '',
          preferredOccupation: applicantEssentials.preferredOccupation,
          city: applicantEssentials.city,
        },
        dateOfBirth,
        age,
        sex,
        religion,
        completedAt: new Date().toISOString(),
        signatureDataUrl: hasSignature && signatureCanvasRef.current
          ? signatureCanvasRef.current.toDataURL('image/png')
          : null,
        aiText,
      };

      const dataUri = pdf.output('datauristring');
      const base64 = dataUri.includes(',') ? dataUri.substring(dataUri.indexOf(',') + 1) : '';
      const delivered = sendToFlutter({
        status: 'completed',
        kind: 'nsrp_form',
        data: aiText,
        aiText,
        formData,
        artifact: base64 ? {
          fileName: 'NSRP_Form1.pdf',
          category: 'nsrp_form',
          mimeType: 'application/pdf',
          base64,
        } : null,
      });

      if (!delivered) {
        alert('The NSRP form was downloaded, but no Flutter app was detected to save the data. Open this form from PESO JobKonek to sync it to your profile.');
      }
    } catch (error) {
      console.error('NSRP PDF or data extraction failed:', error);
      alert('Could not complete the NSRP form. Please check the browser console and try again.');
    } finally {
      if (zoomWrapper) zoomWrapper.style.transform = originalTransform;
      setIsProcessing(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-200 py-8 flex flex-col items-center font-sans overflow-x-hidden">
      
      {/* Zoom Controls */}
      <div className="fixed top-0 left-0 w-full bg-gradient-to-r from-emerald-950 via-emerald-800 to-teal-800 px-3 py-3 flex flex-wrap items-center justify-center gap-2 sm:gap-3 z-50 shadow-lg border-b border-emerald-700">
        <div className="flex items-center gap-2 mr-2">
          <span className="rounded-lg bg-white/15 px-2.5 py-1.5 text-white text-xs font-black tracking-wide">NSRP FORM 1</span>
          <span className="text-white/85 text-xs sm:text-sm font-semibold">Review &amp; edit</span>
        </div>
        <div className="rounded-xl bg-white/10 p-1 flex items-center gap-1" aria-label="Form zoom controls">
          <button onClick={handleZoomOut} aria-label="Zoom out" className="bg-white text-emerald-900 px-3 py-1.5 rounded-lg hover:bg-emerald-50 font-bold text-sm">-</button>
          <button onClick={handleResetZoom} className="bg-white text-emerald-900 px-3 py-1.5 rounded-lg hover:bg-emerald-50 font-bold text-sm">100%</button>
          <button onClick={handleZoomIn} aria-label="Zoom in" className="bg-white text-emerald-900 px-3 py-1.5 rounded-lg hover:bg-emerald-50 font-bold text-sm">+</button>
        </div>
        <button onClick={clearSignature} disabled={!hasSignature} className="rounded-lg bg-white/15 px-3 py-1.5 text-white text-xs font-semibold hover:bg-white/25 disabled:opacity-45 disabled:cursor-not-allowed">
          Clear signature
        </button>
      </div>
      {validationOpen && missingEssentials.length > 0 && (
        <aside role="alertdialog" aria-label="Incomplete required information"
          data-testid="applicant-missing" className="fixed z-[70] top-20 right-3 left-3 sm:left-auto sm:w-[390px] rounded-2xl border border-amber-200 bg-white text-slate-900 p-4 shadow-2xl shadow-amber-900/15">
          <div className="flex items-start gap-3">
            <div className="rounded-full bg-amber-100 text-amber-700 p-2 font-black" aria-hidden="true">!</div>
            <div className="min-w-0 flex-1">
              <h3 className="font-extrabold text-base">A few details are still needed</h3>
              <p className="text-xs text-slate-600 mt-1">Please complete the green-highlighted required fields. Select a field to jump to it; missing fields are highlighted below.</p>
            </div>
            <button aria-label="Dismiss validation notification" onClick={() => setValidationOpen(false)} className="text-slate-500 hover:text-slate-900 font-bold px-2">×</button>
          </div>
          <ul className="mt-3 max-h-52 overflow-y-auto space-y-1.5">
            {missingEssentials.map(item => (
              <li key={item.key}>
                <button className="text-left text-sm w-full rounded-lg bg-amber-50 hover:bg-amber-100 p-2.5 text-amber-950"
                  onClick={() => {
                    const target = document.querySelector(
                      '[data-applicant-field="' + item.key + '"], ' +
                      '[data-nsrp-required="' + item.key + '"], ' +
                      '[data-nsrp-group="' + item.key + '"]',
                    );
                    target?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    target?.focus?.({ preventScroll: true });
                  }}>
                  • {item.label}
                </button>
              </li>
            ))}
          </ul>
        </aside>
      )}

      {/* Applicant-only matching essentials. These controls do not alter the
          official printable form's assessor or government-ID fields. */}
      <section id="applicant-essentials" className="mt-24 w-[min(94vw,850px)] bg-white rounded-2xl shadow p-5 sm:p-7 border border-emerald-200">
        <div className="text-xs font-bold tracking-wider text-emerald-700">OPTIONAL FOR BETTER JOB SUGGESTIONS</div>
        <h2 className="font-bold text-xl text-slate-900 mt-1">Additional career details</h2>
        <p className="text-sm text-slate-600 mt-2">
          These optional details can improve job suggestions, but they do not block Form 1 completion.
          Complete the green-highlighted fields in the official NSRP form below. You may report no work experience or still learning; do not invent qualifications.
          Government IDs, certificates you do not hold, and PESO assessor fields are not required here.
        </p>

        <div className="grid sm:grid-cols-2 gap-4 mt-4">
          <label className="text-sm font-semibold text-slate-800">
            Highest education / currently studying
            <select aria-label="Highest education" data-testid="career-education-select" data-applicant-field="education"
              value={careerEducation} onChange={event => commitCareerChoice('education', event.currentTarget.value, setCareerEducation)}
              className="mt-1 w-full border border-slate-300 rounded-lg p-3 bg-white text-slate-900">
              <option value="">Select your actual education</option>
              {educationChoices.map(choice => <option key={choice} value={choice}>{choice}</option>)}
            </select>
            <output data-testid="career-education-selected" aria-live="polite" className="mt-1 block text-xs font-medium text-emerald-800">
              {careerEducation ? `Selected: ${careerEducation}` : 'No education selected yet'}
            </output>
          </label>
          <label className="text-sm font-semibold text-slate-800">
            Work experience
            <select aria-label="Work experience status" data-testid="career-experience-select" data-applicant-field="experience"
              value={experienceStatus} onChange={event => commitCareerChoice('experience', event.currentTarget.value, setExperienceStatus)}
              className="mt-1 w-full border border-slate-300 rounded-lg p-3 bg-white text-slate-900">
              <option value="">Select your situation</option>
              {experienceChoices.map(choice => <option key={choice} value={choice}>{choice}</option>)}
            </select>
            <output data-testid="career-experience-selected" aria-live="polite" className="mt-1 block text-xs font-medium text-emerald-800">
              {experienceStatus ? `Selected: ${experienceStatus}` : 'No experience status selected yet'}
            </output>
          </label>
          <label className="text-sm font-semibold text-slate-800 sm:col-span-2">
            Skills or training
            <select aria-label="Skills stage" data-testid="career-skills-select" data-applicant-field="skillsStage"
              value={skillsStage} onChange={event => commitCareerChoice('skillsStage', event.currentTarget.value, setSkillsStage)}
              className="mt-1 w-full border border-slate-300 rounded-lg p-3 bg-white text-slate-900">
              <option value="">Select your situation</option>
              {skillsChoices.map(choice => <option key={choice} value={choice}>{choice}</option>)}
            </select>
            <output data-testid="career-skills-selected" aria-live="polite" className="mt-1 block text-xs font-medium text-emerald-800">
              {skillsStage ? `Selected: ${skillsStage}` : 'No skills stage selected yet'}
            </output>
          </label>
          {skillsStage === skillsChoices[0] && (
            <label className="text-sm font-semibold text-slate-800 sm:col-span-2">
              What skills or training have you actually completed?
              <textarea aria-label="Applicant skills" data-applicant-field="skills" rows={2}
                value={careerSkills} onChange={event => commitCareerChoice('skills', event.currentTarget.value, setCareerSkills)}
                placeholder="e.g. Carpentry, MS Excel, customer service"
                className="mt-1 w-full border border-slate-300 rounded-lg p-3"/>
            </label>
          )}
        </div>
        <p className="text-xs text-slate-500 mt-3">Optional or PESO-only fields can be completed later. Only your own verified statements are saved as applicant qualifications.</p>
        <p className="text-xs text-slate-500 mt-2" aria-live="polite">
          {hasSignature ? 'Signature added. Use “Clear signature” above to start again.' : 'You can draw your signature with a mouse, touchpad, or touchscreen in the signature box on page 2.'}
        </p>
      </section>

      <div
        id="nsrp-preview-viewport"
        data-testid="nsrp-pinch-viewport"
        className="mt-24 w-full"
        style={{ overflowX: 'auto', touchAction: 'pan-x pan-y', overscrollBehaviorX: 'contain' }}
      >
        <div
          id="nsrp-zoom-shell"
          style={{ width: (850 * previewScale) + 'px', height: (contentHeight * previewScale) + 'px', margin: '0 auto', position: 'relative' }}
        >
          <div
            id="zoom-wrapper"
            className="origin-top-left pb-24"
            style={{ width: '850px', transform: `scale(${previewScale})`, transformOrigin: 'top left' }}
          >
        
        <div data-testid="nsrp-draft-status" role="status" aria-live="polite"
        className="text-xs font-semibold text-emerald-900 bg-white border border-emerald-200 rounded-lg px-3 py-2 mx-auto w-fit mb-3">
        Draft: {draftStatus}
        {draftStatus === 'Sync Failed' && (
          <button type="button" className="underline ml-3"
            onClick={() => {
              if (ownerUidRef.current) sendToFlutter({
                status: 'draft', kind: 'nsrp_form',
                formData: lastDraftRef.current || snapshotDraft(),
              });
            }}>Retry sync</button>
        )}
      </div>
      {/* ======================= PAGE 1 ======================= */}
        <div id="peso-page-1" className="w-[850px] bg-white shadow-sm mb-8 border border-gray-400 p-8 text-xs text-black">
          
          <div className="flex border border-black mb-2">
            <div className="w-1/4 border-r border-black p-2 flex flex-col justify-center">
              <span className="font-bold">NSRP Form 1</span>
              <span>January 2017</span>
            </div>
            <div className="w-2/4 p-2 text-center flex flex-col justify-center">
              <span>Republic of the Philippines</span>
              <span>Department of Labor and Employment</span>
              <span className="font-bold text-sm">PESO EMPLOYMENT INFORMATION SYSTEM</span>
              <span className="font-bold">REGISTRATION FORM</span>
            </div>
            <div className="w-1/4 border-l border-black p-2 flex justify-center items-center">
              <img src={pesoformicon} alt="PESO Form icon" className="h-16 w-12 object-contain" />
            </div>
          </div>

          <div className="border border-black p-2 mb-2 bg-gray-50">
            <span className="font-bold">INSTRUCTIONS:</span> Please fill out the form legibly with ball pen. Print in block letters. Complete every green-highlighted field or section before continuing. Enter "N/A" when a required field or section does not apply to you. Check the appropriate boxes.<br/><strong><span className="text-red-600">*</span> Green-highlighted fields/sections are required. Use N/A only where the field or section does not apply.</strong> You may use an extra sheet if needed. Submit the accomplished form to the Public Employment Service Office Manager or Officer in your city/municipality.
          </div>

          <div className="bg-gray-300 font-bold p-1 border border-black border-b-0">
            I. PERSONAL INFORMATION
          </div>

          <div className="border border-black flex flex-col">
            <div className="flex border-b border-black divide-x divide-black">
              <div className="w-1/4 p-1"><GreenLabel required>SURNAME</GreenLabel><input type="text" required data-prefill="lastName" data-applicant-field="lastName" data-field="Surname" aria-required="true" aria-label="Surname" className="block w-full min-w-0 box-border outline-none uppercase mt-1 text-[12px]" /></div>
              <div className="w-1/4 p-1"><GreenLabel required>FIRST NAME</GreenLabel><input type="text" required data-prefill="firstName" data-applicant-field="firstName" data-field="First name" aria-required="true" aria-label="First name" className="block w-full min-w-0 box-border outline-none uppercase mt-1 text-[12px]" /></div>
              <div className="w-1/4 p-1"><GreenLabel required>MIDDLE NAME</GreenLabel><input type="text" data-prefill="middleName" data-nsrp-required="middleName" aria-label="Middle name or N/A" aria-required="true" placeholder="N/A if not applicable" className="w-full outline-none uppercase mt-1" /></div>
              <div className="w-1/4 p-1"><GreenLabel required>SUFFIX</GreenLabel> (Ex: Sr., Jr., III, etc.)<input type="text" data-nsrp-required="suffix" aria-label="Name suffix or N/A" aria-required="true" placeholder="N/A if not applicable" className="w-full outline-none uppercase mt-1" /></div>
            </div>

            <div className="flex border-b border-black divide-x divide-black">
              <div className="w-1/4 p-1 flex flex-col justify-between"><GreenLabel required>DATE OF BIRTH</GreenLabel> (mm/dd/yyyy)<div className="flex flex-wrap gap-1 mt-1">
                <input type="date" aria-label="Choose date of birth" data-applicant-field="dateOfBirth"
                  aria-required="true" aria-invalid={missingEssentials.some(item => item.key === 'dateOfBirth')}
                  style={missingEssentials.some(item => item.key === 'dateOfBirth') ? { border: '1px solid #dc2626', backgroundColor: '#fff1f2' } : undefined}
                  value={dateOfBirth}
                  onChange={event => {
                    setDateOfBirth(event.target.value);
                    if (manualDobRef.current) manualDobRef.current.value = dobAsText(event.target.value);
                    if (event.target.value) setMissingEssentials(previous => previous.filter(item => item.key !== 'dateOfBirth'));
                  }}
                  className="w-full min-w-0 outline-none" />
                <input type="text" inputMode="numeric" aria-label="Type date of birth" data-applicant-field="dateOfBirth"
                  aria-required="true" aria-invalid={missingEssentials.some(item => item.key === 'dateOfBirth')}
                  style={missingEssentials.some(item => item.key === 'dateOfBirth') ? { border: '1px solid #dc2626', backgroundColor: '#fff1f2' } : undefined}
                  placeholder="MM/DD/YYYY" maxLength={10} ref={manualDobRef}
                  onChange={event => changeTypedDob(event.target.value)}
                  className="w-full min-w-0 border-t border-gray-300 outline-none" />
              </div></div>
              <div className="w-1/4 p-1"><GreenLabel required>SEX</GreenLabel><select aria-label="Sex" data-applicant-field="sex" aria-required="true"
                aria-invalid={missingEssentials.some(item => item.key === 'sex')}
                style={missingEssentials.some(item => item.key === 'sex') ? { border: '1px solid #dc2626', backgroundColor: '#fff1f2' } : undefined}
                className="w-full min-w-0 text-[11px]" value={sex} onChange={event => setSex(event.target.value)}><option value="">Choose</option><option>Male</option><option>Female</option><option>Other</option></select></div>
              <div className="w-[12.5%] p-1"><GreenLabel>AGE</GreenLabel><input type="text" aria-label="Age (calculated)" readOnly value={age} className="w-full outline-none mt-1" /></div>
              <div className="w-[37.5%] p-1"><GreenLabel required>PLACE OF BIRTH</GreenLabel><input type="text" data-nsrp-required="placeOfBirth" aria-label="Place of birth" aria-required="true" placeholder="City / municipality" className="w-full outline-none mt-1" /></div>
            </div>

            <div className="flex border-b border-black divide-x divide-black">
              <div className="w-1/2 flex flex-col divide-y divide-black">
                <div className="flex divide-x divide-black h-1/2">
                   <div className="w-1/2 p-1 font-bold text-green-700">Personal details</div>
                   <div className="w-1/2 p-1"><GreenLabel required>RELIGION</GreenLabel><select data-nsrp-required="religion" aria-label="Religion" className="w-full min-w-0" value={religion} onChange={event => setReligion(event.target.value)}><option value="">Select or prefer not to say</option><option>Prefer not to say</option><option>Roman Catholic</option><option>Islam</option><option>Iglesia ni Cristo</option><option>Protestant</option><option>Born Again Christian</option><option>Other</option><option>None</option></select></div>
                </div>
                <div className="flex divide-x divide-black h-1/2">
                    <div className="w-1/4 p-1"><GreenLabel required>CIVIL STATUS</GreenLabel></div>
                    <div className="w-3/4 p-1 grid grid-cols-2 gap-1">
                        <label className="flex items-center gap-1"><input type="checkbox" data-nsrp-group="civilStatus"/> Single</label>
                        <label className="flex items-center gap-1"><input type="checkbox" data-nsrp-group="civilStatus"/> Separated</label>
                        <label className="flex items-center gap-1"><input type="checkbox" data-nsrp-group="civilStatus"/> Married</label>
                        <label className="flex items-center gap-1"><input type="checkbox" data-nsrp-group="civilStatus"/> Live-in</label>
                        <label className="flex items-center gap-1"><input type="checkbox" data-nsrp-group="civilStatus"/> Widowed</label>
                    </div>
                </div>
              </div>
              <div className="w-1/2 flex divide-x divide-black">
                  <div className="w-1/3 p-1 flex flex-col justify-center"><GreenLabel required>PRESENT ADDRESS</GreenLabel></div>
                  <div className="w-2/3 flex flex-col divide-y divide-black">
                      <div className="p-1 flex"><span className="w-24 text-[10px]">House No./Street</span><input type="text" data-nsrp-group="presentAddress" aria-label="House number and street or N/A" placeholder="House / street or N/A" className="w-full outline-none" /></div>
                      <div className="p-1 flex"><span className="w-24 text-[10px]">Village</span><input type="text" data-nsrp-group="presentAddress" aria-label="Village or N/A" placeholder="Village / N/A" className="w-full outline-none" /></div>
                      <div className="p-1 flex"><span className="w-24 text-[10px]">Barangay</span><input type="text" data-nsrp-group="presentAddress" aria-label="Barangay of present address" placeholder="Barangay" className="w-full outline-none" /></div>
                      <div className="p-1 flex"><span className="w-24 text-[10px]"><GreenLabel required>Municipality/City</GreenLabel></span><input type="text" data-applicant-field="city" data-nsrp-group="presentAddress" data-field="Municipality/City" aria-label="City or municipality" className="w-full outline-none" /></div>
                      <div className="p-1 flex"><span className="w-24 text-[10px]">Province</span><input type="text" data-nsrp-group="presentAddress" aria-label="Province of present address" placeholder="Province" className="w-full outline-none" /></div>
                  </div>
              </div>
            </div>

            <div className="flex border-b border-black divide-x divide-black">
              <div className="w-1/2 flex flex-col divide-y divide-black">
                  <div className="flex"><div className="w-1/3 p-1 bg-gray-200">TIN</div><div className="w-2/3 p-1"><input type="text" className="w-full outline-none" /></div></div>
                  <div className="flex"><div className="w-1/3 p-1 bg-gray-200">GSIS/SSS ID NO.</div><div className="w-2/3 p-1"><input type="text" className="w-full outline-none" /></div></div>
                  <div className="flex"><div className="w-1/3 p-1 bg-gray-200">PAG-IBIG NO.</div><div className="w-2/3 p-1"><input type="text" className="w-full outline-none" /></div></div>
                  <div className="flex"><div className="w-1/3 p-1 bg-gray-200">PHILHEALTH NO.</div><div className="w-2/3 p-1"><input type="text" className="w-full outline-none" /></div></div>
              </div>
              <div className="w-1/2 flex flex-col divide-y divide-black">
                  <div className="flex"><div className="w-1/2 p-1"><GreenLabel required>HEIGHT</GreenLabel></div><div className="w-1/2 p-1"><input type="text" data-nsrp-required="height" aria-label="Height or N/A" aria-required="true" placeholder="cm / N/A" className="w-full outline-none" /></div></div>
                  <div className="flex"><div className="w-1/2 p-1"><GreenLabel required>EMAIL ADDRESS</GreenLabel></div><div className="w-1/2 p-1"><input type="text" data-prefill="email" data-applicant-field="email" data-field="Email address" aria-label="Email address or N/A" aria-required="true" placeholder="Email / N/A" className="w-full outline-none" /></div></div>
                  <div className="flex"><div className="w-1/2 p-1"><GreenLabel required>LANDLINE NUMBER</GreenLabel></div><div className="w-1/2 p-1"><input type="text" data-nsrp-required="landline" aria-label="Landline number or N/A" aria-required="true" placeholder="Number / N/A" className="w-full outline-none" /></div></div>
                  <div className="flex"><div className="w-1/2 p-1"><GreenLabel required>CELLPHONE NUMBER</GreenLabel></div><div className="w-1/2 p-1"><input type="text" data-prefill="phone" data-applicant-field="phone" data-field="Cellphone number" aria-label="Cellphone number or N/A" aria-required="true" placeholder="Number / N/A" className="w-full outline-none" /></div></div>
              </div>
            </div>

             <div className="flex border-b border-black divide-x divide-black p-1">
                <div className="w-[16.5%] font-bold">DISABILITY</div>
                <div className="w-[83.5%] grid grid-cols-4 px-2">
                    <label className="flex items-center gap-1"><input type="checkbox"/> Visual</label>
                    <label className="flex items-center gap-1"><input type="checkbox"/> Speech</label>
                    <div className="col-span-2 flex items-center gap-1">
                        <input type="checkbox"/> Others, specify: <input type="text" className="border-b border-black outline-none flex-grow mx-1"/>
                    </div>
                    <label className="flex items-center gap-1"><input type="checkbox"/> Hearing</label>
                    <label className="flex items-center gap-1"><input type="checkbox"/> Physical</label>
                </div>
            </div>

            <div className="flex border-b border-black divide-x divide-black">
                <div className="w-[16.5%] p-1"><GreenLabel required>EMPLOYMENT</GreenLabel><br/><GreenLabel required>STATUS/TYPE</GreenLabel></div>
                <div className="w-[83.5%] flex divide-x divide-black">
                    <div className="w-1/3 p-1 flex flex-col gap-2 border-r border-black">
                        <label className="flex items-center gap-1 font-bold"><input type="checkbox" data-nsrp-group="employmentStatus"/> Employed</label>
                        <div className="ml-4 flex flex-col gap-1">
                            <label className="flex items-center gap-1"><input type="checkbox" data-nsrp-group="employmentStatus"/> Wage Employed</label>
                            <label className="flex items-center gap-1"><input type="checkbox" data-nsrp-group="employmentStatus"/> Self Employed</label>
                        </div>
                    </div>
                    <div className="w-2/3 p-1 flex flex-col gap-2">
                        <label className="flex items-center gap-1 font-bold"><input type="checkbox" data-nsrp-group="employmentStatus"/> Unemployed</label>
                        <div className="ml-4 flex gap-4">
                            <div className="flex flex-col gap-1 w-1/2">
                                <label className="flex items-center gap-1"><input type="checkbox" data-nsrp-group="employmentStatus"/> New Entrant/Fresh Graduate</label>
                                <label className="flex items-center gap-1"><input type="checkbox" data-nsrp-group="employmentStatus"/> Finished Contract</label>
                                <label className="flex items-center gap-1"><input type="checkbox" data-nsrp-group="employmentStatus"/> Resigned</label>
                                <label className="flex items-center gap-1"><input type="checkbox" data-nsrp-group="employmentStatus"/> Retired</label>
                            </div>
                             <div className="flex flex-col gap-1 w-1/2">
                                <label className="flex items-center gap-1"><input type="checkbox" data-nsrp-group="employmentStatus"/> Terminated/Laidoff(local)</label>
                                <label className="flex items-start gap-1"><input type="checkbox" data-nsrp-group="employmentStatus"/>
                                    <div className="flex flex-col">
                                        <span>Terminated/Laidoff(abroad)</span>
                                        <span className="flex">specify country <input type="text" className="border-b border-black outline-none w-20 ml-1"/></span>
                                    </div>
                                </label>
                                <label className="flex items-center gap-1 mt-2"><input type="checkbox" data-nsrp-group="employmentStatus"/> Others, specify <input type="text" className="border-b border-black outline-none w-20 ml-1"/></label>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            <div className="p-1 flex items-center gap-4 border-b border-black">
                <span>Are you actively looking for work?</span>
                <label className="flex items-center gap-1"><input type="checkbox"/> Yes</label>
                <label className="flex items-center gap-1"><input type="checkbox"/> No</label>
                <span className="ml-4">How long have you been looking for work?</span>
                <input type="text" className="border-b border-black outline-none flex-grow"/>
            </div>
            <div className="p-1 flex items-center gap-4 border-b border-black">
                <span>Willing to work immediately?</span>
                <label className="flex items-center gap-1"><input type="checkbox"/> Yes</label>
                <label className="flex items-center gap-1"><input type="checkbox"/> No</label>
                <span className="ml-4">If no, when?</span>
                <input type="text" className="border-b border-black outline-none flex-grow"/>
            </div>
             <div className="p-1 flex items-center gap-4">
                <span>Are you a 4Ps beneficiary?</span>
                <label className="flex items-center gap-1"><input type="checkbox"/> Yes</label>
                <label className="flex items-center gap-1"><input type="checkbox"/> No</label>
                <span className="ml-4">If yes, Household ID No.</span>
                <input type="text" className="border-b border-black outline-none w-64"/>
            </div>
          </div>

          <div className="bg-gray-300 font-bold p-1 border border-black border-t-0 border-b-0 mt-2">
            II. JOB PREFERENCE
          </div>
          <div className="border border-black flex flex-col">
            <div className="flex divide-x divide-black border-b border-black">
                <div className="w-1/2 p-1 font-bold text-center"><GreenLabel required>PREFERRED OCCUPATION</GreenLabel></div>
                <div className="w-1/2 p-1 font-bold text-center"><GreenLabel required>PREFERRED WORK LOCATION</GreenLabel></div>
            </div>
            <div className="flex divide-x divide-black">
                <div className="w-1/2 divide-y divide-black">
                    {[1,2,3,4].map(num => (
                        <div key={num} className="flex p-1 h-8"><span className="w-4">{num}.</span><input type="text" data-applicant-field={num === 1 ? 'preferredOccupation' : undefined} data-field="Preferred occupation" aria-label={`Preferred occupation ${num}`} className="w-full outline-none"/></div>
                    ))}
                </div>
                <div className="w-1/2 flex divide-x divide-black">
                    <div className="w-1/2 divide-y divide-black border-r border-black">
                        <div className="p-1 flex items-center gap-1 border-b border-black h-8"><input type="checkbox"/> Local, specify cities/municipalities:</div>
                        {[1,2,3].map(num => (
                             <div key={num} className="flex p-1 h-8"><span className="w-4">{num}.</span><input type="text" data-nsrp-group="preferredWorkLocation" placeholder="Location or N/A" className="w-full outline-none"/></div>
                        ))}
                    </div>
                     <div className="w-1/2 divide-y divide-black">
                        <div className="p-1 flex items-center gap-1 border-b border-black h-8"><input type="checkbox"/> Overseas, specify countries:</div>
                        {[1,2,3].map(num => (
                             <div key={num} className="flex p-1 h-8"><span className="w-4">{num}.</span><input type="text" data-nsrp-group="preferredWorkLocation" placeholder="Location or N/A" className="w-full outline-none"/></div>
                        ))}
                    </div>
                </div>
            </div>
             <div className="flex divide-x divide-black border-t border-black">
                 <div className="w-1/2 p-1 flex">Expected Salary (Range) <input type="text" className="w-full outline-none ml-2"/></div>
                 <div className="w-1/4 p-1 flex border-r border-black">Passport No. <input type="text" className="w-full outline-none ml-2"/></div>
                 <div className="w-1/4 p-1 flex">Expiry date <input type="date" className="w-full outline-none ml-2"/></div>
             </div>
          </div>

           <div className="font-bold p-1 border-l border-r border-black mt-2 bg-gray-100 flex items-center">
             III. <GreenLabel required className="ml-1">LANGUAGE / DIALECT PROFICIENCY</GreenLabel>
          </div>
          <table className="w-full border-collapse border border-black text-center">
            <thead>
                <tr className="divide-x divide-black border-b border-black bg-gray-100">
                    <th className="w-1/4 p-1 font-normal text-left">(check if applicable)</th>
                    <th className="w-[18.75%] p-1">READ</th>
                    <th className="w-[18.75%] p-1">WRITE</th>
                    <th className="w-[18.75%] p-1">SPEAK</th>
                    <th className="w-[18.75%] p-1">UNDERSTAND</th>
                </tr>
            </thead>
            <tbody>
                <tr className="divide-x divide-black border-b border-black">
                    <td className="p-1 text-left">English</td>
                    <td><input type="checkbox" data-nsrp-group="languageProficiency" /></td>
                    <td><input type="checkbox" data-nsrp-group="languageProficiency" /></td>
                    <td><input type="checkbox" data-nsrp-group="languageProficiency" /></td>
                    <td><input type="checkbox" data-nsrp-group="languageProficiency" /></td>
                </tr>
            </tbody>
          </table>

          <div className="flex justify-between items-end mt-4">
              <div className="border border-black p-1 text-[10px] text-center w-32">
                  OM-25-001<br/>Revision No: 00<br/>Date Issued: 25/201
              </div>
              <div className="font-bold text-sm pr-4">Page 1 of 3</div>
          </div>

        </div>

        {/* ======================= PAGE 2 ======================= */}
        <div id="peso-page-2" className="w-[850px] bg-white shadow-sm mb-8 border border-gray-400 p-8 text-xs text-black">
            
           <table className="w-full border-collapse border border-black text-center mb-4">
            <tbody>
                <tr className="divide-x divide-black border-b border-black">
                    <td className="w-1/4 p-1 text-left">Filipino</td>
                    <td className="w-[18.75%]"><input type="checkbox" data-nsrp-group="languageProficiency" /></td>
                    <td className="w-[18.75%]"><input type="checkbox" data-nsrp-group="languageProficiency" /></td>
                    <td className="w-[18.75%]"><input type="checkbox" data-nsrp-group="languageProficiency" /></td>
                    <td className="w-[18.75%]"><input type="checkbox" data-nsrp-group="languageProficiency" /></td>
                </tr>
                <tr className="divide-x divide-black border-b border-black">
                    <td className="p-1 text-left flex">Others: <input type="text" data-nsrp-group="languageProficiency" aria-label="Other language or N/A" placeholder="Language / N/A" className="w-full outline-none ml-1"/></td>
                    <td><input type="checkbox" data-nsrp-group="languageProficiency" /></td>
                    <td><input type="checkbox" data-nsrp-group="languageProficiency" /></td>
                    <td><input type="checkbox" data-nsrp-group="languageProficiency" /></td>
                    <td><input type="checkbox" data-nsrp-group="languageProficiency" /></td>
                </tr>
            </tbody>
          </table>

          <div className="bg-gray-300 font-bold p-1 border border-black border-b-0 flex items-center">
             IV. <GreenLabel required className="ml-1">EDUCATIONAL BACKGROUND</GreenLabel>
          </div>
          <table className="w-full border-collapse border border-black text-center mb-4">
            <thead>
                <tr className="divide-x divide-black border-b border-black bg-gray-100">
                    <th className="w-1/5 p-1" rowSpan={2}>School</th>
                    <th className="w-1/5 p-1" rowSpan={2}>Course</th>
                    <th className="w-[10%] p-1" rowSpan={2}>Year<br/>graduated</th>
                    <th className="w-1/4 p-1 border-b border-black" colSpan={2}>If undergraduate,</th>
                    <th className="w-[15%] p-1" rowSpan={2}>Awards<br/>received</th>
                </tr>
                <tr className="divide-x divide-black border-b border-black bg-gray-100">
                    <th className="p-1 w-1/2 font-normal">what level?</th>
                    <th className="p-1 w-1/2 font-normal">year last<br/>attended</th>
                </tr>
            </thead>
            <tbody className="divide-y divide-black">
                {['Elementary', 'Secondary', 'Tertiary', 'Graduate Studies'].map((level) => (
                    <tr key={level} className="divide-x divide-black h-8">
                        <td className="p-1 text-left">{level}</td>
                        <td><input type="text" data-nsrp-group="educationBackground" placeholder={level === 'Elementary' ? 'Course / N/A' : undefined} aria-label={level + ' course or N/A'} className="w-full outline-none text-center h-full"/></td>
                        <td><input type="text" data-nsrp-group="educationBackground" className="w-full outline-none text-center h-full"/></td>
                        <td><input type="text" data-nsrp-group="educationBackground" className="w-full outline-none text-center h-full"/></td>
                        <td><input type="text" data-nsrp-group="educationBackground" className="w-full outline-none text-center h-full"/></td>
                        <td><input type="text" data-nsrp-group="educationBackground" className="w-full outline-none text-center h-full"/></td>
                    </tr>
                ))}
            </tbody>
          </table>

           <div className="bg-gray-300 font-bold p-1 border border-black border-b-0">
             V. TECHNICAL/VOCATIONAL AND OTHER TRAINING <span className="font-normal">(Include courses takens as part of college education)</span>
          </div>
          <table className="w-full border-collapse border border-black text-center mb-4">
            <thead>
                <tr className="divide-x divide-black border-b border-black bg-gray-100">
                    <th className="w-1/3 p-1">TRAINING/VOCATIONAL COURSE</th>
                    <th className="w-[15%] p-1">Duration<br/><span className="font-normal text-[8px]">(mm/dd/yyyy to mm/dd/yyyy)</span></th>
                    <th className="w-1/4 p-1">Training Institution</th>
                    <th className="w-[27%] p-1">Certificates Received<br/><span className="font-normal text-[8px]">(NC I, NC II, NC III, NC IV, etc)</span></th>
                </tr>
            </thead>
            <tbody className="divide-y divide-black">
                {[1, 2, 3].map((num) => (
                    <tr key={num} className="divide-x divide-black h-8">
                        <td className="p-1 text-left flex"><span className="w-4">{num}.</span><input type="text" className="w-full outline-none"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full"/></td>
                    </tr>
                ))}
            </tbody>
          </table>

          <div className="bg-gray-300 font-bold p-1 border border-black border-b-0">
             VI. ELIGIBILITY/ PROFESSIONAL LICENSE
          </div>
          <table className="w-full border-collapse border border-black text-center mb-4">
            <thead>
                <tr className="divide-x divide-black border-b border-black bg-gray-100">
                    <th className="w-[30%] p-1">ELIGIBILITY (Civil Service)</th>
                    <th className="w-[10%] p-1">Rating</th>
                    <th className="w-[20%] p-1">Date of examination</th>
                    <th className="w-[25%] p-1">PROFESSIONAL LICENSE (PRC)</th>
                    <th className="w-[15%] p-1">Valid Until</th>
                </tr>
            </thead>
            <tbody className="divide-y divide-black">
                {[1, 2].map((num) => (
                    <tr key={num} className="divide-x divide-black h-8">
                        <td className="p-1 text-left flex"><span className="w-4">{num}.</span><input type="text" className="w-full outline-none"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full"/></td>
                        <td className="p-1 text-left flex"><span className="w-4">{num}.</span><input type="text" className="w-full outline-none"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full"/></td>
                    </tr>
                ))}
            </tbody>
          </table>

          <div className="bg-gray-300 font-bold p-1 border border-black border-b-0 flex items-center">
             <GreenLabel required>VII. WORK EXPERIENCE</GreenLabel> <span className="ml-1 font-normal">(Limit to 10 year period, start with the most recent employment)</span>
          </div>
          <table className="w-full border-collapse border border-black text-center mb-4">
            <thead>
                <tr className="divide-x divide-black border-b border-black bg-gray-100">
                    <th className="w-1/4 p-1">Company Name</th>
                    <th className="w-1/4 p-1">Address<br/><span className="font-normal text-[9px]">(City/Municipality)</span></th>
                    <th className="w-[15%] p-1">Position</th>
                    <th className="w-[20%] p-1">Inclusive Dates<br/><span className="font-normal text-[9px]">(mm/yyyy to mm/yyyy)</span></th>
                    <th className="w-[15%] p-1">Status<br/><span className="font-normal text-[8px]">(Permanent, Contractual,<br/>Part-time, Probationary)</span></th>
                </tr>
            </thead>
            <tbody className="divide-y divide-black">
                {[1, 2, 3].map((num) => (
                    <tr key={num} className="divide-x divide-black h-10">
                        <td><input type="text" data-nsrp-group="workExperience" placeholder={num === 1 ? 'Company / N/A if none' : undefined} aria-label={'Work experience company ' + num + ' or N/A'} className="w-full outline-none text-center h-full px-1"/></td>
                        <td><input type="text" data-nsrp-group="workExperience" className="w-full outline-none text-center h-full px-1"/></td>
                        <td><input type="text" data-nsrp-group="workExperience" className="w-full outline-none text-center h-full px-1"/></td>
                        <td><input type="text" data-nsrp-group="workExperience" className="w-full outline-none text-center h-full px-1"/></td>
                        <td><input type="text" data-nsrp-group="workExperience" className="w-full outline-none text-center h-full px-1"/></td>
                    </tr>
                ))}
            </tbody>
          </table>

          <div className="font-bold p-1 border border-black border-b-0 flex items-center bg-gray-100">
             <GreenLabel required>VII OTHER SKILLS ACQUIRED WITHOUT FORMAL TRAINING</GreenLabel>
          </div>
          <div className="border border-black p-4 grid grid-cols-3 gap-y-2 text-sm mb-4">
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> AUTO MECHANIC</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> ELECTRICIAN</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> PHOTOGRAPHY</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> BEAUTICIAN</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> EMBROIDERY</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> PLUMBING</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> CARPENTRY WORK</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> GARDENING</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> SEWING DRESSES</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> COMPUTER LITERATE</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> MASONRY</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> STENOGRAPHY</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> DOMESTIC CHORES</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> PAINTER/ARTIST</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> TAILORING</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> DRIVER</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> PAINTING JOBS</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> OTHERS:</label>
             <label className="flex items-center gap-2"><input type="checkbox" data-nsrp-group="otherSkills" className="w-4 h-4"/> N/A - no other skills to list</label>
          </div>

          <div data-testid="print-career-information" className="border border-emerald-800 p-2 text-[10px] mb-3">
            <div className="font-bold text-emerald-900">APPLICANT CAREER INFORMATION</div>
            <div className="grid grid-cols-3 gap-2 mt-1">
              <div><span className="font-bold">Education:</span> {careerEducation || 'Not provided'}</div>
              <div><span className="font-bold">Work experience:</span> {experienceStatus || 'Not provided'}</div>
              <div><span className="font-bold">Career stage:</span> {skillsStage || 'Not provided'}</div>
              {skillsStage === skillsChoices[0] && careerSkills.trim() && (
                <div className="col-span-3">
                  <span className="font-bold">Skills or training:</span> {careerSkills.trim()}
                </div>
              )}
            </div>
          </div>

          <div className="text-center font-bold mb-2">CERTIFICATION/AUTHORIZATION</div>
          <p className="text-justify indent-8 mb-8">
            This is to certify that all data/information that I have provided in this form are true to the best of my knowledge. This is also to authorized the DOLE to include my profile in the PESO Employment Information System, which is a subsystem of the PhilJobNet. It is understood that my name shall be made available to employers who have access to the Registry. I am also aware that DOLE is not obliged to seek employment on my behalf.
          </p>

          <div className="flex justify-between px-12 mb-8">
            <div className="flex flex-col items-center w-64">
                <canvas
                  ref={signatureCanvasRef}
                  width={640}
                  height={150}
                  aria-label="Draw your signature"
                  data-testid="applicant-signature-canvas"
                  data-nsrp-required="signature"
                  onPointerDown={beginSignature}
                  onPointerMove={drawSignature}
                  onPointerUp={() => setIsSigning(false)}
                  onPointerCancel={() => setIsSigning(false)}
                  onLostPointerCapture={() => setIsSigning(false)}
                  className="w-full h-20 border-b border-black touch-none cursor-crosshair"
                />
                <span className="font-bold"><GreenLabel required>Signature of Applicant</GreenLabel></span>
            </div>
            <div className="flex flex-col items-center w-48">
                <input type="date" data-nsrp-required="signatureDate" aria-label="Signature date" aria-required="true"
                  className="w-full border-b border-black outline-none text-center" />
                <span className="font-bold"><GreenLabel required>Date</GreenLabel></span>
            </div>
          </div>

          <div className="border border-black p-2 border-dashed relative">
             <div className="absolute -top-3 left-1/2 transform -translate-x-1/2 bg-white px-2 font-bold text-gray-700 tracking-wide">
                 FOR USE OF PESO ONLY. PLEASE DO NOT WRITE BELOW THIS DOTTED LINE.
             </div>
             
             <div className="flex mt-4">
                 <div className="w-1/3 flex flex-col gap-1">
                     <span className="font-bold mb-1">Eligible for public employment services?</span>
                     <label className="flex items-center gap-2"><input type="checkbox" /> SPES</label>
                     <label className="flex items-center gap-2"><input type="checkbox" /> GIP</label>
                     <label className="flex items-center gap-2"><input type="checkbox" /> TUPAD</label>
                     <label className="flex items-center gap-2"><input type="checkbox" /> JobStart</label>
                     <label className="flex items-center gap-2"><input type="checkbox" /> Others, specify: <input type="text" className="border-b border-black outline-none w-24"/></label>
                 </div>
                 
                 <div className="w-2/3 flex flex-col justify-end items-end pr-8 pb-4 relative">
                     <span className="absolute top-0 left-0 font-bold">Assessed by:</span>
                     <div className="flex w-full justify-end gap-4">
                         <div className="flex flex-col items-center w-64">
                             <input type="text" className="w-full border-b border-black outline-none text-center" />
                             <span>Signature over Printed Name of Assessor</span>
                         </div>
                         <div className="flex flex-col items-center w-32">
                             <input type="date" className="w-full border-b border-black outline-none text-center" />
                             <span>Date</span>
                         </div>
                     </div>
                 </div>
             </div>
          </div>

          <div className="flex justify-between items-end mt-4">
              <div className="border border-black p-1 text-[10px] text-center w-32">
                  OM-25-001<br/>Revision No: 00<br/>Date Issued: 25/201
              </div>
              <div className="font-bold text-sm pr-4">Page 2 of 3</div>
          </div>

        </div>
        
        <div className="flex justify-center mt-4 pb-20">
          <button 
            disabled={isProcessing}
            onClick={handleCompleteRegistration}
            className="bg-green-700 text-white font-black text-xl py-4 px-12 rounded-xl hover:bg-green-800 shadow-xl shadow-green-900/30 transition-transform hover:scale-105 flex items-center gap-3 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isProcessing ? (
              <span>Preparing PDF & continuing...</span>
            ) : (
              <>
                <svg className="w-6 h-6" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path></svg>
                Download Form & Continue
              </>
            )}
          </button>
        </div>

          </div>
        </div>
      </div>
    </div>
  );
}