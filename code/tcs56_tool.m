function R = tcs56_tool(mdFile, varargin)
%TCS56_TOOL  Course-list extraction, TCS-56 metrics and gap analysis.
%
%   R = tcs56_tool(mdFile) reads Appendix A of the manuscript "Medical
%   Physics Education in Malaysia: A Critical Analysis against the IAEA
%   TCS-56 Curriculum Standard" (pandoc markdown export, v14 layout) and:
%
%     1. extracts every programme's course list into a table (course name,
%        credit units, core / elective, TCS-56 item, coverage level);
%     2. replaces course names that do not clearly name their TCS-56 topic
%        by the TCS-56 item name (substitute name), keeping the coverage
%        level, so every topic can be read at a glance;
%     3. recomputes every metric reported in the manuscript: CorePM% (Eq. 1),
%        AchPM% (Eq. 2), items covered (of 15 and of 12), Dedicated / Split /
%        Part of broader / Not covered counts, the physics/mathematics
%        CU-equivalent, years-equivalent and the 60 CU benchmark (Table 4),
%        with UK and Australian credits converted by notional hours;
%     4. reports each topic's credit units (core, elective) and its
%        percentage equivalent of the programme;
%     5. lists the gaps (items not covered, items reached only by electives,
%        items covered only as part of a broader course, CU shortfall) and
%        summarises each item across the Malaysian bachelor's programmes;
%     6. checks the recomputed values against the values printed in
%        Appendix A and Table 4 of the manuscript;
%     7. draws four figures and writes everything to one Excel workbook.
%
%   R = tcs56_tool(mdFile, 'OutDir', dir, 'Excel', true, 'Figures', true,
%                  'Verbose', true)
%
%   Output R (struct):
%     R.programmes   struct array, one element per programme, with fields
%                    .courses (table), .mapping (table), .topics (table)
%     R.courses      all programmes' course lists stacked (table)
%     R.topics       topic table, all programmes stacked (table)
%     R.metrics      one row per programme: every reported metric (table)
%     R.coverage     programme x 27 item coverage matrix (table)
%     R.gaps         gap list (table)
%     R.itemSummary  item-by-item counts over Malaysian bachelor's (table)
%     R.verification recomputed vs reported values (table)
%     R.unclear      course names replaced by TCS-56 substitute names (table)
%
%   Rules (item names, keywords, tracks, conversions) are in tcs56_config.m.
%
%   Example
%     R = tcs56_tool();   % reads ../data/Appendix_A_Anonymized_v14_submission.md
%     R.programmes(12).topics          % B.5 topic table
%     R.gaps(strcmp(R.gaps.Severity,'High'),:)
%
%   Runs in MATLAB R2019b or later (tables, writetable). Core logic is
%   also Octave-compatible.
% ------------------------------------------------------------------ setup
if nargin < 1 || isempty(mdFile)
    mdFile = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data', ...
                      'Appendix_A_Anonymized_v14_submission.md');
end
opt = struct('OutDir', fullfile(pwd, 'tcs56_output'), 'Excel', true, ...
             'Figures', true, 'Verbose', true);
for k = 1:2:numel(varargin)
    opt.(varargin{k}) = varargin{k+1};
end
if ~exist(opt.OutDir, 'dir'), mkdir(opt.OutDir); end
cfg = tcs56_config();
cfg.allItems  = [cfg.physItems(:,1); cfg.profItems(:,1)];
cfg.allShort  = [cfg.physItems(:,2); cfg.profItems(:,2)];
cfg.allKeys   = [cfg.physItems(:,3); cfg.profItems(:,3)];
cfg.nPhys = size(cfg.physItems,1);
cfg.nProf = size(cfg.profItems,1);
[cfg.dagger, cfg.ddagger] = markChars(cfg);

% ---------------------------------------------------------------- parsing
[P, overview] = parseAppendix(mdFile, cfg);
if opt.Verbose
    fprintf('Parsed %d programmes from %s\n', numel(P), mdFile);
end

% --------------------------------------------------------- per programme
for i = 1:numel(P)
    P(i) = analyseProgramme(P(i), cfg, overview);
end

% ------------------------------------------------------ combined tables
R = struct();
R.programmes   = P;
R.courses      = stackTables(P, 'courses');
R.mapping      = stackTables(P, 'mapping');
R.topics       = stackTables(P, 'topics');
R.metrics      = metricsTable(P);
R.coverage     = coverageTable(P, cfg);
[R.gaps, R.itemSummary] = gapAnalysis(P, cfg);
R.verification = verificationTable(P, cfg);
R.unclear      = subRows(R.mapping, ~R.mapping.NameClear & ~strcmp(R.mapping.Item, '(none)'));
R.options      = opt;

% ----------------------------------------------------------------- output
if opt.Figures
    R.figures = drawFigures(P, cfg, opt.OutDir);
end
if opt.Excel
    xl = fullfile(opt.OutDir, 'TCS56_analysis.xlsx');
    if exist(xl, 'file'), delete(xl); end
    sheets = {'Metrics','metrics'; 'CourseList','courses'; 'TopicTable','topics'; ...
              'CourseToItem','mapping'; 'Coverage','coverage'; 'Gaps','gaps'; ...
              'ItemSummary_MY_BSc','itemSummary'; 'SubstituteNames','unclear'; ...
              'Verification','verification'};
    for s = 1:size(sheets,1)
        writetable(R.(sheets{s,2}), xl, 'Sheet', sheets{s,1});
    end
    R.excelFile = xl;
    if opt.Verbose, fprintf('Workbook written: %s\n', xl); end
end
if opt.Verbose, printSummary(R, cfg); end
end

