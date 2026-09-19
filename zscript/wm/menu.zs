// ============================================================================
// THE GRAB-POINT PAGE: PICK A PART BY NAME, MOVE IT WHILE YOU WATCH.
//
// Built in code, not in MENUDEF, for two reasons that come from the same place
// -- a menu cannot know what a gun is made of until that gun is loaded:
//
//   * THE PARTS ARE NAMED, and the names come from the card. A page written in
//     MENUDEF can only say "part 3". The game writes each part's role and name
//     into a cvar as the card loads and these rows read them back, so you pick
//     "slide" or "magazine".
//
//   * ONE SCRATCH SET, BAKED INTO THE CARD (BUILD.md step 5, the owner's choice 2026-09-13). The
//     sliders move wm_tune_*, which only the picked part reads (WM_Rig.IsTuned): every other part
//     draws and tests its card numbers. "Bake" prints the card lines -- grab and grabsize or
//     grabradius, a load zone's at and size -- to paste into the gun's card; then clear. Picking
//     another part bakes the last one first if its scratch is not zero, and clears it, so a nudge
//     never walks onto the next part (wm_tune_for says which slot the scratch was set for). The old
//     per-slot sets wm_gp_<m|o><n>_* stay declared, read only by "Bake every part from its OLD
//     tuning", so nothing tuned before is lost.
//
// Everything these rows drive is read by the RENDERER -- a seat set, a
// placement set, a size cvar -- so it all moves with the playsim frozen, which
// is the only state a menu is ever open in.
//
// LINT-CVARS: wm_gp_m0_r wm_gp_m1_r wm_gp_m2_r wm_gp_m3_r wm_gp_m4_r wm_gp_m5_r wm_gp_m6_r wm_gp_m7_r
// LINT-CVARS: wm_gp_o0_r wm_gp_o1_r wm_gp_o2_r wm_gp_o3_r wm_gp_o4_r wm_gp_o5_r wm_gp_o6_r wm_gp_o7_r
// LINT-PREFIXES: wm_gp_m0 wm_gp_m1 wm_gp_m2 wm_gp_m3 wm_gp_m4 wm_gp_m5 wm_gp_m6 wm_gp_m7
// LINT-PREFIXES: wm_gp_o0 wm_gp_o1 wm_gp_o2 wm_gp_o3 wm_gp_o4 wm_gp_o5 wm_gp_o6 wm_gp_o7
// LINT-PREFIXES: wm_gp_m0_sh wm_gp_m1_sh wm_gp_m2_sh wm_gp_m3_sh wm_gp_m4_sh wm_gp_m5_sh wm_gp_m6_sh wm_gp_m7_sh
// LINT-PREFIXES: wm_gp_o0_sh wm_gp_o1_sh wm_gp_o2_sh wm_gp_o3_sh wm_gp_o4_sh wm_gp_o5_sh wm_gp_o6_sh wm_gp_o7_sh
// LINT-SEATS: wm_gp_m0 wm_gp_m1 wm_gp_m2 wm_gp_m3 wm_gp_m4 wm_gp_m5 wm_gp_m6 wm_gp_m7
// LINT-SEATS: wm_gp_o0 wm_gp_o1 wm_gp_o2 wm_gp_o3 wm_gp_o4 wm_gp_o5 wm_gp_o6 wm_gp_o7
// LINT-CVARS: wm_gp_sel_m0 wm_gp_sel_m1 wm_gp_sel_m2 wm_gp_sel_m3 wm_gp_sel_m4 wm_gp_sel_m5 wm_gp_sel_m6 wm_gp_sel_m7
// LINT-CVARS: wm_gp_sel_o0 wm_gp_sel_o1 wm_gp_sel_o2 wm_gp_sel_o3 wm_gp_sel_o4 wm_gp_sel_o5 wm_gp_sel_o6 wm_gp_sel_o7
// LINT-CVARS: wm_gp_name_m0 wm_gp_name_m1 wm_gp_name_m2 wm_gp_name_m3 wm_gp_name_m4 wm_gp_name_m5 wm_gp_name_m6 wm_gp_name_m7
// LINT-CVARS: wm_gp_name_o0 wm_gp_name_o1 wm_gp_name_o2 wm_gp_name_o3 wm_gp_name_o4 wm_gp_name_o5 wm_gp_name_o6 wm_gp_name_o7
// ============================================================================

