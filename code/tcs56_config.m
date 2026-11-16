function cfg = tcs56_config()
%TCS56_CONFIG  Settings for the TCS-56 curriculum analysis tool.
%
%   cfg = tcs56_config() returns every rule the tool applies, in one place,
%   so that a reviewer can see (and change) each assumption without reading
%   the analysis code. Values follow Section 2.1 of the manuscript and the
%   notes in Appendix A (v14).
%
%   Edit this file, not tcs56_tool.m, when:
%     * the appendix is revised (new programme, new elective track),
%     * a keyword rule wrongly flags a course name as clear/unclear,
%     * the manuscript values used for cross-checking change.
%% ---------------------------------------------------------------- items
% TCS-56 undergraduate physics/mathematics admission prerequisite (15 items)
% Each row: {item name as written in Appendix A, short label, keywords}.
% Keywords decide whether a course title "clearly" names the item. If the
% title contains none of them, the course is shown under the TCS-56 item
% name instead (substitute name) together with its coverage level.
cfg.physItems = {
 'Applied Linear Algebra',                   'Lin. algebra',  {'linear algebra','algebra','vector','matri'}
 'Advanced Calculus',                        'Calculus',      {'calculus'}
 'Complex Variables',                        'Complex var.',  {'complex'}
 'Differential Equations',                   'Diff. eq.',     {'differential equation'}
 'Numerical Methods / Computational Physics & Computer Programming', 'Numerical/comp.', ...
                                             {'numerical','comput','programming','matlab','java','simulation','modelling','finite element','data'}
 'Electricity and Magnetism',                'E&M',           {'electric','magnet'}
 'Atomic Physics/Nuclear Physics',           'Atomic/nuclear',{'atomic','nuclear','particle'}
 'Quantum Mechanics',                        'Quantum mech.', {'quantum'}
 'Classical Mechanics',                      'Classical mech.',{'mechanic','dynamical'}
 'Solid State Physics',                      'Solid state',   {'solid state','condensed','material','semiconductor'}
 'Modern Physics and Relativity',            'Modern/relativ.',{'modern physics','relativity'}
 'Thermodynamics / Statistical Physics',     'Thermo/stat.',  {'thermo','statistical','thermal'}
 'Signal Processing',                        'Signal proc.',  {'signal'}
 'Physics of Fluids and Gases',              'Fluids/gases',  {'fluid','gas','hydraulic','plasma'}
 'Optics',                                   'Optics',        {'optic','photon','laser'}
};

% TCS-56 postgraduate professional/clinical curriculum (12 items)
cfg.profItems = {
 'Anatomy and Physiology as applied to Medical Physics', 'Anat./physiol.', {'anatom','physiolog','human body','human structure'}
 'Radiobiology',                             'Radiobiology',  {'radiobiolog','radiation biolog','biophysics'}
 'Radiation Physics',                        'Rad. physics',  {'radiation physics'}
 'Radiation Protection',                     'Rad. protection',{'protection','safety','health physics'}
 'Professional and Scientific Development',  'Prof. dev.',    {'professional','ethic','quality management'}
 'Research Project',                         'Research proj.',{'project','research','dissertation','capstone'}
 'Medical Imaging Fundamentals',             'Imaging fund.', {'imaging','image'}
 'Radiation Dosimetry',                      'Dosimetry',     {'dosimetry','detection'}
 'Physics of Radiation Oncology',            'Rad. oncology', {'radiotherapy','oncology','brachytherapy','treatment'}
 'Physics of Nuclear Medicine',              'Nuc. medicine', {'nuclear medicine','radionuclide','nuclear techniques in medicine'}
 'Physics of Diagnostic and Interventional Radiology', 'Diag./interv. rad.', ...
                                             {'diagnostic','radiolog','radiograph','tomography','magnetic resonance','ultrasound'}
 'Advanced topics laboratory',               'Adv. lab',      {'laborator','practical','lab '}
};

% Reinforcing (Other-group) mapping that counts as physics/mathematics
% content but is not one of the 15 items.
cfg.generalPhysItem = 'General Physics and Mathematics';
cfg.generalPhysKeywords = {'physics','math','statistic','practical','laborator','astro','astronomy'};

% Titles that never name a topic clearly, whatever item they map to
% (regular expressions, case-insensitive).
cfg.genericTitlePatterns = {'^physics( [ivx]+)?$', 'slot', 'optional module', ...
    'bundled', 'special topic', '^project$', 'practicum', 'clinical training', ...
    'professional training', 'current physics'};

%% ------------------------------------------------------- classification
% Course marks used in Appendix A
cfg.markElective   = '*';
cfg.markUniversity = 8224;   % Unicode dagger: university course (compulsory)
cfg.markMajor      = 8225;   % Unicode double dagger: major course (compulsory)

