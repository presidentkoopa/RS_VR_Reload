// ============================================================================
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
