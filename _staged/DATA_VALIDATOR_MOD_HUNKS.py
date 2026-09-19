# RS_VR_Reload, MOD SIDE of the data validators (Engine docs/COMPILE_CHECK_DATA_VALIDATORS_PLAN.md section 6; the engine
# half is Engine docs/DATA_VALIDATORS_HUNKS.py). Written by the reload lane, 2026-09-15. STAGED: NOT APPLIED.
#
# APPLY ONLY WITH AN EXE THAT HAS DataValidator. Against an older exe, `class WM_CardValidator : DataValidator` and the
# DataValidation calls are unknown symbols, and the whole RS_VR_Reload pk3 fails to compile. _staged/ is outside
# build.ps1's allowlist, so this file is never packed.
#
# WHAT IT DOES.
#   1. WM_Parser.BuildCardSet: the card pipeline WM_System.LoadCards runs at WorldLoaded -- every WMCARD lump (each card
#      remembering its lump), ResolveBases, every WMSHEET lump, BorrowModels, ApplyToCards, Finish -- moved into one
#      static function. LoadCards calls it and keeps its own logging. ONE READER, NOT A COPY.
#      One visible change: the "N weapon sheet(s)" line now prints after Finish's refusals instead of before them.
#   2. WM_CardValidator (zscript/wm/cardvalidator.zs): Validate() calls BuildCardSet and prints one summary line.
#   3. WM_Parser.Refuse and WM_SheetReader.Refuse, the two funnels every card and sheet refusal already goes through,
#      also hand the refusal to DataValidation.Refuse while DataValidation.Running() -- so a card or sheet the game would
#      skip fails the compile check with the game's own words. In play Running() is false: one native call, nothing else.
#   The magfamily warning (FinishCard 3g) stays a warning until MAGFAMILY_REQUIRED is flipped; then it is a refusal and
#   fails the check too.
#
# Paths are relative to RS_VR_Reload. Every anchor must occur exactly once; a new file is written only if absent or
# identical. `python _staged/DATA_VALIDATOR_MOD_HUNKS.py` is a dry run; add --write to apply.

def T(n, s):
    return '\t' * n + s + '\n'

