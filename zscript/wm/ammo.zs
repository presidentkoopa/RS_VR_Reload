// ============================================================================
// WHAT THE GUN HOLDS. Three places, and they are three different things.
//
//   RESERVE    what you carry. Ordinary Doom ammo (Clip), so pickups off the
//              floor feed it and every HUD already understands it.
//   MAGAZINE   what is in the magazine currently seated in the gun. Goes with
//              the magazine when it leaves.
//   CHAMBER    ONE round, up the spout. A slot, not a count.
//
// THE CHAMBER IS NOT PART OF THE MAGAZINE, and conflating them is the bug this
// separation exists to prevent. A chambered round:
//   - survives the magazine being removed. Drop the mag on a real pistol and
//     you still have one shot. Clearing it with the magazine leaves the gun
//     completely dead, which is wrong and is immediately visible.
//   - is what a trigger pull actually spends.
//   - is thrown away when you rack a loaded gun, because the extractor pulls
//     it out to make room. That is why nobody racks a loaded pistol for fun.
//
// It is also where the 15-versus-16 comes from: a full magazine PLUS one
// chambered is sixteen in a fifteen-round gun.
//
// ------------------------------------------------------ OVER NAMED STORES
//
// The magazine and the chamber are two WM_Stores (store.zs) -- this gun's own
// copies of what its card declares: a COUNTED detachable `mag` and a SLOTTED
// one-slot `chamber`, synthesised for every card that declares no stores.
//
// THIS CLASS IS A FACADE, and its outside has not changed: the same methods,
// the same five fields, every caller untouched. The stores are the truth.
//
// FOUR OF THE FIELDS ARE A MIRROR. rounds, chambered, magIn and capacity are
// re-derived from the stores by Sync(), and nothing outside may write them.
// The fragile part of any mirror is a path that forgets to re-derive -- a HUD
// that disagrees with the gun -- so here it cannot be forgotten: every public
// method that changes a store is a wrapper, Adopt / body / Sync, and every
// early return happens INSIDE the body, where it cannot skip the Sync after
// it. Add a mutator the same way or not at all.
//
// actionLock IS NOT MIRRORED. It is the gun's held-open state, and lives here
// because this object lives on the weapon and survives a rebind. With wm_verbs
// on, WHEN it is set is the cycle verb's `holdopen = whenempty` (verb.zs): the
// verbs set it through SetActionLock, by that rule, and nothing else does.
//
// ------------------------------------------------------------- BY STORE NAME
//
// The verbs work named stores: EjectFrom, FeedFrom and Discharge below. The
// same Adopt / body / Sync shape as every other mutator, so the mirror cannot
// be left behind by them either. Fire, Cycle and ReleaseLock above are the old
// role code's, kept exactly, for wm_verbs off.
// ============================================================================

class WM_Ammo
{
	// ---- THE MIRROR: read these, never write them ---------------------------
	int  rounds;      // in the seated magazine; 0 while it is out
	bool chambered;   // one live round up the spout
	bool magIn;       // is there a magazine at all
	int  capacity;    // the magazine's

	// ---- NOT A MIRROR: the action's own state -------------------------------
	bool actionLock;  // held open on empty, until worked
	// A GUN'S ENGINE IS RUNNING (verb.zs START, a chainsaw's ripcord). Not a mirror either: kept on
	// the weapon for the reason actionLock is, so a rebind is not a free start. Set by the start
	// verb's pull (WM_Rig.StartEngine), cleared as the gun leaves the hand (WM_Rig.Unbind).
	bool engineRunning;
	// HOW THIS GUN FIRES (WM_Card.FIRES_*), copied from its card at every bind (WM_Rig.Bind), so a reader with no card to
	// hand -- a weapon HUD drawing in ui scope, through RS_WeaponAmmoService -- can tell a chamber gun from a reserve one.
	int  firesFrom;