% Titles treated as electives although unmarked (un-itemised elective slots)
cfg.electiveTitlePatterns = {'optional module', 'elective or minor study slot'};

% Programmes with parallel elective tracks: AchPM% counts the single best
% track plus the general (non-track) elective pool (Eq. 2, Section 2.1).
cfg.tracks = struct( ...
  'sec',   {'B.1', 'C.1'}, ...
  'names', {{'EP1','EP2'}, {'Academic','Industry'}}, ...
  'courses', { ...
     {{'Analytical Techniques and Materials Characterization','Materials Processing', ...
       'Nanophysics and Nanotechnology','Advanced Materials','Corrosion and Control'}, ...
      {'Microelectronic Devices','Sensor Technology II','Signals and Control Systems', ...
       'Sensor Technology I','Optoelectronics'}}, ...
     {{'Advanced Nuclear Physics','Introduction to Thermal Hydraulics','Radiation Safety Management', ...
       'Nuclear Techniques in Medicine','High Energy Physics','Energy Generation and Development','Nuclear Law'}, ...
      {'Radiation Safety Management','Nuclear Techniques in Medicine','Nuclear Technology in Industry', ...
       'Non-Destructive Testing I','Product Innovation','Materials Quality Control', ...
       'Nuclear Industrial Chemistry','Industrial Safety'}} });

% Programmes whose elective status cannot be rebuilt from the course list
% (elective pool not marked in Appendix A). Reported K, P and E are used.
cfg.useReportedCredit = {'B.6'};

% Bound on AchPM% from un-itemised elective slots (Section 2.1)
cfg.achBound = struct('sec', {'B.2','A.6','A.7','B.7'}, ...
                      'bound', {'lower','upper','upper','upper'});

%% ------------------------------------------------------ credit systems
% Notional hours per credit (Section 2.1). Malaysia: 40 h per CU (MQF).
cfg.hoursPerCU = 40;
cfg.creditSystem = struct( ...
  'prefix', {'UCL', 'U. Wollongong'}, ...
  'name',   {'UK credit', 'Australian credit point'}, ...
  'hoursLow',  {10, 24}, ...      % UK 10 h/credit; UOW 12 h/wk per 6 cp x 12 wk
  'hoursHigh', {10, 26});         % UOW x 13 wk
cfg.cuPerYear   = 30;    % 120 CU / 4 years
cfg.benchmarkCU = 60;    % two-year-equivalent physics/mathematics load

%% ----------------------------------------------- programme categories
% Category used for grouping in figures and cross-programme summaries.
cfg.category = struct( ...
 'sec', {'A.1','A.2','A.3','A.4','A.5','A.6','A.7','B.1','B.2','B.3','B.4','B.5','B.6','B.7','C.1','C.2','C.3','D.1','D.2'}, ...
 'cat', {'Physics','Physics','Physics','Physics','Physics','Comparator','Comparator', ...
         'Applied physics','Applied physics','Applied physics','Applied physics','Medical physics (BSc)', ...
         'Comparator','Comparator','Clinical/allied','Clinical/allied','Clinical/allied','Master','Master'});

%% ------------------------------------- manuscript values for checking
% Table 4 (v16): Phys+Math CU-equivalent and Ded/Split/PoB/NC counts.
% CU for comparators is the converted value (lower bound for UOW).
cfg.manuscriptTable4 = struct( ...
 'sec',  {'C.3','C.1','C.2','B.1','B.3','A.3','B.5','B.2','A.1','A.4','B.4','A.2','A.5','B.7','A.7','A.6','B.6'}, ...
 'cu',   {2, 14, 15, 37, 41, 42, 44, 48, 57, 57, 59, 60, 63, 50, 54, 63.75, 67.5}, ...
 'dspn', {[1 0 0 14],[1 5 0 9],[0 7 0 8],[6 2 7 0],[7 6 2 0],[4 10 1 0],[10 1 4 0],[9 3 3 0], ...
          [1 12 2 0],[9 5 1 0],[7 2 6 0],[8 4 3 0],[5 6 4 0],[8 3 4 0],[8 4 3 0],[3 10 2 0],[3 11 1 0]});