// LINT-SEATS: wm_tune
// LINT-PREFIXES: wm_tune_sh
class WM_GrabMenu : OptionMenu
{
	private int  shownGun, shownPart;

	override void Init(Menu parent, OptionMenuDescriptor desc)
	{
		Super.Init(parent, desc);
		shownGun = -1; shownPart = -1;
		Build();
	}

	override void Ticker()
	{
		Super.Ticker();
		int g = WM_MenuCVar.Gun(), p = WM_MenuCVar.Part();
		if (g != shownGun || p != shownPart) Build();
		Light(g, p);
	}

	override void OnDestroy()
	{
		Light(-1, -1);
		Super.OnDestroy();
	}

	// ---- the rows ----------------------------------------------------------

	private void Build()
	{
		int gun  = WM_MenuCVar.Gun();
		int part = WM_MenuCVar.Part();
		shownGun = gun; shownPart = part;

		// OUR ROWS START AT THE MARKER, EVERY TIME. The descriptor this page is
		// built on OUTLIVES the page: close it and open it again and the rows added
		// last time are still in the list. Counting the list at open therefore
		// counted our old rows as MENUDEF's, and every visit stacked another copy
		// of the part sliders below the last -- stale copies still aimed at
		// whichever part was selected back then, so dragging "the" slider moved
		// one oval no matter what was picked. Everything from the marker on is
		// ours and is cut before rebuilding.
		int cut = -1;
		for (int i = 0; i < mDesc.mItems.Size(); i++)
		{
			if (mDesc.mItems[i] is "WM_RowsBegin") { cut = i; break; }
		}
		if (cut >= 0) while (mDesc.mItems.Size() > cut) mDesc.mItems.Pop();
		mDesc.mItems.Push(new("WM_RowsBegin").Init("", 0, false));

		String partName = WM_MenuCVar.PartName(gun, part);

		// THE SCRATCH BELONGS TO ONE SLOT. Set for another one and not zero: bake that one first, then
		// clear, before this slot takes the scratch.
		int forSlot = gun * 16 + part + 1;
		int owner = WM_MenuCVar.GetI("wm_tune_for");
		if (owner != 0 && owner != forSlot && WM_BakeRow.ScratchSet())
		{
			WM_BakeRow.SendBake((owner - 1) / 16, (owner - 1) % 16, WM_BakeRow.BAKE_PART);
			WM_BakeRow.ClearScratch();
		}
		WM_MenuCVar.SetI("wm_tune_for", forSlot);

		mDesc.mTitle = (partName == "") ? "GRAB POINTS" : String.Format("GRAB POINTS -- %s", partName);

		Text("");
		Text("PICK A PART -- the one you pick breathes in the world", 1);
		mDesc.mItems.Push(new("OptionMenuItemOption").Init("Which gun", 'wm_tune_gun', 'WMGuns'));

		int shown = 0;
		for (int i = 0; i < 8; i++)
		{
			String role, id;
			[role, id] = WM_MenuCVar.PartRole(gun, i);
			if (id == "") continue;
			// EVERY GRAB SLOT THE GUN DREW: its moving parts -- a slide, a magazine,
			// a pump's forend (which has no role) -- and its load zones ("load|gate").
			// The brace is a grab point too, but two-handed bracing has never been
			// seen to work in this system, so it stays off this page until it is
			// taken on. The game clears a slot's name when that gun fills nothing
			// there, so a pistol's magazine is not offered on a shotgun.
			// A TWO-HANDED gun's support grip (card `hands = 2`) is published as "grip" and IS
			// listed: the other hand must hold it for the trigger to fire.
			if (role == "support") continue;
			String label = id;
			if (role == "load") label = "load zone: " .. id;
			else if (role == "grip") label = "support grip: " .. id;
			mDesc.mItems.Push(new("WM_PartPick").InitPick(label, i, i == part));
			shown++;
		}
		if (shown == 0) Text("-- no gun in that hand, or it has no moving parts --");

		if (partName == "")
		{
			if (mDesc.mSelectedItem >= mDesc.mItems.Size()) mDesc.mSelectedItem = mDesc.mItems.Size() - 1;
			return;
		}

		Text("");
		Text("After picking a part, close this menu and open it again: then these move it live.");
		Text("");
		Text("WHERE IT SITS -- moves live", 1);
		Slide("  Along the barrel", "wm_tune_ofs_x", -20.0, 20.0, 0.25);
		Slide("  Across",           "wm_tune_ofs_y", -20.0, 20.0, 0.25);
		Slide("  Up / down",        "wm_tune_ofs_z", -20.0, 20.0, 0.25);

		Text("");
		Text("ITS SHAPE -- 1.00 is the card's own", 1);
		Slide("  Length (along the barrel)", "wm_tune_sh_scale_x", 0.1, 6.0, 0.05);
		Slide("  Width (across)",            "wm_tune_sh_scale_y", 0.1, 6.0, 0.05);
		Slide("  Height (up and down)",      "wm_tune_sh_scale_z", 0.1, 6.0, 0.05);

		Text("");
		Slide("Reach as a ball (0 = the card's own)", "wm_tune_r", 0.0, 12.0, 0.25);

		Text("");
		Text("INTO THE CARD -- the lines print when this menu closes, and are kept in the bake ledger", 1);
		mDesc.mItems.Push(new("WM_BakeRow").InitBake("  Bake this part", WM_BakeRow.BAKE_PART));
		mDesc.mItems.Push(new("WM_BakeRow").InitBake("  Bake every part of this gun", WM_BakeRow.BAKE_GUN));
		mDesc.mItems.Push(new("WM_BakeRow").InitBake("  Bake every part from its OLD tuning (from before baking)", WM_BakeRow.BAKE_OLD));
		mDesc.mItems.Push(new("WM_BakeRow").InitBake("  Clear this part's tuning (once it is baked)", WM_BakeRow.CLEAR_PART));
		Text("Clear a part once it is baked: its lines are kept below, and a nudge left on counts twice once the card has them.");

		Text("");
		Text(String.Format("THE BAKE LEDGER -- %d of %d parts kept, saved in the ini", WM_BakeLedger.Count(), WM_BakeLedger.SIZE), 1);
		Text("Every bake stays here through relaunches and crashes until it is cleared.");
		mDesc.mItems.Push(new("WM_BakeRow").InitBake("  Clear the bake ledger (only once it is handed over)", WM_BakeRow.CLEAR_LEDGER));

		// The cursor may have been on a row that no longer exists.
		if (mDesc.mSelectedItem >= mDesc.mItems.Size()) mDesc.mSelectedItem = mDesc.mItems.Size() - 1;
	}