	// ---- THE STORES, this gun's own copies ----------------------------------
	Array<WM_Store> stores;   // every store the gun has, the two below included
	WM_Store magStore;        // COUNTED: what the action feeds from
	WM_Store chamberStore;    // SLOTTED: what a trigger pull spends

	// A LOADED GUN: every store full, the action closed. Given its card, the
	// stores are copies of the card's own (declared, or synthesised at load);
	// without one they are the synthesised pair built from `cap`. For a card
	// that declares no stores the two are the same stores.
	void Init(int cap, WM_Card card = null)
	{
		Build(cap, card);
		for (int i = 0; i < stores.Size(); i++) stores[i].Fill();
		actionLock = false;
		Sync();
	}

	// ---- THE SHOT ---------------------------------------------------------
	//
	// ONE TRIGGER PULL SPENDS EXACTLY ONE ROUND: the chambered one. The
	// magazine loses one only to REPLACE it, which is what the action does on
	// its way back.
	//
	// Written as one function because the version where the trigger took one
	// off the magazine AND fired the chambered round is a real bug that has
	// shipped in this project before, and it cost two rounds a shot.
	//
	// Returns true if a shot happened. False means there was nothing to fire.
	bool Fire()
	{
		Adopt();
		bool shot = FireBody();
		Sync();
		return shot;
	}

	// Racking. Throws away whatever was chambered -- that is what an extractor
	// does -- and feeds the next one if there is one.
	//
	// Returns true if a live round was ejected, so the caller can throw a real
	// one on the floor rather than silently deleting it.
	bool Cycle()
	{
		Adopt();
		bool threw = CycleBody();
		Sync();
		return threw;
	}

	// Releasing a locked-back action on a fresh magazine: chambers the first
	// round and closes up. Costs a round, and that is correct -- it is where
	// the chambered round comes from on every path.
	bool ReleaseLock()
	{
		Adopt();
		bool fed = ReleaseBody();
		Sync();
		return fed;
	}

	// Read off the mirror, which every mutator above re-derives before it
	// returns -- and which, for a gun restored from a save written before the
	// stores existed, is still the saved truth.
	bool CanFire() const { return chambered && !actionLock; }

	// What the gun is holding altogether, which is what a person counting their
	// shots means -- magazine plus the one up the spout.
	int Total() const { return rounds + (chambered ? 1 : 0); }

	// The magazine leaves. THE CHAMBERED ROUND STAYS, deliberately: dropping a
	// magazine does not empty the chamber. Returns the rounds that went with it.
	int TakeMagazine()
	{
		Adopt();
		int had = magStore.Remove();
		Sync();
		return had;
	}

	void SeatMagazine(int withRounds)
	{
		Adopt();
		magStore.Insert(withRounds);
		Sync();
	}

	// ONE LINE: every store this gun has -- id, kind, capacity or slots, whether
	// it detaches, its family, and whether the card declared it or it was
	// synthesised. Printed once per bind (WM_Rig.Bind).
	String DescribeStores()
	{
		Adopt();
		String line = "";
		for (int i = 0; i < stores.Size(); i++)
			line = line .. (i > 0 ? "; " : "") .. stores[i].Describe();
		return line;
	}

	// ---- BY STORE NAME: what the verbs work (verb.zs) --------------------------

	// This gun's own store by name, case-insensitively. Null when it has none.
	WM_Store FindStore(String storeId)
	{
		Adopt();
		for (int i = 0; i < stores.Size(); i++)
			if (stores[i].id ~== storeId) return stores[i];
		return null;
	}

	// Live rounds in a named store; 0 when the gun has no store by that name.
	int LiveIn(String storeId)
	{
		let s = FindStore(storeId);
		return s ? s.Live() : 0;
	}

	// NOTHING TO FEED FROM THAT STORE: none by that name, out of the gun, or empty.
	// Asked BEFORE a feed, because "the feed failed for want of a round" is the
	// holdopen rule, and a feed that takes the last round leaves it empty too.
	bool FeedEmpty(String storeId)
	{
		let s = FindStore(storeId);
		return !s || s.Detached() || s.Live() <= 0;
	}