% =========================================================================
%                                PARSING
% =========================================================================
function [P, overview] = parseAppendix(mdFile, cfg)
txt   = fileread(mdFile);
lines = regexp(txt, '\r?\n', 'split');
P = emptyProgramme();
P(1) = [];
overview = struct('sec', {}, 'listTotal', {}, 'req', {}, 'ach', {}, 'phys', {}, 'prof', {});
cur = 0; grp = '';
for n = 1:numel(lines)
    s = strtrim(lines{n});
    if isempty(s) || ~isempty(regexp(s, '^[-\s]+$', 'once')), continue; end
    s = strrep(strrep(strrep(s, '\*', '*'), '\[', '['), '\]', ']');

    % programme header  ***A.1 University A: Bachelor degree in Physics***
    tok = regexp(s, '^\*\*\*([A-D]\.\d+)\s+(.*?)\*\*\*$', 'tokens', 'once');
    if ~isempty(tok)
        cur = cur + 1;
        P(cur) = emptyProgramme();
        P(cur).sec  = tok{1};
        P(cur).name = strtrim(tok{2});
        parts = regexp(P(cur).name, ':\s*', 'split', 'once');
        P(cur).institution = parts{1};
        P(cur).degree      = parts{end};
        grp = '';
        continue
    end
    % group headers
    if ~isempty(regexp(s, '^\*\*\*TCS56 Mathematics', 'once')), grp = 'MP'; continue; end
    if ~isempty(regexp(s, '^\*\*\*TCS56 Professional', 'once')), grp = 'PC'; continue; end
    if ~isempty(regexp(s, '^\*\*\*Other courses', 'once')),       grp = 'OT'; continue; end
    if ~isempty(regexp(s, '^\*\*\*Credit-unit summary', 'once')), grp = 'SUM'; continue; end
    % notes
    if cur > 0 && ~isempty(regexp(s, '^\*Note:', 'once'))
        P(cur).notes = strtrim(regexprep(s, '^\*Note:\s*|\*$', ''));
        continue
    end
    tk = regexp(s, '\s{2,}', 'split');
    % summary-of-all table (before the first programme)
    if cur == 0
        if numel(tk) >= 7 && ~isempty(regexp(tk{1}, '^[A-D]\.\d+$', 'once'))
            o.sec = tk{1}; o.listTotal = num(tk{end-4}); o.req = num(tk{end-3});
            o.ach = num(tk{end-2}); o.phys = fracNum(tk{end-1}); o.prof = fracNum(tk{end});
            overview(end+1) = o; %#ok<AGROW>
        end
        continue
    end
    % course rows
    if numel(tk) >= 5 && (~isempty(regexp(tk{1}, '^\d+$', 'once')) || strcmp(tk{1}, '---'))
        r.group    = grp;
        r.item     = tk{end-1};
        r.coverage = tk{end};
        if strcmp(tk{1}, '---')
            r.no = NaN; r.rawTitle = ''; r.cu = NaN;
        else
            r.no = str2double(tk{1});
            r.rawTitle = strjoin(tk(2:end-3), ' ');
            r.cu = num(tk{end-2});
        end
        P(cur).rows(end+1) = r;
        continue
    end
    % credit-unit summary rows (label  value)
    if numel(tk) == 2
        lab = lower(regexprep(tk{1}, '\*', ''));
        val = num(tk{2});
        f = summaryField(lab);
        if ~isempty(f), P(cur).reported.(f) = val; end
    end
end
end

function f = summaryField(lab)
f = '';
if     ~isempty(strfind(lab, 'corepm%')),                    f = 'CorePM';
elseif ~isempty(strfind(lab, 'achpm%')),                     f = 'AchPM';
elseif ~isempty(strfind(lab, 'total credit units required')),f = 'C';
elseif ~isempty(strfind(lab, 'compulsory credit units that are physics')), f = 'P';
elseif ~isempty(strfind(lab, 'credit units that are compulsory')), f = 'K';
elseif ~isempty(strfind(lab, 'elective credit units available')),  f = 'Budget';
elseif ~isempty(strfind(lab, 'single best elective track')),       f = 'Etrack';
elseif ~isempty(strfind(lab, 'general (non-track) elective pool')),f = 'Egen';
elseif ~isempty(strfind(lab, 'most of the elective credit')),      f = 'Ecap';
elseif ~isempty(strfind(lab, 'course list total')),                f = 'ListTotal';
end
end

function p = emptyProgramme()
rep = struct('C',NaN,'K',NaN,'P',NaN,'Budget',NaN,'Etrack',NaN,'Egen',NaN, ...
             'Ecap',NaN,'CorePM',NaN,'AchPM',NaN,'ListTotal',NaN);
rows = struct('group',{},'item',{},'coverage',{},'no',{},'rawTitle',{},'cu',{});
p = struct('sec','','name','','institution','','degree','','notes','', ...
           'rows',rows,'reported',rep,'courses',[],'mapping',[],'topics',[], ...
           'm',[],'cov',[],'elecOnly',[],'label','','category','','level','', ...
           'cuFactor',[1 1],'creditName','CU','reportedPhys',NaN,'reportedProf',NaN);
end

% =========================================================================
%                          PER-PROGRAMME ANALYSIS
% =========================================================================
function p = analyseProgramme(p, cfg, overview)
p.level    = ternary(p.sec(1) == 'D', 'Master', 'Bachelor');
p.category = lookupField(cfg.category, 'sec', p.sec, 'cat', 'Other');
p.label    = shortLabel(p);
k = find(strcmp({overview.sec}, p.sec), 1);
if ~isempty(k)
    p.reportedPhys = overview(k).phys; p.reportedProf = overview(k).prof;
    if isnan(p.reported.ListTotal), p.reported.ListTotal = overview(k).listTotal; end
end
for c = 1:numel(cfg.creditSystem)
    cs = cfg.creditSystem(c);
    if strncmp(p.institution, cs.prefix, numel(cs.prefix))
        p.cuFactor   = [cs.hoursLow cs.hoursHigh] / cfg.hoursPerCU;
        p.creditName = cs.name;
    end
end

% ---- clean every row: title, course type, item indices, name clarity
rows = p.rows;
nR = numel(rows);
for r = 1:nR
    [t, typ] = cleanTitle(rows(r).rawTitle, cfg);
    rows(r).title = t;
    rows(r).type  = typ;
    [rows(r).idx, rows(r).isGen] = itemIndex(rows(r).item, cfg);
end

% ---- distinct courses (a course listed on several rows counts once)
real = ~cellfun(@isempty, {rows.title});
titles = {rows(real).title};
[ut, ~, ~] = unique(titles, 'stable');
nC = numel(ut);
C = struct('title', ut, 'cu', 0, 'type', '', 'items', {cell(1,0)}, 'idx', [], ...
           'isGen', false, 'covs', {cell(1,0)}, 'groups', {cell(1,0)});
for r = find(real)
    c = find(strcmp(ut, rows(r).title), 1);
    C(c).cu   = rows(r).cu;
    C(c).type = rows(r).type;
    if ~strcmp(rows(r).item, '---')
        C(c).items{end+1}  = rows(r).item;
        C(c).covs{end+1}   = rows(r).coverage;
        C(c).idx   = unique([C(c).idx(:)' rows(r).idx(:)']);
        C(c).isGen = C(c).isGen || rows(r).isGen;
    end
    C(c).groups{end+1} = rows(r).group;