%% ------------------------------------------ self-assessment (tcs56_assess)
% Content keywords, used to read course synopses and topic names. Matching
% is at the start of a word ('thermo' matches 'thermodynamics'); a trailing
% space forces a whole word ('ct ' does not match 'electric').
% Order follows cfg.physItems then cfg.profItems.
cfg.contentKeywords = {
 {'linear algebra','matrix','matrices','eigen','vector space','linear transformation','determinant','vector analysis'}
 {'calculus','integral','integration','derivative','differentiation','partial derivative','taylor','multiple integral','gradient','divergence'}
 {'complex variable','complex number','complex analysis','analytic function','contour','residue','cauchy','laurent'}
 {'differential equation','ode ','pde ','boundary value','laplace transform','fourier series','separation of variables','initial value'}
 {'numerical','programming','algorithm','simulation','monte carlo','python','matlab','fortran','c++','finite difference','finite element','computational','computer','data analy','root finding'}
 {'electrostatic','electric field','electricity','magnetic field','magnetism','electromagn','maxwell','gauss','ampere','faraday','induction','capacitance'}
 {'atomic','atom ','hydrogen atom','nucleus','nuclear','radioactiv','decay','binding energy','fission','fusion','isotope','particle physics'}
 {'quantum','schrodinger','wave function','wavefunction','uncertainty principle','tunnelling','tunneling','harmonic oscillator','spin ','perturbation theory'}
 {'classical mechanics','mechanics','newton','lagrang','hamilton','kinematics','dynamics','rigid body','central force','momentum'}
 {'solid state','crystal','lattice','band theory','band structure','semiconductor','phonon','bravais','condensed matter','fermi'}
 {'modern physics','relativity','lorentz','photoelectric','compton','de broglie','blackbody','black body'}
 {'thermodynamic','entropy','heat engine','enthalpy','statistical mechanics','statistical physics','partition function','boltzmann','ensemble','kinetic theory','thermal physics'}
 {'signal','fourier transform','filter','sampling','noise','amplifier','electronic','analog','analogue','digital','transistor','op-amp','instrumentation'}
 {'fluid','viscosity','bernoulli','hydrostatic','gas law','ideal gas','kinetic theory of gases','plasma','navier','hydraulic'}
 {'optic','lens','refraction','diffraction','interference','polaris','polariz','laser','light ','photon'}
 {'anatomy','anatomical','physiology','physiological','organ ','tissue','human body','human structure','cardiovascular'}
 {'radiobiolog','radiation biology','cell survival','linear-quadratic','linear quadratic','dna damage','radiosensitiv','fractionation','oxygen enhancement','radiation biophysics'}
 {'radiation physics','interaction of radiation','interactions of radiation','photon interaction','compton scattering','pair production','attenuation coefficient','stopping power','x-ray production','charged particle'}
 {'radiation protection','shielding','alara','dose limit','radiation safety','licensing','personnel monitoring','icrp','health physics'}
 {'ethics','ethical','professionalism','professional development','quality management','quality system','communication','leadership','legislation','regulatory framework'}
 {'research project','dissertation','thesis','research methodology','final year project','capstone','research proposal'}
 {'image quality','image formation','spatial resolution','image reconstruction','image processing','medical imaging','imaging principles','principles of imaging','modulation transfer'}
 {'dosimetry','dosimeter','ionisation chamber','ionization chamber','absorbed dose','kerma','cavity theory','tld ','radiation detection','radiation detector'}
 {'radiotherapy','radiation therapy','linac','linear accelerator','treatment planning','brachytherapy','imrt','vmat','external beam','radiation oncology'}
 {'nuclear medicine','gamma camera','spect','pet ','radiopharmaceutical','radionuclide','scintigraph'}
 {'radiography','radiology','computed tomography','ct ','mri ','magnetic resonance','ultrasound','fluoroscopy','mammography','interventional'}
 {'laboratory','practical','experiment','lab '}
};
% Words removed when comparing a course title with Appendix A titles.
cfg.titleStopWords = {'introduction','intro','to','of','and','in','the','for','fundamentals', ...
    'fundamental','basic','principles','principle','i','ii','iii','iv', ...
    'v','vi','1','2','3','4','with','course','module','a','an','on','topics','topic'};
% Title words that block a title-keyword match (item number, words):
% e.g. 'Quantum Mechanics' must not count as Classical Mechanics.
cfg.titleExclusions = struct('item', {9, 27}, 'words', {{'quantum','statistical','fluid'}, ...
    {'physics practical','physics laborator','physics lab '}});
% Appendix A route: keep an item only if at least this share of the
% programmes listing the same course title map it to that item.
cfg.kbMinShare = 0.5;
% A synopsis must hit this many distinct keywords of an item to map it.
cfg.contentMinHits = 2;

%% ----------------------------------------------------------- output
cfg.colors.dedicated = [24 79 149]/255;    % blue 600
cfg.colors.split     = [57 135 229]/255;   % blue 400
cfg.colors.pob       = [158 197 244]/255;  % blue 200
cfg.colors.nc        = [208 59 59]/255;    % status critical (gap)
cfg.colors.na        = [0.93 0.93 0.92];   % not assessed
cfg.colors.series    = [42 120 214; 235 104 52; 27 175 122]/255;  % blue, orange, aqua
end