	// THE TRIGGER, WITHOUT ITS ACTION: the chambered round is spent and nothing is
	// fed. What happens next is the cycle verb's -- a pistol's feeds on the same
	// tic, a pump's waits for a hand. False when there was nothing to fire.
	//
	// leaveSpent: THE CASE STAYS IN THE CHAMBER, SLOT_SPENT, for an action nothing
	// works on the shot -- a pump's hull comes out when the forend is pulled, not when
	// the trigger is. Off (the default, and every pistol), the slot is emptied and the
	// casing is Brass's to throw, exactly as before.
	bool Discharge(bool leaveSpent = false)
	{
		Adopt();
		bool shot = DischargeBody(leaveSpent);
		Sync();
		return shot;
	}

	// ---- A PULL THAT FIRES SEVERAL CHAMBERS (WM_Gun.ChambersPerPull) -------------------

	// LIVE ROUNDS IN THE CHAMBER STORE, every slot of it -- not only the selected one,
	// which is all `chambered` and CanFire look at. 0 when the store is out of the gun.
	int LiveChambers()
	{
		Adopt();
		return chamberStore.Detached() ? 0 : chamberStore.Live();
	}

	// UP TO `most` LIVE CHAMBERS SPENT AT ONCE, in slot order from the selected one, each
	// left SPENT (leaveSpent) or EMPTY exactly as Discharge leaves its one. Returns how
	// many fired; 0, and nothing changed, when none was live or the action is held open.
	// Discharge is untouched: a pull of one never comes here.
	int DischargeChambers(int most, bool leaveSpent = false)
	{
		Adopt();
		int fired = DischargeChambersBody(most, leaveSpent);
		Sync();
		return fired;
	}

	private int DischargeChambersBody(int most, bool leaveSpent)
	{
		if (actionLock || chamberStore.Detached()) return 0;
		int size = chamberStore.slots.Size();
		int start = chamberStore.Selected();
		int fired = 0;
		for (int i = 0; i < size && fired < most; i++)
		{
			int s = (start + i) % size;
			if (chamberStore.SlotAt(s) != WM_Store.SLOT_LIVE) continue;
			chamberStore.SetSlot(s, leaveSpent ? WM_Store.SLOT_SPENT : WM_Store.SLOT_EMPTY);
			fired++;
		}
		return fired;
	}

	// ---- A SECOND BARREL (card.zs WM_Barrel): its own store, fired by its own input ----------

	// CAN A SECOND BARREL FIRE FROM ITS STORE: a live slot in a slotted one, a round in a
	// counted one. False for a store the gun does not have, or one out of the gun.
	bool BarrelLoaded(String storeId)
	{
		let s = FindStore(storeId);
		return s && !s.Detached() && s.Live() > 0;
	}

	// ONE SHOT OF A SECOND BARREL: the selected slot when it is live, else the first live one,
	// left SPENT -- nothing cycles a barrel, so its case waits for the store to be emptied; or
	// one round out of a counted store. False, and nothing changed, when nothing was live.
	bool DischargeBarrel(String storeId)
	{
		Adopt();
		bool shot = DischargeBarrelBody(storeId);
		Sync();
		return shot;
	}

	private bool DischargeBarrelBody(String storeId)
	{
		let s = FindStore(storeId);
		if (!s || s.Detached()) return false;
		if (s.kind == WM_Store.COUNTED) return s.Take(1) > 0;
		int slot = s.Selected();
		if (s.SlotAt(slot) != WM_Store.SLOT_LIVE) slot = s.FirstLive();
		if (slot < 0) return false;
		s.SetSlot(slot, WM_Store.SLOT_SPENT);
		return true;
	}

	// ---- A MANUAL ACTION, AND ONE ROUND AT A TIME (verb.zs CYCLE by hand, LOAD) ----

