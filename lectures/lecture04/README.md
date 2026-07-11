# Lecture 4 · Literature Review in Finance

Faithful rebuild of the Week 4 lecture "Literature Review in Finance" plus the two Week 4
handouts: the evaluating-sources template and the abstracts worksheet.

## Objectives

- Explain the purpose and strategic scope of a literature review in finance.
- Turn a research question into keywords, Boolean searches and a database strategy
  (Google Scholar, SSRN, EconLit, JSTOR, Scopus).
- Judge journal quality with the Chartered ABS Academic Journal Guide 2024.
- Evaluate individual sources systematically with the module's seven-column template.
- Identify themes, trends and gaps in volatility, efficiency, behavioural and crypto research.
- Structure the review (thematic, chronological, methodological) and write synthesis rather
  than sequential summaries.
- Draft a conventional six-move abstract (background, purpose, methods, results, evaluation,
  conclusion) within the 300-word limit.

## Interactive elements

1. **ABS ranking explorer** - searchable, filterable table of 220 finance-relevant journals
   from the ABS Academic Journal Guide 2024: the full Finance field (126 journals, all
   ratings) plus every Economics, Econometrics and Statistics journal rated 3 or above.
   Plain-JS text filter, star-rating buttons (All / 4* / 4 / 3 / 2 / 1) and field buttons
   (All / Finance / Economics); journals added to the guide in 2024 carry a "new 2024" tag.
   Data in `data_abs.js` (`window.DATA_ABS`), generated with pandas from
   "ABS Guide 2024 with changes marked" (kept to 220 rows for fast in-slide rendering).
2. **Label-the-abstract task** - sentences 3 to 7 of the Gillett EAP abstract from the
   Week 4 abstracts worksheet, each with Background / Purpose / Method / Results / Conclusion
   buttons and instant feedback (answers: purpose, method, method, results, conclusion).
3. **Literature search funnel** - a deterministic, PRISMA-style canvas sim on the search
   strategy slides. Sliders for keyword breadth (1-10), databases searched (1-6), screening
   strictness (1-10) and snowballing rounds (0-3) feed a pipeline of papers identified,
   de-duplicated, title/abstract screened and finally included; four horizontal bars on a
   log scale keep the funnel visible, and a readout traces the counts and gives a verdict
   (too thin / realistic UG corpus / more than you can critically evaluate). Built on
   `SIM.Plot` and `SIM.slider` from `assets/js/sim-core.js`; no randomness, so no seed.
4. Two self-check quizzes: journal quality and synthesis versus summary.

## Files

- `index.html` - reveal.js deck (title, foundations, search strategy, journal quality with
  ABS explorer, evaluating sources, themes, writing the review, abstracts, roadmap, summary,
  references).
- `data_abs.js` - compact journal-guide extract for the explorer.

## Sources

- `Week 4/Lecture 4 Literature-Review-in-Finance.pdf` (all 16 pages represented).
- `Week 4/Evaluating-Sources-Literature-Review-Template(1).docx` (worked example row rebuilt
  as a table).
- `Understanding Your Project Scope/Week 4 Abstracts.pdf` (abstract structure and task,
  with answers wired into the interactive).
- `Week 4/ABS Guide 2024 with changes marked-1 - Copy.xlsx` (journal ratings for the explorer).