	private void Text(String s, int header = 0)
	{
		mDesc.mItems.Push(new("OptionMenuItemStaticText").Init(s, header, false));
	}

	private void Slide(String label, String cvar, double lo, double hi, double step)
	{
		mDesc.mItems.Push(new("OptionMenuItemSlider").Init(label, Name(cvar), lo, hi, step, 2));
	}

	// ONE LIT AT MOST: every other gate is cleared on the same pass, so no stale
	// one can leave a second oval breathing behind this one. And only a slot the
	// gun fills: a selection left on an emptied slot lights nothing.
	private void Light(int gun, int part)
	{
		bool named = (gun >= 0 && WM_MenuCVar.PartName(gun, part) != "");
		for (int g = 0; g < 2; g++)
			for (int i = 0; i < 8; i++)
				WM_MenuCVar.SetF(String.Format("wm_gp_sel_%s%d", g == 0 ? "m" : "o", i),
					(named && g == gun && i == part) ? 1.0 : 0.0);
	}
}

// Where this page's own rows begin. Blank and unselectable; its only job is to
// be findable, so the rows after it can be cut and rebuilt without touching the
// rows MENUDEF wrote above it.
class WM_RowsBegin : OptionMenuItemStaticText
{
}

// A part, by name. Picking one only changes which part the page is pointed at.
class WM_PartPick : OptionMenuItem
{
	private int  mPart;
	private bool mCurrent;