	// A STROKE'S FAR END, SAYING WHAT CAME OUT: the selected slot of a named slotted
	// store is emptied and its old state returned -- SLOT_LIVE, SLOT_SPENT or
	// SLOT_EMPTY -- so the caller throws a live round, a spent case, or nothing. -1
	// when the gun has no slotted store by that name.
	int EjectCase(String storeId)
	{
		Adopt();
		int was = EjectCaseBody(storeId);
		Sync();
		return was;
	}

	// WHY ONE ROUND WILL NOT GO INTO A NAMED STORE, or "" when it will. Changes nothing.
	// slot is a slotted store's position; slotNext means its first empty one.
	String LoadRefusal(String storeId, int slot, bool slotNext)
	{
		Adopt();
		return LoadRefusalBody(storeId, slot, slotNext);
	}

	// ONE ROUND IN. True when it went; when it did not, nothing changed.
	bool LoadRound(String storeId, int slot, bool slotNext)
	{
		Adopt();
		bool went = LoadRoundBody(storeId, slot, slotNext);
		Sync();
		return went;
	}

	// CAN THE FACADE'S MAGAZINE LEAVE THE GUN. A pistol's can; a tube cannot, and a
	// drop-mag button on a tube must do nothing rather than spawn an empty magazine.
	bool MagDetaches()
	{
		Adopt();
		return magStore.detach;
	}

	// ---- A GUN WITH NO CHAMBER (WM_Card.FIRES_MAGAZINE) ---------------------------------

	// THE MAGAZINE CAN PAY FOR A PULL: in the gun, and holding at least n.
	bool MagazineHolds(int n)
	{
		Adopt();
		return !magStore.Detached() && magStore.Live() >= max(n, 1);
	}

	// ONE PULL, PAID STRAIGHT OUT OF THE MAGAZINE: n rounds, or none at all when it holds
	// fewer -- a pull is never half paid. Returns how many went.
	int SpendFromMagazine(int n)
	{
		Adopt();
		int went = SpendFromMagazineBody(n);
		Sync();
		return went;
	}

	private int SpendFromMagazineBody(int n)
	{
		int need = max(n, 1);
		if (magStore.Detached() || magStore.Live() < need) return 0;
		return magStore.Take(need);
	}

	// EVERY STORE AND WHAT IS IN IT NOW, one phrase: "tube 4/5, chamber [spent]".
	String StoreCounts()
	{
		Adopt();
		String line = "";
		for (int i = 0; i < stores.Size(); i++)
		{
			if (stores[i].placeholder) continue;
			line = line .. (line != "" ? ", " : "") .. stores[i].Contents();
		}
		return line;
	}

	// ---- A CYLINDER (store.zs SLOTTED, indexed) ----------------------------------------

	// THE CHAMBER UNDER THE HAMMER TURNS ON THE SHOT: the gun's chamber store is indexed
	// and says advance = onshot. False for every single-chamber gun.
	bool TurnsOnShot()
	{
		Adopt();
		return chamberStore.indexed && chamberStore.advanceOnShot;
	}

	// TURN IT ONE POSITION. Returns the position now under the hammer, -1 when the
	// chamber store is not indexed.
	int TurnChamber()
	{
		Adopt();
		int at = TurnBody();
		Sync();
		return at;
	}

	// The position under the hammer and what is in it, for the logs: "3 (spent)".
	String UnderHammer()
	{
		Adopt();
		int at = chamberStore.Selected();
		return String.Format("%d (%s)", at, WM_Store.SlotWord(chamberStore.SlotAt(at)));
	}

	// EVERY SLOT OF A NAMED SLOTTED STORE THROWN OUT AT ONCE -- a break-top opening, a rod
	// pushed. Returns how many were LIVE and how many SPENT, so the caller throws a round
	// for each live one and brass for each spent one. An indexed store turns back to its
	// first slot, so rounds loaded into it next are fired in the order they went in.
	int, int EjectAll(String storeId)
	{
		Adopt();
		int live, spent;
		[live, spent] = EjectAllBody(storeId);
		Sync();
		return live, spent;
	}

