import React, { useState } from 'react';

export default function App() {
  const [zoomLevel, setZoomLevel] = useState(1);

  const handleZoomIn = () => setZoomLevel(prev => Math.min(prev + 0.1, 2));
  const handleZoomOut = () => setZoomLevel(prev => Math.max(prev - 0.1, 0.5));
  const handleResetZoom = () => setZoomLevel(1);

  // --- THE FLUTTER BRIDGE ---
  const handleCompleteRegistration = () => {
    if (window.FlutterBridge) {
      // This tells your Flutter app to close the WebView and open the dashboard
      window.FlutterBridge.postMessage('completed');
    } else {
      // Fallback for Chrome browser testing
      alert("Form Submitted!\n\nIf you are testing Flutter on Chrome Web, click the 'Skip (Web Test)' button in the Flutter AppBar to continue.");
    }
  };

  // Helper component for the green highlighted headers
  const GreenLabel = ({ children, className = '' }) => (
    <span className={`bg-green-200/60 px-1 font-bold ${className}`}>{children}</span>
  );

  return (
    <div className="min-h-screen bg-gray-200 py-8 flex flex-col items-center font-sans overflow-x-hidden">
      
      {/* Zoom Controls (Fixed at top) */}
      <div className="fixed top-0 left-0 w-full bg-slate-800 p-3 flex justify-center gap-4 z-50 shadow-lg">
        <span className="text-white font-semibold my-auto">Form Viewer Controls:</span>
        <button onClick={handleZoomOut} className="bg-white px-4 py-1 rounded hover:bg-gray-100 font-bold">- Zoom Out</button>
        <button onClick={handleResetZoom} className="bg-white px-4 py-1 rounded hover:bg-gray-100 font-bold">Reset (100%)</button>
        <button onClick={handleZoomIn} className="bg-white px-4 py-1 rounded hover:bg-gray-100 font-bold">+ Zoom In</button>
      </div>

      {/* Zoomable Container */}
      <div 
        className="transition-transform duration-200 origin-top mt-12 pb-24"
        style={{ transform: `scale(${zoomLevel})` }}
      >
        
        {/* ======================= PAGE 1 ======================= */}
        <div className="w-[850px] bg-white shadow-2xl mb-8 border border-gray-400 p-8 text-xs text-black">
          
          {/* Header */}
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
              <div className="w-12 h-16 border border-gray-400 rounded-b-full flex items-center justify-center text-[8px] text-center">DOLE/PESO Logo</div>
            </div>
          </div>

          {/* Instructions */}
          <div className="border border-black p-2 mb-2 bg-gray-50">
            <span className="font-bold">INSTRUCTIONS:</span> Please fill out the form legibly with ball pen. Print in block letters. Check appropriate boxes. Please do not leave any items unanswered. Indicate "NA" if not applicable. You may use extra sheet if needed. Submit accomplished form to the Public Employment Service Office Manager or Officer in your city/municipality.
          </div>

          {/* I. PERSONAL INFORMATION */}
          <div className="bg-gray-300 font-bold p-1 border border-black border-b-0">
            I. PERSONAL INFORMATION
          </div>

          <div className="border border-black flex flex-col">
            {/* Name Row */}
            <div className="flex border-b border-black divide-x divide-black">
              <div className="w-1/4 p-1"><GreenLabel>SURNAME</GreenLabel><input type="text" className="w-full outline-none uppercase mt-1" /></div>
              <div className="w-1/4 p-1"><GreenLabel>FIRST NAME</GreenLabel><input type="text" className="w-full outline-none uppercase mt-1" /></div>
              <div className="w-1/4 p-1"><GreenLabel>MIDDLE NAME</GreenLabel><input type="text" className="w-full outline-none uppercase mt-1" /></div>
              <div className="w-1/4 p-1"><GreenLabel>SUFFIX</GreenLabel> (Ex: Sr., Jr., III, etc.)<input type="text" className="w-full outline-none uppercase mt-1" /></div>
            </div>

            {/* DOB / Age / Birthplace */}
            <div className="flex border-b border-black divide-x divide-black">
              <div className="w-1/4 p-1 flex flex-col justify-between"><GreenLabel>DATE OF BIRTH</GreenLabel> (mm/dd/yyyy)<input type="date" className="w-full outline-none mt-1" /></div>
              <div className="w-1/4 flex divide-x divide-black">
                  <div className="w-1/2 p-1 flex items-center gap-1"><input type="checkbox"/> Male</div>
                  <div className="w-1/2 p-1 flex items-center gap-1"><input type="checkbox"/> Female</div>
              </div>
              <div className="w-[12.5%] p-1"><GreenLabel>AGE</GreenLabel><input type="text" className="w-full outline-none mt-1" /></div>
              <div className="w-[37.5%] p-1"><GreenLabel>PLACE OF BIRTH</GreenLabel><input type="text" className="w-full outline-none mt-1" /></div>
            </div>

            {/* Sex/Religion & Address Block */}
            <div className="flex border-b border-black divide-x divide-black">
              <div className="w-1/2 flex flex-col divide-y divide-black">
                <div className="flex divide-x divide-black h-1/2">
                   <div className="w-1/2 p-1 font-bold text-green-700">SEX</div>
                   <div className="w-1/2 p-1"><GreenLabel>RELIGION</GreenLabel><input type="text" className="w-full outline-none" /></div>
                </div>
                <div className="flex divide-x divide-black h-1/2">
                    <div className="w-1/4 p-1"><GreenLabel>CIVIL STATUS</GreenLabel></div>
                    <div className="w-3/4 p-1 grid grid-cols-2 gap-1">
                        <label className="flex items-center gap-1"><input type="checkbox"/> Single</label>
                        <label className="flex items-center gap-1"><input type="checkbox"/> Separated</label>
                        <label className="flex items-center gap-1"><input type="checkbox"/> Married</label>
                        <label className="flex items-center gap-1"><input type="checkbox"/> Live-in</label>
                        <label className="flex items-center gap-1"><input type="checkbox"/> Widowed</label>
                    </div>
                </div>
              </div>
              <div className="w-1/2 flex divide-x divide-black">
                  <div className="w-1/3 p-1 flex flex-col justify-center"><GreenLabel>PRESENT ADDRESS</GreenLabel></div>
                  <div className="w-2/3 flex flex-col divide-y divide-black">
                      <div className="p-1 flex"><span className="w-24 text-[10px]">House No./Street</span><input type="text" className="w-full outline-none" /></div>
                      <div className="p-1 flex"><span className="w-24 text-[10px]">Village</span><input type="text" className="w-full outline-none" /></div>
                      <div className="p-1 flex"><span className="w-24 text-[10px]">Barangay</span><input type="text" className="w-full outline-none" /></div>
                      <div className="p-1 flex"><span className="w-24 text-[10px]"><GreenLabel>Municipality/City</GreenLabel></span><input type="text" className="w-full outline-none" /></div>
                      <div className="p-1 flex"><span className="w-24 text-[10px]">Province</span><input type="text" className="w-full outline-none" /></div>
                  </div>
              </div>
            </div>

            {/* IDs and Contact Block */}
            <div className="flex border-b border-black divide-x divide-black">
              <div className="w-1/2 flex flex-col divide-y divide-black">
                  <div className="flex"><div className="w-1/3 p-1 bg-gray-200">TIN</div><div className="w-2/3 p-1"><input type="text" className="w-full outline-none" /></div></div>
                  <div className="flex"><div className="w-1/3 p-1 bg-gray-200">GSIS/SSS ID NO.</div><div className="w-2/3 p-1"><input type="text" className="w-full outline-none" /></div></div>
                  <div className="flex"><div className="w-1/3 p-1 bg-gray-200">PAG-IBIG NO.</div><div className="w-2/3 p-1"><input type="text" className="w-full outline-none" /></div></div>
                  <div className="flex"><div className="w-1/3 p-1 bg-gray-200">PHILHEALTH NO.</div><div className="w-2/3 p-1"><input type="text" className="w-full outline-none" /></div></div>
              </div>
              <div className="w-1/2 flex flex-col divide-y divide-black">
                  <div className="flex"><div className="w-1/2 p-1"><GreenLabel>HEIGHT</GreenLabel></div><div className="w-1/2 p-1"><input type="text" className="w-full outline-none" /></div></div>
                  <div className="flex"><div className="w-1/2 p-1"><GreenLabel>EMAIL ADDRESS</GreenLabel></div><div className="w-1/2 p-1"><input type="text" className="w-full outline-none" /></div></div>
                  <div className="flex"><div className="w-1/2 p-1"><GreenLabel>LANDLINE NUMBER</GreenLabel></div><div className="w-1/2 p-1"><input type="text" className="w-full outline-none" /></div></div>
                  <div className="flex"><div className="w-1/2 p-1"><GreenLabel>CELLPHONE NUMBER</GreenLabel></div><div className="w-1/2 p-1"><input type="text" className="w-full outline-none" /></div></div>
              </div>
            </div>

            {/* Disability */}
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

            {/* Employment Status */}
            <div className="flex border-b border-black divide-x divide-black">
                <div className="w-[16.5%] p-1"><GreenLabel>EMPLOYMENT</GreenLabel><br/><GreenLabel>STATUS/TYPE</GreenLabel></div>
                <div className="w-[83.5%] flex divide-x divide-black">
                    <div className="w-1/3 p-1 flex flex-col gap-2 border-r border-black">
                        <label className="flex items-center gap-1 font-bold"><input type="checkbox"/> Employed</label>
                        <div className="ml-4 flex flex-col gap-1">
                            <label className="flex items-center gap-1"><input type="checkbox"/> Wage Employed</label>
                            <label className="flex items-center gap-1"><input type="checkbox"/> Self Employed</label>
                        </div>
                    </div>
                    <div className="w-2/3 p-1 flex flex-col gap-2">
                        <label className="flex items-center gap-1 font-bold"><input type="checkbox"/> Unemployed</label>
                        <div className="ml-4 flex gap-4">
                            <div className="flex flex-col gap-1 w-1/2">
                                <label className="flex items-center gap-1"><input type="checkbox"/> New Entrant/Fresh Graduate</label>
                                <label className="flex items-center gap-1"><input type="checkbox"/> Finished Contract</label>
                                <label className="flex items-center gap-1"><input type="checkbox"/> Resigned</label>
                                <label className="flex items-center gap-1"><input type="checkbox"/> Retired</label>
                            </div>
                             <div className="flex flex-col gap-1 w-1/2">
                                <label className="flex items-center gap-1"><input type="checkbox"/> Terminated/Laidoff(local)</label>
                                <label className="flex items-start gap-1"><input type="checkbox"/> 
                                    <div className="flex flex-col">
                                        <span>Terminated/Laidoff(abroad)</span>
                                        <span className="flex">specify country <input type="text" className="border-b border-black outline-none w-20 ml-1"/></span>
                                    </div>
                                </label>
                                <label className="flex items-center gap-1 mt-2"><input type="checkbox"/> Others, specify <input type="text" className="border-b border-black outline-none w-20 ml-1"/></label>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            {/* Job Search questions */}
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

          {/* II. JOB PREFERENCE */}
          <div className="bg-gray-300 font-bold p-1 border border-black border-t-0 border-b-0 mt-2">
            II. JOB PREFERENCE
          </div>
          <div className="border border-black flex flex-col">
            <div className="flex divide-x divide-black border-b border-black">
                <div className="w-1/2 p-1 font-bold text-center"><GreenLabel>PREFERRED OCCUPATION</GreenLabel></div>
                <div className="w-1/2 p-1 font-bold text-center"><GreenLabel>PREFERRED WORK LOCATION</GreenLabel></div>
            </div>
            <div className="flex divide-x divide-black">
                <div className="w-1/2 divide-y divide-black">
                    {[1,2,3,4].map(num => (
                        <div key={num} className="flex p-1 h-8"><span className="w-4">{num}.</span><input type="text" className="w-full outline-none"/></div>
                    ))}
                </div>
                <div className="w-1/2 flex divide-x divide-black">
                    <div className="w-1/2 divide-y divide-black border-r border-black">
                        <div className="p-1 flex items-center gap-1 border-b border-black h-8"><input type="checkbox"/> Local, specify cities/municipalities:</div>
                        {[1,2,3].map(num => (
                             <div key={num} className="flex p-1 h-8"><span className="w-4">{num}.</span><input type="text" className="w-full outline-none"/></div>
                        ))}
                    </div>
                     <div className="w-1/2 divide-y divide-black">
                        <div className="p-1 flex items-center gap-1 border-b border-black h-8"><input type="checkbox"/> Overseas, specify countries:</div>
                        {[1,2,3].map(num => (
                             <div key={num} className="flex p-1 h-8"><span className="w-4">{num}.</span><input type="text" className="w-full outline-none"/></div>
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

          {/* III. LANGUAGE / DIALECT PROFICIENCY (Page 1 part) */}
           <div className="font-bold p-1 border-l border-r border-black mt-2 bg-gray-100 flex items-center">
             III. <GreenLabel className="ml-1">LANGUAGE / DIALECT PROFICIENCY</GreenLabel>
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
                    <td><input type="checkbox" /></td>
                    <td><input type="checkbox" /></td>
                    <td><input type="checkbox" /></td>
                    <td><input type="checkbox" /></td>
                </tr>
            </tbody>
          </table>

          {/* Page 1 Footer */}
          <div className="flex justify-between items-end mt-4">
              <div className="border border-black p-1 text-[10px] text-center w-32">
                  OM-25-001<br/>Revision No: 00<br/>Date Issued: 25/201
              </div>
              <div className="font-bold text-sm pr-4">Page 1 of 3</div>
          </div>

        </div>

        {/* ======================= PAGE 2 ======================= */}
        <div className="w-[850px] bg-white shadow-2xl mb-8 border border-gray-400 p-8 text-xs text-black">
            
           {/* III. Language Continued */}
           <table className="w-full border-collapse border border-black text-center mb-4">
            <tbody>
                <tr className="divide-x divide-black border-b border-black">
                    <td className="w-1/4 p-1 text-left">Filipino</td>
                    <td className="w-[18.75%]"><input type="checkbox" /></td>
                    <td className="w-[18.75%]"><input type="checkbox" /></td>
                    <td className="w-[18.75%]"><input type="checkbox" /></td>
                    <td className="w-[18.75%]"><input type="checkbox" /></td>
                </tr>
                <tr className="divide-x divide-black border-b border-black">
                    <td className="p-1 text-left flex">Others: <input type="text" className="w-full outline-none ml-1"/></td>
                    <td><input type="checkbox" /></td>
                    <td><input type="checkbox" /></td>
                    <td><input type="checkbox" /></td>
                    <td><input type="checkbox" /></td>
                </tr>
            </tbody>
          </table>

          {/* IV. EDUCATIONAL BACKGROUND */}
          <div className="bg-gray-300 font-bold p-1 border border-black border-b-0 flex items-center">
             IV. <GreenLabel className="ml-1">EDUCATIONAL BACKGROUND</GreenLabel>
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
                        <td><input type="text" className="w-full outline-none text-center h-full"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full"/></td>
                    </tr>
                ))}
            </tbody>
          </table>

           {/* V. TECHNICAL/VOCATIONAL */}
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

          {/* VI. ELIGIBILITY / PROFESSIONAL LICENSE */}
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

          {/* VII. WORK EXPERIENCE */}
          <div className="bg-gray-300 font-bold p-1 border border-black border-b-0 flex items-center">
             <GreenLabel>VII. WORK EXPERIENCE</GreenLabel> <span className="ml-1 font-normal">(Limit to 10 year period, start with the most recent employment)</span>
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
                        <td><input type="text" className="w-full outline-none text-center h-full px-1"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full px-1"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full px-1"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full px-1"/></td>
                        <td><input type="text" className="w-full outline-none text-center h-full px-1"/></td>
                    </tr>
                ))}
            </tbody>
          </table>

          {/* VIII. OTHER SKILLS */}
          <div className="font-bold p-1 border border-black border-b-0 flex items-center bg-gray-100">
             <GreenLabel>VII OTHER SKILLS ACQUIRED WITHOUT FORMAL TRAINING</GreenLabel>
          </div>
          <div className="border border-black p-4 grid grid-cols-3 gap-y-2 text-sm mb-4">
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> AUTO MECHANIC</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> ELECTRICIAN</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> PHOTOGRAPHY</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> BEAUTICIAN</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> EMBROIDERY</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> PLUMBING</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> CARPENTRY WORK</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> GARDENING</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> SEWING DRESSES</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> COMPUTER LITERATE</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> MASONRY</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> STENOGRAPHY</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> DOMESTIC CHORES</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> PAINTER/ARTIST</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> TAILORING</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> DRIVER</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> PAINTING JOBS</label>
             <label className="flex items-center gap-2"><input type="checkbox" className="w-4 h-4"/> OTHERS:</label>
          </div>

          {/* Certification / Authorization */}
          <div className="text-center font-bold mb-2">CERTIFICATION/AUTHORIZATION</div>
          <p className="text-justify indent-8 mb-8">
            This is to certify that all data/information that I have provided in this form are true to the best of my knowledge. This is also to authorized the DOLE to include my profile in the PESO Employment Information System, which is a subsystem of the PhilJobNet. It is understood that my name shall be made available to employers who have access to the Registry. I am also aware that DOLE is not obliged to seek employment on my behalf.
          </p>

          <div className="flex justify-between px-12 mb-8">
            <div className="flex flex-col items-center w-64">
                <input type="text" className="w-full border-b border-black outline-none text-center" />
                <span className="font-bold"><GreenLabel>Signature of Applicant</GreenLabel></span>
            </div>
            <div className="flex flex-col items-center w-48">
                <input type="date" className="w-full border-b border-black outline-none text-center" />
                <span className="font-bold"><GreenLabel>Date</GreenLabel></span>
            </div>
          </div>

          {/* FOR USE OF PESO ONLY */}
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

          {/* Page 2 Footer */}
          <div className="flex justify-between items-end mt-4">
              <div className="border border-black p-1 text-[10px] text-center w-32">
                  OM-25-001<br/>Revision No: 00<br/>Date Issued: 25/201
              </div>
              <div className="font-bold text-sm pr-4">Page 2 of 3</div>
          </div>

        </div>
        
        {/* BIG SUBMIT BUTTON */}
        <div className="flex justify-center mt-4">
          <button 
            onClick={handleCompleteRegistration}
            className="bg-green-700 text-white font-black text-xl py-4 px-12 rounded-xl hover:bg-green-800 shadow-xl shadow-green-900/30 transition-transform hover:scale-105"
          >
            Save changes to profile
          </button>
        </div>

      </div>
    </div>
  );
}