end
cu    = [C.cu]; cu(isnan(cu)) = 0;
elec  = strcmp({C.type}, 'Elective');
isPhys = false(1,nC); isProf = false(1,nC);
for c = 1:nC
    isPhys(c) = C(c).isGen || any(C(c).idx <= cfg.nPhys);
    isProf(c) = any(C(c).idx > cfg.nPhys);
end
inMP = cellfun(@(g) any(strcmp(g, 'MP')), {C.groups});

% ---- tracks
trk = [];
for t = 1:numel(cfg.tracks)
    if strcmp(cfg.tracks(t).sec, p.sec), trk = cfg.tracks(t); end
end
inTrack = false(1,nC); trackE = [];
if ~isempty(trk)
    trackE = zeros(1, numel(trk.courses));
    for t = 1:numel(trk.courses)
        m = ismember(ut, trk.courses{t});
        inTrack = inTrack | m;
        trackE(t) = sum(cu(m & elec & isPhys));
    end
end

% ---- credit metrics (Eq. 1 and Eq. 2)
m = struct();
m.ListTotal = sum(cu);
m.C = p.reported.C; if isnan(m.C), m.C = m.ListTotal; end
m.K = sum(cu(~elec));
m.P = sum(cu(~elec & isPhys));
m.Egen = sum(cu(elec & isPhys & ~inTrack));
m.Etrack = NaN; m.bestTrack = '';
if ~isempty(trackE)
    [m.Etrack, b] = max(trackE);
    m.bestTrack = trk.names{b};
end
m.E = m.Egen + max([0 m.Etrack(~isnan(m.Etrack))]);
m.basis = 'Recomputed from course list';
if any(strcmp(cfg.useReportedCredit, p.sec))
    m.K = p.reported.K; m.P = p.reported.P;
    m.E = p.reported.Egen; m.Egen = p.reported.Egen;
    m.basis = 'Reported (elective pool not marked)';
end
% the elective budget comes from the official requirement C and the
% official compulsory load K where the appendix reports it
Kofficial = p.reported.K; if isnan(Kofficial), Kofficial = m.K; end
m.Budget = m.C - Kofficial;
m.Ecap   = min(m.Budget, m.E);
if strcmp(p.level, 'Master')
    m.CorePM = 0; m.AchPM = 0;            % no undergraduate phys/maths content
else
    m.CorePM = 100 * m.P / m.C;
    m.AchPM  = 100 * (m.P + m.Ecap) / m.C;
end
m.achBound = lookupField(cfg.achBound, 'sec', p.sec, 'bound', 'exact');
m.Kofficial = Kofficial;

% ---- item-level coverage (27 items), from the TCS-56 group rows
nI = cfg.nPhys + cfg.nProf;
cov = repmat({'Not covered'}, 1, nI);
seen = false(1, nI); elecOnly = false(1, nI); hasCore = false(1, nI);
for r = 1:nR
    if ~any(strcmp(rows(r).group, {'MP','PC'})), continue; end
    for ii = rows(r).idx
        seen(ii) = true;
        if ~strcmp(rows(r).coverage, '---')
            cov{ii} = rows(r).coverage;
            if strcmp(rows(r).type, 'Elective'), elecOnly(ii) = true;
            else, hasCore(ii) = true; end
        end
    end
end
elecOnly = elecOnly & ~hasCore;
if strcmp(p.level, 'Master')
    cov(1:cfg.nPhys) = {'Not assessed'};
end
p.cov = cov; p.elecOnly = elecOnly;
ph = cov(1:cfg.nPhys); pr = cov(cfg.nPhys+1:end);
m.physDSPN = [sum(strcmp(ph,'Dedicated')) sum(strcmp(ph,'Split')) ...
              sum(strcmp(ph,'Part of broader')) sum(strcmp(ph,'Not covered'))];
m.profDSPN = [sum(strcmp(pr,'Dedicated')) sum(strcmp(pr,'Split')) ...
              sum(strcmp(pr,'Part of broader')) sum(strcmp(pr,'Not covered'))];
m.physCovered = ternary(strcmp(p.level,'Master'), NaN, cfg.nPhys - m.physDSPN(4));
m.profCovered = cfg.nProf - m.profDSPN(4);
m.physElecOnly = sum(elecOnly(1:cfg.nPhys));

% ---- 15-item CU benchmark (distinct courses in the Mathematics & Physics group)
m.physCU = sum(cu(inMP));
m.physCUeq = m.physCU * p.cuFactor;          % [low high] in Malaysian CU
m.yearsEq  = m.physCUeq / cfg.cuPerYear;
if strcmp(p.level, 'Master')
    m.benchmark = 'n/a';
elseif m.physCUeq(1) >= cfg.benchmarkCU
    m.benchmark = 'Meets';
elseif m.physCUeq(2) >= cfg.benchmarkCU
    m.benchmark = 'Borderline (range spans 60)';
else
    m.benchmark = 'Below';
end
m.shortfallCU = max(0, cfg.benchmarkCU - m.physCUeq(1));
p.m = m;

% ---- course list table -------------------------------------------------
nameClear = true(1,nC); subst = cell(1,nC); itemsTxt = cell(1,nC); covTxt = cell(1,nC);
for c = 1:nC
    itemsTxt{c} = joinOr(C(c).items, '(none)');
    covTxt{c}   = joinOr(unique(C(c).covs, 'stable'), '---');
    [nameClear(c), subst{c}] = clarity(C(c), cfg);
