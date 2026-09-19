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
// AND THE NAMES A CARD GIVES ITS MODELS. A card names parts of its mesh -- a part's `surface` and `joint`, the card's
// `hidesurface` and `hidejoint` -- and in play a name the mesh lacks is only found at bind (WM_Rig.Resolve), as a
// log line, on a gun that then quietly does not move. So the check finds each named model's names and refuses a name
// that is not among them, in the same DATA REFUSED form as a bad key. Names match without case, as the engine's
// FName lookups do (FindModelSurfaceIndex, FindModelJointIndex).
//   MODEL 0 is the card's own `model`, which WM_Rig.Bind puts on the prop: its file is read (WM_ModelNames below).
//   MODEL N (a part's `model = N`) is the prop class's own MODELDEF model N -- the card replaces model 0 only -- so the
//   engine is asked what that class's MODELDEF gives index N (Actor.GetClassModelFile / GetClassModelSurfaceName /
//   GetClassModelJointName, engine build 10): the model the rig's lookups find in play.
//   A model file no loaded package has, a format other than IQM and MD3, or a model N the class's MODELDEF does not
//   load is said and not refused: which packages a check loads is not the card's fault, and a card is right or wrong
//   only against a model that is there.
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
			[n, m] = CheckOtherModelNames(set.cards[i]);
			names += n;
			missing += m;
		}
		Console.Printf("WM data check: %d model name(s) checked (%d model file(s) read); %d not in their model", names, models.Size(), missing);
	}

	// Model 0: how many names this card gives it, and how many of them were refused.
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
				int si = WM_SurfaceRef.Resolve(m.IndexOf(p.surfaceNames[s]), p.surfaceNames[s], m.surfaces.Size());
				if (si < 0)
				{
					missing += Miss(card, p.line, what, m.fullName, p.surfaceNames[s],
						WM_SurfaceRef.IsIndex(p.surfaceNames[s])
						? String.Format("surface = %s -- %s has %d surface(s), numbered 0 to %d, so this part never moves. IT HAS: %s",
							p.surfaceNames[s], m.fullName, m.surfaces.Size(), m.surfaces.Size() - 1, m.SurfaceList())
						: String.Format("surface = %s -- %s has no surface by that name, so this part never moves. IT HAS: %s",
							p.surfaceNames[s], m.fullName, m.SurfaceList()));
					continue;
				}
				missing += CheckFingerprint(card, p, m, si);
			}
			if (p.jointName != "")
			{
				names++;
				if (!m.HasJoint(p.jointName))
					missing += Miss(card, p.line, what, m.fullName, p.jointName, String.Format(
						"joint = %s -- %s, so this part never moves", p.jointName, m.NoJointBecause()));
			}
		}
		for (int k = 0; k < card.hideSurfaces.Size(); k++)
		{
			names++;
			if (m.HasSurface(card.hideSurfaces[k])) continue;
			int line = (k < card.hideSurfaceLines.Size()) ? card.hideSurfaceLines[k] : card.mechanismLine;
			missing += Miss(card, line, card.weaponClass .. " hidesurface", m.fullName, card.hideSurfaces[k], String.Format(
				"hidesurface = %s -- %s has no surface by that name, so nothing is hidden. IT HAS: %s",
				card.hideSurfaces[k], m.fullName, m.SurfaceList()));
		}
		for (int k = 0; k < card.hideJoints.Size(); k++)
		{
			names++;
			if (m.HasJoint(card.hideJoints[k])) continue;
			int line = (k < card.hideJointLines.Size()) ? card.hideJointLines[k] : card.mechanismLine;
			missing += Miss(card, line, card.weaponClass .. " hidejoint", m.fullName, card.hideJoints[k], String.Format(
				"hidejoint = %s -- %s, so nothing is hidden", card.hideJoints[k], m.NoJointBecause()));
		}
		return names, missing;
	}

	// Model N (a part's `model = N`, N above 0): the prop class's own MODELDEF model N, asked of the engine.
	private int, int CheckOtherModelNames(WM_Card card)
	{
		int names = 0, missing = 0;
		class<Actor> prop = null;
		bool looked = false;
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let p = card.parts[i];
			if (p.modelIndex <= 0 || (p.jointName == "" && p.surfaceNames.Size() == 0)) continue;
			if (!looked)
			{
				prop = (class<Actor>)(Object.FindClass(card.propClass, "Actor"));
				looked = true;
			}
			if (!prop)
			{
				Console.Printf("WM data check: %s's prop %s is no actor class -- part %s on model %d is not checked",
					card.weaponClass, card.propClass, p.id, p.modelIndex);
				continue;
			}
			int mi = p.modelIndex;
			String file = Actor.GetClassModelFile(prop, mi);
			if (file == "")
			{
				Console.Printf("WM data check: %s -- %s's MODELDEF loads no model %d, so part %s on it is not checked",
					card.weaponClass, card.propClass, mi, p.id);
				continue;
			}
			String what = String.Format("part %s (%s)", p.id, card.weaponClass);
			for (int s = 0; s < p.surfaceNames.Size(); s++)
			{
				names++;
				int total = Actor.GetClassModelSurfaceCount(prop, mi);
				int si = WM_SurfaceRef.Resolve(ClassModelIndexOf(prop, mi, p.surfaceNames[s]), p.surfaceNames[s], total);
				if (si < 0)
					missing += Miss(card, p.line, what, file, p.surfaceNames[s],
						WM_SurfaceRef.IsIndex(p.surfaceNames[s])
						? String.Format("surface = %s on model %d -- %s has %d surface(s), numbered 0 to %d, so this part never moves. IT HAS: %s",
							p.surfaceNames[s], mi, file, total, total - 1, ClassModelSurfaceList(prop, mi))
						: String.Format("surface = %s on model %d -- %s has no surface by that name, so this part never moves. IT HAS: %s",
							p.surfaceNames[s], mi, file, ClassModelSurfaceList(prop, mi)));
			}
			if (p.jointName != "")
			{
				names++;
				if (!ClassModelHasJoint(prop, mi, p.jointName))
					missing += Miss(card, p.line, what, file, p.jointName, String.Format(
						"joint = %s on model %d -- %s has no joint by that name (IT HAS: %s), so this part never moves",
						p.jointName, mi, file, ClassModelJointList(prop, mi)));
			}
		}
		return names, missing;
	}

	// WHICH surface carries that name, or -1. The yes/no twin this replaced could not
	// feed WM_SurfaceRef, which needs the answer itself to decide whether to fall back
	// to reading the card's text as an index.
	private static int ClassModelIndexOf(class<Actor> prop, int mi, String name)
	{
		int count = Actor.GetClassModelSurfaceCount(prop, mi);
		for (int k = 0; k < count; k++)
		{
			String have = "" .. Actor.GetClassModelSurfaceName(prop, mi, k);
			if (have ~== name) return k;
		}
		return -1;
	}

	private static bool ClassModelHasJoint(class<Actor> prop, int mi, String name)
	{
		int count = Actor.GetClassModelJointCount(prop, mi);
		for (int k = 0; k < count; k++)
		{
			String have = "" .. Actor.GetClassModelJointName(prop, mi, k);
			if (have ~== name) return true;
		}
		return false;
	}

	private static String ClassModelSurfaceList(class<Actor> prop, int mi)
	{
		String s = "";
		int count = Actor.GetClassModelSurfaceCount(prop, mi);
		for (int k = 0; k < count; k++) s = s .. (k > 0 ? ", " : "") .. Actor.GetClassModelSurfaceName(prop, mi, k);
		return (s == "") ? "none" : s;
	}

	private static String ClassModelJointList(class<Actor> prop, int mi)
	{
		String s = "";
		int count = Actor.GetClassModelJointCount(prop, mi);
		for (int k = 0; k < count; k++) s = s .. (k > 0 ? ", " : "") .. Actor.GetClassModelJointName(prop, mi, k);
		return (s == "") ? "no joints -- only a rigged IQM has any" : s;
	}

	// THE FINGERPRINT (a part's `fingerprint = <verts>, <size>`), CHECKED.
	//
	// An index is a position in a file and not a description of anything. Re-export the
	// mesh with its surfaces in another order and every card addressing it by index is
	// suddenly driving a different piece -- which looks exactly like a bad measurement,
	// and gets blamed on the card, the engine and the player's eyes long before anyone
	// suspects the file. The fingerprint is what the part was measured against, so this
	// can say which it is.
	//
	// THE VERTEX COUNT ONLY, HERE. It is exact, it is one number per surface already in
	// the header, and two surfaces of one gun almost never carry the same count -- so it
	// catches a renumbering for the price of a table lookup. The SIZE half is card_lint's
	// (rest pose, bounding-box diagonal, the same convention the generator measures): it
	// needs every vertex of the surface read, and this runs at every boot of a check.
	//
	// MD3 ONLY. This checker does not read an IQM's vertices, so an IQM part's
	// fingerprint is not checked rather than wrongly refused.
	private int CheckFingerprint(WM_Card card, WM_Part p, WM_ModelNames m, int si)
	{
		if (p.fpVerts <= 0) return 0;            // the card did not say
		int have = m.VertsOf(si);
		if (have < 0) return 0;                  // not an MD3, or the count was not read
		if (have == p.fpVerts) return 0;
		return Miss(card, p.line, String.Format("part %s (%s)", p.id, card.weaponClass), m.fullName, "fingerprint",
			String.Format("fingerprint says surface %d had %d vertices; %s's surface %d has %d. The mesh has been re-exported or its surfaces renumbered, so this part is driving the wrong piece -- re-measure the card against the model it now names.",
				si, p.fpVerts, m.fullName, si, have));
	}

	private int Miss(WM_Card card, int line, String what, String file, String name, String why)
	{
		String key = String.Format("%s|%s|%d|%s", file, card.sourceName, line, name);
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
	// Vertices per surface, in surface order, for the fingerprint check. MD3 only, and
	// empty where the surface list did not parse -- kept in step with `surfaces`.
	Array<int>    verts;

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

	// WHICH surface carries that name, or -1. WM_SurfaceRef needs the answer itself,
	// not a yes or no: -1 is what tells it to try the card's text as an index.
	int IndexOf(String name)
	{
		for (int i = 0; i < surfaces.Size(); i++) if (surfaces[i] ~== name) return i;
		return -1;
	}

	// How many vertices surface si carries, or -1 where that was not read (an IQM, or a
	// file whose surface list did not parse). Straight out of the MD3 surface header.
	int VertsOf(int si)
	{
		return (si >= 0 && si < verts.Size()) ? verts[si] : -1;
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
	// (not always null-terminated), its vertex count at +80, and the offset to the next surface at +104.
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
				verts.Clear();
				return;
			}
			int e = at + 4;
			while (e < at + 68 && d.ByteAt(e) != 0) e++;
			surfaces.Push(d.Mid(at + 4, e - (at + 4)));
			verts.Push(U32(d, at + 80));
			int step = U32(d, at + 104);
			if (step <= 0)
			{
				why = "an MD3 whose surface list runs past the end of the file";
				surfaces.Clear();
				verts.Clear();
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