	// DOES A SLOT HOLD A CASE, live or spent. slot < 0: does any slot. False when the gun
	// has no slotted store by that name. What a round surface is drawn by.
	bool SlotHeld(String storeId, int slot)
	{
		let s = FindStore(storeId);
		if (!s || s.kind != WM_Store.SLOTTED || s.Detached()) return false;
		if (slot >= 0) return s.SlotAt(slot) != WM_Store.SLOT_EMPTY;
		int size = s.slots.Size();
		for (int i = 0; i < size; i++)
			if (s.slots[i] != WM_Store.SLOT_EMPTY) return true;
		return false;
	}

	// DOES A ROUND SURFACE SHOW (card.zs WM_Part.roundSurfName). A SLOTTED store: that slot holds
	// a case, live or spent -- `any` (at < 0), any slot does (SlotHeld). A COUNTED store: it holds
	// more than `at` rounds -- a rack's third rocket, at = 2, shows while three or more are left --
	// and `any`, while it holds one. False for a store the gun lacks, or one out of the gun.
	bool RoundShows(String storeId, int at)
	{
		let s = FindStore(storeId);
		if (!s || s.Detached()) return false;
		if (s.kind == WM_Store.COUNTED) return s.Live() > max(at, 0);
		return SlotHeld(storeId, at);
	}

	private int TurnBody()
	{
		if (!chamberStore.indexed) return -1;
		chamberStore.Advance();
		return chamberStore.Selected();
	}

	private int, int EjectAllBody(String storeId)
	{
		let s = FindStore(storeId);
		if (!s || s.kind != WM_Store.SLOTTED) return 0, 0;
		int live = 0;
		int spent = 0;
		int size = s.slots.Size();
		for (int i = 0; i < size; i++)
		{
			if (s.slots[i] == WM_Store.SLOT_LIVE) live++;
			else if (s.slots[i] == WM_Store.SLOT_SPENT) spent++;
			s.slots[i] = WM_Store.SLOT_EMPTY;
		}
		if (s.indexed) s.index = 0;
		return live, spent;
	}

	// A STROKE'S FAR END: the selected slot of a named slotted store is emptied.
	// True when a LIVE round came out, so the caller can throw a real one.
	bool EjectFrom(String storeId)
	{
		Adopt();
		bool threw = EjectBody(storeId);
		Sync();
		return threw;
	}

	// A STROKE'S NEAR END: one round stripped from a named counted store into a
	// named slotted store's selected position. False when nothing moved.
	bool FeedFrom(String feedId, String intoId)
	{
		Adopt();
		bool fed = FeedBody(feedId, intoId);
		Sync();
		return fed;
	}

	// Held open, or not. Set by the verbs by their holdopen rule.
	void SetActionLock(bool held)
	{
		Adopt();
		actionLock = held;
		Sync();
	}

	// ---- THE BODIES: early returns live here, never in the wrappers ---------

	// Fire's first half, exactly: the same test, the same slot, the same EMPTY --
	// or SPENT, for an action whose case waits for a hand.
	private bool DischargeBody(bool leaveSpent)
	{
		int slot = chamberStore.Selected();
		if (chamberStore.SlotAt(slot) != WM_Store.SLOT_LIVE || actionLock) return false;
		chamberStore.SetSlot(slot, leaveSpent ? WM_Store.SLOT_SPENT : WM_Store.SLOT_EMPTY);
		return true;
	}

	private int EjectCaseBody(String storeId)
	{
		let s = FindStore(storeId);
		if (!s || s.kind != WM_Store.SLOTTED) return -1;
		int slot = s.Selected();
		int was = s.SlotAt(slot);
		s.SetSlot(slot, WM_Store.SLOT_EMPTY);
		return was;
	}