end
catg = repmat({'Non-TCS-56'}, 1, nC);
catg(isProf) = {'Professional/clinical'};
catg(isPhys) = {'Physics/mathematics'};
p.courses = mkTable( ...
  {'Programme','Course','CU','Core','Elective','CourseType','Category', ...
   'TCS56_Items','Coverage','NameClear','DisplayName','InTrack'}, ...
  [repmat({p.sec},nC,1), ut(:), num2cell(cu(:)), num2cell(~elec(:)), num2cell(elec(:)), ...
   {C.type}', catg(:), itemsTxt(:), covTxt(:), num2cell(nameClear(:)), subst(:), num2cell(inTrack(:))]);

% ---- course-to-item mapping table (one row per appendix row) -----------
mp = cell(0, 10);
for r = find(real)
    c = find(strcmp(ut, rows(r).title), 1);
    [clr, disp1] = clarityRow(rows(r), cfg);
    mp(end+1,:) = {p.sec, rows(r).no, rows(r).title, cu(c), rows(r).type, ...
        groupName(rows(r).group), itemOrNone(rows(r).item), coverageOrNone(rows(r).coverage), clr, disp1}; %#ok<AGROW>
end
p.mapping = mkTable({'Programme','No','Course','CU','CourseType','Group','Item', ...
                     'Coverage','NameClear','DisplayName'}, mp);

% ---- topic table: 27 items + general physics + non-TCS -----------------
nT = nI + 3;
tName = [cfg.allItems; {cfg.generalPhysItem; 'Non-TCS-56: university courses'; 'Non-TCS-56: other courses'}];
tGroup = [repmat({'Physics/mathematics'}, cfg.nPhys, 1); repmat({'Professional/clinical'}, cfg.nProf, 1); ...
          {'Physics/mathematics (reinforcing)'; 'Non-TCS-56'; 'Non-TCS-56'}];
coreCU = zeros(nT,1); elecCU = zeros(nT,1); coreApp = zeros(nT,1); elecApp = zeros(nT,1);
names = repmat({''}, nT, 1);
for c = 1:nC
    tgt = C(c).idx(:)';
    if C(c).isGen, tgt = [tgt nI+1]; end %#ok<AGROW>
    if isempty(tgt)
        tgt = ternary(strcmp(C(c).type,'University'), nI+2, nI+3);
    end
    share = cu(c) / numel(tgt);
    for t = tgt
        if elec(c), elecCU(t) = elecCU(t) + cu(c); elecApp(t) = elecApp(t) + share;
        else,       coreCU(t) = coreCU(t) + cu(c); coreApp(t) = coreApp(t) + share; end
        if t <= nI, keys = cfg.allKeys{t}; else, keys = cfg.generalPhysKeywords; end
        clearHere = t > nI+1 || (~isGeneric(C(c).title, cfg) && hasKey(C(c).title, keys));
        lbl = ternary(clearHere, C(c).title, [C(c).title ' [title does not name topic]']);
        if elec(c), lbl = [lbl ' (E)']; end %#ok<AGROW>
        names{t} = joinOr([names(t) {lbl}], '');
    end
end
tCov = [cov(:); repmat({'---'}, 3, 1)];
tEO  = [elecOnly(:); false(3,1)];
p.topics = mkTable({'Programme','Topic','TopicGroup','Coverage','ElectiveOnly', ...
    'CoreCU','ElectiveCU','CoreCU_apportioned','ElectiveCU_apportioned', ...
    'PctOfRequirement_core','PctOfCourseList','Courses'}, ...
    [repmat({p.sec},nT,1), tName, tGroup, tCov, num2cell(tEO), num2cell(coreCU), ...
     num2cell(elecCU), num2cell(rnd(coreApp,2)), num2cell(rnd(elecApp,2)), ...
     num2cell(rnd(100*coreApp/m.C, 1)), num2cell(rnd(100*(coreApp+elecApp)/m.ListTotal, 1)), ...
     regexprep(names, '^; ', '')]);
p.rows = rows;
end

% ------------------------------------------------------------- helpers
function [t, typ] = cleanTitle(raw, cfg)
t = strtrim(raw); typ = 'Core';
if isempty(t), return; end
if endsWith_(t, '*')
    typ = 'Elective'; t = strtrim(t(1:end-1));
elseif endsWith_(t, cfg.dagger)
    typ = 'University'; t = strtrim(t(1:end-numel(cfg.dagger)));
elseif endsWith_(t, cfg.ddagger)
    typ = 'Major'; t = strtrim(t(1:end-numel(cfg.ddagger)));
end
for k = 1:numel(cfg.electiveTitlePatterns)
    if ~isempty(regexpi(t, cfg.electiveTitlePatterns{k}, 'once')), typ = 'Elective'; end
end
end

function [idx, isGen] = itemIndex(item, cfg)
idx = []; isGen = false;
if strcmp(item, '---'), return; end
k = find(strcmp(cfg.allItems, item));
if isempty(k)
    for j = 1:numel(cfg.allItems)
        if ~isempty(strfind(item, cfg.allItems{j})), k(end+1) = j; end %#ok<AGROW>
    end
end
idx = k(:)';
isGen = ~isempty(strfind(item, cfg.generalPhysItem));
end

function [ok, disp1] = clarity(C, cfg)
% A course title is "clear" if it names (by keyword) every TCS-56 item it
% is mapped to and is not a generic placeholder title.
if isempty(C.items)
    ok = true;
    disp1 = ternary(strcmp(C.type,'University'), [C.title ' (non-TCS-56 university course)'], C.title);
    if isGeneric(C.title, cfg), disp1 = 'Non-TCS-56 (bundled/general courses)'; end
    return
end
ok = ~isGeneric(C.title, cfg);
for j = C.idx
    ok = ok && hasKey(C.title, cfg.allKeys{j});
end
if C.isGen && isempty(C.idx)
    ok = ok && hasKey(C.title, cfg.generalPhysKeywords);
end
if ok
    disp1 = C.title;
else
    parts = cell(1, numel(C.items));
    for k = 1:numel(C.items)
        parts{k} = sprintf('%s [%s]', C.items{k}, C.covs{k});
    end
    disp1 = sprintf('%s  (course: %s)', strjoin(unique(parts,'stable'), '; '), C.title);
end
end

function [ok, disp1] = clarityRow(r, cfg)
if strcmp(r.item, '---')
    ok = true; disp1 = r.title; return
end
ok = ~isGeneric(r.title, cfg);
for j = r.idx, ok = ok && hasKey(r.title, cfg.allKeys{j}); end
if r.isGen && isempty(r.idx), ok = ok && hasKey(r.title, cfg.generalPhysKeywords); end
if ok, disp1 = r.title;
else,  disp1 = sprintf('%s [%s]  (course: %s)', r.item, r.coverage, r.title); end
end

function tf = isGeneric(t, cfg)
tf = false;
for k = 1:numel(cfg.genericTitlePatterns)
    if ~isempty(regexpi(t, cfg.genericTitlePatterns{k}, 'once')), tf = true; return; end
end
end

function tf = hasKey(t, keys)
t = lower(t); tf = false;
for k = 1:numel(keys)
    if ~isempty(strfind(t, keys{k})), tf = true; return; end
end
end

% =========================================================================
%                          COMBINED TABLES
% =========================================================================
function T = metricsTable(P)
n = numel(P); rows = cell(n, 27);
for i = 1:n
    m = P(i).m;
    rows(i,:) = {P(i).sec, P(i).institution, P(i).degree, P(i).category, P(i).level, ...
      P(i).creditName, m.C, m.ListTotal, m.Kofficial, m.K, m.P, m.Egen, m.Etrack, m.Budget, m.Ecap, ...
      rnd(m.CorePM,1), rnd(m.AchPM,1), m.achBound, m.physCovered, m.profCovered, ...
      dspn(m.physDSPN, P(i).level), dspn(m.profDSPN, ''), m.physElecOnly, ...
      m.physCU, rangeStr(m.physCUeq), rangeStr(m.yearsEq, 2), m.benchmark};
end
T = mkTable({'Sec','Institution','Degree','Category','Level','CreditUnit', ...
  'CreditRequirement_C','CourseListTotal','Compulsory_K_official','Compulsory_K_list', ...
  'CorePhysMaths_P','PhysMathsElectives_general','PhysMathsElectives_bestTrack', ...
  'ElectiveBudget_CminusK','AchievableElective_min','CorePM_pct','AchPM_pct','AchPM_bound', ...
  'PhysMathsItemsCovered_of15','ProfClinicalItemsCovered_of12','Phys_Ded_Split_PoB_NC', ...
  'Prof_Ded_Split_PoB_NC','PhysItemsElectiveOnly','PhysMathsCU_own','PhysMathsCU_MYequiv', ...
  'YearsEquivalent','Benchmark60CU'}, rows);
end

function T = coverageTable(P, cfg)
n = numel(P); nI = cfg.nPhys + cfg.nProf;
rows = cell(n, nI+1);
for i = 1:n
    rows{i,1} = P(i).sec;
    for j = 1:nI
        s = P(i).cov{j};
        if P(i).elecOnly(j), s = [s ' (elective only)']; end %#ok<AGROW>
        rows{i,j+1} = s;
    end
end
vn = [{'Sec'}; cellfun(@(s) ['I' regexprep(s,'[^A-Za-z]','')], cfg.allShort, 'UniformOutput', false)];
T = mkTable(vn', rows);
end

function [G, S] = gapAnalysis(P, cfg)
g = cell(0, 7);
for i = 1:numel(P)
    p = P(i); m = p.m; bach = strcmp(p.level, 'Bachelor');
    for j = 1:cfg.nPhys
        if ~bach, break; end
        it = cfg.allItems{j};
        switch p.cov{j}
            case 'Not covered'
                g(end+1,:) = {p.sec, p.label, 'Physics/maths prerequisite', it, 'Not covered', 'High', ...
                    'No course in the programme addresses this TCS-56 prerequisite item.'}; %#ok<AGROW>
            case 'Part of broader'
                g(end+1,:) = {p.sec, p.label, 'Physics/maths prerequisite', it, 'Part of broader only', 'Low', ...
                    'Covered only inside a broader course; depth not guaranteed.'}; %#ok<AGROW>
        end
        if p.elecOnly(j)
            g(end+1,:) = {p.sec, p.label, 'Physics/maths prerequisite', it, 'Elective only', 'Medium', ...
                'Reached only through elective courses; a graduate may not have taken it.'}; %#ok<AGROW>
        end
    end
    for j = cfg.nPhys+1:cfg.nPhys+cfg.nProf
        it = cfg.allItems{j};
        if strcmp(p.cov{j}, 'Not covered')
            if bach
                g(end+1,:) = {p.sec, p.label, 'Professional/clinical (UG exposure)', it, 'No UG exposure', 'Info', ...
                    'Expected at master''s level under TCS-56; listed for comparison only.'}; %#ok<AGROW>
            else
                g(end+1,:) = {p.sec, p.label, 'Professional/clinical', it, 'Not covered', 'High', ...
                    'TCS-56 master''s curriculum item without a course.'}; %#ok<AGROW>
            end
        elseif ~bach && p.elecOnly(j)
            g(end+1,:) = {p.sec, p.label, 'Professional/clinical', it, 'Elective only', 'Medium', ...
                'Master''s item reached only through electives.'}; %#ok<AGROW>
        end
    end
    if bach
        if ~strcmp(m.benchmark, 'Meets')
            g(end+1,:) = {p.sec, p.label, 'Credit benchmark', '15-item physics/maths load', m.benchmark, ...
                ternary(m.shortfallCU > 15, 'High', 'Medium'), ...
                sprintf('%s CU-equivalent mapped to the 15 items; %.1f CU short of the 60 CU (2-year) benchmark.', ...
                rangeStr(m.physCUeq), m.shortfallCU)}; %#ok<AGROW>
        end
        if m.CorePM < 50
            g(end+1,:) = {p.sec, p.label, 'Credit share', 'Compulsory physics/maths share', ...
                sprintf('CorePM %.1f%%', m.CorePM), 'Medium', ...
                sprintf('Less than half of the credit requirement is compulsory physics/maths (AchPM %.1f%%, %s).', ...
                m.AchPM, m.achBound)}; %#ok<AGROW>
        end
    end
end
G = mkTable({'Sec','Programme','Area','Item','Gap','Severity','Detail'}, g);

% item summary over the Malaysian bachelor's programmes
my = arrayfun(@(p) strcmp(p.level,'Bachelor') && ~strcmp(p.category,'Comparator'), P);
Q = P(my); nI = cfg.nPhys + cfg.nProf; s = cell(nI, 9);
for j = 1:nI
    cv = arrayfun(@(p) p.cov{j}, Q, 'UniformOutput', false);
    eo = arrayfun(@(p) p.elecOnly(j), Q);
    nc = strcmp(cv, 'Not covered');
    s(j,:) = {cfg.allItems{j}, ternary(j <= cfg.nPhys, 'Physics/mathematics', 'Professional/clinical (UG exposure)'), ...
        sum(strcmp(cv,'Dedicated')), sum(strcmp(cv,'Split')), sum(strcmp(cv,'Part of broader')), ...
        sum(nc), sum(eo), numel(Q), strjoin(arrayfun(@(p) p.sec, Q(nc), 'UniformOutput', false), ', ')};
end
S = mkTable({'Item','Scope','Dedicated','Split','PartOfBroader','NotCovered','ElectiveOnly', ...
             'ProgrammesAssessed','NotCoveredIn'}, s);
end

function T = verificationTable(P, cfg)
v = cell(0, 6);
for i = 1:numel(P)
    p = P(i); m = p.m; r = p.reported; sec = p.sec;
    v = chk(v, sec, 'Course list total', m.ListTotal, r.ListTotal, 0);
    v = chk(v, sec, 'Compulsory CU (K)', m.K, r.K, 0);
    v = chk(v, sec, 'Compulsory phys/maths CU (P)', m.P, r.P, 0);
    v = chk(v, sec, 'Phys/maths electives, general pool', m.Egen, r.Egen, 0);
    v = chk(v, sec, 'Phys/maths electives, best track', m.Etrack, r.Etrack, 0);
    v = chk(v, sec, 'Achievable elective (capped)', m.Ecap, r.Ecap, 0);
    v = chk(v, sec, 'CorePM%', rnd(m.CorePM,1), r.CorePM, 0.05);
    v = chk(v, sec, 'AchPM%', rnd(m.AchPM,1), r.AchPM, 0.05);
    v = chk(v, sec, 'Phys/maths items covered', m.physCovered, p.reportedPhys, 0);
    v = chk(v, sec, 'Prof/clinical items covered', m.profCovered, p.reportedProf, 0);
    k = find(strcmp({cfg.manuscriptTable4.sec}, sec));
    if ~isempty(k)
        t4 = cfg.manuscriptTable4(k);
        v = chk(v, sec, 'Table 4 phys/maths CU-equiv (low)', rnd(m.physCUeq(1),2), t4.cu, 0.6);
        v = chk(v, sec, 'Table 4 Ded/Split/PoB/NC', dspn(m.physDSPN,''), dspn(t4.dspn,''), 0);
    end
end
% explain differences that leave the headline percentages unchanged
for i = 1:numel(P)
    rows = find(strcmp(v(:,1), P(i).sec));
    pm = rows(ismember(v(rows,2), {'CorePM%','AchPM%'}));
    if all(strcmp(v(pm,5), 'Match'))
        bad = rows(strcmp(v(rows,5), 'MISMATCH'));
        for b = bad(:)'
            v{b,6} = ['No effect on CorePM%/AchPM%. ' explainDiff(P(i), v{b,2})];
        end
    end
end
T = mkTable({'Sec','Quantity','Recomputed','Reported','Status','Note'}, v);
end

function s = explainDiff(p, q)
s = '';
if ~isempty(strfind(q, '(K)'))
    s = 'Course-list core differs from the official compulsory load (see programme note: un-itemised slots, n.c. courses or catalogue credit values); the official K is used for the elective budget.';
elseif ~isempty(strfind(q, 'general pool'))
    s = 'Appendix counts a different set of elective courses as physics/maths (check courses mapped to both a physics and a professional item, e.g. radiation physics electives); the elective cap binds, so AchPM% is unchanged.';
end
if ~isempty(p.notes), s = [s ' Note: ' p.notes]; end
end

function v = chk(v, sec, q, a, b, tol)
if ischar(a)
    if isempty(b), return; end
    ok = strcmp(a, b); A = a; B = b;
else
    if isempty(b) || (isnan(b) && isnan(a)), return; end
    if isnan(b), v(end+1,:) = {sec, q, num2str(a), 'not reported', 'Info', ''}; return; end
    ok = abs(a - b) <= tol + 1e-9; A = num2str(a); B = num2str(b);
end
note = '';
if ~ok, note = 'Differs: see the programme note in Appendix A or the rule in tcs56_config.m'; end
v(end+1,:) = {sec, q, A, B, ternary(ok, 'Match', 'MISMATCH'), note};
end

% =========================================================================
%                                FIGURES
% =========================================================================
function F = drawFigures(P, cfg, outDir)
F = struct();
lbl = {P.label};
n = numel(P); nI = cfg.nPhys + cfg.nProf;
% ---- Figure A: coverage matrix ------------------------------------------
M = zeros(n, nI); txt = cell(n, nI);
for i = 1:n
    bach = strcmp(P(i).level, 'Bachelor');
    for j = 1:nI
        switch P(i).cov{j}
            case 'Dedicated',       M(i,j) = 1; txt{i,j} = 'D';
            case 'Split',           M(i,j) = 2; txt{i,j} = 'S';
            case 'Part of broader', M(i,j) = 3; txt{i,j} = 'P';
            case 'Not covered'
                if j > cfg.nPhys && bach, M(i,j) = 5; txt{i,j} = '';   % no UG exposure (not a gap)
                else,                    M(i,j) = 4; txt{i,j} = 'x'; end
            otherwise,              M(i,j) = 5; txt{i,j} = '';
        end
        if P(i).elecOnly(j), txt{i,j} = [txt{i,j} 'e']; end
    end
end
cmap = [cfg.colors.dedicated; cfg.colors.split; cfg.colors.pob; cfg.colors.nc; cfg.colors.na];
f1 = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1500 760]);
ax = axes('Parent', f1, 'Position', [0.17 0.22 0.80 0.68]);
image(ax, ind2rgb(M, cmap)); hold(ax, 'on');
for i = 1:n
    for j = 1:nI
        if isempty(txt{i,j}), continue; end
        tc = ternary(M(i,j) == 3, [0.1 0.1 0.1], [1 1 1]);
        text(ax, j, i, txt{i,j}, 'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', tc);
    end
end
for x = 0.5:1:nI+0.5, plot(ax, [x x], [0.5 n+0.5], 'w-', 'LineWidth', 1); end
for y = 0.5:1:n+0.5,  plot(ax, [0.5 nI+0.5], [y y], 'w-', 'LineWidth', 1); end
plot(ax, (cfg.nPhys+0.5)*[1 1], [0.5 n+0.5], 'k-', 'LineWidth', 1.5);
set(ax, 'XTick', [], 'YTick', 1:n, 'YTickLabel', lbl, 'TickLength', [0 0], 'FontSize', 8, ...
    'TickLabelInterpreter', 'none', 'YLim', [0.5 n+0.5], 'XLim', [0.5 nI+0.5]);
for j = 1:nI
    text(ax, j, n + 0.75, cfg.allShort{j}, 'Rotation', 90, 'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'middle', 'FontSize', 8, 'Interpreter', 'none');
end
text(ax, cfg.nPhys/2 + 0.5, 0.2, 'Undergraduate physics/mathematics prerequisite (15)', ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'Interpreter', 'none');
text(ax, cfg.nPhys + cfg.nProf/2 + 0.5, 0.2, 'Professional/clinical curriculum (12)', ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'Interpreter', 'none');
text(ax, 0.5, -0.5, ['TCS-56 item coverage.  D Dedicated, S Split, P Part of broader, x Not covered (gap), ' ...
    'e = reached only through electives.  Grey: not assessed (master''s, physics items) or ' ...
    'no undergraduate exposure (not required by TCS-56 at bachelor''s level).'], ...
    'FontSize', 9, 'Interpreter', 'none');
F.coverage = fullfile(outDir, 'Fig_A_item_coverage.png');
print(f1, F.coverage, '-dpng', '-r200'); close(f1);

% ---- Figure B: CU benchmark ---------------------------------------------
B = P(strcmp({P.level}, 'Bachelor'));
cuL = arrayfun(@(p) p.m.physCUeq(1), B); cuH = arrayfun(@(p) p.m.physCUeq(2), B);
[~, o] = sort(cuL); B = B(o); cuL = cuL(o); cuH = cuH(o);
f2 = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 900 640]);
ax = axes('Parent', f2, 'Position', [0.30 0.10 0.65 0.82]); hold(ax, 'on');
for i = 1:numel(B)
    meets = cuL(i) >= cfg.benchmarkCU;
    col = ternary(meets, cfg.colors.dedicated, cfg.colors.pob);
    rectangle('Parent', ax, 'Position', [0 i-0.35 cuL(i) 0.7], 'FaceColor', col, 'EdgeColor', 'none');
    if cuH(i) > cuL(i)
        plot(ax, [cuL(i) cuH(i)], [i i], '-', 'Color', cfg.colors.dedicated, 'LineWidth', 2);
    end
    text(ax, cuH(i) + 1, i, rangeStr([cuL(i) cuH(i)]), 'FontSize', 8, 'Color', [0.32 0.32 0.31]);
