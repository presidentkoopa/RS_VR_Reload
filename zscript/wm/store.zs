// ============================================================================
// WHERE ROUNDS ARE. A gun's ammunition is a set of NAMED STORES, and there are
// exactly two kinds of store.
//
//   COUNTED   fungible rounds in a number, up to a capacity. A box magazine, a
//             tube, a belt. May detach (a magazine) or not (a tube).
//   SLOTTED   fixed positions, each EMPTY, LIVE or SPENT. A chamber is one
//             slot; a double's barrels are two; a revolver's cylinder is six,
//             indexed, and turns on the shot.
//
// Slotted is what makes a revolver possible: three live and three spent is not
// a count. Everything the two pistols do falls out of a counted detachable
// `mag` plus a one-slot `chamber` -- which is exactly the pair synthesised for
// a card that declares no stores (SynthMag / SynthChamber below).
//
// --------------------------------------- THE DECLARATION HERE, THE ROUNDS THERE
//
// The stores on a WM_Card are the DECLARATION and are never filled. A card is
// one shared object, read by whichever hand binds it, and shared live state on
// it is exactly what must not grow. Each gun holds its own COPY (Copy) inside
// its WM_Ammo, which lives on the weapon, and only a copy ever has rounds in it.
//
// ---------------------------------------------------- NAMES THAT CANNOT MEET
//
// ZSCRIPT IDENTIFIERS ARE CASE-INSENSITIVE: a field `rounds` and a method
// `Rounds()` are one identifier, and the compiler refuses the file -- fatally,
// for every pk3 after this one. So no method here shares a name with a field:
// `rounds` is read directly and the count is Live(); `detach` is the field and
// Detached() the question; the container leaves by Remove() and returns by
// Insert(). And one constant per `const` line: the grammar takes no list.
// ============================================================================

class WM_Store
{
	const UNSTATED = -1;   // a card's store block that has not said its kind yet
	const COUNTED  = 0;
	const SLOTTED  = 1;

	const SLOT_EMPTY = 0;
	const SLOT_LIVE  = 1;
	const SLOT_SPENT = 2;

	// A bound on `slots`, so a typo in a card cannot allocate a thousand chambers.
	const MAX_SLOTS = 64;

	// ---- WHAT IT IS: declared by the card, copied into every gun ------------
	String     id;
	int        kind;           // COUNTED | SLOTTED
	int        capacity;       // COUNTED: the most rounds it holds
	bool       detach;         // it can leave the gun -- a magazine
	String     family;         // detachable: which ones interchange
	bool       indexed;        // SLOTTED: has a selected position
	bool       advanceOnShot;  // SLOTTED + indexed: the shot turns it on
	bool       synthesised;    // made for a card that did not declare it
	// A STAND-IN FOR A MAGAZINE THE GUN DOES NOT HAVE. WM_Ammo's facade runs over a
	// counted store and a slotted one; a card that declares stores and no counted one --
	// a revolver: its cylinder is all it has -- gets this instead of a synthesised
	// detachable `mag`, which would fill itself, show on the HUD, and let the drop-mag
	// button throw a magazine out of a revolver. It holds nothing, never detaches, takes
	// nothing, and is left out of every store listing. A gun that fires straight from its
	// magazine gets a placeholder CHAMBER for the same reason (SynthPlaceholderChamber).
	bool       placeholder;

	// ---- WHAT IS IN IT: live, and only ever on a gun's own copy -------------
	int        rounds;         // COUNTED
	Array<int> slots;          // SLOTTED: SLOT_EMPTY | SLOT_LIVE | SLOT_SPENT each
	int        index;          // SLOTTED + indexed: the selected position
	bool       attached;       // is it in the gun. Always true for a fixed store.

	void InitCounted(String i, int cap, bool det, String fam)
	{
		id            = i;
		kind          = COUNTED;
		capacity      = max(1, cap);
		detach        = det;
		family        = fam.MakeLower();
		indexed       = false;
		advanceOnShot = false;
		rounds        = 0;
		slots.Clear();
		index         = 0;
		attached      = true;
	}

	void InitSlotted(String i, int n, bool idx, bool adv)
	{
		id            = i;
		kind          = SLOTTED;
		capacity      = 0;
		detach        = false;
		family        = "";
		indexed       = idx;
		advanceOnShot = adv;
		rounds        = 0;
		attached      = true;
		SetSlotCount(n);
	}