	// The same questions a person loading asks: is there such a store, is it in the
	// gun, is there room. A spent case in a slot is not room.
	private String LoadRefusalBody(String storeId, int slot, bool slotNext)
	{
		let s = FindStore(storeId);
		if (!s) return String.Format("this gun has no store called %s", storeId);
		if (s.Detached()) return String.Format("%s is out of the gun", s.id);
		if (s.kind == WM_Store.COUNTED)
		{
			if (s.IsFull()) return String.Format("%s is full, %d of %d", s.id, s.rounds, s.capacity);
			return "";
		}
		if (slotNext)
		{
			if (s.FirstEmpty() < 0) return String.Format("every slot of %s is taken", s.id);
			return "";
		}
		int size = s.slots.Size();
		if (slot < 0 || slot >= size) return String.Format("%s has no slot %d", s.id, slot);
		int state = s.SlotAt(slot);
		if (state != WM_Store.SLOT_EMPTY)
			return String.Format("slot %d of %s already holds a %s case", slot, s.id, WM_Store.SlotWord(state));
		return "";
	}

	private bool LoadRoundBody(String storeId, int slot, bool slotNext)
	{
		if (LoadRefusalBody(storeId, slot, slotNext) != "") return false;
		let s = FindStore(storeId);
		if (s.kind == WM_Store.COUNTED) return s.Put(1) == 0;
		int pick = slotNext ? s.FirstEmpty() : slot;
		s.SetSlot(pick, WM_Store.SLOT_LIVE);
		return true;
	}

	// CycleBody's first half, over any slotted store by name.
	private bool EjectBody(String storeId)
	{
		let s = FindStore(storeId);
		if (!s || s.kind != WM_Store.SLOTTED) return false;
		int slot = s.Selected();
		bool threw = (s.SlotAt(slot) == WM_Store.SLOT_LIVE);
		s.SetSlot(slot, WM_Store.SLOT_EMPTY);
		return threw;
	}

	// Feed, over named stores. One test Feed never needed: the position must be
	// empty. Feed was only ever called on a slot just emptied (or empty by the lock's
	// own invariant), so for the old sequences the test never fails; for a verb it
	// is what stops a second round being stripped into an occupied chamber.
	private bool FeedBody(String feedId, String intoId)
	{
		let src = FindStore(feedId);
		let dst = FindStore(intoId);
		if (!src || !dst || src.kind != WM_Store.COUNTED || dst.kind != WM_Store.SLOTTED) return false;
		if (src.Detached() || src.Live() <= 0) return false;
		int slot = dst.Selected();
		if (dst.SlotAt(slot) != WM_Store.SLOT_EMPTY) return false;
		src.Take(1);
		dst.SetSlot(slot, WM_Store.SLOT_LIVE);
		return true;
	}

	private bool FireBody()
	{
		int slot = chamberStore.Selected();
		if (chamberStore.SlotAt(slot) != WM_Store.SLOT_LIVE || actionLock) return false;

		chamberStore.SetSlot(slot, WM_Store.SLOT_EMPTY);   // that round is gone

		// And the action feeds the next. Nothing to feed, and the gun tells you
		// by holding its own action open -- no text, no icon, the shape of the
		// gun IS the message, and your off hand answers it without being told.
		if (!Feed(slot)) actionLock = true;
		return true;
	}

	private bool CycleBody()
	{
		int slot = chamberStore.Selected();
		bool threw = (chamberStore.SlotAt(slot) == WM_Store.SLOT_LIVE);
		chamberStore.SetSlot(slot, WM_Store.SLOT_EMPTY);
		actionLock = !Feed(slot);
		return threw;
	}

	private bool ReleaseBody()
	{
		if (!actionLock) return false;
		if (!Feed(chamberStore.Selected())) return false;   // nothing to chamber
		actionLock = false;
		return true;
	}