end
plot(ax, cfg.benchmarkCU*[1 1], [0.4 numel(B)+0.6], '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1);
text(ax, cfg.benchmarkCU + 0.5, numel(B)+0.75, '60 CU (2 years)', 'FontSize', 8);
set(ax, 'YTick', 1:numel(B), 'YTickLabel', {B.label}, 'TickLabelInterpreter', 'none', 'FontSize', 8, 'YLim', [0.4 numel(B)+1], ...
    'XLim', [0 80], 'Box', 'off');
xlabel(ax, 'CU (Malaysian CU-equivalent) of distinct courses mapped to the 15 items');
title(ax, 'Physics/mathematics credit load vs 60 CU benchmark (dark = meets; line = UOW conversion range)', ...
    'FontSize', 9, 'FontWeight', 'normal');
F.benchmark = fullfile(outDir, 'Fig_B_CU_benchmark.png');
print(f2, F.benchmark, '-dpng', '-r200'); close(f2);

% ---- Figure C: CorePM% -> AchPM% (dumbbell) ------------------------------
B = P(strcmp({P.level}, 'Bachelor'));
core = arrayfun(@(p) p.m.CorePM, B); ach = arrayfun(@(p) p.m.AchPM, B);
[~, o] = sort(ach); B = B(o); core = core(o); ach = ach(o);
f3 = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 900 640]);
ax = axes('Parent', f3, 'Position', [0.30 0.10 0.65 0.82]); hold(ax, 'on');
for i = 1:numel(B)
    plot(ax, [core(i) ach(i)], [i i], '-', 'Color', [0.75 0.75 0.73], 'LineWidth', 2);