	// N positions, every one empty, the first selected.
	void SetSlotCount(int n)
	{
		int size = clamp(n, 1, MAX_SLOTS);
		slots.Resize(size);
		for (int s = 0; s < size; s++) slots[s] = SLOT_EMPTY;
		index = 0;
	}

	// ---- THE SYNTHESIS RULE, in one place ------------------------------------
	//
	// What every card written before stores existed meant: a COUNTED detachable
	// `mag` of the card's capacity, in the card's magazine family, and a SLOTTED
	// one-slot `chamber`. WM_Card.SynthesiseStores uses it for a card that
	// declares no stores; WM_Ammo uses it for a gun whose stores lack either half.
	static WM_Store SynthMag(int cap, String fam)
	{
		let s = new("WM_Store");
		s.InitCounted("mag", cap, true, fam);
		s.synthesised = true;
		return s;
	}

	static WM_Store SynthChamber()
	{
		let s = new("WM_Store");
		s.InitSlotted("chamber", 1, false, false);
		s.synthesised = true;
		return s;
	}

	// See `placeholder`. Empty, fixed, and it never fills.
	static WM_Store SynthPlaceholder(String fam)
	{
		let s = new("WM_Store");
		s.InitCounted("mag", 1, false, "");
		s.synthesised = true;
		s.placeholder = true;
		return s;
	}

	// A STAND-IN FOR A CHAMBER THE GUN DOES NOT HAVE: a gun that fires straight from its
	// magazine (WM_Card.FIRES_MAGAZINE). The facade runs over a slotted store as well as a
	// counted one; a live synthesised chamber would show one round up the spout that no pull
	// ever fires. This one is never filled (Fill), never fired from, and left out of every
	// store listing.
	static WM_Store SynthPlaceholderChamber()
	{
		let s = new("WM_Store");
		s.InitSlotted("chamber", 1, false, false);
		s.synthesised = true;
		s.placeholder = true;
		return s;
	}

	// A fresh, EMPTY store of this declaration -- what a gun keeps its rounds in.
	// The caller fills it.
	WM_Store Copy()
	{
		let s = new("WM_Store");
		s.id            = id;
		s.kind          = kind;
		s.capacity      = capacity;
		s.detach        = detach;
		s.family        = family;
		s.indexed       = indexed;
		s.advanceOnShot = advanceOnShot;
		s.synthesised   = synthesised;
		s.placeholder   = placeholder;
		s.rounds        = 0;
		s.index         = 0;
		s.attached      = true;
		if (kind == SLOTTED) s.SetSlotCount(slots.Size());
		return s;
	}

	// ---- HOW MUCH ------------------------------------------------------------

	// COUNTED: the rounds in it. SLOTTED: how many positions hold a live round.
	int Live() const
	{
		if (kind == COUNTED) return rounds;
		int size = slots.Size();
		int n = 0;
		for (int s = 0; s < size; s++)
			if (slots[s] == SLOT_LIVE) n++;
		return n;
	}

	// NOTHING TO FIRE OR FEED. A spent case counts as empty here...
	bool IsEmpty() const { return Live() <= 0; }

	// NO ROOM FOR ANOTHER ROUND. ...and as full here: a spent case still sits
	// in its chamber, and nothing loads into it until it is thrown out.
	bool IsFull() const
	{
		if (kind == COUNTED) return rounds >= capacity;
		return FirstEmpty() < 0;
	}

	// ---- COUNTED ---------------------------------------------------------------

	// Remove up to n. Returns how many actually came out.
	int Take(int n)
	{
		if (kind != COUNTED) return 0;
		int got = clamp(n, 0, rounds);
		rounds -= got;
		return got;
	}

	// Add up to n, stopping at capacity. Returns what did NOT fit.
	int Put(int n)
	{
		if (n <= 0) return 0;
		if (kind != COUNTED || placeholder) return n;
		int got = min(n, max(0, capacity - rounds));
		rounds += got;
		return n - got;
	}

	// Full: a counted store to capacity, every slot of a slotted one live.
	void Fill()
	{
		if (placeholder) { rounds = 0; return; }
		if (kind == COUNTED) { rounds = capacity; return; }
		int size = slots.Size();
		for (int s = 0; s < size; s++) slots[s] = SLOT_LIVE;
	}

	// ---- SLOTTED ---------------------------------------------------------------

