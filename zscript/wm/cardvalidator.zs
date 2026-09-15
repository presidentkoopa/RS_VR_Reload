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
// AND THE NAMES A CARD GIVES ITS MODEL. A card names parts of its mesh -- a part's `surface` and `joint`, the card's
// `hidesurface` and `hidejoint` -- and in play a name the mesh lacks is only found at bind (WM_Rig.Resolve), as a
// log line, on a gun that then quietly does not move. So the check reads the card's model file itself (WM_ModelNames
// below) and refuses a name that is not in it, in the same DATA REFUSED form as a bad key. Names match without case,
// as the engine's FName lookups do (FindModelSurfaceIndex, FindBoneIndex).
//   Model index 0 only -- the card's own `model`. A part on another MODELDEF model (`model = N`) is not checked.
//   A model file no loaded package has, or a format other than IQM and MD3, is said and not refused: which packages
//   a check loads is not the card's fault, and the card is right or wrong only against a file that is there.
//
// NOTHING ELSE RUNS: no level, no pawns, no handler. The set it builds is thrown away.
// ============================================================================

class WM_CardValidator : DataValidator
{
	// Each model file is read once, however many cards name it.
	private Array<WM_ModelNames> models;
	// A child card or a borrowed copy repeats its base's names: each (file, line, name) is refused once.
	private Array<String> said;

	override void Validate()
	{
		WM_CardSet set;
		int cardLumps, sheetLumps;
		[set, cardLumps, sheetLumps] = WM_Parser.BuildCardSet();
		Console.Printf("WM data check: %d card(s) and %d archetype(s) from %d WMCARD lump(s); %d sheet(s) from %d WMSHEET lump(s)",
			set.cards.Size(), set.archetypes.Size(), cardLumps, set.sheets.Size(), sheetLumps);

		int names = 0, missing = 0;
		for (int i = 0; i < set.cards.Size(); i++)
		{
			int n, m;
			[n, m] = CheckModelNames(set.cards[i]);
			names += n;
			missing += m;
		}
		Console.Printf("WM data check: %d model name(s) checked in %d model file(s); %d not in their model", names, models.Size(), missing);
	}

