![Trama — narrative continuity auditor for manuscripts](assets/header.png)

# Trama

🌐 **English** (you are here) · [Español](README-es.md)

> *Trama* in Spanish carries a double meaning: the plot of a story + the transversal thread of woven fabric. Both need auditing for a novel to hold together.

A continuity auditor for your novel. Point it at your manuscript and it answers questions about what you've already written, with **exact citations** (chapter, line, verbatim text).

---

## What it helps you do

- **Recall everything you said about a character, place, or object** without re-reading the entire manuscript.
- **Detect contradictions**: does Marta's age add up across chapters? did the eye color change? is the chronology consistent with the time jumps?
- **Build your character bible automatically** from the text: characters, family relationships, detected attributes.
- **Find loose threads**: promises a character made and never kept, questions raised and never answered, objects introduced with emphasis that never reappeared (Chekhov's gun unfired).
- **Map the manuscript's timeline** and verify that jumps line up with character ages and seasons.
- **Compare versions**: every time you finish a chapter, see what changed since the last audit — which threads you opened, which you closed.

Works with manuscripts in **Spanish and English**. Supports multi-volume sagas and long books.

## What it does NOT do

- Write, generate, continue, or rewrite prose
- Suggest plots, characters, or developments
- Critique the quality of your writing
- Replace a human developmental editor

It's a **literal auditor**, not a creative collaborator. It only tells you what is already in your text.

---

## Features

| Capability | Detail |
|---|---|
| 🔍 **Search with citations** | All mentions of a character, place, or object, with verbatim text + chapter + line. Sub-ms searches even on 500k-word books. |
| 📖 **Automated character bible** | Extracts characters, places, and objects from the text. Detects family relationships, attributes, frequency of appearance. Generates an editable markdown scaffold you can complete. |
| ⚠️ **Attribute audit** | Detects explicit contradictions: age, eyes, hair, height, profession, relationships. Attributes each claim to the correct owner (filters out "Elena's eyes" when Marta is also in the context). Excludes flashbacks ("when she was 12 years old") from the main audit. |
| ⏰ **Timeline** | Extracts 8 marker types: absolute dates, relative jumps, days of the week, seasons, ages, upcoming days, temporal hedge. Cross-checks with the audit to validate coherence (does the age line up with the months elapsed?). |
| 🧵 **Narrative threads** | Detects open questions, promises (`promised`, `swore`, `going to`), orphan characters (appear once with dialogue and never return), objects introduced with emphasis and never used. Marks which were closed and which weren't. |
| 🔁 **Recurring audit** | Every time you run an audit, Trama saves a snapshot. You can then compare runs and see what changed: new entities, closed threads, persistent threads, frequency changes. |
| 🧠 **Large sagas** | For manuscripts >150k words or multi-volume, orchestrates parallel analysis by arc/character/dimension. Aggregates findings into a single report. |
| 📁 **Multi-format** | Reads `.txt`, `.md`, `.docx`, `.rtf`, or folders with multiple files in alphabetical order. |
| 🌐 **Bilingual ES/EN** | Auto-detects language. Specific patterns for chapters, temporal markers, dialog tags, and attributes in each language. |
| 🗺️ **Line → chapter mapping** | Every citation carries chapter + line. Find the exact passage without opening the manuscript. |
| 🔍 **Accent-insensitive search** | `anos` finds `años`, `marta` finds `Marta`. No need to worry about case or diacritics. |
| 🔄 **Auto-update** | Notifies you when new versions are available on GitHub (at most once per day). |

---

## Installation

Trama runs in **[Claude Code](https://claude.com/claude-code)** (Anthropic's CLI). Install it as a plugin — two slash commands inside Claude Code, **run them in order** (the second one needs the first to finish first):

**Step 1 — register the marketplace:**
```
/plugin marketplace add ChrisPiz/trama
```

**Step 2 — install the plugin:**
```
/plugin install trama@trama
```

Done. Trama is available immediately. Update later with `/plugin update trama`. Same Pro/Max plan you already pay for — no extra cost.

<details>
<summary>Manual install (without plugin manager)</summary>

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/ChrisPiz/trama.git ~/.claude/skills/trama-repo
ln -sf ~/.claude/skills/trama-repo/skills/trama ~/.claude/skills/trama
```

Update later with `git -C ~/.claude/skills/trama-repo pull`.
</details>

> ⚠️ **Claude Desktop / Claude.ai web** work in limited mode (one-shot auditor, no history between sessions). See [DETAILS.md](DETAILS.md) for details.

---

## Supported formats

| Format | Notes |
|---------|-------|
| `.txt`, `.md` | Direct read |
| `.docx` | On macOS uses `textutil` (preinstalled, nothing to install). Falls back to `pandoc` or `python-docx` if textutil fails |
| `.rtf` | On macOS uses `textutil`. Falls back to `pandoc` |
| Folder with multiple files | Concatenates in alphabetical order — useful for sagas with one file per book |

On macOS, **you don't need to install anything** for `.docx` and `.rtf` — Trama uses the native macOS tool (`textutil`). On Linux, install `pandoc` (`brew install pandoc` / `apt install pandoc`).

For **Pages** or **Google Docs**: export to Word or Markdown first.

**PDF is not supported** — the extraction loses too much to maintain exact citations. If your manuscript is only in PDF, export to Word first.

---

## Where files live

Trama creates a `trama-doc/` folder **next to your manuscript**, not in a hidden directory. If you audit `/Users/me/Documents/novel.docx`:

```
/Users/me/Documents/
├── novel.docx              ← your manuscript
└── trama-doc/
    └── novel/              ← workspace, everything visible here
        ├── manuscript.txt   # normalized text version
        ├── chapters.tsv     # chapter map
        ├── entities.tsv     # detected characters/places/objects
        ├── timeline.tsv     # temporal markers
        ├── threads.tsv      # unresolved threads
        ├── runs/            # snapshots by date
        └── audit-log.tsv    # audit history
```

Open it in Finder, version it with git alongside the book, share it with your editor — it's where you expect to find it, not hidden.

---

## How to use

Once installed, talk to Claude Code in natural language:

```
You:    Audit /Users/me/Documents/my-novel.docx

Claude: ✓ Manuscript ready: 87,432 words, 18 chapters.
        What do you want to review?

You:    What have I said about Elena?

Claude: About Elena: 7 mentions across 5 chapters.

        Chapter 1 — line 5
        > Her mother Elena entered the kitchen without knocking.

        Chapter 4 — line 230
        > Elena's green eyes looked at her with concern.

        [...]

You:    Is Marta's age consistent?

Claude: 🟡 Marta's age — 3 statements, severity=soft

        L23 · Chapter 2: The letter
          [34] > Marta was 34 when it all began.
        L1843 · Chapter 5: The letter
          [36] > Marta was now 36.

        Narrative Δt between citations: ~3 years. Age difference: 2 years.
        Possibly coherent, depends on the narrative jump.
```

---

## What to say to Claude

Natural phrases that trigger each feature. You don't have to memorize them — if in doubt, ask Claude what it can do with your manuscript.

### Get started
- `audit /Users/me/Documents/novel.docx`
- `I want to audit my novel at /path/to/book.md`
- `review the folder /Users/me/saga/` (multi-volume)

### Search with citations
- `what have I said about Elena`
- `all mentions of the gun`
- `where does the lighthouse appear`
- `find the phrase "the red of the sunset"`
- `how many times does "silence" appear`

### Character bible
- `build the character bible`
- `extract characters and places`
- `what do we know about Marta`
- `family relationships of the characters`
- `who are the main characters`

### Attribute audit (contradictions)
- `is Marta's age consistent`
- `what eye color does Elena have in the book`
- `check Carmen's profession`
- `audit all character attributes`
- `check whether X's height adds up across chapters`

### Timeline
- `timeline of the book`
- `chronology of the first act`
- `how much time passes between Ch 3 and Ch 8`
- `verify that ages line up with the time jumps`
- `temporal markers in the manuscript`

### Loose threads
- `what was left unresolved`
- `open threads`
- `what promises did characters make and not keep`
- `unanswered questions in the book`
- `orphan characters` (appear once and never return)
- `unfired objects` (Chekhov's gun)

### Recurring audit / diff
- `what changed since the last audit`
- `compare with the previous version`
- `re-run the audit`
- `trends of open threads`
- `show me the audit log`
- `audit and save this run with the note "post Ch 12"`

### List / stats
- `how many words does the book have`
- `list the chapters`
- `how many words does each chapter have`
- `which chapter is the longest`

### Saga / large book
- `audit the entire saga`
- `full audit with parallel subagents`
- `audit the complete manuscript` (for >150k words)

### Final report
- `generate the complete audit report`
- `give me a summary to send to the editor`
- `create the character bible in editable markdown`

### Don't forget
- Trama **always cites verbatim** — chapter + line + verbatim
- If Claude can't find something, it tells you (no inventing)
- You can ask for confirmation if the answer is ambiguous ("do you mean Elena the mother or Elena the cousin?")

---

## Honest limitations

- **Unresolved pronouns**: "She entered" after "Elena arrived" probably refers to Elena, but Trama doesn't resolve pronouns. It asks you for confirmation when relevant.
- **Implicit inconsistencies**: subtext, tone, atmosphere are out of scope. Only explicit contradictions with direct citations are detected.
- **Highly metaphorical prose**: there can be false positives in temporal markers ("haven't seen you in a thousand years"). It shows you the raw match and you decide.
- **Characters referred to only by description** ("the old man at the lighthouse") don't appear in the extractor.
- **Nicknames**: "Marta" and "Martita" count as distinct entities. You can register them manually as aliases so they merge.
- **Manuscripts without chapter markers**: citations use line number only.
- **Deliberate changes** (a character ages between volumes, changes profession): you can register them as exceptions so the audit respects them.

Trama tells you what it found, what it didn't find, and what it can't know. Never inflates certainty.

---

## More details

Want to know how to run it on cron, what happens in Claude.ai vs Claude Code, what files it creates internally, or how to configure environment variables? → See [DETAILS.md](DETAILS.md).

---

## License

MIT. See [LICENSE](LICENSE).
