# TCS-56 Programme Alignment Tool: supplementary software

Supplementary software for: **Medical Physics Education in Malaysia: A Critical Analysis against the IAEA TCS-56 Curriculum Standard** (Mohd Zin H, et al.).

The tool assesses **one programme** against the IAEA TCS-56 curriculum standard. It is meant for a programme team checking its curriculum or a student checking their degree.

The input is a course list or a list of topics. The tool maps each entry to the 15 TCS-56 undergraduate physics/mathematics prerequisite items and to the 12 postgraduate professional/clinical items. It then reports how well the programme aligns. Every finding carries a confidence level, a remark and the caveats that apply. The courses already classified in Appendix A of the manuscript serve as reference data.

## Folder structure
```
TCS56_Toolkit_Publication/
  README.md
  run_examples.m               runs the six worked examples
  code/
    tcs56_assess.m             single-programme assessment (main function)
    tcs56_tool.m               reads the Appendix A reference data (called by tcs56_assess)
    tcs56_config.m             rules: TCS-56 items, keywords, credit conversion
  data/
    Appendix_A_Anonymized_v14_submission.md   reference course classifications (Appendix A)
  examples/
    input/                     six example course lists and two blank templates
    output/
      EXAMPLES_OVERVIEW.md     summary of the six examples
      ex1 ... ex6/             report (.md), workbook (.xlsx), coverage chart (.png)
```

## Requirements and use
MATLAB R2019b or later; no toolboxes are needed. In MATLAB, change to this folder and run the worked examples:
```matlab
run_examples             % writes examples/output/ex1 ... ex6
```
To assess your own programme, copy `examples/input/templates/course_list_template.csv` and fill in your courses. The columns are Course, CU, Type (Core/Elective) and Synopsis; only Course is required. Then run:
```matlab
addpath('code')
A = tcs56_assess('my_programme.csv', 'Programme', 'My programme', 'CreditRequirement', 120);
```
A student can give topic names only, either as a `.txt` file with one per line or as a list:
```matlab
A = tcs56_assess({'Calculus','Quantum mechanics','Optics'}, 'Programme', 'My degree');
```

| Option | Meaning |
|---|---|
| `Level` | `'Bachelor'` (default) or `'Master'` |
| `CreditRequirement` | credits needed to graduate (C) |
| `CompulsoryCredit` | official compulsory credits (K), if known |
| `CreditFactor` | converts credits to Malaysian CU (0.25 for UK credits, about 0.6 for Australian credit points) |
| `CompareWith` | an Appendix A programme to compare with, e.g. `'A.1'` |
| `OutDir` | output folder |

## What is reported
* **Item alignment.** Each of the 27 TCS-56 items is classed as Dedicated, Split, Part of broader or Not covered. The report gives the courses that cover each item, a confidence level, whether the item is reached only through electives, and a remark.
* **Credit measures** (when credits are supplied):
  * CorePM% = P/C, the compulsory physics/mathematics share of the credit requirement.
  * AchPM% = (P + min(C − K, E))/C, the share reachable by also choosing physics/mathematics electives.
  * The CU of courses mapped to the 15 prerequisite items, compared with the 60 CU (two-year) benchmark.
* **Gaps**, by severity:
  * High: an item not covered, or more than 15 CU short of the benchmark.
  * Medium: an item reached only through electives, or CorePM% below 50%.
  * Low: an item covered only inside a broader course, or supported by title evidence only.
* **Caveats**, added according to the input. Examples: titles only, no credits, course type not given, an assumed credit requirement, converted credits, or professional items counted as undergraduate exposure only.

## How a course is mapped
1. **Synopsis.** At least two distinct keywords of a TCS-56 item appear in the synopsis.
2. **Appendix A.** A course with the same or a similar title is already classified in Appendix A. An item is used only if most programmes listing that title map it there.
3. **Title.** A keyword of the item appears in the course title.

When a synopsis is supplied, an item suggested only by the title is dropped if the synopsis does not support it. **Confidence** is High when the synopsis and another source agree, Medium for the synopsis alone or an identical Appendix A title, and Low for title evidence only.

## Limitations
The result is an automated, indicative mapping based on course titles, synopses and keyword rules. It cannot judge the depth or quality of teaching, and it is **not** an accreditation, MQA or MAHPC registration decision. For bachelor's programmes, professional/clinical items show undergraduate exposure only, because TCS-56 places that content at postgraduate level. Institutions in Appendix A are anonymised as University A–H. The keyword rules in `code/tcs56_config.m` can be adjusted.

## Licence and citation
[To be completed by the authors: licence (e.g. MIT or CC BY 4.0) and repository DOI.]
If you use this tool, please cite the manuscript above.