	// The selected position: the index when indexed, otherwise always 0.
	int Selected() const
	{
		int size = slots.Size();
		if (!indexed || size == 0) return 0;
		return clamp(index, 0, size - 1);
	}

	int SlotAt(int i) const
	{
		int size = slots.Size();
		if (i < 0 || i >= size) return SLOT_EMPTY;
		return slots[i];
	}

	void SetSlot(int i, int v)
	{
		int size = slots.Size();
		if (i < 0 || i >= size) return;
		slots[i] = clamp(v, SLOT_EMPTY, SLOT_SPENT);
	}

	// For `slot = next`: the first position with nothing in it, -1 when none.
	int FirstEmpty() const
	{
		int size = slots.Size();
		for (int s = 0; s < size; s++)
			if (slots[s] == SLOT_EMPTY) return s;
		return -1;
	}

	int FirstLive() const
	{
		int size = slots.Size();
		for (int s = 0; s < size; s++)
			if (slots[s] == SLOT_LIVE) return s;
		return -1;
	}

	// An indexed store turns to its next position.
	void Advance()
	{
		int size = slots.Size();
		if (kind != SLOTTED || !indexed || size == 0) return;
		index = (index + 1) % size;
	}

	// Every position emptied. Returns how many were LIVE -- read `slots` first
	// if the spent ones matter to what is thrown out.
	int EmptyAll()
	{
		if (kind != SLOTTED) return 0;
		int had = Live();
		int size = slots.Size();
		for (int s = 0; s < size; s++) slots[s] = SLOT_EMPTY;
		return had;
	}

	// ---- THE CONTAINER ---------------------------------------------------------

	bool Detached() const { return detach && !attached; }

	// THE CONTAINER LEAVES, and what is in it goes with it. Returns how many live
	// rounds left with it. A store that does not detach stays put and gives 0.
	int Remove()
	{
		if (!detach) return 0;
		int had = attached ? Live() : 0;
		rounds = 0;
		int size = slots.Size();
		for (int s = 0; s < size; s++) slots[s] = SLOT_EMPTY;
		attached = false;
		return had;
	}

	// A CONTAINER GOES IN, holding withRounds, clamped to what it can hold. It
	// REPLACES what the store held: the store is the container. A store that
	// does not detach cannot have one pushed into it.
	void Insert(int withRounds)
	{
		if (!detach) return;
		attached = true;
		if (kind == COUNTED) { rounds = clamp(withRounds, 0, capacity); return; }
		int size = slots.Size();
		for (int s = 0; s < size; s++) slots[s] = (s < withRounds) ? SLOT_LIVE : SLOT_EMPTY;
	}

	// WHAT IS IN IT NOW, in a few characters, for the load and stroke logs and
	// wm_dump: "tube 4/5", "mag OUT", "chamber [live]", "barrels [spent, empty]"
	// (an indexed store's selected slot is starred).
	String Contents() const
	{
		if (kind == COUNTED)
		{
			if (Detached()) return String.Format("%s OUT", id);
			return String.Format("%s %d/%d", id, rounds, capacity);
		}
		String s = "";
		int size = slots.Size();
		int sel = Selected();
		for (int i = 0; i < size; i++)
		{
			s = s .. ((i > 0) ? ", " : "") .. SlotWord(slots[i]);
			if (indexed && i == sel) s = s .. "*";
		}
		return String.Format("%s [%s]", id, s);
	}

	static String SlotWord(int state)
	{
		if (state == SLOT_LIVE)  return "live";
		if (state == SLOT_SPENT) return "spent";
		return "empty";
	}

	// ONE STORE, ONE PHRASE, for the bind log: what it is and who said so.
	String Describe() const
	{
		if (placeholder)
		{
			if (kind == SLOTTED) return "(no chamber -- it fires from its magazine, the reserve or nothing; the facade's chamber is an empty placeholder)";
			return "(no counted store -- the facade's magazine is an empty placeholder)";
		}
		String shape;
		if (kind == COUNTED)
		{
			shape = String.Format("counted, capacity %d", capacity);
		}
		else
		{
			int size = slots.Size();
			shape = String.Format("slotted, %d slot%s%s%s", size, (size == 1) ? "" : "s",
				indexed ? ", indexed" : "", advanceOnShot ? ", advances on the shot" : "");
		}
		return String.Format("%s [%s, %s, family %s] %s", id, shape,
			detach ? "detachable" : "fixed",
			(family == "") ? "none" : family,
			synthesised ? "synthesised" : "declared");
	}
}
