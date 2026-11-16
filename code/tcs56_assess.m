function A = tcs56_assess(input, varargin)
%TCS56_ASSESS  Self-assessment of ONE programme against IAEA TCS-56.
%
%   A = tcs56_assess(input, Name, Value, ...) maps one programme's courses
%   (or a student's list of topics) to the 15 TCS-56 physics/mathematics
%   prerequisite items and the 12 professional/clinical items, reports how
%   well the programme aligns, and attaches a remark and a confidence level
%   to every finding.
%
%   INPUT can be
%     * a .csv / .xlsx file or a MATLAB table with columns (any order, case
%       ignored; only the course name is required):
%         Course | Name | Title | Topic         course or topic name
%         CU | Credit | Credits                 credit units
%         Type | Status | Core                  'Core'/'Elective' (or 1/0)
%         Content | Synopsis | Description      course synopsis (recommended)
%     * a .txt file with one course or topic per line (student mode)
%     * a cell array of course / topic names (student mode)
%
%   Each course is mapped by up to three routes, strongest first:
%     1. Content  - keywords of each TCS-56 item found in the synopsis
%                   (at least cfg.contentMinHits distinct keywords);
%     2. Appendix - the same or a similar course title already classified in
%                   Appendix A of the manuscript (19 programmes, 2026);
%     3. Title    - keywords of a TCS-56 item found in the title.
%   Confidence: High = content and another route agree; Medium = content
%   only, or an exact Appendix A title match; Low = title keyword only or a
%   similar (not identical) Appendix A title.
%
%   Name-Value options
%     'Programme'         programme name for the report     ('Programme')
%     'Level'             'Bachelor' (default) or 'Master'
%     'CreditRequirement' credits needed to graduate (C). If omitted, the
%                         sum of listed credits is used (with a caveat).
%     'CompulsoryCredit'  official compulsory credits (K), if known
%     'CreditFactor'      multiply credits by this to get Malaysian CU
%                         (UK credit 0.25; Australian credit point 0.6)
%     'CompareWith'       Appendix A section to compare with, e.g. 'A.1'
%     'AppendixFile'      Appendix A markdown file (default: ../data)
%     'OutDir'            output folder (default: ./tcs56_assessment)
%     'Excel','Figure','Report','Verbose'   true/false (default true)
%
%   Output A (struct)
%     A.courses   course table: CU, core/elective, mapped items, route,
%                 confidence, Appendix A match and a remark per course
%     A.items     27-item table: coverage, courses, credits, confidence,
%                 elective-only flag, remark (and Appendix A comparison)
%     A.metrics   CorePM%, AchPM%, items covered, CU benchmark (if credits)
%     A.gaps      gaps with severity and remark
%     A.caveats   caveats that apply to this assessment
%     Files: assessment_report.md, TCS56_assessment.xlsx, coverage figure.
%
%   Examples
%     % university: course list with credits, type and synopsis
%     A = tcs56_assess('my_programme.xlsx', 'Programme', 'BSc Physics', ...
%                      'CreditRequirement', 120, 'CompareWith', 'A.1');
%     % student: topics only
%     A = tcs56_assess({'Calculus','Quantum Mechanics','Electronics', ...
%                       'Radiation Physics'}, 'Programme', 'My degree');
%
%   The result is an automated, indicative mapping. It is not an
%   accreditation or registration decision (see A.caveats).
% ------------------------------------------------------------------ options
here = fileparts(mfilename('fullpath'));
opt = struct('Programme', 'Programme', 'Level', 'Bachelor', 'CreditRequirement', NaN, ...
    'CompulsoryCredit', NaN, 'CreditFactor', 1, 'CompareWith', '', ...
    'AppendixFile', fullfile(fileparts(here), 'data', 'Appendix_A_Anonymized_v14_submission.md'), ...
    'OutDir', fullfile(pwd, 'tcs56_assessment'), 'Excel', true, 'Figure', true, ...
    'Report', true, 'Verbose', true);
for k = 1:2:numel(varargin), opt.(varargin{k}) = varargin{k+1}; end
if ~exist(opt.OutDir, 'dir'), mkdir(opt.OutDir); end
cfg = tcs56_config();
items = [cfg.physItems(:,1); cfg.profItems(:,1)];
short = [cfg.physItems(:,2); cfg.profItems(:,2)];
nP = size(cfg.physItems,1); nI = numel(items);
isMaster = strcmpi(opt.Level, 'Master');

% ------------------------------------------- reference data (Appendix A)
R  = tcs56_tool(opt.AppendixFile, 'Excel', false, 'Figures', false, 'Verbose', false);
KB = buildKB(R.mapping, cfg);

% -------------------------------------------------------------- input
C = readInput(input);
nC = numel(C);
hasCU      = any(~isnan([C.cu]));
hasType    = any(~cellfun(@isempty, {C.type}));
hasContent = any(~cellfun(@isempty, {C.content}));
mode = ternary(hasCU, 'University (course list)', 'Student (topics only)');

% ------------------------------------------------------- map each course
mapped = cell(1, nC);
for c = 1:nC
    mapped{c} = mapCourse(C(c), cfg, KB, items, nP);
end
C = [mapped{:}];

% ------------------------------------------------------------ item table
cov = repmat({'Not covered'}, nI, 1); conf = repmat({''}, nI, 1);
names = repmat({''}, nI, 1); cuItem = zeros(nI,1); eo = false(nI,1); rmk = repmat({''}, nI, 1);
rank = struct('Low', 1, 'Medium', 2, 'High', 3);
for j = 1:nI
    hit = arrayfun(@(x) any(x.idx == j), C);
    if ~any(hit)
        if isMaster && j <= nP
            cov{j} = 'Not assessed';
            rmk{j} = 'Physics/mathematics prerequisites are assessed at bachelor''s level (TCS-56 admission criteria).';
        elseif ~isMaster && j > nP
            rmk{j} = 'No undergraduate exposure found. TCS-56 places this item in the postgraduate curriculum, so this is not a bachelor''s-level gap.';
        else
            rmk{j} = 'No course found for this item. Check whether it is taught inside a course whose title and synopsis do not name it.';
        end
        continue
    end
    K = C(hit);
    names{j} = strjoin(arrayfun(@(x) sprintf('%s (%s)', x.name, x.conf{x.idx == j}), K, ...
                       'UniformOutput', false), '; ');
    x = [K.cu]; x(isnan(x)) = 0; cuItem(j) = sum(x);
    best = 0;
    for k = 1:numel(K)
        best = max(best, rank.(K(k).conf{K(k).idx == j}));
    end
    conf{j} = ternary(best == 3, 'High', ternary(best == 2, 'Medium', 'Low'));
    eo(j) = hasType && all(strcmp({K.type}, 'Elective'));
    % coverage level, following the Appendix A definitions
    if numel(K) >= 2
        cov{j} = 'Split';
    elseif ~isempty(K.kbCov) && any(K.kbItems == j) && strcmp(K.kbMatch, 'exact')
        cov{j} = K.kbCov{find(K.kbItems == j, 1)};            % as classified in Appendix A
        if any(strcmp(cov{j}, {'Split','Reinforced','---'}))   % split / supporting there, single course here
            cov{j} = ternary(numel(K.idx) >= 2, 'Part of broader', 'Dedicated');
        end
    elseif numel(K.idx) >= 2
        cov{j} = 'Part of broader';
    else
        cov{j} = 'Dedicated';
    end
    r = {};
    if eo(j), r{end+1} = 'Reached only through electives: a graduate may not have taken it.'; end %#ok<AGROW>
    if strcmp(conf{j}, 'Low'), r{end+1} = 'Inferred from a course title only; confirm against the syllabus.'; end %#ok<AGROW>
    if strcmp(cov{j}, 'Part of broader'), r{end+1} = 'Covered inside a broader course; depth is not guaranteed.'; end %#ok<AGROW>
    rmk{j} = strjoin(r, ' ');
end

% ----------------------------------------------------------------- metrics
m = struct();
scope = ternary(isMaster, nP+1:nI, 1:nI);
ph = cov(1:nP); pr = cov(nP+1:end);
m.physDSPN = [sum(strcmp(ph,'Dedicated')) sum(strcmp(ph,'Split')) sum(strcmp(ph,'Part of broader')) sum(strcmp(ph,'Not covered'))];
m.profDSPN = [sum(strcmp(pr,'Dedicated')) sum(strcmp(pr,'Split')) sum(strcmp(pr,'Part of broader')) sum(strcmp(pr,'Not covered'))];
m.physCovered = ternary(isMaster, NaN, nP - m.physDSPN(4));
m.profCovered = (nI - nP) - m.profDSPN(4);
m.lowConfidenceItems = sum(strcmp(conf(scope), 'Low'));
cu = [C.cu] * opt.CreditFactor; cuz = cu; cuz(isnan(cuz)) = 0;
elec = strcmp({C.type}, 'Elective');
isPhys = arrayfun(@(x) x.isPhys, C);
inMP   = arrayfun(@(x) any(x.idx <= nP), C);
m.ListTotal = ternary(hasCU, sum(cuz), NaN);
m.C = opt.CreditRequirement * opt.CreditFactor;
if isnan(m.C) && hasCU, m.C = m.ListTotal; end
m.K = ternary(hasCU, sum(cuz(~elec)), NaN);
if ~isnan(opt.CompulsoryCredit), m.K = opt.CompulsoryCredit * opt.CreditFactor; end
m.P = ternary(hasCU, sum(cuz(~elec & isPhys)), NaN);
m.E = ternary(hasCU, sum(cuz(elec & isPhys)), NaN);
if hasCU && ~isMaster
    m.CorePM = 100 * m.P / m.C;
    m.AchPM  = 100 * (m.P + min(max(m.C - m.K, 0), m.E)) / m.C;
    m.physCU = sum(cuz(inMP));
    m.yearsEq = m.physCU / cfg.cuPerYear;
    m.benchmark = ternary(m.physCU >= cfg.benchmarkCU, 'Meets', 'Below');
else
    m.CorePM = NaN; m.AchPM = NaN; m.physCU = NaN; m.yearsEq = NaN; m.benchmark = 'Not computed';
end

% ---------------------------------------------------------------- gaps
g = cell(0, 5);
for j = scope
    if strcmp(cov{j}, 'Not covered') && (isMaster || j <= nP)
        g(end+1,:) = {items{j}, 'Not covered', 'High', ...
            'No mapped course.', rmk{j}}; %#ok<AGROW>
    end
    if eo(j)
        g(end+1,:) = {items{j}, 'Elective only', 'Medium', 'Only elective courses map to it.', rmk{j}}; %#ok<AGROW>
    end
    if strcmp(cov{j}, 'Part of broader') && j <= nP
        g(end+1,:) = {items{j}, 'Part of broader only', 'Low', 'Single broad course.', rmk{j}}; %#ok<AGROW>
    end
    if ~strcmp(cov{j}, 'Not covered') && strcmp(conf{j}, 'Low')
        g(end+1,:) = {items{j}, 'Coverage uncertain', 'Low', 'Title-only evidence.', rmk{j}}; %#ok<AGROW>
    end
end
if ~isMaster && hasCU && strcmp(m.benchmark, 'Below')
    g(end+1,:) = {'15-item physics/maths load', 'Below 60 CU benchmark', ...
        ternary(cfg.benchmarkCU - m.physCU > 15, 'High', 'Medium'), ...
        sprintf('%.1f CU mapped; %.1f CU short of two years (60 CU).', m.physCU, cfg.benchmarkCU - m.physCU), ...
        'Benchmark of Section 2.1: two years of physics/mathematics at 30 CU per year.'};
end
if ~isMaster && hasCU && m.CorePM < 50
    g(end+1,:) = {'Compulsory physics/maths share', sprintf('CorePM %.1f%%', m.CorePM), 'Medium', ...
        sprintf('AchPM %.1f%% if physics/maths electives are chosen.', m.AchPM), ...
        'Less than half of the credit requirement is guaranteed physics/mathematics.'};
end
unm = C(cellfun(@isempty, {C.idx}) & ~[C.nonTCS] & ~[C.isPhys]);
for k = 1:numel(unm)
    g(end+1,:) = {unm(k).name, 'Course not mapped', 'Info', 'No TCS-56 item identified.', ...
        'Review manually: the course may cover an item under a different name, or be outside TCS-56.'}; %#ok<AGROW>
end

% ---------------------------------------------------------- comparison
cmp = repmat({''}, nI, 1); agree = repmat({''}, nI, 1);
if ~isempty(opt.CompareWith)
    p = R.programmes(strcmp({R.programmes.sec}, opt.CompareWith));
    if isempty(p), error('tcs56_assess:compare', 'Section %s not found in Appendix A.', opt.CompareWith); end
    for j = 1:nI
        cmp{j} = p.cov{j};
        a = ~any(strcmp(cov{j}, {'Not covered','Not assessed'}));
        b = ~any(strcmp(cmp{j}, {'Not covered','Not assessed'}));
        if a == b, agree{j} = ternary(strcmp(cov{j}, cmp{j}), 'Same', 'Both covered, different level');
        elseif a,  agree{j} = 'Covered here only (new course or wider mapping)';
        else,      agree{j} = 'Covered in Appendix A only (check list or synopsis)';
        end
    end
end

% ------------------------------------------------------------- caveats
cv = {};
cv{end+1} = ['This is an automated, indicative mapping against IAEA TCS-56 (Rev. 1). It is not an ' ...
    'accreditation, MQA or MAHPC registration decision.'];
cv{end+1} = ['Mappings use keywords and the course classifications of Appendix A (19 programmes, ' ...
    'curricula current in 2026). A course is matched on what its title and synopsis say, not on how it is taught or assessed.'];
if ~hasContent
    cv{end+1} = ['No course content was supplied, so every mapping rests on titles alone. Generic titles ' ...
        '(e.g. "Mathematical Methods", "Physics II") can hide or overstate coverage; supply synopses for a firmer result.'];
end
if ~hasCU
    cv{end+1} = ['No credits were supplied (student mode): CorePM%, AchPM% and the 60 CU benchmark are not ' ...
        'computed. Item coverage only shows whether a topic appears, not how much of it is taught.'];
end
if hasCU && ~hasType
    cv{end+1} = 'Course type was not supplied, so every course is treated as compulsory: CorePM% may be overstated and elective-only gaps cannot be detected.';
end
if hasCU && isnan(opt.CreditRequirement)
    cv{end+1} = sprintf(['No credit requirement was given; the listed total (%g CU) is used as C. If the list ' ...
        'includes elective options beyond what a student takes, CorePM%% and AchPM%% are understated.'], m.ListTotal);
end
if opt.CreditFactor ~= 1
    cv{end+1} = sprintf('Credits were converted to Malaysian CU with factor %g (notional-hours basis, Section 2.1).', opt.CreditFactor);
end
if ~isMaster
    cv{end+1} = ['Professional/clinical items are reported as undergraduate exposure only. TCS-56 expects them ' ...
        'in a postgraduate programme, so their absence is not a bachelor''s-level gap.'];
end
cv{end+1} = ['Coverage levels (Dedicated, Split, Part of broader) follow Appendix A where an identical course ' ...
    'title exists there; otherwise they are inferred from the number of courses and items involved.'];
cv{end+1} = 'Numerical Methods and Computational Physics/Programming are one merged item, as in the manuscript.';
nLow = sum(strcmp([C.conf], 'Low'));
if nLow > 0
    cv{end+1} = sprintf('%d course-to-item mapping(s) are Low confidence (title only or a similar, not identical, Appendix A title); check them first.', nLow);
end

% ------------------------------------------------------------- tables
A = struct();
A.programme = opt.Programme; A.level = opt.Level; A.mode = mode;
A.courses = mkT({'Course','CU','Type','Core','Elective','TCS56_Items','Route','Confidence', ...
    'AppendixA_Match','Remark'}, courseRows(C, short));
A.items = mkT({'Item','Scope','Coverage','Confidence','ElectiveOnly','CU_mapped','Courses', ...
    'AppendixA_Coverage','Agreement','Remark'}, ...
    [items, [repmat({'Physics/mathematics'}, nP, 1); repmat({ternary(isMaster,'Professional/clinical','Professional/clinical (UG exposure)')}, nI-nP, 1)], ...
     cov, conf, num2cell(eo), num2cell(cuItem), names, cmp, agree, rmk]);
A.metrics = m;
A.gaps = mkT({'Item','Gap','Severity','Finding','Remark'}, g);
A.caveats = cv(:);
A.raw = C;

% -------------------------------------------------------------- output
if opt.Report,  A.reportFile = writeReport(A, opt, cfg, nP); end
if opt.Excel
    xl = fullfile(opt.OutDir, 'TCS56_assessment.xlsx');
    if exist(xl, 'file'), delete(xl); end
    writetable(A.items,   xl, 'Sheet', 'Items');
    writetable(A.courses, xl, 'Sheet', 'Courses');
    writetable(A.gaps,    xl, 'Sheet', 'Gaps');
    writetable(mkT({'Caveat'}, cv(:)), xl, 'Sheet', 'Caveats');
    A.excelFile = xl;
end
if opt.Figure, A.figureFile = drawFigure(A, cfg, short, opt, isMaster, nP); end
if opt.Verbose, printConsole(A, nP, isMaster); end
end

% =========================================================================
function KB = buildKB(M, cfg)
% Appendix A knowledge base: one entry per distinct normalised title.
keys = cellfun(@(t) normTitle(t, cfg), M.Course, 'UniformOutput', false);
[uk, ~, ix] = unique(keys);
KB = struct('key', uk, 'tok', [], 'items', [], 'covs', [], 'secs', [], 'titles', [], 'allNone', false, 'general', false);
allItems = [cfg.physItems(:,1); cfg.profItems(:,1)];
for k = 1:numel(uk)
    r = find(ix == k);
    KB(k).tok = strsplit(uk{k}, ' ');
    it = []; cv = {}; who = {};
    for q = r(:)'
        j = find(strcmp(allItems, M.Item{q}));
        if isempty(j)   % combined items such as 'Optics / Quantum Mechanics'
            j = find(cellfun(@(s) ~isempty(strfind(M.Item{q}, s)), allItems))';
        end
        for jj = j(:)'
            w = find(it == jj, 1);
            if isempty(w)
                it(end+1) = jj; cv{end+1} = M.Coverage{q}; who{end+1} = M.Programme(q); %#ok<AGROW>
            else
                who{w} = unique([who{w}; M.Programme(q)]);
            end
        end
    end
    nProg = numel(unique(M.Programme(r)));
    share = cellfun(@numel, who) / nProg;
    keep = share >= cfg.kbMinShare | nProg == 1;
    it = it(keep); cv = cv(keep);
    KB(k).items = it; KB(k).covs = cv;
    KB(k).secs = unique(M.Programme(r))';
    KB(k).allNone = all(strcmp(M.Item(r), '(none)'));
    KB(k).general = any(~cellfun(@isempty, strfind(M.Item(r), cfg.generalPhysItem)));
    KB(k).titles = unique(M.Course(r))';
end
end

function c = mapCourse(c, cfg, KB, items, nP)
allKeys = cfg.contentKeywords;
nI = numel(items);
% 1. content
hitsC = zeros(1, nI);
if ~isempty(c.content)
    for j = 1:nI, hitsC(j) = countHits(c.content, allKeys{j}); end
end
viaContent = find(hitsC >= cfg.contentMinHits);
weakContent = find(hitsC > 0 & hitsC < cfg.contentMinHits);
% 2. Appendix A
key = normTitle(c.name, cfg); tok = strsplit(key, ' ');
c.kbMatch = ''; c.kbItems = []; c.kbCov = {}; c.kbText = ''; kbNone = false; kbGen = false;
k = find(strcmp({KB.key}, key), 1);
if ~isempty(k) && ~isempty(key)
    c.kbMatch = 'exact';
else
    best = 0; k = [];
    for q = 1:numel(KB)
        sh = numel(intersect(tok, KB(q).tok));
        jac = sh / numel(union(tok, KB(q).tok));
        if sh >= 2 && jac >= 0.5 && jac > best, best = jac; k = q; end
    end
    if ~isempty(k), c.kbMatch = 'similar'; end
end
if ~isempty(k)
    c.kbItems = KB(k).items; c.kbCov = KB(k).covs; kbNone = KB(k).allNone; kbGen = KB(k).general;
    secs = KB(k).secs; if numel(secs) > 4, secs = [secs(1:4) {'...'}]; end
    ti = KB(k).titles; same = find(strcmpi(regexprep(ti, '\*', ''), c.name), 1);
    if isempty(same), same = 1; end
    lab = ternary(strcmp(c.kbMatch, 'exact'), 'same course title', 'similar title');
    c.kbText = sprintf('%s: "%s" (%s)', lab, regexprep(ti{same}, '\*', ''), strjoin(secs, ', '));
end
% 3. title keywords
viaTitle = [];
titleKeys = [cfg.physItems(:,3); cfg.profItems(:,3)];
for j = 1:nI
    if countHits(c.name, titleKeys{j}) > 0 || countHits(c.name, allKeys{j}) > 0
        blocked = false;
        for e = 1:numel(cfg.titleExclusions)
            if cfg.titleExclusions(e).item == j && countHits(c.name, cfg.titleExclusions(e).words) > 0
                blocked = true;
            end
        end
        if ~blocked, viaTitle(end+1) = j; end %#ok<AGROW>
    end
end
% combine
viaKB = c.kbItems;
idx = unique([viaContent viaTitle viaKB]);
if ~isempty(c.content)
    % with a synopsis, title/appendix items need at least some content support
    kbExact = viaKB(:)'; if ~strcmp(c.kbMatch, 'exact'), kbExact = []; end
    keep = ismember(idx, [viaContent weakContent]) | ismember(idx, kbExact);
    dropped = idx(~keep); idx = idx(keep);
else
    dropped = [];
end
c.idx = idx; c.conf = cell(1, numel(idx)); c.route = cell(1, numel(idx));
for q = 1:numel(idx)
    j = idx(q);
    inC = any(viaContent == j); inK = any(viaKB == j); inT = any(viaTitle == j);
    r = {};
    if inC, r{end+1} = 'content'; end %#ok<AGROW>
    if inK, r{end+1} = ternary(strcmp(c.kbMatch,'exact'), 'Appendix A (same title)', 'Appendix A (similar title)'); end %#ok<AGROW>
    if inT, r{end+1} = 'title'; end %#ok<AGROW>
    c.route{q} = strjoin(r, '+');
    if inC && (inK || inT),               c.conf{q} = 'High';
    elseif inC || (inK && strcmp(c.kbMatch, 'exact')), c.conf{q} = 'Medium';
    else,                                 c.conf{q} = 'Low';
    end
end
% physics/maths classification (incl. general physics/maths courses)
genPM = countHits(c.name, {'physics','mathemat','statistic','calculus','astrophysic','astronom'}) > 0 || kbGen;
c.isPhys = any(idx <= nP) || (isempty(idx) && genPM);
c.nonTCS = isempty(idx) && kbNone && ~genPM;   % known non-TCS course in Appendix A
% remark
r = {};
if isempty(c.content), r{end+1} = 'Title only (no synopsis).'; end
if isempty(idx)
    if c.nonTCS, r{end+1} = 'Classified as outside TCS-56 in Appendix A.';
    elseif genPM, r{end+1} = 'General physics/mathematics course (as in Appendix A): counted as physics/maths credit but mapped to no specific item.';
    else, r{end+1} = 'No TCS-56 item identified; review manually.'; end
end
if strcmp(c.kbMatch, 'similar'), r{end+1} = 'Appendix A match is a similar title, not identical.'; end
if ~isempty(dropped)
    r{end+1} = sprintf('Title suggested %s, but the synopsis does not support it.', ...
        strjoin(cellfun(@(s) ['"' s '"'], items(dropped)', 'UniformOutput', false), ', '));
end
if ~isempty(weakContent)
    w = setdiff(weakContent, idx);
    if ~isempty(w)
        r{end+1} = sprintf('Synopsis briefly mentions %s (one keyword; not counted).', ...
            strjoin(items(w)', ', '));
    end
end
if numel(idx) >= 4, r{end+1} = 'Broad course mapped to many items; depth per item is limited.'; end
c.remark = strjoin(r, ' ');
end

function n = countHits(text, keys)
t = [' ' regexprep(lower(text), '[^a-z0-9+\-]', ' ') ' '];
t = regexprep(t, '\s+', ' ');
n = 0;
for k = 1:numel(keys)
    if ~isempty(strfind(t, [' ' keys{k}])), n = n + 1; end
end
end

function k = normTitle(t, cfg)
t = lower(regexprep(t, '[\*]', ''));
t = regexprep(t, '[^a-z0-9 ]', ' ');
w = strsplit(strtrim(regexprep(t, '\s+', ' ')), ' ');
w = w(~ismember(w, cfg.titleStopWords) & ~cellfun(@isempty, w));
k = strjoin(sort(w), ' ');
end

function C = readInput(in)
C = struct('name', {}, 'cu', {}, 'type', {}, 'content', {});
if ischar(in) && exist(in, 'file')
    [~, ~, ext] = fileparts(in);
    if strcmpi(ext, '.txt')
        L = regexp(fileread(in), '\r?\n', 'split');
        in = strtrim(L(~cellfun(@isempty, strtrim(L))));
    else
        in = readtable(in, 'TextType', 'char');
    end
end
if iscell(in)
    for k = 1:numel(in), C(end+1) = struct('name', strtrim(in{k}), 'cu', NaN, 'type', '', 'content', ''); end %#ok<AGROW>
    return
end
if isstruct(in) && isfield(in, 'name')       % struct array input
    for k = 1:numel(in)
        s = struct('name', in(k).name, 'cu', NaN, 'type', '', 'content', '');
        if isfield(in, 'cu') && ~isempty(in(k).cu), s.cu = in(k).cu; end
        if isfield(in, 'type'), s.type = normType(in(k).type); end
        if isfield(in, 'content'), s.content = in(k).content; end
        C(end+1) = s; %#ok<AGROW>
    end
    return
end
% table
v = in.Properties.VariableNames; lv = lower(v);
col = @(names) v(find(ismember(lv, names), 1));
cn = col({'course','name','title','topic','coursename','course_name'});
if isempty(cn), error('tcs56_assess:input', 'No course/topic name column found.'); end
cc = col({'cu','credit','credits','creditunit','credit_units'});
ct = col({'type','status','core','coretype','category'});
cs = col({'content','synopsis','description','outline','syllabus'});
for k = 1:height(in)
    s = struct('name', strtrim(toStr(in.(cn{1})(k))), 'cu', NaN, 'type', '', 'content', '');
    if ~isempty(cc), x = in.(cc{1})(k); if iscell(x), x = str2double(x{1}); end, s.cu = double(x); end
    if ~isempty(ct), s.type = normType(in.(ct{1})(k)); end
    if ~isempty(cs), s.content = toStr(in.(cs{1})(k)); end
    if ~isempty(s.name), C(end+1) = s; end %#ok<AGROW>
end
end

function t = normType(x)
if iscell(x), x = x{1}; end
if isnumeric(x) || islogical(x)
    if isnan(double(x)), t = ''; elseif x, t = 'Core'; else, t = 'Elective'; end
    return
end
x = lower(strtrim(x));
if isempty(x), t = '';
elseif any(x(1) == 'eo*'), t = 'Elective';   % elective / optional / *
else, t = 'Core';
end
end

function s = toStr(x)
if iscell(x), x = x{1}; end
if isnumeric(x), x = num2str(x); end
if isempty(x), s = ''; else, s = char(x); end
end

function rows = courseRows(C, short)
n = numel(C); rows = cell(n, 10);
for c = 1:n
    it = cell(1, numel(C(c).idx)); rt = it; cf = it;
    for q = 1:numel(C(c).idx)
        it{q} = short{C(c).idx(q)};
        rt{q} = sprintf('%s: %s', short{C(c).idx(q)}, C(c).route{q});
        cf{q} = sprintf('%s: %s', short{C(c).idx(q)}, C(c).conf{q});
    end
    ty = C(c).type; if isempty(ty), ty = 'Not given'; end
    rows(c,:) = {C(c).name, C(c).cu, ty, strcmp(ty, 'Core'), strcmp(ty, 'Elective'), ...
        joinOr(it, '(none)'), joinOr(rt, ''), joinOr(cf, ''), C(c).kbText, C(c).remark};
end
end

function f = writeReport(A, opt, cfg, nP)
f = fullfile(opt.OutDir, 'assessment_report.md');
fid = fopen(f, 'w');
m = A.metrics;
fprintf(fid, '# TCS-56 alignment: %s\n\n', A.programme);
fprintf(fid, 'Level: %s. Input: %s. Generated %s.\n\n', A.level, A.mode, datestr(now, 'yyyy-mm-dd'));
fprintf(fid, '## Summary\n\n| Measure | Value |\n|---|---|\n');
if ~strcmpi(A.level, 'Master')
    fprintf(fid, '| Physics/mathematics items covered | %d of 15 (Ded %d / Split %d / PoB %d / NC %d) |\n', ...
        m.physCovered, m.physDSPN);
end
fprintf(fid, '| Professional/clinical items covered | %d of 12 |\n', m.profCovered);
if ~isnan(m.CorePM)
    fprintf(fid, '| CorePM%% (compulsory physics/maths) | %.1f%% |\n| AchPM%% (with physics/maths electives) | %.1f%% |\n', m.CorePM, m.AchPM);
    fprintf(fid, '| Physics/maths CU mapped to the 15 items | %.1f CU (%.2f years) - %s 60 CU |\n', m.physCU, m.yearsEq, m.benchmark);
else
    fprintf(fid, '| CorePM%%, AchPM%%, 60 CU benchmark | Not computed (no credits supplied) |\n');
end
fprintf(fid, '| Items whose coverage rests on title evidence only | %d |\n\n', m.lowConfidenceItems);
fprintf(fid, '## Item alignment\n\n| Item | Coverage | Confidence | Courses | Remark |\n|---|---|---|---|---|\n');
T = A.items;
for j = 1:numel(T.Item)
    if j == nP+1, fprintf(fid, '| **Professional/clinical** | | | | |\n'); end
    s = T.Coverage{j}; if T.ElectiveOnly(j), s = [s ' (elective only)']; end
    if ~isempty(T.AppendixA_Coverage{j}), s = sprintf('%s; App. A: %s', s, T.AppendixA_Coverage{j}); end
    fprintf(fid, '| %s | %s | %s | %s | %s |\n', T.Item{j}, s, T.Confidence{j}, ...
        strrep(T.Courses{j}, '|', '/'), T.Remark{j});
end
fprintf(fid, '\n## Gaps\n\n');
G = A.gaps;
if isempty(G.Item), fprintf(fid, 'None identified.\n');
else
    fprintf(fid, '| Severity | Item | Gap | Finding |\n|---|---|---|---|\n');
    for s = {'High','Medium','Low','Info'}
        for k = find(strcmp(G.Severity, s{1}))'
            fprintf(fid, '| %s | %s | %s | %s |\n', G.Severity{k}, G.Item{k}, G.Gap{k}, G.Finding{k});
        end
    end
end
fprintf(fid, '\n## Caveats\n\n');
for k = 1:numel(A.caveats), fprintf(fid, '%d. %s\n', k, A.caveats{k}); end
fclose(fid);
end

function f = drawFigure(A, cfg, short, opt, isMaster, nP)
T = A.items; nI = numel(T.Item);
cmap = [cfg.colors.dedicated; cfg.colors.split; cfg.colors.pob; cfg.colors.nc; cfg.colors.na];
lv = zeros(nI,1);
for j = 1:nI
    switch T.Coverage{j}
        case 'Dedicated', lv(j) = 1; case 'Split', lv(j) = 2; case 'Part of broader', lv(j) = 3;
        case 'Not covered', lv(j) = ternary(~isMaster && j > nP, 5, 4);
        otherwise, lv(j) = 5;
    end
end
fh = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 900 760]);
ax = axes('Parent', fh, 'Position', [0.33 0.07 0.62 0.85]); hold(ax, 'on');
for j = 1:nI
    y = nI - j + 1;
    rectangle('Parent', ax, 'Position', [0 y-0.38 1 0.76], 'FaceColor', cmap(lv(j),:), 'EdgeColor', 'none');
    lab = T.Coverage{j};
    if lv(j) == 5 && strcmp(lab, 'Not covered'), lab = 'No UG exposure (not required at bachelor''s level)'; end
    if lv(j) == 4, lab = 'NOT COVERED (gap)'; end
    if T.ElectiveOnly(j), lab = [lab ', elective only']; end
    if ~isempty(T.Confidence{j}), lab = [lab ' - ' T.Confidence{j} ' confidence']; end
    text(ax, 1.05, y, lab, 'FontSize', 8, 'Interpreter', 'none', 'Color', [0.2 0.2 0.2]);
end
plot(ax, [0 3], (nI-nP+0.5)*[1 1], 'k-');
set(ax, 'YTick', 1:nI, 'YTickLabel', flipud(short), 'TickLabelInterpreter', 'none', ...
    'XTick', [], 'XLim', [0 3], 'YLim', [0.4 nI+0.6], 'FontSize', 8, 'Box', 'off', 'XColor', 'w');
title(ax, sprintf('TCS-56 alignment: %s  (red = gap; grey = not required at this level / not assessed)', ...
    A.programme), 'FontSize', 9, 'FontWeight', 'normal', 'Interpreter', 'none');
f = fullfile(opt.OutDir, 'assessment_coverage.png');
print(fh, f, '-dpng', '-r200'); close(fh);
end

function printConsole(A, nP, isMaster)
m = A.metrics;
fprintf('\nTCS-56 alignment: %s  [%s, %s]\n', A.programme, A.level, A.mode);
if ~isMaster, fprintf('  Physics/maths items covered: %d/15\n', m.physCovered); end
fprintf('  Professional/clinical items covered: %d/12\n', m.profCovered);
if ~isnan(m.CorePM)
    fprintf('  CorePM %.1f%%, AchPM %.1f%%, phys/maths CU %.1f (%s 60 CU)\n', m.CorePM, m.AchPM, m.physCU, m.benchmark);
end
G = A.gaps;
fprintf('  Gaps: %d High, %d Medium, %d Low, %d Info\n', sum(strcmp(G.Severity,'High')), ...
    sum(strcmp(G.Severity,'Medium')), sum(strcmp(G.Severity,'Low')), sum(strcmp(G.Severity,'Info')));
fprintf('  %d caveats apply (see A.caveats / report).\n', numel(A.caveats));
end

function T = mkT(names, rows)
s = struct();
for k = 1:numel(names)
    col = rows(:, k);
    if isempty(col), s.(names{k}) = cell(0,1);
    elseif all(cellfun(@(x) (isnumeric(x) || islogical(x)) && isscalar(x), col))
        if all(cellfun(@islogical, col)), s.(names{k}) = logical(cell2mat(col));
        else, s.(names{k}) = double(cell2mat(col)); end
    else
        s.(names{k}) = cellfun(@(x) toStr(x), col, 'UniformOutput', false);
    end
end
T = struct2table(s);
end

function s = joinOr(c, empty)
c = c(~cellfun(@isempty, c));
if isempty(c), s = empty; else, s = strjoin(c, '; '); end
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end