	WM_PartPick InitPick(String label, int part, bool current)
	{
		Super.Init(current ? ("> " .. label) : ("   " .. label), 'None');
		mPart    = part;
		mCurrent = current;
		return self;
	}

	override bool Selectable() { return true; }

	override bool Activate()
	{
		WM_MenuCVar.SetF("wm_tune_part", mPart);
		Menu.MenuSound("menu/choose");
		return true;
	}

	override int Draw(OptionMenuDescriptor desc, int y, int indent, bool selected)
	{
		drawLabel(indent, y, mCurrent ? Font.CR_GOLD
			: (selected ? OptionMenuSettings.mFontColorSelection : OptionMenuSettings.mFontColor));
		return indent;
	}
}

// A BAKE ROW (BUILD.md step 5). Baking sends the scratch IN the events -- a menu freezes the game, so
// they run once it closes, by when the scratch may already be cleared for the next part -- and
// WM_System.BakePrint prints the card lines. Clearing puts the scratch back to the card's own.
class WM_BakeRow : OptionMenuItem
{
	const BAKE_PART    = 0;
	const BAKE_GUN     = 1;
	const BAKE_OLD     = 2;
	const CLEAR_PART   = 3;
	const CLEAR_LEDGER = 4;

	private int  mMode;
	private bool mArmed;

	WM_BakeRow InitBake(String label, int mode)
	{
		Super.Init(label, 'None');
		mMode = mode;
		return self;
	}

	override bool Selectable() { return true; }

	// CLEARING THE LEDGER TAKES TWO PRESSES: it holds bakes that may not be in any card yet, so one stray
	// press must not throw them away. The first press arms the row and says so; the second clears.
	override bool Activate()
	{
		if (mMode == CLEAR_LEDGER)
		{
			if (!mArmed)
			{
				mArmed = true;
				mLabel = String.Format("  PRESS AGAIN to clear all %d kept parts -- any not yet in a card are lost", WM_BakeLedger.Count());
			}
			else
			{
				WM_BakeLedger.Clear();
				mArmed = false;
				mLabel = "  Cleared -- the bake ledger is empty";
			}
		}
		else if (mMode == CLEAR_PART) ClearScratch();
		else SendBake(WM_MenuCVar.Gun(), WM_MenuCVar.Part(), mMode);
		Menu.MenuSound("menu/choose");
		return true;
	}

	override int Draw(OptionMenuDescriptor desc, int y, int indent, bool selected)
	{
		drawLabel(indent, y, mArmed ? Font.CR_RED
			: (selected ? OptionMenuSettings.mFontColorSelection : OptionMenuSettings.mFontColorMore));
		return indent;
	}

	static int Milli(String n) { return int(floor(WM_MenuCVar.GetF(n) * 1000.0 + 0.5)); }

	static void SendBake(int gun, int part, int mode)
	{
		EventHandler.SendNetworkEvent("wm_bake_ofs", Milli("wm_tune_ofs_x"), Milli("wm_tune_ofs_y"), Milli("wm_tune_ofs_z"));
		EventHandler.SendNetworkEvent("wm_bake_shape", Milli("wm_tune_sh_scale_x"), Milli("wm_tune_sh_scale_y"), Milli("wm_tune_sh_scale_z"));
		EventHandler.SendNetworkEvent("wm_bake_go", gun, part + 100 * mode, Milli("wm_tune_r"));
	}