	// How many names this card gives its model, and how many of them were refused.
	private int, int CheckModelNames(WM_Card card)
	{
		if (card.modelFile == "") return 0, 0;
		bool any = card.hideSurfaces.Size() > 0 || card.hideJoints.Size() > 0;
		for (int i = 0; i < card.parts.Size() && !any; i++)
		{
			let p = card.parts[i];
			if (p.modelIndex == 0 && (p.jointName != "" || p.surfaceNames.Size() > 0)) any = true;
		}
		if (!any) return 0, 0;

		let m = ModelFor(card.modelPath, card.modelFile);
		if (m.lump < 0)
		{
			Console.Printf("WM data check: %s's model %s is in no loaded package -- its names are not checked", card.weaponClass, m.fullName);
			return 0, 0;
		}
		if (m.why != "")
		{
			Console.Printf("WM data check: %s's model %s is %s -- its names are not checked", card.weaponClass, m.fullName, m.why);
			return 0, 0;
		}

		int names = 0, missing = 0;
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let p = card.parts[i];
			if (p.modelIndex != 0) continue;
			String what = String.Format("part %s (%s)", p.id, card.weaponClass);
			for (int s = 0; s < p.surfaceNames.Size(); s++)
			{
				names++;
				if (!m.HasSurface(p.surfaceNames[s]))
					missing += Miss(card, p.line, what, m, p.surfaceNames[s], String.Format(
						"surface = %s -- %s has no surface by that name, so this part never moves. IT HAS: %s",
						p.surfaceNames[s], m.fullName, m.SurfaceList()));
			}
			if (p.jointName != "")
			{
				names++;
				if (!m.HasJoint(p.jointName))
					missing += Miss(card, p.line, what, m, p.jointName, String.Format(
						"joint = %s -- %s, so this part never moves", p.jointName, m.NoJointBecause()));
			}
		}
		for (int k = 0; k < card.hideSurfaces.Size(); k++)
		{
			names++;
			if (m.HasSurface(card.hideSurfaces[k])) continue;
			int line = (k < card.hideSurfaceLines.Size()) ? card.hideSurfaceLines[k] : card.mechanismLine;
			missing += Miss(card, line, card.weaponClass .. " hidesurface", m, card.hideSurfaces[k], String.Format(
				"hidesurface = %s -- %s has no surface by that name, so nothing is hidden. IT HAS: %s",
				card.hideSurfaces[k], m.fullName, m.SurfaceList()));
		}
		for (int k = 0; k < card.hideJoints.Size(); k++)
		{
			names++;
			if (m.HasJoint(card.hideJoints[k])) continue;
			int line = (k < card.hideJointLines.Size()) ? card.hideJointLines[k] : card.mechanismLine;
			missing += Miss(card, line, card.weaponClass .. " hidejoint", m, card.hideJoints[k], String.Format(
				"hidejoint = %s -- %s, so nothing is hidden", card.hideJoints[k], m.NoJointBecause()));
		}
		return names, missing;
	}

	private int Miss(WM_Card card, int line, String what, WM_ModelNames m, String name, String why)
	{
		String key = String.Format("%s|%s|%d|%s", m.fullName, card.sourceName, line, name);
		key = key.MakeLower();
		if (said.Find(key) != said.Size()) return 0;
		said.Push(key);
		DataValidation.Refuse(String.Format("%s line %d", card.sourceName, line), String.Format("card '%s': %s", what, why));
		return 1;
	}

	private WM_ModelNames ModelFor(String path, String file)
	{
		String full = WM_ModelNames.JoinPath(path, file);
		for (int i = 0; i < models.Size(); i++)
			if (models[i].fullName ~== full) return models[i];
		let m = WM_ModelNames.Read(full);
		models.Push(m);
		return m;
	}
}

// ============================================================================
// THE NAMES A MODEL FILE CARRIES, read as the engine's loaders read them: an IQM's mesh names (what GetSurfaceName
// answers for a rigged mesh, IQMModel::Load in src/common/models/models_iqm.cpp) and joint names (FindJoint), an MD3's
// surface names (FMD3Model::Load, models_md3.cpp). Wads.ReadLump keeps every byte of the lump. Only the names are
// read; nothing else of the file. Used by the card checker above, never in play.
// ============================================================================

class WM_ModelNames
{
	String fullName;
	int    lump;
	String kind;              // "IQM" or "MD3" once recognised
	String why;               // why the names could not be read; "" when they were
	Array<String> surfaces;
	Array<String> joints;

	// As A_ChangeModel joins them (p_actionfunctions.cpp ChangeModelNative): a path not ending in '/' gets one.
	static String JoinPath(String path, String file)   // not FullName: ZScript names ignore case, and fullName is the field
	{
		if (path == "" || path.Mid(path.Length() - 1) == "/") return path .. file;
		return path .. "/" .. file;
	}

	static WM_ModelNames Read(String full)
	{
		let m = new("WM_ModelNames");
		m.fullName = full;
		m.lump = Wads.CheckNumForFullName(full);
		if (m.lump < 0) return m;
		String d = Wads.ReadLump(m.lump);
		int size = d.Length();
		if (size >= 124 && d.Mid(0, 15) == "INTERQUAKEMODEL" && d.ByteAt(15) == 0) m.ReadIqm(d, size);
		else if (size >= 108 && d.Mid(0, 4) == "IDP3")                              m.ReadMd3(d, size);
		else m.why = "not an IQM or an MD3 (the only formats this check reads)";
		return m;
	}

	bool HasSurface(String name)
	{
		for (int i = 0; i < surfaces.Size(); i++) if (surfaces[i] ~== name) return true;
		return false;
	}

	bool HasJoint(String name)
	{
		for (int i = 0; i < joints.Size(); i++) if (joints[i] ~== name) return true;
		return false;
	}