end
h1 = plot(ax, core, 1:numel(B), 'o', 'MarkerSize', 7, 'MarkerFaceColor', cfg.colors.series(1,:), ...
    'MarkerEdgeColor', 'w');
h2 = plot(ax, ach, 1:numel(B), 's', 'MarkerSize', 7, 'MarkerFaceColor', cfg.colors.series(2,:), ...
    'MarkerEdgeColor', 'w');
for i = 1:numel(B)
    text(ax, ach(i) + 1.5, i, sprintf('%.1f', ach(i)), 'FontSize', 7, 'Color', [0.32 0.32 0.31]);
end
plot(ax, [50 50], [0.4 numel(B)+0.6], ':', 'Color', [0.5 0.5 0.5]);
set(ax, 'YTick', 1:numel(B), 'YTickLabel', {B.label}, 'TickLabelInterpreter', 'none', 'FontSize', 8, 'XLim', [0 105], ...
    'YLim', [0.4 numel(B)+0.6], 'Box', 'off');
xlabel(ax, 'Share of credit requirement that is physics/mathematics (%)');
legend(ax, [h1 h2], {'CorePM% (compulsory)', 'AchPM% (with phys/maths electives)'}, 'Location', 'northwest');
title(ax, 'Compulsory and achievable physics/mathematics share (Eq. 1 and Eq. 2)', 'FontSize', 9, 'FontWeight', 'normal');
F.share = fullfile(outDir, 'Fig_C_CorePM_AchPM.png');
print(f3, F.share, '-dpng', '-r200'); close(f3);

