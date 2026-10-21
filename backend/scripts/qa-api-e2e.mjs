// Fictional account E2E audit. ONLY loopback QA ports 3003 and 9099.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';

const API = 'http://127.0.0.1:3003';
const AUTH = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/';
const report = { scenario: 'fictional-qa-applicant-and-admin', results: [], environment: 'isolated local Mongo+Firebase emulator; simulated Gemini' };
const mark = (name, data={}) => { const row={name,ok:true,...data}; report.results.push(row); console.log('PASS',name,JSON.stringify(data)); };
async function auth(endpoint, data) {
  const resp = await fetch(AUTH+endpoint+'?key=qa-local', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});
  const result=await resp.json();
  assert.equal(resp.status,200,'Firebase Auth emulator '+endpoint+' failed: '+resp.status);
  return result;
}
async function req(path,token,{method='GET',body=null}={}) {
  const headers={ Accept:'application/json' };
  if (token) headers.Authorization='Bearer '+token;
  if (body != null) headers['Content-Type']='application/json';
  const response=await fetch(API+path,{method,headers,body:body==null?undefined:JSON.stringify(body)});
  let data;
  const contentType=response.headers.get('content-type')||'';
  if(contentType.includes('application/json')) data=await response.json();
  else data=await response.arrayBuffer();
  return {status:response.status,data,contentType};
}
function expect(r,status,label) {
  if (r.status !== status) throw new Error(label+' got '+r.status+' '+JSON.stringify(r.data?.error||r.data?.message||'').slice(0,200));
  return r.data;
}
const unique=(Date.now()%100000000).toString(36);
const applicant = await auth('accounts:signUp',{email:'qa-applicant-'+unique+'@example.test',password:'qa-applicant-temp-42!',returnSecureToken:true});
const second = await auth('accounts:signUp',{email:'qa-second-'+unique+'@example.test',password:'qa-secondary-temp-42!',returnSecureToken:true});
const admin = await auth('accounts:signInWithPassword',{email:'qa-admin@peso.example.test',password:'QA-Temporary-Admin-Only-42!',returnSecureToken:true});
const user=applicant.idToken,other=second.idToken,manager=admin.idToken;

expect(await req('/api/jobs',null),401,'unauthorized jobs');
mark('Unauthenticated job endpoint denies access');

const profile=expect(await req('/api/profile/ensure',user,{method:'POST',body:{firstName:'QA',lastName:'Applicant',displayName:'QA Applicant'}}),200,'create profile').profile;
assert.equal(profile.role,'job_seeker');
mark('Firebase emulator registration token creates Mongo applicant');

const jobsResponse=expect(await req('/api/jobs',user),200,'job feed');
const jobs=jobsResponse.jobs;
assert.equal(jobs.length,2); assert.ok(jobs.every(x=>x.company.includes('QA Fictional')));
const mainJob=jobs.find(x=>x.title==='QA Data Entry Clerk');
assert.ok(mainJob);
mark('User sees both isolated fictional jobs',{count:jobs.length});

const data={resumeData:{fullName:'QA Applicant',education:'Senior High School',skills:['MS Excel','Data Entry']},pesoFormData:{firstName:'QA',lastName:'Applicant',educationLevel:'Senior High School'},onboardingText:'I finished Senior High School and can use MS Excel and do Data Entry. This is fictional QA data.'};
expect(await req('/api/profile/onboarding',user,{method:'PATCH',body:data}),200,'save onboarding');
const persisted=expect(await req('/api/profile',user),200,'reload persisted profile').profile;
assert.equal(persisted.resumeData?.fullName,'QA Applicant');
assert.equal(persisted.pesoFormData?.firstName,'QA');
mark('NSRP and resume sources persist across new GET');

const matched=expect(await req('/api/ai/job-match',user,{method:'POST',body:{jobId:mainJob.id}}),200,'Go match');
mark('Job match API invoked against seeded actual job',{status:matched.status,modelVersion:matched.modelVersion||null,resultCount:matched.results?.length||0});

const extracted=expect(await req('/api/ai/profile',user,{method:'POST',body:{rawText:'Senior High School graduate. I use MS Excel and Data Entry in a clerk role. Fictional QA applicant.'}}),200,'Gemini fake extraction');
assert.equal(extracted.saved,true);
const afterAI=expect(await req('/api/profile',user),200,'persisted AI profile').profile;
assert.equal(afterAI.aiProfile?.professionalTitle,'Data Entry Clerk');
mark('Simulated Gemini extraction saves a verifiable separate AI profile',{evidenceStatus:afterAI.aiMatchingExtraction?.status||null,matchStatus:afterAI.latestAiJobMatch?.status||null});