HUNKS = [
 {'name': 'system.zs LoadCards: the pipeline becomes WM_Parser.BuildCardSet',
  'file': 'zscript/wm/system.zs',
  'old': (T(2, 'set = new("WM_CardSet");')
        + T(2, 'int lump = -1;')
        + T(2, 'int lumps = 0;')
        + T(2, 'while ((lump = Wads.FindLump("WMCARD", lump + 1, Wads.GLOBALNAMESPACE)) >= 0)')
        + T(2, '{')
        + T(3, 'int cardsBefore = set.cards.Size();')
        + T(3, 'WM_Parser.ParseAll(Wads.ReadLump(lump), "WMCARD", set);')
        + T(3, '// EACH CARD KNOWS ITS LUMP, so a gun that borrows it reads its own copy from there (sheet.zs BorrowModels).')
        + T(3, 'for (int c = cardsBefore; c < set.cards.Size(); c++) set.cards[c].sourceLump = lump;')
        + T(3, 'lumps++;')
        + T(2, '}')
        + T(2, 'if (lumps == 0)')
        + T(2, '{')
        + T(3, 'set.finished = true;')
        + T(3, 'set.typed    = true;')
        + T(3, 'set.throwablesRead = true;')
        + T(3, 'set.sheetsRead = true;')
        + T(3, 'set.modelsRead = true;')
        + T(3, 'set.basesRead = true;')
        + T(3, 'WM_Log.Err("no WMCARD lump in the load order. The card IS the weapon -- with no card there is nothing to build.");')
        + T(3, 'return;')
        + T(2, '}')
        + T(2, '// A CARD THAT STARTS FROM ANOTHER (`base = <id>`, parser.zs INHERITANCE) is built whole now, in its own place in the')
        + T(2, '// order, before any sheet borrows a card or lays keys over one.')
        + T(2, 'WM_Parser.ResolveBases(set);')
        + T(2, 'set.basesRead = true;')
        + '\n'
        + T(2, "// THE WEAPON SHEETS (sheet.zs): every WMSHEET lump in the load order, laid over the cards' own capacity,")
        + T(2, '// firesfrom, firesound and barrel shots BEFORE Finish, so Finish checks each card as its sheet leaves it.')
        + T(2, '// Their shot keys reach the guns themselves at WorldLoaded and as each gun is made (ApplySheet).')
        + T(2, 'int sheetLumps = 0;')
        + T(2, 'lump = -1;')
        + T(2, 'while ((lump = Wads.FindLump("WMSHEET", lump + 1, Wads.GLOBALNAMESPACE)) >= 0)')
        + T(2, '{')
        + T(3, 'WM_SheetReader.ParseAll(Wads.ReadLump(lump), "WMSHEET", set);')
        + T(3, 'sheetLumps++;')
        + T(2, '}')
        + T(2, "// A GUN THAT NAMES A MODEL CARD gets its own copy of it first, so its sheet's card keys land on that copy.")
        + T(2, 'WM_SheetReader.BorrowModels(set);')
        + T(2, 'set.modelsRead = true;')
        + T(2, 'WM_SheetReader.ApplyToCards(set);')
        + T(2, 'set.sheetsRead = true;')
        + T(2, 'if (sheetLumps > 0)')
        + T(3, 'WM_Log.Info(String.Format("%d weapon sheet(s) from %d WMSHEET lump(s)", set.sheets.Size(), sheetLumps));')
        + '\n'
        + T(2, '// MECHANISMS, SYNTHESIS AND EVERY VERB CHECKED -- only now, with every lump')
        + T(2, '// read, because an archetype may live in a later one.')
        + T(2, 'WM_Parser.Finish(set);')),
  'new': (T(2, '// THE ONE PIPELINE (WM_Parser.BuildCardSet): every WMCARD lump, the card bases, every WMSHEET lump, the borrowed')
        + T(2, '// model cards, the sheets laid over the cards, and Finish -- the very call the compile check makes through')
        + T(2, '// WM_CardValidator, so the check proves exactly what play loads.')
        + T(2, 'WM_CardSet built;')
        + T(2, 'int lumps, sheetLumps;')
        + T(2, '[built, lumps, sheetLumps] = WM_Parser.BuildCardSet();')
        + T(2, 'set = built;')
        + T(2, 'if (lumps == 0)')
        + T(2, '{')
        + T(3, 'WM_Log.Err("no WMCARD lump in the load order. The card IS the weapon -- with no card there is nothing to build.");')
        + T(3, 'return;')
        + T(2, '}')
        + T(2, 'if (sheetLumps > 0)')
        + T(3, 'WM_Log.Info(String.Format("%d weapon sheet(s) from %d WMSHEET lump(s)", set.sheets.Size(), sheetLumps));')),
 },

 {'name': 'parser.zs: WM_Parser.BuildCardSet after Finish',
  'file': 'zscript/wm/parser.zs',
  'old': (T(2, 'set.cards.Copy(kept);')
        + T(2, 'set.finished = true;')
        + T(2, 'set.typed    = true;')
        + T(2, 'set.throwablesRead = true;')
        + T(1, '}')),
  'new': (T(2, 'set.cards.Copy(kept);')
        + T(2, 'set.finished = true;')
        + T(2, 'set.typed    = true;')
        + T(2, 'set.throwablesRead = true;')
        + T(1, '}')
        + '\n'
        + T(1, '// EVERY CARD AND SHEET IN THE LOAD ORDER, BUILT AND CHECKED. The one pipeline, shared by WM_System.LoadCards (at')
        + T(1, '// WorldLoaded) and WM_CardValidator (a compile check run with -validatedata), so the check proves exactly what')
        + T(1, '// play loads:')
        + T(1, '//   every WMCARD lump, each card remembering its lump (a gun that borrows it reads its own copy from there);')
        + T(1, '//   ResolveBases -- a card that starts from another (`base = <id>`) is built whole, in its own place in the order,')
        + T(1, '//   before any sheet borrows a card or lays keys over one;')
        + T(1, "//   every WMSHEET lump, laid over the cards' own capacity, firesfrom, firesound and barrel shots BEFORE Finish, so")
        + T(1, '//   Finish checks each card as its sheet leaves it (the shot keys reach the guns at WorldLoaded, ApplySheet);')
        + T(1, "//   BorrowModels first -- a gun that names a model card gets its own copy, so its sheet's card keys land on that copy;")
        + T(1, '//   Finish last, with every lump read, because an archetype may live in a later one.')
        + T(1, '// With no WMCARD lump the set comes back empty and marked read, and nothing else runs.')
        + T(1, '// Returns the set, the WMCARD lumps read and the WMSHEET lumps read.')
        + T(1, 'static WM_CardSet, int, int BuildCardSet()')
        + T(1, '{')
        + T(2, 'let set = new("WM_CardSet");')
        + T(2, 'int lump = -1;')
        + T(2, 'int lumps = 0;')
        + T(2, 'while ((lump = Wads.FindLump("WMCARD", lump + 1, Wads.GLOBALNAMESPACE)) >= 0)')
        + T(2, '{')
        + T(3, 'int cardsBefore = set.cards.Size();')
        + T(3, 'ParseAll(Wads.ReadLump(lump), "WMCARD", set);')
        + T(3, 'for (int c = cardsBefore; c < set.cards.Size(); c++) set.cards[c].sourceLump = lump;')
        + T(3, 'lumps++;')
        + T(2, '}')
        + T(2, 'if (lumps == 0)')
        + T(2, '{')
        + T(3, 'set.finished = true;')
        + T(3, 'set.typed    = true;')
        + T(3, 'set.throwablesRead = true;')
        + T(3, 'set.sheetsRead = true;')
        + T(3, 'set.modelsRead = true;')
        + T(3, 'set.basesRead = true;')
        + T(3, 'return set, 0, 0;')
        + T(2, '}')
        + T(2, 'ResolveBases(set);')
        + T(2, 'set.basesRead = true;')
        + '\n'
        + T(2, 'int sheetLumps = 0;')
        + T(2, 'lump = -1;')
        + T(2, 'while ((lump = Wads.FindLump("WMSHEET", lump + 1, Wads.GLOBALNAMESPACE)) >= 0)')
        + T(2, '{')
        + T(3, 'WM_SheetReader.ParseAll(Wads.ReadLump(lump), "WMSHEET", set);')
        + T(3, 'sheetLumps++;')
        + T(2, '}')
        + T(2, 'WM_SheetReader.BorrowModels(set);')
        + T(2, 'set.modelsRead = true;')
        + T(2, 'WM_SheetReader.ApplyToCards(set);')
        + T(2, 'set.sheetsRead = true;')
        + '\n'
        + T(2, 'Finish(set);')
        + T(2, 'return set, lumps, sheetLumps;')
        + T(1, '}')),
 },

 {'name': 'parser.zs Refuse: also a compile-check refusal while a validation run is on',
  'file': 'zscript/wm/parser.zs',
  'old': 'That weapon is skipped; the rest load.",\n' + T(3, 'src, line, what, why);') + T(1, '}'),
  'new': 'That weapon is skipped; the rest load.",\n' + T(3, 'src, line, what, why);')
        + T(2, '// THE COMPILE CHECK (zscript/wm/cardvalidator.zs): while the engine runs the data validators, the same refusal')
        + T(2, '// fails the check. False in play.')
        + T(2, 'if (DataValidation.Running())')
        + T(3, "DataValidation.Refuse(String.Format(\"%s line %d\", src, line), String.Format(\"card '%s': %s\", what, why));")
        + T(1, '}'),
 },

 {'name': 'sheet.zs Refuse: also a compile-check refusal while a validation run is on',
  'file': 'zscript/wm/sheet.zs',
  'old': 'its gun keeps its class\'s and card\'s values.",\n' + T(3, 'src, line, what, why);') + T(1, '}'),
  'new': 'its gun keeps its class\'s and card\'s values.",\n' + T(3, 'src, line, what, why);')
        + T(2, '// THE COMPILE CHECK (zscript/wm/cardvalidator.zs): while the engine runs the data validators, the same refusal')
        + T(2, '// fails the check. False in play.')
        + T(2, 'if (DataValidation.Running())')
        + T(3, "DataValidation.Refuse(String.Format(\"%s line %d\", src, line), String.Format(\"sheet '%s': %s\", what, why));")
        + T(1, '}'),
 },

 {'name': 'zscript.txt: include cardvalidator.zs',
  'file': 'zscript.txt',
  'old': '#include "zscript/wm/handprofile.zs"\n',
  'new': '#include "zscript/wm/handprofile.zs"\n#include "zscript/wm/cardvalidator.zs"\n',
 },
]