% ---- Figure D: compulsory credit composition -----------------------------
comp = zeros(n, 3);
for i = 1:n
    T = P(i).topics; g = T.TopicGroup; c = T.CoreCU_apportioned;
    comp(i,:) = [sum(c(strncmp(g,'Physics',7))), sum(c(strncmp(g,'Professional',12))), ...
                 sum(c(strncmp(g,'Non',3)))] / P(i).m.C * 100;
    if any(strcmp(cfg.useReportedCredit, P(i).sec)), comp(i,:) = 0; end
end
f4 = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 900 680]);
ax = axes('Parent', f4, 'Position', [0.30 0.10 0.65 0.82]); hold(ax, 'on');
for i = 1:n
    x0 = 0;
    for k = 1:3
        w = comp(i,k);
        if w <= 0, continue; end
        rectangle('Parent', ax, 'Position', [x0 n-i+1-0.35 max(w-0.4,0.01) 0.7], ...
            'FaceColor', cfg.colors.series(k,:), 'EdgeColor', 'none');
        x0 = x0 + w;
    end
    if any(strcmp(cfg.useReportedCredit, P(i).sec))
        text(ax, 1, n-i+1, 'n/a: elective modules not marked in Appendix A', 'FontSize', 7, ...
            'Color', [0.32 0.32 0.31], 'Interpreter', 'none');
    end
end
for k = 1:3, lh(k) = plot(ax, NaN, NaN, 's', 'MarkerFaceColor', cfg.colors.series(k,:), ...
        'MarkerEdgeColor', cfg.colors.series(k,:), 'MarkerSize', 9); end %#ok<AGROW>
set(ax, 'YTick', 1:n, 'YTickLabel', fliplr({P.label}), 'TickLabelInterpreter', 'none', 'FontSize', 8, 'XLim', [0 110], ...
    'YLim', [0.4 n+0.6], 'Box', 'off');
