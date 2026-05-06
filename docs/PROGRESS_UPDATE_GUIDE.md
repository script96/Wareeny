# Progress Update Writing Guide

Reference for anyone writing a Wareeny progress update or similar team document.

---

## File Location and Naming

- Path: `docs/progress_updates/progress_update_N.tex`
- Format: LaTeX (`.tex`)
- Compile with pdflatex or any standard LaTeX distribution

---

## Document Structure

Every update follows this exact order:

1. **Cover page** — project name, update number, month/year, team table, supervisor table
2. **Completed This Cycle** — one subsection per completed feature
3. **Other Improvements** — short paragraphs for fixes and non-feature work
4. **Currently In Progress** — table of in-flight work with descriptions and owners

Do not add new top-level sections. Do not reorder existing ones.

---

## Cover Page

Copy the cover page from the previous update. Change only:
- Update number (`\#N`)
- Month/year in the subtitle line

Team members, IDs, and supervisors stay the same unless personnel changes.

---

## Feature Sections

### Structure per feature

1. **One paragraph** — what it does, how it works, any notable design decision
2. **If the feature uses a known ML technique** — name it explicitly and explain briefly why it fits
3. **Bullet list** (optional) — user-facing controls or flow steps
4. **Metrics table**
5. **Footnotes** for any stat that references an external source or is an estimate

### Metrics tables

- Wrap every table in `\begin{center}...\end{center}`
- Use `\toprule`, `\midrule`, `\bottomrule` (booktabs style — no vertical lines)
- Columns: `\textbf{Metric}` and `\textbf{Value}`
- Use `$\approx$` for estimates
- Use `\textsuperscript{N}` inline to mark stats that need a footnote

### Footnote format

Place footnotes directly below the table they annotate, inside `{\small ... }`:

```latex
{\small
\textsuperscript{1}~Source or explanation.\\
\textsuperscript{2}~Source or explanation.
}
```

One footnote per stat. Explain whether the number is a formal benchmark, an estimate,
or a comparison to a similar published system.

---

## Terminology Standards

| Write this | Not this |
|---|---|
| Delay / processing delay / detection delay | Inference time |
| Detection accuracy | Precision (unless formally computed with TP/FP counts) |
| $\approx$XX\% | "about XX\%" or "roughly XX\%" in tables |
| `\textbf{Feature Name}` | Bold in prose for the first mention of a named technique |

---

## Accuracy Stats — Rules

Always include a **baseline comparison** for any detection feature.
A bare "accuracy: 87%" is meaningless without context.

Standard comparisons to include:
- Baseline general model (e.g., plain YOLOv8n) without the feature's specific enhancement
- Published benchmark for a similar system (cite in footnote)
- Previous cycle's result if the feature was updated

If no published benchmark exists for the exact task, write:
> *Consistent with [similar system type] benchmarks ([Source, Year]).*

Do not fabricate specific paper citations. If unsure of exact numbers, write
`$\approx$` and add `*~Realistic estimate; not a formal benchmark.` as a footnote.

---

## ML Technique Inclusion

When a feature uses or plans to use a specific ML technique, name it inline in the
feature description. Use this pattern:

**For implemented techniques:**
> The pipeline applies **few-shot in-context learning**: [one sentence on how and why].
> This is consistent with [comparable approach] (Author, Year).

**For planned/evaluated techniques:**
> We are evaluating **one-shot learning** — specifically [method name] — to [goal].
> [One sentence on why it fits the problem].

Techniques to mention when applicable:
- Few-shot in-context learning / RAG → LLM-based features with prompt injection
- One-shot / zero-shot learning → adding new classes without retraining
- Transfer learning → fine-tuning a base model on domain data
- Quantization / int8 / fp16 → model compression for on-device deployment

---

## Limitations

Every completed feature section must honestly state its current limitations.
Do not describe limitations only in the "In Progress" section — put them
in the feature's own subsection so the reader understands the current state.

---

## Currently In Progress Table

Columns: `Feature`, `Description`, `Assigned To`

Column widths: `p{4.5cm} p{5.5cm} p{4cm}` (same as established updates).

The description should include:
- What specifically is being built or changed
- Any planned assets (model filenames, APIs)
- Target metric if known

---

## Distance / Proximity Tables

For any feature involving physical distance (e.g., In Hand Detection, Navigation),
include a three-column zone table: `Zone`, `Estimated Distance`, `Spoken Feedback`.
This gives reviewers and supervisors concrete UX behavior, not just accuracy numbers.

---

## Language and Tone

- Write in third person, present tense for completed features
- Write in present progressive for in-progress features ("is being built")
- Keep paragraphs to 3–5 sentences; use bullet lists for step-by-step flows
- **No Arabic text anywhere in the document.** Overleaf does not support Arabic script
  without a full RTL/bidi setup that is not in this template. Describe Arabic UI strings
  in English (e.g., write `\textit{Ask about text}` not `\textit{اسأل عن نص}`).
  Same rule for any Arabic TTS phrases — describe the meaning in English.

---

## LaTeX Preamble

Copy the preamble from any previous update unchanged. Key packages:

```
geometry, titlesec, booktabs, array, enumitem,
xcolor, fancyhdr, hyperref, lmodern, parskip
```

Primary color: `\definecolor{primary}{RGB}{0, 120, 80}`

Header: right = update title, left = university name, footer = page number.