	// THE SCRATCH HOLDS SOMETHING: a nudge, a shape not 1, or a reach.
	static bool ScratchSet()
	{
		return abs(WM_MenuCVar.GetF("wm_tune_ofs_x")) > 0.0005 || abs(WM_MenuCVar.GetF("wm_tune_ofs_y")) > 0.0005
			|| abs(WM_MenuCVar.GetF("wm_tune_ofs_z")) > 0.0005 || WM_MenuCVar.GetF("wm_tune_r") > 0.0005
			|| abs(WM_MenuCVar.GetF("wm_tune_sh_scale_x") - 1.0) > 0.0005 || abs(WM_MenuCVar.GetF("wm_tune_sh_scale_y") - 1.0) > 0.0005
			|| abs(WM_MenuCVar.GetF("wm_tune_sh_scale_z") - 1.0) > 0.0005;
	}

	static void ClearScratch()
	{
		WM_MenuCVar.SetF("wm_tune_ofs_x", 0.0);
		WM_MenuCVar.SetF("wm_tune_ofs_y", 0.0);
		WM_MenuCVar.SetF("wm_tune_ofs_z", 0.0);
		WM_MenuCVar.SetF("wm_tune_r", 0.0);
		WM_MenuCVar.SetF("wm_tune_sh_scale_x", 1.0);
		WM_MenuCVar.SetF("wm_tune_sh_scale_y", 1.0);
		WM_MenuCVar.SetF("wm_tune_sh_scale_z", 1.0);
	}
}

// THE BAKE LEDGER (BUILD.md step 5): every baked grab slot's card lines, kept in this machine's ini as well as
// printed. The console was the only other copy, the engine opens its log fresh on every launch, and picking
// another part auto-bakes the old one and clears its nudge -- so a bake nobody copied out was simply gone.
//
// One entry per gun class and part, "WM_M4A3|part slide|grab = -6.090, 0.090, 6.200|grabradius = 3.000":
// a re-bake of the same part replaces its own entry, a new part takes the first empty one, and a full ledger
// says so rather than overwriting a bake. NOSAVE string cvars nothing in the game reads, written only for
// the machine that sent the bake, so none of it touches the simulation. A plain class, so both the game
// (WM_System.BakePrint) and this page can call it. E:/DOOMWork/tools/bake_defaults.py --ledger reads it back.
class WM_BakeLedger
{
	const SIZE = 64;
	// LINT-CVARS: wm_bake_ledger_00 wm_bake_ledger_01 wm_bake_ledger_02 wm_bake_ledger_03 wm_bake_ledger_04 wm_bake_ledger_05 wm_bake_ledger_06 wm_bake_ledger_07 wm_bake_ledger_08 wm_bake_ledger_09 wm_bake_ledger_10 wm_bake_ledger_11 wm_bake_ledger_12 wm_bake_ledger_13 wm_bake_ledger_14 wm_bake_ledger_15
	// LINT-CVARS: wm_bake_ledger_16 wm_bake_ledger_17 wm_bake_ledger_18 wm_bake_ledger_19 wm_bake_ledger_20 wm_bake_ledger_21 wm_bake_ledger_22 wm_bake_ledger_23 wm_bake_ledger_24 wm_bake_ledger_25 wm_bake_ledger_26 wm_bake_ledger_27 wm_bake_ledger_28 wm_bake_ledger_29 wm_bake_ledger_30 wm_bake_ledger_31
	// LINT-CVARS: wm_bake_ledger_32 wm_bake_ledger_33 wm_bake_ledger_34 wm_bake_ledger_35 wm_bake_ledger_36 wm_bake_ledger_37 wm_bake_ledger_38 wm_bake_ledger_39 wm_bake_ledger_40 wm_bake_ledger_41 wm_bake_ledger_42 wm_bake_ledger_43 wm_bake_ledger_44 wm_bake_ledger_45 wm_bake_ledger_46 wm_bake_ledger_47
	// LINT-CVARS: wm_bake_ledger_48 wm_bake_ledger_49 wm_bake_ledger_50 wm_bake_ledger_51 wm_bake_ledger_52 wm_bake_ledger_53 wm_bake_ledger_54 wm_bake_ledger_55 wm_bake_ledger_56 wm_bake_ledger_57 wm_bake_ledger_58 wm_bake_ledger_59 wm_bake_ledger_60 wm_bake_ledger_61 wm_bake_ledger_62 wm_bake_ledger_63