const translation = await req('/api/jobs/'+mainJob.id+'/translation',user,{method:'POST',body:{language:'Tagalog'}});
if (translation.status!==200) {
  report.results.push({name:'Job translation E2E',ok:false,status:translation.status,error:translation.data?.error||null});
  console.log('FAIL job translation',translation.status,translation.data?.error||null);
} else {
  assert.equal(translation.data.translation.requirements.length,2);
  const again=expect(await req('/api/jobs/'+mainJob.id+'/translation',user,{method:'POST',body:{language:'Tagalog'}}),200,'translation cache');
  assert.equal(again.cached,true);
  mark('Job translation endpoint and cache',{cached:again.cached});
}
const unchanged=expect(await req('/api/jobs',user),200,'original job persisted').jobs.find(j=>j.id===mainJob.id);
assert.deepEqual(unchanged.requirements,mainJob.requirements);
mark('Translation did not alter original qualification requirements');

const png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLTTAAAAABJRU5ErkJggg==';
const artifact=expect(await req('/api/artifacts',user,{method:'POST',body:{fileName:'qa-avatar.png',category:'profile_photo',mimeType:'image/png',base64:png}}),201,'avatar upload');
const photoId=artifact.artifact.id;
const photoList=expect(await req('/api/artifacts',user),200,'own artifacts');
assert.ok(photoList.artifacts.some(x=>x.id===photoId));
const cross=await req('/api/artifacts/'+photoId+'/content',other);
assert.equal(cross.status,404);
mark('Profile photo persists; second applicant cannot retrieve it');

const submitted=expect(await req('/api/applications',user,{method:'POST',body:{jobId:mainJob.id,jobTitle:mainJob.title,employer:mainJob.company,location:mainJob.location,answers:{willingness:'Yes',experience:'Training only'}}}),201,'submit job application');
mark('Fictional applicant submission saved separately from readiness preview',{status:submitted.application?.status});

const noAdmin=await req('/api/admin/applications',user);
assert.equal(noAdmin.status,403);
const adminApps=expect(await req('/api/admin/applications',manager),200,'admin applications');
assert.ok(adminApps.applications.some(x=>x.applicantUid===applicant.localId));
mark('Admin sees submitted application; applicant blocked from admin endpoint');

const users=expect(await req('/api/admin/users?limit=50',manager),200,'admin user register');
assert.ok(users.users.some(x=>x.uid===applicant.localId));
mark('Admin live applicant register includes synthetic new applicant',{source:users.source});

const exportLink=expect(await req('/api/admin/applications/export-link',manager,{method:'POST',body:{}}),200,'excel export link');
assert.ok(exportLink.url.startsWith(API+'/api/admin/applications/export?token='));
const excel=await fetch(exportLink.url);
assert.equal(excel.status,200);
const excelHeader=Buffer.from(await excel.arrayBuffer()).subarray(0,4).toString('hex');
assert.equal(excelHeader,'504b0304');
mark('Admin signed Excel link returns real generated XLSX bytes',{contentType:excel.headers.get('content-type')});

const outage=await req('/api/ai/profile',user,{method:'POST',body:{rawText:'QA_SIMULATE_GEMINI_429\nMS Excel and Data Entry'}})
if(outage.status!==429) {
  report.results.push({name:'Simulated Gemini quota response',ok:false,status:outage.status,error:outage.data?.error||null});
  console.log('FAIL simulated quota response',outage.status,outage.data?.error||null);
} else {
  mark('Simulated Gemini quota response is non-success',{code:outage.data.error});
}
const afterOutage=expect(await req('/api/profile',user),200,'profile after Gemini outage').profile;
assert.equal(afterOutage.resumeData?.fullName,'QA Applicant');
mark('Previous NSRP and resume data survive Gemini quota error');

report.summary={passed:report.results.filter(x=>x.ok).length,failed:report.results.filter(x=>!x.ok).length,goMatchingStatus:matched.status,aiMatchingStatus:afterAI.latestAiJobMatch?.status||null};
await fs.writeFile(new URL('../../docs/qa_browser/qa-api-e2e-results.json',import.meta.url),JSON.stringify(report,null,2));
console.log('SUMMARY',JSON.stringify(report.summary));
if(report.summary.failed) process.exitCode=1;