NEW_FILES = {
'zscript/wm/cardvalidator.zs': r'''// ============================================================================
// THE CARDS, CHECKED BY THE COMPILE CHECK.
//
// The engine's DataValidator (zscript/engine/datavalidator.zs, src/gamedata/datavalidation.cpp): a compile check run
// with -norun -validatedata makes one of these after the scripts compile and before any level exists, and calls
// Validate.
//
// ONE READER, NOT A COPY. Validate runs WM_Parser.BuildCardSet -- the very pipeline WM_System.LoadCards runs at
// WorldLoaded: every WMCARD lump, the card bases, every WMSHEET lump, the borrowed model cards, the sheets laid over
// the cards, and Finish. Every refusal on that path goes through WM_Parser.Refuse or WM_SheetReader.Refuse, which hand
// it to DataValidation.Refuse while a validation run is on -- so a card or sheet the game would skip fails the check,
// in the same words the game prints. card_lint.py stays an editor-side lint; this is the proof.
//
// NOTHING ELSE RUNS: no level, no pawns, no handler. The set it builds is thrown away.
// ============================================================================

class WM_CardValidator : DataValidator
{
	override void Validate()
	{
		WM_CardSet set;
		int cardLumps, sheetLumps;
		[set, cardLumps, sheetLumps] = WM_Parser.BuildCardSet();
		Console.Printf("WM data check: %d card(s) and %d archetype(s) from %d WMCARD lump(s); %d sheet(s) from %d WMSHEET lump(s)",
			set.cards.Size(), set.archetypes.Size(), cardLumps, set.sheets.Size(), sheetLumps);
	}
}
''',
}


