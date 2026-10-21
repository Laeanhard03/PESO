import assert from 'node:assert/strict';
import { test } from 'node:test';
import { RODRIGUEZ_BARANGAYS, validateResidency, ageFromBirthDate,
 normalizeDateOfBirth, normalizeSex, isVerifiedResident, documentSummary } from '../src/residency.js';

test('official Montalban list has 11 distinct allowed barangays', () => {
 assert.equal(RODRIGUEZ_BARANGAYS.length, 11);
 assert.equal(new Set(RODRIGUEZ_BARANGAYS).size, 11);
 assert.ok(RODRIGUEZ_BARANGAYS.includes('Mascap'));
 assert.ok(!RODRIGUEZ_BARANGAYS.includes('Wawa'));
});
test('server validates municipality, barangay and real address', () => {
 const valid = validateResidency({ municipality:'Montalban, Rizal', barangay:'Brgy. San Jose', address:'Street 12 Block 4' });
 assert.equal(valid.municipality, 'Rodriguez');
 assert.equal(valid.barangay, 'San Jose');
 assert.equal(validateResidency({ municipality:'Marikina',barangay:'Balite',address:'Street 12' }).error, 'municipality_not_eligible');
 assert.equal(validateResidency({ municipality:'Montalban',barangay:'Wawa',address:'Street 12' }).error, 'invalid_rodriguez_barangay');
 assert.equal(validateResidency({ municipality:'Montalban',barangay:'Balite',address:'' }).error, 'residency_address_incomplete');
});
test('unreviewed and legacy residency never grant privileges', () => {
 const resident = { municipality:'Rodriguez', barangay:'Mascap', address:'Block 12 Lot 5', residency:{status:'pending'} };
 assert.equal(isVerifiedResident(resident),false);
 resident.residency.status='verified';
 assert.equal(isVerifiedResident(resident),true);
 resident.barangay='Wawa';
 assert.equal(isVerifiedResident(resident),false);
 assert.equal(isVerifiedResident({location:'San Jose'}),false);
});
test('date of birth derives age and rejects impossible dates', () => {
 assert.equal(normalizeDateOfBirth('2000-02-29'),'2000-02-29');
 assert.equal(normalizeDateOfBirth('2001-02-29'),'');
 assert.equal(ageFromBirthDate('2000-12-31',new Date('2026-10-22T00:00:00Z')),25);
 assert.equal(ageFromBirthDate('2000-10-22',new Date('2026-10-22T00:00:00Z')),26);
 assert.equal(normalizeSex('other'),'Other');
});
test('document status honors saved content independently of AI',()=>{
 const result=documentSummary({ resumeData: {skills:['Excel']},pesoFormData:{birthDate:'2000-01-01'},aiExtractionStatus:'failed'});
 assert.equal(result.resumeSubmitted,true);
 assert.equal(result.formSubmitted,true);
});