	String SurfaceList()
	{
		String s = "";
		for (int i = 0; i < surfaces.Size(); i++) s = s .. (i > 0 ? ", " : "") .. surfaces[i];
		return (s == "") ? "none" : s;
	}

	// The end of a sentence that begins "joint = <name> -- ".
	String NoJointBecause()
	{
		if (kind != "IQM") return String.Format("%s is an %s, and only a rigged IQM has joints", fullName, kind);
		String s = "";
		for (int i = 0; i < joints.Size(); i++) s = s .. (i > 0 ? ", " : "") .. joints[i];
		return String.Format("%s has no joint by that name (IT HAS: %s)", fullName, (s == "") ? "none" : s);
	}

	// The header's uints from byte 16: version 16, num_text 28, ofs_text 32, num_meshes 36, ofs_meshes 40,
	// num_joints 68, ofs_joints 72. A mesh is 24 bytes and a joint 48, each with its name first -- an offset into the
	// text block.
	private void ReadIqm(String d, int size)
	{
		kind = "IQM";
		int fileVersion = U32(d, 16);      // not `version`: a ZScript keyword
		if (fileVersion != 2)
		{
			why = String.Format("an IQM of version %d, and the engine loads only version 2", fileVersion);
			return;
		}
		int numText   = U32(d, 28);
		int ofsText   = U32(d, 32);
		int numMeshes = U32(d, 36);
		int ofsMeshes = U32(d, 40);
		int numJoints = U32(d, 68);
		int ofsJoints = U32(d, 72);
		if (numText <= 0 || !Fits(ofsText, numText, 1, size) || !Fits(ofsMeshes, numMeshes, 24, size) || !Fits(ofsJoints, numJoints, 48, size))
		{
			why = "an IQM whose tables run past the end of the file";
			return;
		}
		for (int i = 0; i < numMeshes; i++)
			surfaces.Push(Text(d, ofsText, numText, U32(d, ofsMeshes + i * 24)));
		for (int i = 0; i < numJoints; i++)
		{
			String jn = Text(d, ofsText, numText, U32(d, ofsJoints + i * 48));
			if (jn != "") joints.Push(jn);     // the engine files no joint under an empty name
		}
	}

	// md3_header_t: Num_Surfaces at 84, Ofs_Surfaces at 100. Each md3_surface_t has its name in the 64 bytes from +4
	// (not always null-terminated) and the offset to the next surface at +104.
	private void ReadMd3(String d, int size)
	{
		kind = "MD3";
		int num = U32(d, 84);
		int at  = U32(d, 100);
		for (int i = 0; i < num; i++)
		{
			if (at < 0 || at > size - 108)
			{
				why = "an MD3 whose surface list runs past the end of the file";
				surfaces.Clear();
				return;
			}
			int e = at + 4;
			while (e < at + 68 && d.ByteAt(e) != 0) e++;
			surfaces.Push(d.Mid(at + 4, e - (at + 4)));
			int step = U32(d, at + 104);
			if (step <= 0)
			{
				why = "an MD3 whose surface list runs past the end of the file";
				surfaces.Clear();
				return;
			}
			at += step;
		}
	}

	private static int U32(String d, int at)
	{
		return d.ByteAt(at) | (d.ByteAt(at + 1) << 8) | (d.ByteAt(at + 2) << 16) | (d.ByteAt(at + 3) << 24);
	}

	private static bool Fits(int ofs, int count, int each, int size)
	{
		return ofs >= 0 && count >= 0 && ofs <= size && count <= (size - ofs) / each;
	}

	private static String Text(String d, int ofsText, int numText, int at)
	{
		if (at < 0 || at >= numText) return "";
		int start = ofsText + at;
		int textEnd = ofsText + numText - 1;    // not `stop`: a ZScript keyword
		int e       = start;
		while (e < textEnd && d.ByteAt(e) != 0) e++;
		return d.Mid(start, e - start);
	}
}