if __name__ == '__main__':
    import os, sys
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    write = '--write' in sys.argv
    texts, bad = {}, 0
    for h in HUNKS:
        p = os.path.join(root, h['file'])
        if h['file'] not in texts:
            texts[h['file']] = open(p, encoding='utf-8', newline='').read()
        t = texts[h['file']]
        n, done = t.count(h['old']), t.count(h['new'])
        state = 'ok' if n == 1 else ('already in' if n == 0 and done == 1 else 'ANCHOR x%d' % n)
        print('%-72s %s' % (h['name'][:72], state))
        if n == 1:
            texts[h['file']] = t.replace(h['old'], h['new'], 1)
        elif state != 'already in':
            bad += 1
    for rp, body in NEW_FILES.items():
        p = os.path.join(root, rp)
        if os.path.exists(p) and open(p, encoding='utf-8', newline='').read() != body:
            print('new file %s EXISTS and differs' % rp); bad += 1
        else:
            print('new file %s %s' % (rp, 'identical' if os.path.exists(p) else 'absent'))
    print('PROBLEMS: %d' % bad)
    if write and not bad:
        for f, t in texts.items():
            open(os.path.join(root, f), 'w', encoding='utf-8', newline='').write(t)
        for rp, body in NEW_FILES.items():
            open(os.path.join(root, rp), 'w', encoding='utf-8', newline='').write(body)
        print('WRITTEN')
    sys.exit(1 if bad else 0)
