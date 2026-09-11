import React, { useState, useRef } from "react";
import * as htmlToImage from "html-to-image";
import { jsPDF } from "jspdf";

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
const Editable = ({ defaultText, className = "", multiline = false, ...props }) => (
  <span
    contentEditable
    suppressContentEditableWarning
    className={`outline-none hover:bg-amber-50 focus:bg-amber-100 transition-colors rounded px-0.5 ${className}`}
    {...props}
  >
    {defaultText}
  </span>
);

export default function ResumeApp() {
  const [activeTemplate, setActiveTemplate] = useState("sally");
  const [zoom, setZoom] = useState(1);
  const [photo, setPhoto] = useState(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const fileInputRef = useRef(null);

  const handlePhotoUpload = (e) => {
    const file = e.target.files[0];
    if (file) {
      const url = URL.createObjectURL(file);
      setPhoto(url);
    }
  };

  // --- THE FLUTTER BRIDGE WITH SILENT PDF GENERATION ---
  const handleCompleteResume = async () => {
    setIsProcessing(true);

    // FIX: Temporarily remove the scale to prevent clipping/crashing, 
    // take the snapshot, then restore the scale.
    const zoomWrapper = document.getElementById('zoom-wrapper');
    const originalTransform = zoomWrapper.style.transform;
    zoomWrapper.style.transform = 'scale(1)';

    try {
      const element = document.getElementById('resume-node');
      
      // Using html-to-image to silently capture the design
      const imgData = await htmlToImage.toJpeg(element, { 
        quality: 0.98,
        backgroundColor: '#ffffff',
        pixelRatio: 2 // Ensures text is crisp
      });
      
      // Calculate A4 proportions based on the captured canvas
      const pdf = new jsPDF('p', 'mm', 'a4');
      const pdfWidth = pdf.internal.pageSize.getWidth();
      const pdfHeight = (element.offsetHeight * pdfWidth) / element.offsetWidth;
      
      pdf.addImage(imgData, 'JPEG', 0, 0, pdfWidth, pdfHeight);
      
      // Download directly to the user's computer
      pdf.save('JobKonek_Resume.pdf');

      // Extract raw text from all editable fields for the Gemini AI Engine
      const editables = document.querySelectorAll('span[contenteditable]');
      const resumeText = Array.from(editables).map(e => e.innerText).join('\n');
      const payload = JSON.stringify({ status: 'completed', data: resumeText });

      // Send the text payload back to Flutter
      if (window.FlutterBridge) {
        window.FlutterBridge.postMessage(payload);
      } else {
        alert("Resume Downloaded!\n\nIf you are testing Flutter on Chrome Web, click the 'Skip (Web Test)' button in the Flutter AppBar to continue.");
      }
    } catch (error) {
      console.error("PDF Generation failed:", error);
      alert("Failed to generate PDF. Check console for details.");
    } finally {
      // Put the zoom back to normal
      zoomWrapper.style.transform = originalTransform;
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
        <div className="flex items-center gap-2">
          <span className="text-xs font-bold uppercase tracking-wider text-neutral-400 mr-1">Design:</span>
          {[
            { id: "sally", label: "1. Teal Wave" },
            { id: "emily", label: "2. Warm Editorial" },
            { id: "richard", label: "3. Slate Timeline" },
            { id: "dian", label: "4. Organic Pastel" },
          ].map((t) => (
            <button
              key={t.id}
              onClick={() => setActiveTemplate(t.id)}
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
        <div className="flex items-center gap-3">
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
              <span>Processing PDF...</span>
            ) : (
              <>
                <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path></svg>
                Download PDF & Upload
              </>
            )}
          </button>
        </div>
      </header>

      {/* Canvas Workspace */}
      <main className="flex-1 overflow-auto p-6 flex justify-center items-start bg-neutral-200/70">
        <div
          id="zoom-wrapper"
          style={{
            transform: `scale(${zoom})`,
            transformOrigin: "top center",
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
            <Editable defaultText="Sally" />
          </h1>
          <h2 className="text-4xl font-extrabold text-neutral-900 tracking-tight leading-none mb-3">
            <Editable defaultText="Branders" />
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
              <li className="flex items-center"><MailIcon /> <Editable defaultText="sally.branders@gmail.com" /></li>
              <li className="flex items-center"><PhoneIcon /> <Editable defaultText="+1 232 555 55 55" /></li>
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
            <div className="flex items-start"><PhoneIcon /><Editable defaultText="+1 234 567 8900" /></div>
            <div className="flex items-start"><MailIcon /><Editable defaultText="emily.carter@futuremail.com" /></div>
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
            <Editable defaultText="EMILY" />
          </h1>
          <h1 className="text-5xl tracking-widest font-extralight text-neutral-800 leading-none mb-3">
            <Editable defaultText="CARTER" />
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
            <Editable defaultText="RICHARD SANCHEZ" />
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
              <li className="flex items-center"><PhoneIcon /><Editable defaultText="+123-456-7890" /></li>
              <li className="flex items-center"><MailIcon /><Editable defaultText="hello@reallygreatsite.com" /></li>
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
              <span><Editable defaultText="808.555.0118" /></span>
            </li>
            <li className="flex items-center">
              <MailIcon />
              <span><Editable defaultText="dian@example.com" /></span>
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
          <Editable defaultText="DIAN NUGRAHA" />
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