	static String EntryName(int i) { return String.Format("wm_bake_ledger_%02d", i); }

	static void Keep(String weaponClass, String lines)
	{
		Array<String> rows;
		lines.Split(rows, "\n", TOK_SKIPEMPTY);
		String entry = weaponClass;
		String key = "";
		for (int i = 0; i < rows.Size(); i++)
		{
			String row = rows[i];
			row.StripLeftRight();
			if (row == "") continue;
			if (key == "") key = weaponClass .. "|" .. row .. "|";
			entry = entry .. "|" .. row;
		}
		if (key == "") return;

		int empty = -1;
		for (int i = 0; i < SIZE; i++)
		{
			let c = CVar.FindCVar(EntryName(i));
			if (!c) continue;
			String had = c.GetString();
			if (had == "")
			{
				if (empty < 0) empty = i;
				continue;
			}
			if (had.IndexOf(key) == 0)
			{
				c.SetString(entry);
				return;
			}
		}
		if (empty < 0)
		{
			Console.Printf("\c[Red]WM BAKE: the bake ledger is full (%d parts) -- %s is only in the console this time. Hand the ledger over, then clear it on the grab-point page.",
				SIZE, key.Left(key.Length() - 1));
			return;
		}
		let c = CVar.FindCVar(EntryName(empty));
		if (c) c.SetString(entry);
	}

	static int Count()
	{
		int n = 0;
		for (int i = 0; i < SIZE; i++)
		{
			let c = CVar.FindCVar(EntryName(i));
			if (c && c.GetString() != "") n++;
		}
		return n;
	}

	static void Clear()
	{
		for (int i = 0; i < SIZE; i++)
		{
			let c = CVar.FindCVar(EntryName(i));
			if (c) c.SetString("");
		}
		CVar.SaveConfig();
	}
}

// Cvars, read and written the way a USER cvar must be: through the player, not
// through FindCVar, whose raw object does not hold a user cvar's value.
class WM_MenuCVar
{
	static int Gun()  { let c = CVar.GetCVar("wm_tune_gun",  players[consoleplayer]); return c ? c.GetInt() : 0; }
	static int Part() { let c = CVar.GetCVar("wm_tune_part", players[consoleplayer]); return c ? c.GetInt() : 0; }

	static void SetF(String n, double v)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		if (c) c.SetFloat(float(v));
	}

	static String GetS(String n)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetString() : "";
	}

	static double GetF(String n)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetFloat() : 0.0;
	}

	static int GetI(String n)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetInt() : 0;
	}

	static void SetI(String n, int v)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		if (c) c.SetInt(v);
	}

	// The game writes "role|name" as each card loads -- one cvar rather than
	// two, because the pair is always read together.
	static String, String PartRole(int gun, int part)
	{
		String s = GetS(String.Format("wm_gp_name_%s%d", gun == 0 ? "m" : "o", part));
		int bar = s.IndexOf("|");
		if (bar < 0) return "", s;
		return s.Left(bar), s.Mid(bar + 1);
	}

	static String PartName(int gun, int part)
	{
		String role, id;
		[role, id] = PartRole(gun, part);
		return id;
	}
}
