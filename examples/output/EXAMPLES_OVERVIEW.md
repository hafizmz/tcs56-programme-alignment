# Example self-assessments (tcs56_assess)

These six example course lists show how `tcs56_assess` reports on one programme. The programmes are fictional and written for this demonstration; they are **not** the anonymised programmes in Appendix A. The input files are in `../input/`. Each `exN/` folder holds the Markdown report, the Excel workbook (Items, Courses, Gaps and Caveats sheets) and the coverage chart.

| Ex. | Who / programme | Input | Options | Phys/maths items | Prof/clinical items | CorePM% | AchPM% | CU on the 15 items | Gaps |
|---|---|---|---|---|---|---|---|---|---|
| ex1 | University: BSc Physics | CU, type, synopsis | C = 120 | 15/15 | 3/12 | 37.5% | 50.0% | 57.0 CU (1.90 years) - Below 60 CU | 0 High, 3 Medium |
| ex2 | University: BSc Industrial Physics | CU, type, titles only | C = 124; compared with B.3 | 14/15 | 1/12 | 32.3% | 41.9% | 47.0 CU (1.57 years) - Below 60 CU | 1 High, 2 Medium |
| ex3 | University: BSc Medical Imaging & Radiotherapy | CU, type, synopsis | C = 130 | 0/15 | 10/12 | 3.8% | 3.8% | 0.0 CU (0.00 years) - Below 60 CU | 16 High, 2 Medium |
| ex4 | University: MSc Medical Physics (master's level) | CU, type, synopsis | C = 40; compared with D.1 | -/15 | 12/12 | - | - | - | 0 High, 0 Medium |
| ex5 | University: BSc Physics with Medical Physics (UK) | UK credits, type, synopsis | C = 360 UK credits, factor 0.25; compared with B.6 | 15/15 | 8/12 | 45.8% | 58.3% | 52.5 CU (1.75 years) - Below 60 CU | 0 High, 4 Medium |
| ex6 | Student: topic list | Topic names only | - | 9/15 | 3/12 | - | - | - | 6 High, 0 Medium |

## What each example demonstrates
1. **Full course list, physics degree.** Synopses give High-confidence mappings. The result shows a programme that covers all 15 items but sits 3 CU below the 60 CU benchmark, with Radiation Physics offered only as an elective.
2. **Titles only.** Without synopses, mappings rest on titles and on matching course titles in Appendix A, so confidence is at most Medium and a caveat is added. Comparing with B.3 shows item-by-item agreement with the appendix classification.
3. **Clinical (allied health) degree.** The programme has strong professional/clinical exposure but almost no physics/mathematics prerequisites, so most of the 15 items appear as High gaps. This is the physics-light pattern of Section 3.4. "Physics for Radiographers" is kept as general physics: its title alone suggested Diagnostic Radiology, but the synopsis does not support that, and the report says so.
4. **Master's level.** The programme is assessed against the 12 professional/clinical items only; the physics prerequisites are not assessed at this level.
5. **Foreign credits.** UK credits are converted with factor 0.25 (notional hours, Section 2.1) before the 60 CU benchmark is applied, and the report records the conversion as a caveat.
6. **Student mode.** With topic names only, the credit measures are not computed. The report says so, and every finding carries a confidence level and a remark.

## Reading the confidence levels
* **High:** the synopsis and another route (title or Appendix A) agree.
* **Medium:** the synopsis alone, or a course with the same title in Appendix A.
* **Low:** a title keyword alone, or a similar but not identical Appendix A title. Check these first.

All results are indicative. They are not an accreditation, MQA or MAHPC decision; see the Caveats section of each report.
