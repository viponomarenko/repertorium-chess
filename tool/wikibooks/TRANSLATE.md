# Translating Wikibooks texts into Ukrainian (D-106)

Input: a chunk file `tool/wikibooks/work/chunk_NN.jsonl`. Each line is
`{"id": revid, "h": hash, "title": ..., "en": text}`.

Output: write `tool/wikibooks/work/chunk_NN.uk.txt` as plain text. For
every input line, in the same order, write a block:

    @@@ <id> <h>
    <the Ukrainian translation, with its paragraph breaks>

Then pack it, check it, fix what the check reports, and pack and check again
until everything passes:

    dart run tool/wikibooks/pack.dart chunk_NN
    dart run tool/wikibooks/check.dart chunk_NN

## Rules

1. **Moves stay exactly as written.** Copy every move token character for
   character, in the original Latin letters, with its number and dots:
   `3. f4`, `3...d5`, `...O-O`, `Nxe4`, `d2-d4`, `Bb5+`, `e8=Q`.
   - Never translate piece letters (no К, Ф, Т, С, Кр).
   - Never use the Cyrillic look-alikes а, с, е for the files a, c, e.
   - Squares (`e5`, `f7`) and files in words stay Latin too: "the f-pawn"
     → «пішак f», "the c-file" → «вертикаль c», "the e5-pawn" → «пішак e5».
   - Keep every move that is in the original. Do not add or drop any
     move. A script compares the moves of the two texts and rejects a
     translation whose moves differ.
2. **Terms come from `tool/wikibooks/glossary.tsv`.** "White" and "Black"
   (the sides) are «білі» and «чорні», lower case.
3. **Translate faithfully.** Do not correct, add, shorten or explain. If
   the original claims something dubious, translate it as it is.
4. **Use natural Ukrainian chess prose**, as in a Ukrainian chess book:
   - the apostrophe is ʼ (U+02BC);
   - quotes are «…»;
   - use a plain hyphen, never an em or en dash.
5. **Keep the layout.** Paragraph breaks (blank lines) and list items
   starting with "• " stay where they are.