xlabel(ax, 'Compulsory credit in the course list as % of credit requirement (multi-item courses apportioned)');
legend(ax, lh, {'Physics/mathematics', 'Professional/clinical', 'Non-TCS-56'}, 'Location', 'northoutside', 'Orientation', 'horizontal');
set(ax, 'Position', [0.30 0.09 0.65 0.83]);

F.composition = fullfile(outDir, 'Fig_D_compulsory_composition.png');
print(f4, F.composition, '-dpng', '-r200'); close(f4);
end

% =========================================================================
%                              CONSOLE SUMMARY
% =========================================================================
function printSummary(R, cfg)
T = R.metrics;
fprintf('\n%-5s %-58s %7s %7s %6s %6s %-22s\n', 'Sec', 'Programme', 'CorePM', 'AchPM', 'Phys', 'Prof', 'Phys CU vs 60');
for i = 1:height_(T)
    fprintf('%-5s %-58s %6.1f%% %6.1f%% %6s %6s %-22s\n', T.Sec{i}, ...
        trunc([T.Institution{i} ': ' T.Degree{i}], 58), T.CorePM_pct(i), T.AchPM_pct(i), ...
        num2str(T.PhysMathsItemsCovered_of15(i)), num2str(T.ProfClinicalItemsCovered_of12(i)), ...
        [T.PhysMathsCU_MYequiv{i} ' ' T.Benchmark60CU{i}]);
end
V = R.verification;
bad = ~strcmp(V.Status, 'Match') & ~strcmp(V.Status, 'Info');
fprintf('\nVerification: %d checks, %d match, %d differ.\n', height_(V), sum(strcmp(V.Status,'Match')), sum(bad));
G = R.gaps;
fprintf('Gaps: %d High, %d Medium, %d Low, %d Info.\n', sum(strcmp(G.Severity,'High')), ...
    sum(strcmp(G.Severity,'Medium')), sum(strcmp(G.Severity,'Low')), sum(strcmp(G.Severity,'Info')));
fprintf('Course names replaced by TCS-56 substitute names: %d mapping rows.\n', height_(R.unclear));
end

% =========================================================================
%                              SMALL UTILITIES
% =========================================================================
function T = mkTable(names, rows)
% Build a table from a cell matrix, one column per variable name.
s = struct();
for k = 1:numel(names)
    col = rows(:, k);
    if isempty(col)
        s.(names{k}) = cell(0,1);
    elseif all(cellfun(@(x) (isnumeric(x) || islogical(x)) && isscalar(x), col))
        if all(cellfun(@islogical, col)), s.(names{k}) = logical(cell2mat(col));
        else, s.(names{k}) = double(cell2mat(col)); end
    else
        s.(names{k}) = cellfun(@toChar, col, 'UniformOutput', false);
    end
end
T = struct2table(s);
end

function c = toChar(x)
if ischar(x), c = x; elseif isnumeric(x) || islogical(x), c = num2str(x); else, c = ''; end
end

function T = stackTables(P, field)
T = P(1).(field);
for i = 2:numel(P), T = vcat(T, P(i).(field)); end
end

function n = height_(T)
if isstruct(T), f = fieldnames(T); n = numel(T.(f{1})); else, n = height(T); end
end

function v = num(s)
s = regexprep(s, '[\*%,]', '');
v = str2double(s);
end

function v = fracNum(s)
t = regexp(s, '^(\d+)/\d+$', 'tokens', 'once');
if isempty(t), v = NaN; else, v = str2double(t{1}); end
end

function s = rangeStr(x, d)
if nargin < 2, d = 1; end
f = ['%.' num2str(d) 'f'];
if numel(x) == 1 || abs(x(2) - x(1)) < 1e-9
    s = strtrim(regexprep(sprintf(f, x(1)), '\.0+$', ''));
else
    s = [regexprep(sprintf(f, x(1)), '\.0+$', '') '-' regexprep(sprintf(f, x(2)), '\.0+$', '')];
end
end

function s = dspn(v, level)
if strcmp(level, 'Master'), s = 'n/a'; else, s = sprintf('%d / %d / %d / %d', v); end
end

function s = joinOr(c, empty)
c = c(~cellfun(@isempty, c));
if isempty(c), s = empty; else, s = strjoin(c, '; '); end
end

function s = itemOrNone(s), if strcmp(s, '---'), s = '(none)'; end, end
function s = coverageOrNone(s), if strcmp(s, '---'), s = '---'; end, end

function s = groupName(g)
switch g
    case 'MP', s = 'TCS56 Mathematics & Physics';
    case 'PC', s = 'TCS56 Professional/Clinical';
    case 'OT', s = 'Other courses';
    otherwise, s = g;
end
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end

function v = lookupField(S, keyField, key, valField, default)
v = default;
for k = 1:numel(S)
    if strcmp(S(k).(keyField), key), v = S(k).(valField); return; end
end
end

function tf = endsWith_(s, suffix)
tf = numel(s) >= numel(suffix) && strcmp(s(end-numel(suffix)+1:end), suffix);
end

function s = trunc(s, n)
if numel(s) > n, s = [s(1:n-3) '...']; end
end

function [d, dd] = markChars(cfg)
% Dagger marks: MATLAB decodes UTF-8 to Unicode chars; Octave keeps bytes.
if exist('OCTAVE_VERSION', 'builtin')
    d  = char([226 128 160]);  dd = char([226 128 161]);
else
    d  = char(cfg.markUniversity); dd = char(cfg.markMajor);
end
end

function s = shortLabel(p)
inst = p.institution;
inst = regexprep(inst, '^University ([A-H])$', 'Univ $1');
inst = regexprep(inst, '^UCL \(UK\)$', 'UCL');
inst = regexprep(inst, '^U\. Wollongong \(Aus\.\)$', 'UOW');
deg = p.degree;
deg = regexprep(deg, '^Bachelor degree in ', 'BSc ');
deg = regexprep(deg, '^Master degree in ', 'MSc ');
deg = regexprep(deg, '^B\. Medical & Radiation Physics.*', 'BSc Med & Rad Physics');
s = sprintf('%s %s %s', p.sec, inst, deg);
end

function y = rnd(x, d)
y = round(x * 10^d) / 10^d;
end

function T = vcat(A, B)
if isstruct(A)
    f = fieldnames(A); T = A;
    for k = 1:numel(f), T.(f{k}) = [A.(f{k}); B.(f{k})]; end
else
    T = [A; B];
end
end

function T = subRows(T, mask)
if isstruct(T)
    f = fieldnames(T);
    for k = 1:numel(f), T.(f{k}) = T.(f{k})(mask); end
else
    T = T(mask, :);
end
end