	// THE ACTION STRIPS A ROUND OFF THE MAGAZINE INTO THE CHAMBER. The only thing
	// that empties a magazine -- a cartridge leaves it when the action strips it
	// out, not when the trigger is pulled. False when there was nothing to strip:
	// no magazine, or an empty one. Called only from the bodies, so a Sync
	// always follows it.
	private bool Feed(int slot)
	{
		if (magStore.Detached() || magStore.Live() <= 0) return false;
		magStore.Take(1);
		chamberStore.SetSlot(slot, WM_Store.SLOT_LIVE);
		return true;
	}

	// ---- THE MIRROR, RE-DERIVED ---------------------------------------------
	private void Sync()
	{
		magIn     = !magStore.Detached();
		rounds    = magIn ? magStore.Live() : 0;
		chambered = (chamberStore.SlotAt(chamberStore.Selected()) == WM_Store.SLOT_LIVE);
		capacity  = magStore.capacity;
	}

	// ---- WHICH STORES ---------------------------------------------------------

	// This gun's own stores: copies of the card's, then the two the facade runs
	// over -- by name, then by kind, and synthesised when the card has neither.
	private void Build(int cap, WM_Card card)
	{
		stores.Clear();
		if (card)
		{
			for (int i = 0; i < card.stores.Size(); i++)
				stores.Push(card.stores[i].Copy());
		}

		magStore     = FindOwn("mag",     WM_Store.COUNTED, card);
		chamberStore = FindOwn("chamber", WM_Store.SLOTTED, card);
		if (!magStore)
		{
			// A CARD THAT DECLARED STORES AND NO COUNTED ONE (a revolver: its cylinder is
			// all it has) gets an empty placeholder, not a magazine it does not have. A card
			// that declared none -- and a gun from an old save -- gets the pistol's, as always.
			if (card && card.stores.Size() > 0) magStore = WM_Store.SynthPlaceholder(card.FamilyOfMags());
			else magStore = WM_Store.SynthMag(cap, card ? card.FamilyOfMags() : "pistol");
			stores.Push(magStore);
		}
		if (!chamberStore)
		{
			// A GUN THAT DOES NOT FIRE FROM A CHAMBER (WM_Card.firesFrom) gets an empty
			// placeholder, never a live one-slot chamber it would show and never fire.
			if (card && card.firesFrom != WM_Card.FIRES_CHAMBER) chamberStore = WM_Store.SynthPlaceholderChamber();
			else chamberStore = WM_Store.SynthChamber();
			stores.Push(chamberStore);
		}
	}

	// NEVER A SECOND BARREL'S STORE (card.zs WM_Barrel): a launcher's one-slot chamber is not the
	// main barrel's chamber, and falling back to it by kind would fire it on the main trigger.
	private WM_Store FindOwn(String storeId, int storeKind, WM_Card card)
	{
		for (int i = 0; i < stores.Size(); i++)
			if (stores[i].kind == storeKind && stores[i].id ~== storeId && !(card && card.IsBarrelStore(stores[i].id))) return stores[i];
		for (int i = 0; i < stores.Size(); i++)
			if (stores[i].kind == storeKind && !(card && card.IsBarrelStore(stores[i].id))) return stores[i];
		return null;
	}

	// A GUN FROM BEFORE THE STORES. A saved game written by the previous build
	// restores the four fields and no stores at all, and the first shot would
	// abort the VM on a null store. Build the pair FROM those fields, once, so
	// the gun carries on exactly as it was saved.
	private void Adopt()
	{
		if (magStore && chamberStore) return;
		bool wasIn    = magIn;
		int  wasCount = rounds;
		bool wasLive  = chambered;
		Build(capacity, null);
		if (wasIn) magStore.Insert(wasCount);
		else       magStore.Remove();
		chamberStore.SetSlot(chamberStore.Selected(), wasLive ? WM_Store.SLOT_LIVE : WM_Store.SLOT_EMPTY);
		Sync();
	}
}
