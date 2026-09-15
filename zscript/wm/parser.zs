// ============================================================================
// READING CARDS.
//
// Line-oriented, `key = value`, blocks closed by `end`, `#` starts a comment.
// Case-insensitive keys. Several weapons may share one lump: each `weapon`
// line starts a new card, and the `part` blocks after it belong to it.
//
// ------------------------------------------------- AN UNKNOWN KEY IS A REFUSAL
//
// Not a warning and not a skip. A typo'd key would otherwise leave that setting
// at its default forever with nothing said, and whoever wrote the card would be
// debugging a mechanism that never received their number. The refusal names the
// key, the line and the lump.
//
// ONE BAD CARD REFUSES ONE WEAPON. Parsing resumes at the next `weapon` line,
// so a typo in the pistolet's card does not take the M4A3 down with it.
//
// ------------------------------------------------------------------ STORES
//
// `store <name>` ... `end` declares where rounds are (store.zs), one key per
// line like every other block: kind (counted | slotted), capacity, detach,
// family, slots, indexed, advance (onshot | none). A store that closes without
// a kind, with a key belonging to the other kind, or under a name the card
// already used is refused. A card that declares NO stores has the pistol pair
// synthesised as it is accepted, so no card written before stores existed
// needs a line changed.
//
// ------------------------------------------------------------------- VERBS
//
// `cycle | open | swap | load | eject <id>` ... `end` says what the gun does
// with its parts (verb.zs). One key per line; a key that belongs to another
// verb, or a value that is not one of its words, refuses the weapon here, with
// its line. Whether a verb is COMPLETE -- its part exists, its stores exist and
// are the right kind, nothing it states contradicts anything else -- is decided
// once every lump has been read (Finish), because an archetype may lay keys
// under it from a lump that comes later.
//
//   cycle   part outat apex homeat onout(eject|none) from onhome(feed|none)
//           feed into return(spring|hand|stay) holdopen(whenempty|never)
//           auto(onshot|none)
//   open    part latch openat closeat rest|return(spring|hand|stay)
//           onopen(ejectall|none) from close(flick|hand|none) flickaxis(up|side|x,y,z)
//           flickscale button(yes|no)
//   swap    part store seatat detachat pullout button(yes|no) handtake(yes|no) needs latch latchat
//   load    into slot(<n>|next) at(x, y, z) size(x, y, z) dir(x, y, z)
//           subject(shell|round|loader) rides(<part>) needs
//   eject   by(hand|tilt|muzzleup) tiltaxis(barrel|up|down|x,y,z) part at from all(yes|no) needs button(yes|no)
//   start   part outat -- one a card; the gun fires only while its engine runs (card pullsound,
//           startsound, idlesound, stopsound)
//   pulloff part offat by(hand|head) needs(trigger|none) arms(yes|no) -- a thrown weapon's pin
//   release part heldby(grip) -- a thrown weapon's lever
//
// An open verb is open past `openat` and SHUT again only back at `closeat` (default
// 0.05); in between it is neither, and a gun with one not shut does not fire. Opening
// with `onopen = ejectall` throws every case in `from` out -- live rounds as rounds,
// spent ones as brass -- from the card's ejectport, carried by the open part.
//
// A load with `subject = loader` takes a LOADER -- a speedloader, a clip: one loose
// object holding several rounds, the card's magmodel -- and fills every empty slot it
// can at once; a single round still fills one. `rides = <part>` carries the zone with
// that part's motion (a cylinder face tipping down with a break-top's barrel).
//
// An eject `by = muzzleup` names no part: pointing the gun up past `at` (the sine of
// the bore's elevation) while its `needs` holds open throws the cases out.
//
// `needs = open:<id>` gates a load or eject on an open verb. A card that
// declares no verbs and no mechanism has the old role code's behaviour
// synthesised as verbs (card.zs SynthesiseVerbs).
//
// A load's `at` is a point in model space; its `size` is three half-sizes in MAP
// units along the gun's own axes, exactly like a part's `grabsize`. Its `dir` is
// the way a round travels going in, model space (a bottom port loads upward, a
// side port inward) -- optional, recorded and logged, for a load driven along the
// mesh's own shell line. Its `subject` is shell or round.
//
// A part's `handseat = x, y, z` is where a hand gripping it sits, model space
// (card.zs WM_Part.handSeat).
//
// A card's `type = <word>` says what kind of gun it is -- pistol, shotgun, breakaction,
// revolver, rifle, smg, ... -- and so which hand seats its hands read (handprofile.zs).
// Unstated, Finish derives it: the archetype's own `type`, or pistol for a card on
// pistol grammar, or none. `handprofile = <word>` gives one gun seats of its own,
// wm_hs_<word>_*, where a weapon package declares them. Each is one lower-case word,
// because it becomes part of a cvar name.
//
// A card's `firesfrom = chamber | magazine | reserve | none` says what a trigger pull spends
// (WM_Card.firesFrom). chamber, unstated, is every card before it. magazine is a gun with NO
// chamber -- a chaingun's box, a plasma rifle's cells: a pull takes WM_Gun.RoundsPerShot
// straight from its counted store, so a magazine seated is ready with nothing to rack. Such a
// card is refused with a cycle verb (a `role = action` part synthesises one), with no counted
// store, or with a verb that names its chamber. reserve is a gun with no stores that spends
// the owner's own Weapon.AmmoType1 -- a flamethrower; none spends nothing -- a chainsaw. Both
// are refused with any store, or a cycle, swap, load or eject verb.
//
// A card's `casing = yes | none`: none is a gun with no cases -- plasma, a rail, a rocket,
// flame -- so no brass leaves it, on the shot or when a store is emptied (WM_Card.noCasing).
//
// A part's `roundsurface = <surface>, <store>, <slot|any>` is one more surface of that
// part, moving with it, drawn only while that slot of that slotted store holds a case
// (live or spent) -- `any`, while any slot does. A cylinder's rounds, a double's shells.
// On a COUNTED store the third field is a count: drawn while the store holds more than it
// -- a rocket rack's rockets, a belt's last rounds -- and `any`, while it holds one.
// Its store is checked once the card is whole.
//
// A hammer part's `cock = action | trigger`: action (unstated) is cocked by the action
// and falls on the shot, as a pistol's is; trigger follows the finger back and falls on
// the shot or the click -- a double action.
//
// Card sounds `opensound` and `closesound` play as an open verb opens and shuts. Silent
// unless stated, like every gun sound.
//
// ------------------------------------------------------- THE SHOT AND ITS SOUNDS
//
// THE SHOT IS NOT A CARD'S. `pellets`, `spread` and `damage` were card keys; they
// are the weapon class's now (WM_Gun.ShotPellets / ShotSpread / ShotDamage in its
// Default block), and a card still using one is refused, naming where it went.
//
// SOUNDS: every `...sound` key is silent when unstated, except drysound, magdropsound
// and casingsound, which default to the reload system's own wm/dry, wm/magdrop and
// wm/casing. The system names no gun's sounds.
//
// -------------------------------------------------------------- ARCHETYPES
//
// `archetype <name>` ... `end`, in any lump, holds verb blocks and one `type` line.
// A card's `mechanism = <name>` takes them; a verb block on the card under the
// same id changes only the keys it states; a new id is added. A card naming an
// archetype no lump declared -- or one that was itself refused -- is refused.
//
// ------------------------------------------------------------- INHERITANCE
//
// A card's `base = <id>` starts it from another card: a FRESH COPY of that card, read again
// from its own lump (so no part, and none of the live state on one, is shared), with this
// card's own lines laid over it (ResolveBases, as the cards load, before any sheet borrows a
// card). Every key it states replaces the base's. A `part`, `store`, `verb` or `barrel`
// block under an id the base has REPLACES that one whole, in its place; a new id is added.
// `remove part <id>` (or store, verb, barrel), on a line after `base`, takes one of the
// base's away. The base's synthesised stores are dropped and synthesised again for the whole
// card, so a child that declares a store gets no pistol pair beside it. A base may have a
// base, up to MAX_BASE_DEPTH; a base that cannot be built leaves the child unloaded, said
// with its line. A twin gun -- the same mesh on another skin, with other handling sounds, in
// the other hand, or reloaded another way -- is its base plus the lines that differ.
//
// -------------------------------------------------------------- THROWABLES
//
// A weapon that leaves the hand (throw.zs): `throw`, `route` and `fuse` each open ALONE, `mount <id>`
// opens with its id, and each closes with `end` -- one of each a card, on a card only.
// `pouch = whole` is a card key. `pulloff` and `release` are verb blocks like any other, so an
// archetype may hold them. Whether it all fits together -- a route or a fuse with no throw, a catch
// on a weapon that never comes back, a stow with no mount -- is decided once the card is whole
// (ThrowableProblem).
//
// ------------------------------------------ A KEY IS NEVER A BLOCK HEADER
//
// `store = mag` and `part = slide` are keys in a verb block. Read as headers
// they opened a store, or a part, named "=". Every block keyword is guarded the
// same way: a line whose second word begins with `=` is a key.
//
// ------------------------------------ MORE SURFACES THAN SLOTS IS A REFUSAL
//
// A gun has WM_Rig.SLOTS surface-override slots. A card whose parts name more
// moving surfaces than that used to load, log, and leave the parts past the
// limit silently never moving. It is refused at the part that crosses it.
// ============================================================================

class WM_Parser
{
	static WM_CardSet ParseAll(String text, String sourceName, WM_CardSet into = null, WM_Card overlayOnto = null)
	{
		let set = into ? into : new("WM_CardSet");

		Array<String> lines;
		text.Split(lines, "\n");

		// A CHILD CARD'S OWN LINES laid over a fresh copy of its base (FreshCard): the copy is the card being read, a
		// block under an id it already has replaces that one, and `remove` takes one away. null for every lump read.
		WM_Card      card     = overlayOnto;
		WM_Archetype arch     = null;
		bool         refused  = false;
		WM_Part      curPart  = null;
		WM_Dof       curDof   = null;
		WM_Store     curStore = null;
		WM_Verb      curVerb  = null;
		WM_Barrel    curBarrel = null;   // a `barrel <id>` block open on this card (card.zs WM_Barrel)
		WM_Throw     curThrow = null;    // a `throw` block open on this card (throw.zs)
		WM_Route     curRoute = null;    // a `route` block
		WM_Fuse      curFuse  = null;    // a `fuse` block
		WM_Mount     curMount = null;    // a `mount <id>` block
		int          surfaceTotal = 0;   // moving surfaces named by this card's closed parts

		for (int ln = 0; ln < lines.Size(); ln++)
		{
			String raw = lines[ln];
			int hash = raw.IndexOf("#");
			if (hash >= 0) raw = raw.Left(hash);
			raw.StripLeftRight();
			if (raw.Length() == 0) continue;

			Array<String> words;
			raw.Split(words, " ", TOK_SKIPEMPTY);
			String head   = words.Size() > 0 ? words[0].MakeLower() : "";
			String second = words.Size() > 1 ? words[1] : "";
			int    nWords = words.Size();

			// A new weapon, or a new archetype, closes whatever came before it.
			bool weaponLine = IsHeader(head, "weapon", nWords, second);
			bool archLine   = IsHeader(head, "archetype", nWords, second);
			if (weaponLine || archLine)
			{
				// A CHILD'S OWN LINES end at the next card (BlockBody stops there too).
				if (overlayOnto) break;
				if (card && !refused) Accept(set, card, curStore, curVerb, curBarrel, ThrowableBlockOpen(curThrow, curRoute, curFuse, curMount), sourceName, ln + 1);
				if (arch && !refused) Refuse(sourceName, ln + 1, "archetype " .. arch.id, "its block was never closed with `end`");
				card     = null;
				arch     = null;
				refused  = false;
				curPart  = null;
				curDof   = null;
				curStore = null;
				curVerb  = null;
				curBarrel = null;
				curThrow = null;
				curRoute = null;
				curFuse  = null;
				curMount = null;
				surfaceTotal = 0;
				if (weaponLine)
				{
					card = NewCard(Unquote(second));
					card.sourceName = sourceName;
				}
				else
				{
					String archWhy = "";
					if (nWords > 2) archWhy = "one key per line: `archetype <name>` alone, then its verb blocks, then `end`";
					else if (set.FindArchetype(Unquote(second)) != null) archWhy = "an archetype by that name was already read";
					if (archWhy != "")
					{
						Refuse(sourceName, ln + 1, raw, archWhy);
						refused = true;      // skipping to the next weapon or archetype
					}
					else
					{
						arch = new("WM_Archetype");
						arch.id = Unquote(second);
						arch.sourceName = sourceName;
						arch.line = ln + 1;
					}
				}
				continue;
			}

			if (refused) continue;          // skipping to the next weapon or archetype
			if (!card && !arch)
			{
				Refuse(sourceName, ln + 1, raw, "nothing here belongs to a `weapon` or an `archetype` line");
				continue;
			}

			String lower = raw.MakeLower();
			String thrOpen = ThrowableBlockOpen(curThrow, curRoute, curFuse, curMount);   // "" when none is open
			if (lower == "end")
			{
				if (curDof != null) curDof = null;
				else if (curPart != null)
				{
					// NO MORE MOVING SURFACES THAN A GUN HAS OVERRIDE SLOTS. Past
					// the limit WM_Rig.Bind can only log and skip, and the part
					// silently never moves -- so the card is refused here, at the
					// part that crossed it, like any other thing a card gets wrong.
					surfaceTotal += curPart.surfaceNames.Size();
					// A SECOND STAGE THE ENGINE WOULD REFUSE is refused here, with the line, rather
					// than leaving the part silently single-stage in the hand.
					String stageWhy = StageTwoProblem(curPart);   // "" for a part with no dof2
					if (stageWhy != "")
					{
						Refuse(sourceName, ln + 1, "part " .. curPart.id, stageWhy);
						refused = true;
					}
					else if (!overlayOnto && surfaceTotal > WM_Rig.SLOTS)
					{
						Refuse(sourceName, ln + 1, "part " .. curPart.id, String.Format(
							"the parts so far name %d moving surfaces and a gun has %d override slots -- past that a part never moves",
							surfaceTotal, WM_Rig.SLOTS));
						refused = true;
					}
					// A CHILD'S PART UNDER A BASE PART'S ID replaces it, in its place. Its surfaces are counted once the
					// card is whole (FreshCard).
					else if (overlayOnto && card.FindPartIndex(curPart.id) >= 0) card.parts[card.FindPartIndex(curPart.id)] = curPart;
					else card.parts.Push(curPart);
					curPart = null;
				}
				else if (curStore != null)
				{
					// A CHILD'S STORE UNDER A BASE STORE'S NAME replaces it, in its place.
					int baseStore = -1;
					if (overlayOnto)
					{
						for (int k = 0; k < card.stores.Size(); k++)
							if (card.stores[k].id ~== curStore.id) { baseStore = k; break; }
					}
					if (baseStore >= 0) card.stores.Delete(baseStore);
					String bad = StoreProblem(card, curStore);
					if (bad != "")
					{
						Refuse(sourceName, ln + 1, "store " .. curStore.id, bad);
						refused = true;
					}
					else if (baseStore >= 0) card.stores.Insert(baseStore, curStore);
					else card.stores.Push(curStore);
					curStore = null;
				}
				else if (curBarrel != null)
				{
					// ONE ID PER BARREL on a card. What it names is checked once the card is whole
					// (FinishCard, BarrelProblem): its store and verbs may come after it.
					let twinBarrel = card.FindBarrel(curBarrel.id);
					if (twinBarrel != null && !overlayOnto)
					{
						Refuse(sourceName, ln + 1, "barrel " .. curBarrel.id, "a barrel by that id is already declared on this card");
						refused = true;
					}
					// A CHILD'S BARREL UNDER A BASE BARREL'S ID replaces it, in its place.
					else if (twinBarrel != null)
					{
						for (int k = 0; k < card.barrels.Size(); k++)
							if (card.barrels[k] == twinBarrel) card.barrels[k] = curBarrel;
					}
					else card.barrels.Push(curBarrel);
					curBarrel = null;
				}
				// A THROWABLE'S BLOCKS (throw.zs): one of each a card. How they fit together is checked once
				// the card is whole (ThrowableProblem).
				else if (thrOpen != "")
				{
					// (A child's block of a kind its base already has replaces the base's.)
					if (!overlayOnto && ((curThrow && card.throwSpec) || (curRoute && card.routeSpec) || (curFuse && card.fuseSpec) || (curMount && card.mountSpec)))
					{
						Refuse(sourceName, ln + 1, thrOpen, "a card has one block of this kind");
						refused = true;
					}
					else if (curThrow) card.throwSpec = curThrow;
					else if (curRoute) card.routeSpec = curRoute;
					else if (curFuse)  card.fuseSpec  = curFuse;
					else               card.mountSpec = curMount;
					curThrow = null;
					curRoute = null;
					curFuse  = null;
					curMount = null;
				}
				else if (curVerb != null)
				{
					// ONE ID PER VERB in a card or an archetype. Complete or not is
					// Finish's question; a second block by one id is this one's.
					WM_Verb twin = null;
					if (card) twin = card.FindVerb(curVerb.id);
					else      twin = arch.FindVerb(curVerb.id);
					if (twin != null && !overlayOnto)
					{
						Refuse(sourceName, ln + 1, WM_Verb.KindName(curVerb.kind) .. " " .. curVerb.id,
							"a verb by that id is already declared here -- ids name verbs, so each is said once");
						refused = true;
					}
					// A CHILD'S VERB UNDER A BASE VERB'S ID replaces it, in its place.
					else if (twin != null)
					{
						for (int k = 0; k < card.verbs.Size(); k++)
							if (card.verbs[k] == twin) card.verbs[k] = curVerb;
					}
					else if (card) card.verbs.Push(curVerb);
					else           arch.verbs.Push(curVerb);
					curVerb = null;
				}
				else if (arch != null)
				{
					if (arch.verbs.Size() == 0)
					{
						Refuse(sourceName, ln + 1, "archetype " .. arch.id, "it holds no verb blocks -- an archetype supplies verbs and nothing else");
						refused = true;
					}
					else set.archetypes.Push(arch);
					arch = null;
				}
				// Otherwise it is the weapon line's own `end`, which closes nothing:
				// the card runs to the next `weapon` or `archetype` line.
				continue;
			}

			// `remove part|store|verb|barrel <id>` (INHERITANCE): a card with a base takes one of the base's away. On the
			// card's own first reading only its words are checked; it is done as the card is built from its base (FreshCard).
			if (head == "remove" && nWords >= 2 && second.Left(1) != "=")
			{
				String rmKind = second.MakeLower();
				String rmId   = (nWords == 3) ? Unquote(words[2]) : "";
				String rmWhy  = "";
				if (arch != null) rmWhy = "an archetype holds verb blocks only -- remove belongs on a card with a base";
				else if (curPart != null || curStore != null || curVerb != null || curBarrel != null || curDof != null || thrOpen != "")
					rmWhy = "remove sits between blocks -- close the open block with `end` first";
				else if (card.baseId == "") rmWhy = "remove takes something from a base card -- say base = <card> on an earlier line";
				else if (nWords != 3 || (rmKind != "part" && rmKind != "store" && rmKind != "verb" && rmKind != "barrel"))
					rmWhy = "remove part <id>, remove store <id>, remove verb <id> or remove barrel <id> -- one a line";
				else if (overlayOnto)
				{
					bool removed = false;
					if (rmKind == "part")
					{
						int rp = card.FindPartIndex(rmId);
						if (rp >= 0) { card.parts.Delete(rp); removed = true; }
					}
					else if (rmKind == "store")
					{
						for (int k = 0; k < card.stores.Size() && !removed; k++)
							if (card.stores[k].id ~== rmId) { card.stores.Delete(k); removed = true; }
					}
					else if (rmKind == "verb")
					{
						for (int k = 0; k < card.verbs.Size() && !removed; k++)
							if (card.verbs[k].id ~== rmId) { card.verbs.Delete(k); removed = true; }
					}
					else
					{
						for (int k = 0; k < card.barrels.Size() && !removed; k++)
							if (card.barrels[k].id ~== rmId) { card.barrels.Delete(k); removed = true; }
					}
					if (!removed) rmWhy = String.Format("the base card has no %s %s to remove", rmKind, rmId);
				}
				if (rmWhy != "")
				{
					Refuse(sourceName, ln + 1, raw, rmWhy);
					refused = true;
				}
				continue;
			}

			if (IsHeader(head, "part", nWords, second))
			{
				String partWhy = "";
				if (arch != null)          partWhy = "an archetype holds verb blocks only -- parts are measured on each weapon's own card";
				else if (curStore != null) partWhy = "a part cannot open inside a store block -- close the store with `end` first";
				else if (curVerb != null)  partWhy = "a part cannot open inside a verb block -- close the verb with `end` first";
				else if (curPart != null)  partWhy = "a part cannot open inside another part -- close it with `end` first";
				else if (curBarrel != null) partWhy = "a part cannot open inside a barrel block -- close the barrel with `end` first";
				else if (thrOpen != "")     partWhy = String.Format("a part cannot open inside a %s block -- close it with `end` first", thrOpen);
				if (partWhy != "")
				{
					Refuse(sourceName, ln + 1, raw, partWhy);
					refused = true;
					continue;
				}
				curPart = NewPart(Unquote(second));
				curPart.line = ln + 1;
				continue;
			}

			// `store <name>` opens a block. `store = mag` is a KEY (a swap verb
			// names its store that way), so a second word starting with `=` is not
			// a header.
			if (IsHeader(head, "store", nWords, second))
			{
				String whyNot = "";
				if (arch != null)          whyNot = "an archetype holds verb blocks only -- stores are declared on each weapon's own card";
				else if (curPart != null)  whyNot = "a store cannot open inside a part block -- close the part with `end` first";
				else if (curStore != null) whyNot = "a store cannot open inside another store -- close it with `end` first";
				else if (curVerb != null)  whyNot = "a store cannot open inside a verb block -- close the verb with `end` first";
				else if (curBarrel != null) whyNot = "a store cannot open inside a barrel block -- close the barrel with `end` first";
				else if (thrOpen != "")     whyNot = String.Format("a store cannot open inside a %s block -- close it with `end` first", thrOpen);
				else if (nWords > 2)       whyNot = "one key per line: `store <name>` alone, then its keys, then `end`";
				if (whyNot != "")
				{
					Refuse(sourceName, ln + 1, raw, whyNot);
					refused = true;
					continue;
				}
				curStore = NewStore(Unquote(second));
				continue;
			}

			// `barrel <id>` opens a SECOND BARREL block (card.zs WM_Barrel). `barrel = x, y, z` is a
			// KEY -- the card's bore direction, or inside the block that barrel's -- because a
			// second word starting with `=` is not a header.
			if (IsHeader(head, "barrel", nWords, second))
			{
				String barrelWhy = "";
				if (arch != null)           barrelWhy = "an archetype holds verb blocks only -- a second barrel is declared on each weapon's own card";
				else if (curPart != null)   barrelWhy = "a barrel cannot open inside a part block -- close the part with `end` first";
				else if (curStore != null)  barrelWhy = "a barrel cannot open inside a store block -- close the store with `end` first";
				else if (curVerb != null)   barrelWhy = "a barrel cannot open inside a verb block -- close the verb with `end` first";
				else if (curBarrel != null) barrelWhy = "a barrel cannot open inside another barrel -- close it with `end` first";
				else if (thrOpen != "")     barrelWhy = String.Format("a barrel cannot open inside a %s block -- close it with `end` first", thrOpen);
				else if (nWords > 2)        barrelWhy = "one key per line: `barrel <id>` alone, then its keys, then `end`";
				if (barrelWhy != "")
				{
					Refuse(sourceName, ln + 1, raw, barrelWhy);
					refused = true;
					continue;
				}
				curBarrel = NewBarrel(Unquote(second));
				curBarrel.line = ln + 1;
				continue;
			}

			// A THROWABLE'S BLOCKS (throw.zs): `throw`, `route` and `fuse` open ALONE -- `throw = ...` is a
			// key no card has, so it is refused as unknown -- and `mount <id>` opens with its id.
			bool throwHead = (head == "throw" || head == "route" || head == "fuse") && (nWords == 1 || second.Left(1) != "=");
			if (throwHead || IsHeader(head, "mount", nWords, second))
			{
				String thrWhy = "";
				if (arch != null)           thrWhy = String.Format("an archetype holds verb blocks only -- a %s block is declared on each weapon's own card", head);
				else if (curPart != null)   thrWhy = String.Format("a %s block cannot open inside a part -- close the part with `end` first", head);
				else if (curStore != null)  thrWhy = String.Format("a %s block cannot open inside a store -- close the store with `end` first", head);
				else if (curVerb != null)   thrWhy = String.Format("a %s block cannot open inside a verb block -- close the verb with `end` first", head);
				else if (curBarrel != null) thrWhy = String.Format("a %s block cannot open inside a barrel -- close the barrel with `end` first", head);
				else if (thrOpen != "")     thrWhy = String.Format("a %s block cannot open inside a %s block -- close it with `end` first", head, thrOpen);
				else if (throwHead && nWords > 1)  thrWhy = String.Format("one key per line: `%s` alone, then its keys, then `end`", head);
				else if (!throwHead && nWords > 2) thrWhy = "one key per line: `mount <id>` alone, then its keys, then `end`";
				if (thrWhy != "")
				{
					Refuse(sourceName, ln + 1, raw, thrWhy);
					refused = true;
					continue;
				}
				if (head == "throw")      { curThrow = new("WM_Throw"); curThrow.Init(); curThrow.line = ln + 1; }
				else if (head == "route") { curRoute = new("WM_Route"); curRoute.Init(); curRoute.line = ln + 1; }
				else if (head == "fuse")  { curFuse  = new("WM_Fuse");  curFuse.Init();  curFuse.line  = ln + 1; }
				else                      { curMount = new("WM_Mount"); curMount.Init(Unquote(second)); curMount.line = ln + 1; }
				continue;
			}

			// `cycle rack`, `swap magwell` ... opens a verb block, in a card or in an
			// archetype.
			int verbKind = WM_Verb.KindFromWord(head);
			if (verbKind >= 0 && IsHeader(head, head, nWords, second))
			{
				String verbWhy = "";
				if (curPart != null)       verbWhy = "a verb block cannot open inside a part -- close the part with `end` first";
				else if (curStore != null) verbWhy = "a verb block cannot open inside a store -- close the store with `end` first";
				else if (curVerb != null)  verbWhy = "a verb block cannot open inside another verb -- close it with `end` first";
				else if (curBarrel != null) verbWhy = "a verb block cannot open inside a barrel -- close the barrel with `end` first";
				else if (thrOpen != "")     verbWhy = String.Format("a verb block cannot open inside a %s block -- close it with `end` first", thrOpen);
				else if (nWords > 2)       verbWhy = String.Format("one key per line: `%s <id>` alone, then its keys, then `end`", head);
				if (verbWhy != "")
				{
					Refuse(sourceName, ln + 1, raw, verbWhy);
					refused = true;
					continue;
				}
				curVerb = new("WM_Verb");
				curVerb.Init(verbKind, Unquote(second));
				curVerb.sourceName = sourceName;
				curVerb.line = ln + 1;
				continue;
			}

			// `dof` alone opens a part's dof block; `dof = ...` is not a header.
			if (head == "dof" && curPart != null && (nWords == 1 || second.Left(1) != "="))
			{
				curDof = curPart.dof;
				continue;
			}

			// `index` alone opens a part's PER-SHOT INDEX (WM_Part.indexDof, G13); `index = ...` is not
			// a header. Its keys go to IndexKey, told apart by curDof being that part's index, and its
			// `end` closes it exactly as a dof's does.
			if (head == "index" && curPart != null && (nWords == 1 || second.Left(1) != "="))
			{
				String indexWhy = "";
				if (curDof != null)                indexWhy = "an index cannot open inside a dof block -- close the dof with `end` first";
				else if (curPart.indexDof != null) indexWhy = "a part has one index -- its step is said once";
				else if (nWords > 1)               indexWhy = "one key per line: `index` alone, then its keys, then `end`";
				if (indexWhy != "")
				{
					Refuse(sourceName, ln + 1, raw, indexWhy);
					refused = true;
					continue;
				}
				curPart.indexDof = new("WM_Dof");
				curPart.indexDof.moveKind = WM_Dof.MOVE_SLIDE;
				curDof = curPart.indexDof;
				continue;
			}

			// `dof2` alone opens a part's SECOND STAGE (WM_Part.dof2); `dof2 = ...` is not a
			// header. Its keys go to Dof2Key, told apart by curDof being that part's dof2, and
			// its `end` closes it exactly as a dof's does.
			if (head == "dof2" && curPart != null && (nWords == 1 || second.Left(1) != "="))
			{
				String twoWhy = "";
				if (curDof != null)            twoWhy = "a dof2 cannot open inside a dof block -- close the dof with `end` first";
				else if (curPart.dof2 != null) twoWhy = "a part has one dof2 -- its second stage is said once";
				else if (nWords > 1)           twoWhy = "one key per line: `dof2` alone, then its keys, then `end`";
				if (twoWhy != "")
				{
					Refuse(sourceName, ln + 1, raw, twoWhy);
					refused = true;
					continue;
				}
				curPart.dof2 = NewStageTwo();
				curDof = curPart.dof2;
				continue;
			}

			int eq = raw.IndexOf("=");
			if (eq < 0)
			{
				Refuse(sourceName, ln + 1, raw, "expected key = value");
				refused = true;
				continue;
			}
			String key = raw.Left(eq);    key.StripLeftRight(); key = key.MakeLower();
			String val = raw.Mid(eq + 1); val.StripLeftRight();

			bool ok = true;
			String why = "";
			if (curDof != null && curPart != null && curDof == curPart.dof2) { why = Dof2Key(curDof, key, val); ok = (why == ""); }
			else if (curDof != null && curPart != null && curDof == curPart.indexDof) { why = IndexKey(curPart, key, val); ok = (why == ""); }
			else if (curDof != null)   ok = DofKey(curDof, key, val);
			else if (curPart != null)  ok = PartKey(curPart, key, val);
			else if (curStore != null) { why = StoreKey(curStore, key, val); ok = (why == ""); }
			else if (curBarrel != null) { why = BarrelKey(curBarrel, key, val); ok = (why == ""); }
			else if (curThrow != null)  { why = ThrowKey(curThrow, key, val); ok = (why == ""); }
			else if (curRoute != null)  { why = RouteKey(curRoute, key, val); ok = (why == ""); }
			else if (curFuse != null)   { why = FuseKey(curFuse, key, val); ok = (why == ""); }
			else if (curMount != null)  { why = MountKey(curMount, key, val); ok = (why == ""); }
			else if (curVerb != null)  { why = VerbKey(curVerb, key, val); ok = (why == ""); }
			else if (arch != null)
			{
				// AN ARCHETYPE MAY SAY WHAT KIND OF GUN IT MAKES -- `type = shotgun` -- which a
				// card on it with no `type` of its own inherits (FinishCard, handprofile.zs).
				// Anything else outside a verb block is refused, as it always was.
				if (key == "type")
				{
					String archType = Unquote(val).MakeLower();
					String archTypeBad = WM_HandProfile.WordProblem(archType);
					if (archTypeBad == "") arch.gunType = archType;
					else why = "type " .. archTypeBad;
				}
				else why = "an archetype holds verb blocks and one `type` line -- cycle, open, swap, load, eject";
				ok = (why == "");
			}
			else                       { why = CardKey(card, key, val, ln + 1); ok = (why == ""); }

			if (!ok)
			{
				if (why == "")
					why = curDof ? "unknown key in a dof block" : (curPart ? "unknown key in a part block" : "unknown key");
				Refuse(sourceName, ln + 1, key, why);
				refused = true;
			}
		}

		if (card && !refused) Accept(set, card, curStore, curVerb, curBarrel, ThrowableBlockOpen(curThrow, curRoute, curFuse, curMount), sourceName, lines.Size());
		if (arch && !refused) Refuse(sourceName, lines.Size(), "archetype " .. arch.id, "its block was never closed with `end`");
		return set;
	}

	// A BLOCK OPENS ON `<keyword> <name>` -- and only then. A line whose second
	// word begins with `=` is a KEY that happens to share the keyword's spelling.
	private static bool IsHeader(String head, String keyword, int nWords, String second)
	{
		return head == keyword && nWords >= 2 && second.Left(1) != "=";
	}

	// THE THROWABLE BLOCK OPEN ON THIS CARD (throw.zs), as its header -- "throw", "route", "fuse" or
	// "mount <id>" -- or "" when none is.
	private static String ThrowableBlockOpen(WM_Throw t, WM_Route r, WM_Fuse f, WM_Mount m)
	{
		if (t != null) return "throw";
		if (r != null) return "route";
		if (f != null) return "fuse";
		if (m != null) return "mount " .. m.id;
		return "";
	}

	// A CARD IS ACCEPTED ONCE IT IS WHOLE: its stores complete -- declared, or
	// synthesised here for a card that declared none -- and then it joins the
	// set. A store or verb block still open at the end of its card is refused
	// rather than dropped: dropping a store would synthesise the pistol pair in
	// its place and say nothing, and dropping a verb would synthesise the old
	// behaviour in its place.
	private static void Accept(WM_CardSet set, WM_Card card, WM_Store openStore, WM_Verb openVerb, WM_Barrel openBarrel, String openThrowable, String src, int line)
	{
		if (openBarrel != null)
		{
			Refuse(src, line, "barrel " .. openBarrel.id, "its block was never closed with `end`");
			return;
		}
		if (openThrowable != "")
		{
			Refuse(src, line, openThrowable, "its block was never closed with `end`");
			return;
		}
		if (openStore != null)
		{
			Refuse(src, line, "store " .. openStore.id, "its block was never closed with `end`");
			return;
		}
		if (openVerb != null)
		{
			Refuse(src, line, WM_Verb.KindName(openVerb.kind) .. " " .. openVerb.id, "its block was never closed with `end`");
			return;
		}
		card.SynthesiseStores();
		set.cards.Push(card);
	}

	// ---- INHERITANCE: A CARD THAT STARTS FROM ANOTHER (card `base = <id>`) --------------------------------
	//
	// Every card with a base is built whole in its own place in the set -- the order is kept, because CardForAmmo and
	// Equip read it -- before any sheet borrows a card (sheet.zs BorrowModels) and before Finish checks it like any card.
	// A card whose base cannot be built leaves the set, said with its line. Load-time data, read alike on every machine.
	const MAX_BASE_DEPTH = 8;

	static void ResolveBases(WM_CardSet set)
	{
		Array<WM_Card> kept;
		for (int i = 0; i < set.cards.Size(); i++)
		{
			let c = set.cards[i];
			if (c.baseId == "") { kept.Push(c); continue; }
			let built = FreshCard(set, c.weaponClass);
			if (built) kept.Push(built);
		}
		set.cards.Clear();
		for (int i = 0; i < kept.Size(); i++) set.cards.Push(kept[i]);
	}

	// A FRESH, WHOLE COPY OF CARD <id>: read again from its own WMCARD lump -- no part object shared with the card the set
	// already holds -- and, when it has a base, built from a fresh copy of that base with its own lines laid over it.
	// null when it cannot be built, with the reason said. sheet.zs BorrowModels takes its copies here, so a gun that
	// borrows a card with a base gets it whole. A refusal in a lump is printed again as that lump is read again.
	static WM_Card FreshCard(WM_CardSet set, String id, int depth = 0)
	{
		WM_Card rec = null;
		for (int i = 0; i < set.cards.Size(); i++)
			if (set.cards[i].weaponClass ~== id && set.cards[i].modelId == "") { rec = set.cards[i]; break; }
		if (!rec)
		{
			Console.Printf("\c[Red]WM ERROR\c- a card starts from or borrows %s, and no card by that id was read (or it was refused).", id);
			return null;
		}
		String text = Wads.ReadLump(rec.sourceLump);
		let scratch = new("WM_CardSet");
		ParseAll(text, "WMCARD", scratch);
		WM_Card own = null;
		for (int i = 0; i < scratch.cards.Size(); i++)
			if (scratch.cards[i].weaponClass ~== id) { own = scratch.cards[i]; break; }
		if (!own)
		{
			Console.Printf("\c[Red]WM ERROR\c- card %s could not be read again from its WMCARD lump.", id);
			return null;
		}
		own.sourceLump = rec.sourceLump;
		if (own.baseId == "") return own;

		if (depth >= MAX_BASE_DEPTH)
		{
			Refuse(own.sourceName, own.baseLine, "base " .. own.baseId, String.Format("cards more than %d deep -- does a base lead back to this card?", MAX_BASE_DEPTH));
			return null;
		}
		let built = FreshCard(set, own.baseId, depth + 1);
		if (!built)
		{
			Refuse(own.sourceName, own.baseLine, "base " .. own.baseId, "that base card could not be built, so this card is not loaded");
			return null;
		}
		// THE BASE'S SYNTHESISED STORES go: the whole card is synthesised again as it is accepted, from its own keys.
		for (int k = built.stores.Size() - 1; k >= 0; k--)
			if (built.stores[k].synthesised) built.stores.Delete(k);
		built.weaponClass = own.weaponClass;
		let whole = new("WM_CardSet");
		ParseAll(BlockBody(text, own.weaponClass), own.sourceName, whole, built);
		if (whole.cards.Size() == 0) return null;    // refused as its own lines were laid over the base, with the line
		int surfaces = 0;
		for (int p = 0; p < built.parts.Size(); p++) surfaces += built.parts[p].surfaceNames.Size();
		if (surfaces > WM_Rig.SLOTS)
		{
			Refuse(own.sourceName, own.baseLine, "base " .. own.baseId, String.Format(
				"with its base's parts the card names %d moving surfaces and a gun has %d override slots -- past that a part never moves",
				surfaces, WM_Rig.SLOTS));
			return null;
		}
		built.sourceName = own.sourceName;
		built.sourceLump = rec.sourceLump;
		built.modelId    = "";
		built.baseId     = own.baseId;
		built.baseLine   = own.baseLine;
		return built;
	}

	// CARD <weaponClass>'S OWN LINES from its lump's text: an empty line for every line up to and including its `weapon`
	// line, so each keeps its number for a refusal, then its lines up to the next `weapon` or `archetype` line.
	static String BlockBody(String text, String weaponClass)
	{
		Array<String> lines;
		text.Split(lines, "\n");
		String body = "";
		bool inside = false;
		for (int ln = 0; ln < lines.Size(); ln++)
		{
			String raw = lines[ln];
			int hash = raw.IndexOf("#");
			if (hash >= 0) raw = raw.Left(hash);
			raw.StripLeftRight();
			Array<String> words;
			raw.Split(words, " ", TOK_SKIPEMPTY);
			String head   = words.Size() > 0 ? words[0].MakeLower() : "";
			String second = words.Size() > 1 ? words[1] : "";
			if (IsHeader(head, "weapon", words.Size(), second) || IsHeader(head, "archetype", words.Size(), second))
			{
				if (inside) break;
				inside = (head == "weapon" && Unquote(second) ~== weaponClass);
				body = body .. "\n";
				continue;
			}
			body = body .. (inside ? lines[ln] : "") .. "\n";
		}
		return body;
	}

	// ---- AFTER EVERY LUMP: MECHANISMS, SYNTHESIS, AND WHAT EACH VERB NAMES --------
	//
	// An archetype may be in any WMCARD lump, before or after the cards that follow
	// it, so nothing about a card's verbs is settled until every lump has been read.
	// A card refused here leaves the set -- with the lump and line of the verb or
	// the mechanism it got wrong -- and every other card carries on.
	static void Finish(WM_CardSet set)
	{
		Array<WM_Card> kept;
		for (int i = 0; i < set.cards.Size(); i++)
		{
			let card = set.cards[i];
			String why, what, src;
			int line;
			[why, what, src, line] = FinishCard(set, card);
			if (why == "")
			{
				kept.Push(card);
				continue;
			}
			Refuse(src, line, what, why);
		}
		set.cards.Copy(kept);
		set.finished = true;
		set.typed    = true;
		set.throwablesRead = true;
	}

	private static String, String, String, int FinishCard(WM_CardSet set, WM_Card card)
	{
		// 1. THE MECHANISM: an archetype's verbs, with the card's own blocks laid over
		//    them by id.
		if (card.mechanism != "")
		{
			let arch = set.FindArchetype(card.mechanism);
			if (!arch)
				return String.Format("mechanism = %s names no archetype -- no WMCARD lump declared one by that name, or it was refused", card.mechanism),
					card.weaponClass .. " mechanism", card.sourceName, card.mechanismLine;

			Array<WM_Verb> merged;
			for (int a = 0; a < arch.verbs.Size(); a++)
			{
				let av = arch.verbs[a];
				let cv = card.FindVerb(av.id);
				let mv = av.Copy();
				mv.originName = arch.id;
				if (cv)
				{
					if (cv.kind != av.kind)
						return String.Format("archetype %s's `%s` is a %s block -- a card block under its id changes it, so it must be a %s block too",
								arch.id, av.id, WM_Verb.KindName(av.kind), WM_Verb.KindName(av.kind)),
							VerbTag(card, cv), cv.sourceName, cv.line;
					// THE CARD'S KEYS, REPLAYED onto a copy of the archetype's verb, in
					// the order the card said them. Each was taken once already.
					mv.keys.Clear();
					mv.vals.Clear();
					for (int k = 0; k < cv.keys.Size(); k++) VerbKey(mv, cv.keys[k], cv.vals[k]);
					mv.origin     = WM_Verb.FROM_OVERRIDE;
					mv.sourceName = cv.sourceName;
					mv.line       = cv.line;
				}
				else mv.origin = WM_Verb.FROM_ARCHETYPE;
				merged.Push(mv);
			}
			for (int c = 0; c < card.verbs.Size(); c++)
				if (!arch.FindVerb(card.verbs[c].id)) merged.Push(card.verbs[c]);
			card.verbs.Copy(merged);
		}
		// 2. NO VERBS AND NO MECHANISM: the old role code's behaviour, as verbs.
		else card.SynthesiseVerbs();

		// 3. EVERY VERB against the card, now whole.
		for (int i = 0; i < card.verbs.Size(); i++)
		{
			let v = card.verbs[i];
			String bad = VerbProblem(card, v, i);
			if (bad != "")
			{
				String vsrc = (v.sourceName != "") ? v.sourceName : card.sourceName;
				int vline = (v.line > 0) ? v.line : card.mechanismLine;
				return bad, VerbTag(card, v), vsrc, vline;
			}
		}

		// 3b. EVERY ROUND SURFACE against the card's stores, now whole: a slotted store it
		//     has, and a slot that store has.
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let rp = card.parts[i];
			for (int r = 0; r < rp.roundSurfName.Size(); r++)
			{
				String rs = rp.roundSurfStore[r];
				String rwhy = "";
				int rkind = card.StoreKindFor(rs);
				if (rkind == WM_Store.COUNTED)
				{
					// ON A COUNTED STORE the third field is a count: drawn while the store holds more
					// than it (WM_Ammo.RoundShows). A count the store can never exceed would never show,
					// and a placeholder magazine holds nothing at all.
					let cst = card.FindStore(rs);
					int ccap = (cst && cst.capacity > 0) ? cst.capacity : card.capacity;
					if (cst && cst.placeholder)
						rwhy = String.Format("roundsurface %s names store %s -- that is a stand-in for a magazine this gun does not have, and holds nothing", rp.roundSurfName[r], rs);
					else if (rp.roundSurfSlot[r] >= ccap)
						rwhy = String.Format("roundsurface %s names count %d -- %s holds at most %d, and the surface is drawn while it holds MORE than that number, so it would never show",
							rp.roundSurfName[r], rp.roundSurfSlot[r], rs, ccap);
				}
				else if (rkind != WM_Store.SLOTTED)
					rwhy = String.Format("roundsurface %s names store %s -- this card has no store by that name", rp.roundSurfName[r], rs);
				else
				{
					let rst = card.FindStore(rs);
					int rslots = rst ? rst.slots.Size() : 1;
					if (rp.roundSurfSlot[r] >= rslots)
						rwhy = String.Format("roundsurface %s names slot %d -- %s has %d slot%s, counted from 0", rp.roundSurfName[r], rp.roundSurfSlot[r], rs, rslots, rslots == 1 ? "" : "s");
				}
				if (rwhy != "") return rwhy, "part " .. rp.id .. " (" .. card.weaponClass .. ")", card.sourceName, rp.line;
			}
		}

		// 3b. ...AND EVERY PER-SHOT INDEX (WM_Part.indexDof): on the magazine, within its count.
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let ip = card.parts[i];
			if (!ip.indexDof) continue;
			String indexBad = IndexProblem(card, ip);
			if (indexBad != "") return indexBad, "part " .. ip.id .. " (" .. card.weaponClass .. ")", card.sourceName, ip.line;
		}

		// 3b. ...AND EVERY METER (WM_Part.meterSurface): one of the part's own surfaces, a skin file with
		//     one %d, and a number of steps.
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let mp = card.parts[i];
			if (mp.meterSurface == "" && mp.meterSkinFile == "" && mp.meterSteps == 0) continue;
			String meterWhy = MeterProblem(mp);
			if (meterWhy != "") return meterWhy, "part " .. mp.id .. " (" .. card.weaponClass .. ")", card.sourceName, mp.line;
		}

		// 3b. ...AND EVERY FLIPPING PART (WM_Part.flipBy): shown by flip alone, on a phase and a beat.
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let fp = card.parts[i];
			if (fp.flipBy == WM_Part.FLIP_NONE) continue;
			String flipWhy = FlipProblem(fp);
			if (flipWhy != "") return flipWhy, "part " .. fp.id .. " (" .. card.weaponClass .. ")", card.sourceName, fp.line;
		}

		// 3b. ...AND EVERY SPINNING PART (WM_Part.spinBy): a single-stage hinge that nothing else
		//     turns -- no role, no verb -- with a period and a rate it can be seen to turn at.
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let sp = card.parts[i];
			if (sp.spinBy == WM_Part.SPIN_NONE) continue;
			String spinWhy = SpinProblem(card, sp, i);
			if (spinWhy != "") return spinWhy, "part " .. sp.id .. " (" .. card.weaponClass .. ")", card.sourceName, sp.line;
		}

		// 3c. EVERY SECOND BARREL (card.zs WM_Barrel) against the card, now whole -- before what a
		//     pull spends, which leaves a barrel's store and the verbs that work only it alone.
		for (int i = 0; i < card.barrels.Size(); i++)
		{
			let br = card.barrels[i];
			String barrelBad = BarrelProblem(card, br, i);
			if (barrelBad != "")
				return barrelBad, "barrel " .. br.id .. " (" .. card.weaponClass .. ")", card.sourceName, br.line;
		}

		// 3d. WHAT A PULL SPENDS (WM_Card.firesFrom), against the verbs and stores now whole.
		String firesBad = FiresFromProblem(card);
		if (firesBad != "")
			return firesBad, card.weaponClass .. " firesfrom", card.sourceName, (card.firesFromLine > 0) ? card.firesFromLine : card.mechanismLine;

		// 3e. A TWO-HANDED GUN (WM_Card.handsNeeded) needs a place for the other hand to hold.
		if (card.NeedsTwoHands() && card.FindRoleIndex("support") < 0)
			return "hands = 2 needs a part with role = support -- where the other hand holds it",
				card.weaponClass .. " hands", card.sourceName, (card.handsLine > 0) ? card.handsLine : card.mechanismLine;

		// 3f. A WEAPON THAT LEAVES THE HAND (throw.zs): its throw, route, fuse, mount and pouch, and the verbs
		//     that work its pin and lever, fitting together. A card with none of them fits.
		String thrBad, thrWhat;
		int    thrLine;
		[thrBad, thrWhat, thrLine] = ThrowableProblem(card);
		if (thrBad != "")
			return thrBad, thrWhat .. " (" .. card.weaponClass .. ")", card.sourceName, (thrLine > 0) ? thrLine : card.mechanismLine;

		// 4. A PART THE OLD CODE WORKED AND NO VERB DOES. Not a refusal: step 4 demotes
		//    role and this becomes normal. But with wm_verbs on, a hand can still take
		//    it by its role and nothing will happen, so it is said.
		for (int i = 0; i < card.parts.Size(); i++)
		{
			let p = card.parts[i];
			if ((p.role == "action" || p.role == "feed") && card.VerbIndexForPart(i) < 0)
				WM_Log.Warn(String.Format("%s: part %s is role = %s and no verb works it -- with wm_verbs on a hand can take it and nothing will happen",
					card.weaponClass, p.id, p.role));
		}

		// 5. THE GUN'S TYPE, for the hand seats its hands read (handprofile.zs). The card's
		//    own `type` stands. Unstated: its archetype's `type`; for a card on pistol
		//    grammar -- no mechanism, its verbs synthesised from its action and feed
		//    parts -- pistol; otherwise none, and its hands read the uncalibrated seats.
		if (card.gunType != "") card.gunTypeFrom = "its card says so";
		else if (card.mechanism != "")
		{
			let typeArch = set.FindArchetype(card.mechanism);
			if (typeArch && typeArch.gunType != "")
			{
				card.gunType     = typeArch.gunType;
				card.gunTypeFrom = "derived from its mechanism " .. typeArch.id;
			}
			else card.gunTypeFrom = "its mechanism " .. card.mechanism .. " states no type";
		}
		else if (card.verbs.Size() > 0 && card.verbs[0].origin == WM_Verb.FROM_SYNTH)
		{
			card.gunType     = "pistol";
			card.gunTypeFrom = "derived from pistol grammar -- no mechanism, verbs synthesised from its action and feed parts";
		}
		else card.gunTypeFrom = "no type, no mechanism, and verbs of its own";
		return "", "", "", 0;
	}

	// WHY THIS CARD'S `firesfrom` CANNOT WORK, or "". A gun with no chamber (magazine) has a
	// counted store to spend and nothing that feeds or empties a chamber: no cycle -- a
	// `role = action` part synthesises one -- and no verb naming the placeholder chamber. A gun
	// that keeps no rounds (reserve, none) has no store and no verb that works one.
	private static String FiresFromProblem(WM_Card card)
	{
		if (card.KeepsNoRounds())
		{
			String keepsWord = card.FiresFromWord();
			for (int i = 0; i < card.stores.Size(); i++)
				if (!card.stores[i].placeholder && !card.IsBarrelStore(card.stores[i].id))
					return String.Format("firesfrom = %s keeps no rounds of its own -- drop store %s", keepsWord, card.stores[i].id);
			for (int i = 0; i < card.verbs.Size(); i++)
			{
				let kv = card.verbs[i];
				// A SECOND BARREL'S rounds are that barrel's (card.zs WM_Barrel): a machine gun firing
				// from the reserve still loads and empties its underbarrel launcher.
				if (card.VerbWorksOnlyABarrel(kv)) continue;
				if (kv.kind == WM_Verb.CYCLE || kv.kind == WM_Verb.SWAP || kv.kind == WM_Verb.LOAD || kv.kind == WM_Verb.EJECT)
					return String.Format("firesfrom = %s keeps no rounds, so %s %s has nothing to work -- drop it (a role = action or role = feed part synthesises one)",
						keepsWord, WM_Verb.KindName(kv.kind), kv.id);
			}
			return "";
		}
		if (!card.FiresFromMagazine()) return "";
		bool counted = false;
		for (int i = 0; i < card.stores.Size(); i++)
			if (card.stores[i].kind == WM_Store.COUNTED && !card.stores[i].placeholder && !card.IsBarrelStore(card.stores[i].id)) counted = true;
		if (!counted)
			return "firesfrom = magazine spends a counted store, and this card has none -- declare one (kind = counted, detach = yes), or declare no stores and the magazine is synthesised";
		String chamberId = card.FacadeStoreId(WM_Store.SLOTTED);
		for (int i = 0; i < card.verbs.Size(); i++)
		{
			let v = card.verbs[i];
			if (v.kind == WM_Verb.CYCLE)
				return String.Format("cycle %s strokes a round into a chamber, and firesfrom = magazine has none -- drop the cycle (a role = action part synthesises one), or say firesfrom = chamber", v.id);
			String named = "";
			if (v.kind == WM_Verb.LOAD) named = v.intoStore;
			else if (v.kind == WM_Verb.EJECT || (v.kind == WM_Verb.OPEN && v.onOpenEjectAll)) named = v.fromStore;
			if (named == "" || !(named ~== chamberId)) continue;
			let ch = card.FindStore(named);
			if (!ch || ch.placeholder)
				return String.Format("%s %s names %s -- firesfrom = magazine has no chamber", WM_Verb.KindName(v.kind), v.id, named);
		}
		return "";
	}

	// WHY A THROWABLE'S PIECES DO NOT FIT TOGETHER (throw.zs), with what to name and its line, or "" when
	// they do. Settles a throw's unstated `spends` as it goes: 1, or 0 for a weapon that comes back.
	private static String, String, int ThrowableProblem(WM_Card card)
	{
		let t = card.throwSpec;
		let r = card.routeSpec;
		let f = card.fuseSpec;
		let m = card.mountSpec;

		// ONE PIN AND ONE LEVER a weapon.
		int pullIndex  = -1;
		int leverIndex = -1;
		for (int i = 0; i < card.verbs.Size(); i++)
		{
			let v = card.verbs[i];
			if (v.kind == WM_Verb.PULLOFF)
			{
				if (pullIndex >= 0)
					return String.Format("pulloff %s already pulls this weapon's pin -- a card has one pulloff verb", card.verbs[pullIndex].id), "pulloff " .. v.id, v.line;
				pullIndex = i;
			}
			else if (v.kind == WM_Verb.RELEASE)
			{
				if (leverIndex >= 0)
					return String.Format("release %s already holds this weapon's lever -- a card has one release verb", card.verbs[leverIndex].id), "release " .. v.id, v.line;
				leverIndex = i;
			}
		}

		if (!t)
		{
			String noThrow = "this card has no throw block -- the weapon itself leaving the hand";
			if (r) return "a route steers a thrown weapon, and " .. noThrow, "route", r.line;
			if (f) return "a fuse runs on a thrown weapon, and " .. noThrow, "fuse", f.line;
			if (m) return "a mount holds a weapon that leaves the hand, and " .. noThrow, "mount " .. m.id, m.line;
			if (card.pouchWhole) return "pouch = whole hands a whole thrown weapon from the reserve, and " .. noThrow, "pouch", card.pouchLine;
			if (pullIndex >= 0)
				return "a pulloff pulls a thrown weapon's pin, and " .. noThrow, "pulloff " .. card.verbs[pullIndex].id, card.verbs[pullIndex].line;
			if (leverIndex >= 0)
				return "a release lets a thrown weapon's lever fly, and " .. noThrow, "release " .. card.verbs[leverIndex].id, card.verbs[leverIndex].line;
			return "", "", 0;
		}

		// ---- THE THROW ----------------------------------------------------------------
		if (t.on == WM_Throw.ON_UNSTATED)
			return "a throw block needs on = trigger | grip -- the let-go that throws it", "throw", t.line;
		if (t.flightClass == "")
			return "a throw block needs flight = \"<actor>\" -- what flies", "throw", t.line;
		if (card.firesFrom != WM_Card.FIRES_NOTHING)
			return "a thrown weapon's shot is the weapon leaving the hand -- say firesfrom = none", "throw", (card.firesFromLine > 0) ? card.firesFromLine : t.line;
		if (card.barrels.Size() > 0)
			return String.Format("barrel %s -- a thrown weapon has no second barrel", card.barrels[0].id), "throw", t.line;
		if (!t.spendsStated) t.spends = t.returns ? 0 : 1;
		if (t.returns)
		{
			if (t.spends > 0)
				return String.Format("spends = %d -- a weapon that comes back is the same one, and spends nothing: say spends = 0", t.spends), "throw", t.line;
			if (t.after == WM_Throw.AFTER_NEXT)
				return "after = next puts the next one in the hand at once -- a weapon that comes back is the same one: say after = previous or empty", "throw", t.line;
			if (t.miss == WM_Throw.MISS_STOW && !m)
				return String.Format("miss = stow%s puts a returning weapon back on its mount, and this card has no mount block -- declare one, or say miss = drop",
					t.missStated ? "" : " (unset)"), "throw", t.line;
			if (f) return "a fuse goes off -- a weapon that comes back has none", "fuse", f.line;
		}
		else
		{
			if (t.catchByGrip)   return "catch = grip takes back a weapon that comes back, and this one does not -- say returns = yes", "throw", t.line;
			if (t.recallByGrip)  return "recall = grip turns a flying weapon home early, and this one never comes back -- say returns = yes", "throw", t.line;
			if (t.missStated)    return "miss says what becomes of a returning weapon not caught, and this one never comes back", "throw", t.line;
		}
		if (t.catchAtStated && !t.catchByGrip)
			return "catchat is the radius catch = grip takes it back in -- this throw has no catch", "throw", t.line;
		if (card.pouchWhole && t.spends < 1)
			return "pouch = whole hands a whole one from the reserve a throw spends, and this throw spends nothing", "pouch", card.pouchLine;

		// ---- THE ROUTE ----------------------------------------------------------------
		if (r)
		{
			if (!r.paintByFire) return "a route needs paint = fire -- how it is painted", "route", r.line;
			if (t.on == WM_Throw.ON_TRIGGER)
				return "a route is painted while fire is held, and this weapon is thrown on letting go of fire -- every throw would fly off along what it painted: say on = grip", "route", r.line;
		}

		// ---- THE FUSE -----------------------------------------------------------------
		if (f)
		{
			if (f.tics <= 0) return "a fuse needs tics = <from its start to the blast>", "fuse", f.line;
			if (f.starts == WM_Fuse.STARTS_UNSTATED) return "a fuse needs starts = pulloff | release | throw -- what starts it", "fuse", f.line;
			if (f.blastClass == "") return "a fuse needs blast = \"<actor>\" -- what goes off", "fuse", f.line;
			if (f.starts == WM_Fuse.STARTS_PULLOFF && pullIndex < 0) return "starts = pulloff, and this card has no pulloff verb -- no pin to pull", "fuse", f.line;
			if (f.starts == WM_Fuse.STARTS_RELEASE && leverIndex < 0) return "starts = release, and this card has no release verb -- no lever to fly", "fuse", f.line;
		}

		// ---- THE MOUNT ----------------------------------------------------------------
		if (m)
		{
			if (m.at == WM_Mount.AT_UNSTATED) return "a mount needs at = back_left | back_right | forearm_off -- where on the body", "mount " .. m.id, m.line;
			if (!m.holdsWeapon) return "a mount needs holds = weapon -- what lives there", "mount " .. m.id, m.line;
		}
		return "", "", 0;
	}

	// Returns WHY an index key is refused, or "" when it is taken (WM_Part.indexDof, G13).
	private static String IndexKey(WM_Part p, String key, String val)
	{
		let ix = p.indexDof;
		if (key == "kind")
		{
			String indexKind = Unquote(val).MakeLower();
			if (indexKind != "slide" && indexKind != "hinge") return "kind is slide or hinge";
			ix.moveKind = (indexKind == "hinge") ? WM_Dof.MOVE_HINGE : WM_Dof.MOVE_SLIDE;
		}
		else if (key == "axis")     ix.axis     = Unit(ReadTriple(val));
		else if (key == "pivot")    ix.pivot    = ReadTriple(val);
		else if (key == "degrees")  ix.degrees  = val.ToDouble();
		else if (key == "distance") ix.distance = val.ToDouble();
		else if (key == "from" || key == "steps")
		{
			String indexCount = Unquote(val);
			if (!IsWhole(indexCount) || indexCount.ToInt() < 1) return String.Format("%s is a whole number of rounds, at least 1", key);
			if (key == "from") p.indexFrom  = indexCount.ToInt();
			else               p.indexSteps = indexCount.ToInt();
		}
		else return "unknown key in an index block -- kind, axis, pivot, degrees, distance, from or steps";
		return "";
	}

	// WHY A PART CANNOT INDEX WITH ITS MAGAZINE (WM_Part.indexDof), or "" when it can.
	private static String IndexProblem(WM_Card card, WM_Part p)
	{
		let ix = p.indexDof;
		if (p.role != "feed")
			return "an index steps the magazine with its count -- it belongs on the role = feed part";
		if (p.dof2)
			return "an index on a two-stage part is not supported -- this part has a dof2";
		if (ix.axis.Length() < 0.5)
			return "an index needs axis = x, y, z";
		if (ix.moveKind == WM_Dof.MOVE_HINGE && ix.degrees == 0)
			return "a hinge index needs degrees = <the turn a step>";
		if (ix.moveKind == WM_Dof.MOVE_SLIDE && ix.distance == 0)
			return "a slide index needs distance = <the travel a step>";
		let mag = card.FindStore(card.FacadeStoreId(WM_Store.COUNTED));
		if (!mag || mag.placeholder)
			return "an index counts the magazine, and this gun has none";
		int magCap = (mag.capacity > 0) ? mag.capacity : card.capacity;
		if (p.indexFrom > magCap)
			return String.Format("from = %d -- the magazine holds at most %d", p.indexFrom, magCap);
		if (p.indexSteps > magCap)
			return String.Format("steps = %d -- the magazine holds at most %d", p.indexSteps, magCap);
		return "";
	}

	// WHY A PART'S METER CANNOT WORK (WM_Part.meterSurface), or "" when it can.
	private static String MeterProblem(WM_Part p)
	{
		if (p.meterSurface == "" || p.meterSkinFile == "" || p.meterSteps <= 0)
			return "a meter needs all three: metersurface = <one of this part's surfaces>, meterskins = \"<path>\" \"<file with %d>\", metersteps = <how many>";
		bool meterNamed = false;
		for (int j = 0; j < p.surfaceNames.Size(); j++)
			if (p.surfaceNames[j] ~== p.meterSurface) meterNamed = true;
		if (!meterNamed) return String.Format("metersurface = %s -- that is not one of this part's surfaces", p.meterSurface);
		if (p.meterSteps > 32) return "metersteps is a whole number, 1 to 32";
		int pct = p.meterSkinFile.IndexOf("%");
		if (pct < 0 || p.meterSkinFile.Mid(pct, 2) != "%d" || p.meterSkinFile.IndexOf("%", pct + 1) >= 0)
			return String.Format("meterskins file %s needs exactly one %%d -- where the step number goes", p.meterSkinFile);
		return "";
	}

	// WHY A PART CANNOT FLIP (WM_Part.flipBy), or "" when it can.
	private static String FlipProblem(WM_Part p)
	{
		if (p.flipTics < 0 || p.flipTics > 35) return "fliptics is a whole number of tics, 1 to 35 (unset is 2)";
		if (p.flipPhase != 0 && p.flipPhase != 1) return "flipphase is 0 (shown at rest and on even beats) or 1 (shown on odd beats only)";
		if (p.role != "") return String.Format("a flipping part is shown by flip alone -- drop role = %s", p.role);
		if (p.spinBy != WM_Part.SPIN_NONE) return "a part spins or flips, not both";
		if (p.surfaceNames.Size() == 0) return "a flipping part names no surface -- there is nothing to show in turn";
		return "";
	}

	// WHY A PART CANNOT SPIN (WM_Part.spinBy), or "" when it can.
	private static String SpinProblem(WM_Card card, WM_Part p, int index)
	{
		if (p.dof2 || p.dof.moveKind != WM_Dof.MOVE_HINGE)
			return "spin turns a part about its hinge -- give it one dof of kind = hinge (axis, pivot, degrees) and no dof2";
		if (p.dof.degrees <= 0)
			return "a spinning part's degrees is one period of its pattern -- 60 for six barrels, 360 for a shape with none -- so above 0";
		if (p.spinRate == 0)
			return "spin needs spinrate = <degrees a tic at full speed> -- a negative rate turns it the other way";
		if (abs(p.spinRate) >= p.dof.degrees * 0.5)
			return String.Format("spinrate %.2f is half a period (%.2f) or more a tic -- at 35 tics a second it would look still or run backwards; keep it under %.2f",
				p.spinRate, p.dof.degrees * 0.5, p.dof.degrees * 0.5);
		if (p.spinUpTics < 0 || p.spinUpTics > 350 || p.spinDownTics < 0 || p.spinDownTics > 350)
			return "spinup and spindown are whole tics, 0 to 350";
		if (p.role != "")
			return String.Format("a spinning part is turned by spin alone -- drop role = %s", p.role);
		if (card.VerbIndexForPart(index) >= 0)
			return "a verb works this part -- a spinning part is turned by spin alone";
		if (p.surfaceNames.Size() == 0)
			return "a spinning part names no surface -- there is nothing on the mesh to turn";
		return "";
	}

	// WHY A SECOND BARREL CANNOT WORK ON THIS CARD, or "" when it can. Resolves its trigger part,
	// and gives an unstated muzzle and bore the card's own, as it goes.
	private static String BarrelProblem(WM_Card card, WM_Barrel b, int index)
	{
		if (b.input != WM_Barrel.INPUT_ALTFIRE)
			return "a barrel needs input = altfire -- the holding hand's second button, the one input a second barrel takes";
		if (b.fromStore == "") return "a barrel needs from = <the store it fires from>";
		for (int j = 0; j < index; j++)
		{
			let other = card.barrels[j];
			if (other.input == b.input)
				return String.Format("barrel %s already takes input = %s -- one barrel per input", other.id, WM_Barrel.InputWord(b.input));
			if (other.fromStore ~== b.fromStore)
				return String.Format("from = %s -- barrel %s already fires from it; each barrel has a store of its own", b.fromStore, other.id);
		}
		if (b.fromStore ~== "mag" || b.fromStore ~== "chamber")
			return String.Format("from = %s -- mag and chamber are the main barrel's names; give the barrel's store one of its own", b.fromStore);
		let st = card.FindStore(b.fromStore);
		if (!st || st.placeholder) return String.Format("from = %s -- this card declares no store by that name", b.fromStore);
		if (st.detach) return String.Format("from = %s -- a barrel's store stays in the gun, and this one is detach = yes", b.fromStore);
		b.triggerIndex = -1;
		if (b.triggerId != "")
		{
			b.triggerIndex = card.FindPartIndex(b.triggerId);
			if (b.triggerIndex < 0) return String.Format("trigger = %s -- this card has no part by that name", b.triggerId);
			let tp = card.parts[b.triggerIndex];
			if (tp.role == "trigger")
				return String.Format("trigger = %s -- that part is role = trigger, which follows the main trigger; a barrel's trigger is a part of its own", b.triggerId);
			if (card.VerbIndexForPart(b.triggerIndex) >= 0)
				return String.Format("trigger = %s -- a verb works that part; a barrel's trigger follows its button and nothing else", b.triggerId);
			if (tp.surfaceNames.Size() == 0)
				return String.Format("trigger = %s -- that part names no surface, so there is nothing to draw pulled", b.triggerId);
		}
		if (b.needsShut != "")
		{
			let gate = card.FindVerb(b.needsShut);
			if (!gate || gate.kind != WM_Verb.OPEN)
				return String.Format("needs = shut:%s -- this card has no open verb by that id", b.needsShut);
		}
		if (!b.muzzleStated) b.muzzle = card.muzzle;
		if (!b.dirStated) b.dir = card.barrel;
		return "";
	}

	private static String VerbTag(WM_Card card, WM_Verb v)
	{
		return String.Format("%s %s (%s)", WM_Verb.KindName(v.kind), v.id, card.weaponClass);
	}

	// WHY A VERB CANNOT WORK ON THIS CARD, or "" when it can. Resolves its part and
	// latch indices and settles a swap's unstated detach and hand-take as it goes.
	private static String VerbProblem(WM_Card card, WM_Verb v, int index)
	{
		String kn = WM_Verb.KindName(v.kind);

		// ---- WHAT IT WORKS --------------------------------------------------------
		if (v.kind == WM_Verb.EJECT && v.ejectByTilt)
		{
			// THE GUN IS WHAT MOVES: a part here would be a second, silent way to throw.
			if (v.partId != "") return "by = tilt (or muzzleup) is worked by pointing the gun, not by a part -- drop `part`, or say by = hand";
		}
		else if (v.kind != WM_Verb.LOAD)
		{
			if (v.partId == "") return String.Format("a %s verb needs part = <the part a hand moves>", kn);
			v.partIndex = card.FindPartIndex(v.partId);
			if (v.partIndex < 0) return String.Format("part = %s -- this card has no part by that name", v.partId);
		}
		for (int j = 0; j < index; j++)
		{
			let other = card.verbs[j];
			if (other.id ~== v.id) return "a verb by that id is already declared on this card";
			if (v.partIndex >= 0 && other.partIndex == v.partIndex)
				return String.Format("part %s is already worked by %s %s -- one verb per part",
					v.partId, WM_Verb.KindName(other.kind), other.id);
		}

		// A SYNTHESISED VERB IS THE OLD CODE'S BEHAVIOUR, which loads today on every
		// card it loads on. Nothing more is asked of it.
		if (v.origin == WM_Verb.FROM_SYNTH) return "";

		WM_Part part = null;
		if (v.partIndex >= 0)
		{
			part = card.parts[v.partIndex];
			if (part.surfaceNames.Size() == 0)
				return String.Format("part %s names no surface -- there is nothing on the mesh for a hand to move", part.id);
		}

		if (v.latchId != "")
		{
			v.latchIndex = card.FindPartIndex(v.latchId);
			if (v.latchIndex < 0) return String.Format("latch = %s -- this card has no part by that name", v.latchId);
			if (v.latchIndex == v.partIndex) return "a part cannot be its own latch";
			if (card.parts[v.latchIndex].surfaceNames.Size() == 0)
				return String.Format("latch = %s -- that part names no surface, so there is nothing for a hand to throw", v.latchId);
		}
		if (v.latchReturnSpring && v.latchId == "")
			return "latchreturn says how a latch comes back -- this verb has no latch";
		if (v.needsOpen != "")
		{
			let gate = card.FindVerb(v.needsOpen);
			if (!gate || gate.kind != WM_Verb.OPEN)
				return String.Format("needs = open:%s -- this card has no open verb by that id", v.needsOpen);
		}

		// ---- BY KIND ----------------------------------------------------------------
		if (v.kind == WM_Verb.CYCLE)
		{
			if (v.apex < v.outAt)
				return String.Format("apex %.2f comes before outat %.2f -- the stop is felt at full travel, past where the stroke counts", v.apex, v.outAt);

			if (v.onOutEject)
			{
				if (v.fromStore == "") return "onout = eject needs from = <the slotted store it empties>";
				if (card.StoreKindFor(v.fromStore) != WM_Store.SLOTTED)
					return String.Format("from = %s -- onout = eject empties a slotted store, and this card has no slotted store by that name", v.fromStore);
			}
			else if (v.fromStore != "") return "from says what onout = eject empties -- this cycle has no onout = eject";

			if (v.onHomeFeed)
			{
				if (v.feedStore == "" || v.intoStore == "") return "onhome = feed needs feed = <a counted store> and into = <a slotted store>";
				if (card.StoreKindFor(v.feedStore) != WM_Store.COUNTED)
					return String.Format("feed = %s -- a round is stripped from a counted store, and this card has no counted store by that name", v.feedStore);
				if (card.StoreKindFor(v.intoStore) != WM_Store.SLOTTED)
					return String.Format("into = %s -- a round is fed into a slotted store, and this card has no slotted store by that name", v.intoStore);
				String chamber = card.FacadeStoreId(WM_Store.SLOTTED);
				if (!(v.intoStore ~== chamber))
					return String.Format("into = %s -- the trigger fires from this gun's chamber, %s, so a round fed anywhere else could never be fired", v.intoStore, chamber);
			}
			else if (v.feedStore != "" || v.intoStore != "") return "feed and into say what onhome = feed moves -- this cycle has no onhome = feed";

			if (v.holdOpenWhenEmpty)
			{
				if (!v.onHomeFeed) return "holdopen = whenempty holds the action open when there was nothing to feed -- this cycle feeds nothing";
				if (v.ret != WM_Verb.RET_SPRING) return "holdopen = whenempty is what a spring does on an empty feed -- an action returned by hand stays wherever the hand leaves it";
			}
			if (v.ret == WM_Verb.RET_SPRING)
			{
				if (v.homeAtStated) return "homeat is where an action returned by hand counts as home -- this one is return = spring";
			}
			else if (v.homeAt >= v.outAt)
				return String.Format("homeat %.2f is not short of outat %.2f -- one position would be both out and home", v.homeAt, v.outAt);
		}
		else if (v.kind == WM_Verb.OPEN)
		{
			if (v.closeAt >= v.openAt)
				return String.Format("closeat %.2f is not short of openat %.2f -- one position would be both open and shut", v.closeAt, v.openAt);
			if (v.ret == WM_Verb.RET_HAND)
				return "an open verb rests `stay` (held where the hand leaves it) or `spring` (shuts when let go) -- `hand` is a cycle's";
			// A FLICK SHUTS IT (FEEL_PLAN section 1).
			if (v.flickStated && v.closeBy != "flick")
				return "flickaxis and flickscale say how a flick shuts it -- this open verb has no close = flick";
			if (v.closeBy == "flick" && v.ret == WM_Verb.RET_SPRING)
				return "close = flick shuts a part that stays open -- rest = spring already shuts it by itself";
			if (v.closeBy == "flick" && v.flickAxisSide && part && WM_Verb.FlickSideSign(part) == 0)
				return "flickaxis = side, but this part does not move across the gun as it shuts -- give flickaxis a vector";
			if (v.onOpenEjectAll)
			{
				if (v.fromStore == "") return "onopen = ejectall needs from = <the slotted store it empties>";
				if (card.StoreKindFor(v.fromStore) != WM_Store.SLOTTED)
					return String.Format("from = %s -- onopen = ejectall empties a slotted store, and this card has no slotted store by that name", v.fromStore);
			}
			else if (v.fromStore != "") return "from says what onopen = ejectall empties -- this open verb has no onopen = ejectall";
		}
		else if (v.kind == WM_Verb.SWAP)
		{
			if (v.storeId == "") return "a swap needs store = <the detachable counted store that leaves>";
			let st = card.FindStore(v.storeId);
			bool detachable = (card.StoreKindFor(v.storeId) == WM_Store.COUNTED);   // a synthesised mag detaches
			if (st) detachable = detachable && st.detach;
			if (!detachable)
				return String.Format("store = %s -- a swap moves a counted store declared detach = yes", v.storeId);
			String mag = card.FacadeStoreId(WM_Store.COUNTED);
			if (!(v.storeId ~== mag))
				return String.Format("store = %s -- the magazine this gun drops and seats is its first counted store, %s, until parts are worked by id (step 4)", v.storeId, mag);
			if (v.detachAt < 0) v.detachAt = part.dof.detach;
			if (v.handTakeStated)
			{
				if (part.takeStated && part.handTake != v.handTake)
					return String.Format("handtake = %s disagrees with part %s's take = %s -- say it once",
						v.handTake ? "yes" : "no", part.id, part.handTake ? "yes" : "no");
				part.handTake = v.handTake;
			}
			else v.handTake = part.handTake;
		}
		else if (v.kind == WM_Verb.LOAD)
		{
			if (v.intoStore == "") return "a load verb needs into = <the store a round goes into>";
			int intoKind = card.StoreKindFor(v.intoStore);
			if (intoKind == WM_Store.UNSTATED) return String.Format("into = %s -- this card has no store by that name", v.intoStore);
			if (intoKind == WM_Store.SLOTTED)
			{
				if (!v.slotNext && v.slot < 0) return "a slotted store is loaded one position at a time: slot = <index> or slot = next";
				let into = card.FindStore(v.intoStore);
				int slotCount = into ? into.slots.Size() : 1;
				if (v.slot >= slotCount)
					return String.Format("slot = %d -- %s has %d slot%s, counted from 0", v.slot, v.intoStore, slotCount, slotCount == 1 ? "" : "s");
			}
			else if (v.slotNext || v.slot >= 0)
				return String.Format("slot belongs to a slotted store -- %s is counted", v.intoStore);
			if (v.loadSize.X <= 0 || v.loadSize.Y <= 0 || v.loadSize.Z <= 0)
				return "a load verb needs size = <x, y, z>: the half-sizes of the oval a round is brought into";
			if (v.ridesId != "")
			{
				v.ridesIndex = card.FindPartIndex(v.ridesId);
				if (v.ridesIndex < 0) return String.Format("rides = %s -- this card has no part by that name", v.ridesId);
			}
			if (v.subject == "loader" && intoKind != WM_Store.SLOTTED)
				return String.Format("subject = loader fills empty slots -- %s is counted; a counted store is loaded a round at a time", v.intoStore);
		}
		else if (v.kind == WM_Verb.EJECT)
		{
			if (v.ejectByTilt && !v.tiltAlongBarrel && v.tiltAxis.Length() < 0.5)
				return "by = tilt needs tiltaxis = barrel | up | down | x, y, z -- which axis of the gun has to point up";
			if (!v.ejectByTilt && v.tiltAxisStated)
				return "tiltaxis says which axis of the gun has to point up -- this eject is by = hand";
			if (v.at < 0) return "an eject verb needs at = <how far the part travels before it throws>";
			if (v.fromStore == "" || card.StoreKindFor(v.fromStore) != WM_Store.SLOTTED)
				return "an eject verb needs from = <a slotted store this card has>";
		}
		else if (v.kind == WM_Verb.START)
		{
			// ONE ENGINE A GUN.
			for (int j = 0; j < index; j++)
				if (card.verbs[j].kind == WM_Verb.START)
					return String.Format("start %s already starts this gun's engine -- a gun has one start verb", card.verbs[j].id);
			if (v.ret != WM_Verb.RET_SPRING)
				return "a start verb's part springs home when let go -- it takes no return";
		}
		else if (v.kind == WM_Verb.PULLOFF || v.kind == WM_Verb.RELEASE)
		{
			// A PIN OR A LEVER comes away in one motion along one dof (THROWABLE_PLAN.md §2.3). One of each a
			// card, and only on a thrown weapon: both checked with its throw (ThrowableProblem).
			if (part && part.dof2)
				return String.Format("part %s has a dof2 -- a %s comes away in one motion along one dof", part.id, (v.kind == WM_Verb.PULLOFF) ? "pin" : "lever");
		}
		return "";
	}

	private static WM_Card NewCard(String weaponClass)
	{
		let c = new("WM_Card");
		c.weaponClass = weaponClass;
		c.capacity    = 15;
		c.barrel      = (1, 0, 0);
		c.ejectDir    = (0, -1, 0.4);
		c.magScale    = 0.3;
		c.roundScale  = 0.17;
		// THE RELOAD SYSTEM NAMES NO GUN'S SOUNDS. Fire, magazine out and in, slide
		// back and forward, the rack, a manual cycle and a load all stay empty --
		// silent until the card states them. Only the two this package ships
		// itself, which no one gun owns, are defaults. casingSound stays empty: a
		// spent casing sounds as its RS_Ballistics ejecta profile, and a loose round
		// lands on wm/casing (WM_LooseMag.DropSound), unless the card names one.
		c.drySound       = "wm/dry";
		c.magDropSound   = "wm/magdrop";
		return c;
	}

	private static WM_Part NewPart(String id)
	{
		let p = new("WM_Part");
		p.id         = id;
		p.modelIndex = 0;
		p.grabRadius = 3.0;
		p.grabSize   = (0, 0, 0);   // no oval stated: a ball of grabRadius
		p.handSeat       = (0, 0, 0);
		p.handSeatStated = false;   // no seat stated: the hand is seated as it always was
		p.present    = true;
		p.handTake   = true;
		p.cockByTrigger = false;    // a hammer is cocked by its action unless the card says trigger
		p.driveSlot  = -1;
		p.poseSlot   = -1;
		p.dof        = new("WM_Dof");
		p.dof.moveKind = WM_Dof.MOVE_SLIDE;
		p.dof.detach   = 0.9;
		p.dof.rest     = 0.0;
		return p;
	}

	// Returns WHY a card key is refused, or "" when it is taken -- "unknown key" for
	// a key no card has, as before; a reason where one helps more than that.
	private static String CardKey(WM_Card c, String key, String val, int line)
	{
		if      (key == "prop")       c.propClass = Unquote(val);
		else if (key == "hand")       c.hand = (Unquote(val).MakeLower() == "off") ? 1 : 0;
		else if (key == "model")      ReadPair(val, c.modelPath, c.modelFile);
		else if (key == "skin")       ReadPair(val, c.skinPath,  c.skinFile);
		else if (key == "capacity")   c.capacity = val.ToInt();
		else if (key == "magfamily")  c.magFamily = Unquote(val).MakeLower();
		else if (key == "muzzle")     c.muzzle    = ReadTriple(val);
		else if (key == "barrel")     c.barrel    = Unit(ReadTriple(val));
		else if (key == "ejectport")  c.ejectPort = ReadTriple(val);
		else if (key == "ejectdir")   c.ejectDir  = Unit(ReadTriple(val));
		// AN ENGINE'S EXHAUST PORT (WM_Card.exhaustPort, WM_Rig.ExhaustLook): the port states it; unset dir blows up.
		else if (key == "exhaustport") { c.exhaustPort = ReadTriple(val); c.exhaustStated = true; if (c.exhaustDir.Length() < 0.5) c.exhaustDir = (0, 0, 1); }
		else if (key == "exhaustdir")  c.exhaustDir  = Unit(ReadTriple(val));
		else if (key == "magmodel")   ReadPair(val, c.magModelPath, c.magModelFile);
		else if (key == "magskin")    ReadPair(val, c.magSkinPath,  c.magSkinFile);
		else if (key == "magskinempty") ReadPair(val, c.magSkinEmptyPath, c.magSkinEmptyFile);
		else if (key == "magscale")   c.magScale  = val.ToDouble();
		else if (key == "magcenter")  c.magCenter = ReadTriple(val);
		else if (key == "roundmodel") ReadPair(val, c.roundModelPath, c.roundModelFile);
		else if (key == "roundskin")  ReadPair(val, c.roundSkinPath,  c.roundSkinFile);
		else if (key == "roundscale") c.roundScale = val.ToDouble();
		// A BELT LINK with every case (WM_Card.linkModelFile, G16).
		else if (key == "linkmodel")  ReadPair(val, c.linkModelPath, c.linkModelFile);
		else if (key == "linkskin")   ReadPair(val, c.linkSkinPath,  c.linkSkinFile);
		else if (key == "linkscale")  c.linkScale = val.ToDouble();
		else if (key == "firesound")      c.fireSound      = Unquote(val);
		else if (key == "drysound")       c.drySound       = Unquote(val);
		else if (key == "magoutsound")    c.magOutSound    = Unquote(val);
		else if (key == "maginsound")     c.magInSound     = Unquote(val);
		else if (key == "slidebacksound") c.slideBackSound = Unquote(val);
		else if (key == "slidefwdsound")  c.slideFwdSound  = Unquote(val);
		else if (key == "rackapexsound")  c.rackApexSound  = Unquote(val);
		else if (key == "rackresetsound") c.rackResetSound = Unquote(val);
		else if (key == "magdropsound")   c.magDropSound   = Unquote(val);
		else if (key == "casingsound")    c.casingSound    = Unquote(val);
		else if (key == "cycleoutsound")  c.cycleOutSound  = Unquote(val);
		else if (key == "cyclehomesound") c.cycleHomeSound = Unquote(val);
		else if (key == "loadsound")      c.loadSound      = Unquote(val);
		else if (key == "ejectsound")     c.ejectSound     = Unquote(val);
		else if (key == "opensound")      c.openSound      = Unquote(val);
		else if (key == "closesound")     c.closeSound     = Unquote(val);
		else if (key == "spinupsound")    c.spinUpSound    = Unquote(val);
		else if (key == "spinsound")      c.spinSound      = Unquote(val);
		else if (key == "spindownsound")  c.spinDownSound  = Unquote(val);
		else if (key == "pullsound")      c.pullSound      = Unquote(val);
		else if (key == "startsound")     c.startSound     = Unquote(val);
		else if (key == "idlesound")      c.idleSound      = Unquote(val);
		else if (key == "stopsound")      c.stopSound      = Unquote(val);
		// WHAT KIND OF GUN, AND WHOSE HAND SEATS (handprofile.zs). One lower-case word
		// each: it becomes part of every hand seat cvar's name.
		else if (key == "type" || key == "handprofile")
		{
			String word = Unquote(val).MakeLower();
			String wordBad = WM_HandProfile.WordProblem(word);
			if (wordBad != "") return key .. " " .. wordBad;
			if (key == "type") c.gunType = word;
			else               c.handProfile = word;
		}
		// WHAT A TRIGGER PULL SPENDS (WM_Card.firesFrom). Checked against the card's verbs and
		// stores once every lump is read (FinishCard, FiresFromProblem).
		else if (key == "firesfrom")
		{
			String firesWord = Unquote(val).MakeLower();
			if (firesWord == "chamber")       c.firesFrom = WM_Card.FIRES_CHAMBER;
			else if (firesWord == "magazine") c.firesFrom = WM_Card.FIRES_MAGAZINE;
			else if (firesWord == "reserve")  c.firesFrom = WM_Card.FIRES_RESERVE;
			else if (firesWord == "none")     c.firesFrom = WM_Card.FIRES_NOTHING;
			else return "firesfrom is chamber (a round in the chamber, which an action feeds -- the default), magazine (no chamber: a pull spends straight from the magazine), reserve (no stores: a pull spends your reserve ammo) or none (no ammunition at all)";
			c.firesFromLine = line;
		}
		// WHETHER A CASE LEAVES THE GUN (WM_Card.noCasing).
		else if (key == "casing")
		{
			String casingWord = Unquote(val).MakeLower();
			if (casingWord == "yes") c.noCasing = false;
			else if (casingWord == "none" || casingWord == "no") c.noCasing = true;
			else return "casing is yes (a case leaves the gun on the shot or when emptied -- the default) or none (it has no cases: plasma, a rail, a rocket, flame)";
		}
		// HOW MANY HANDS IT TAKES TO FIRE (WM_Card.handsNeeded). A 2 is checked for a
		// `role = support` part once the card is whole (FinishCard).
		else if (key == "hands")
		{
			String handsWord = Unquote(val);
			if (handsWord == "1")      c.handsNeeded = 1;
			else if (handsWord == "2") c.handsNeeded = 2;
			else return "hands is 1 (one hand fires it -- the default) or 2 (it fires only while the other hand holds its role = support part)";
			c.handsLine = line;
		}
		// A THROWN WEAPON'S POUCH (throw.zs): `pouch = whole` hands a whole one from the reserve. Checked
		// against its throw once the card is whole (ThrowableProblem).
		else if (key == "pouch")
		{
			if (Unquote(val).MakeLower() != "whole")
				return "pouch is whole -- the pouch hands a whole thrown weapon from the reserve; unset, it hands what the gun's verbs load";
			c.pouchWhole = true;
			c.pouchLine  = line;
		}
		else if (key == "mechanism")
		{
			c.mechanism     = Unquote(val);
			c.mechanismLine = line;
		}
		// THE CARD THIS ONE STARTS FROM (INHERITANCE): built whole from a fresh copy of that card as the cards load
		// (ResolveBases, FreshCard).
		else if (key == "base")
		{
			String baseWord = Unquote(val);
			if (baseWord == "") return "base names the card this one starts from: base = <that card's weapon class>";
			if (baseWord ~== c.weaponClass) return "base names this card itself -- a card starts from a different card";
			c.baseId   = baseWord;
			c.baseLine = line;
		}
		// THE SHOT MOVED TO THE WEAPON CLASS. Refused like any unknown key -- the
		// card is skipped, the rest load -- but saying where the number goes now, so
		// an old card is fixed in one edit rather than debugged.
		else if (key == "pellets" || key == "spread" || key == "damage")
			return String.Format("unknown key -- `%s` is no longer a card key: the shot is the weapon class's, set in its Default block as WM_Gun.ShotPellets N, WM_Gun.ShotSpread h, v and WM_Gun.ShotDamage min, max", key);
		else return "unknown key";
		return "";
	}

	private static bool PartKey(WM_Part p, String key, String val)
	{
		if      (key == "role")       p.role = Unquote(val).MakeLower();
		else if (key == "subject")    p.subject = Unquote(val).MakeLower();
		else if (key == "surface")    p.surfaceNames.Push(Unquote(val));
		else if (key == "model")      p.modelIndex = val.ToInt();
		else if (key == "grab")       p.grabAt = ReadTriple(val);
		else if (key == "grabradius") p.grabRadius = val.ToDouble();
		else if (key == "grabsize")   p.grabSize = ReadTriple(val);
		else if (key == "handseat")
		{
			// Where the hand sits on the part, model space (card.zs WM_Part.handSeat).
			if (!IsTriple(Unquote(val))) return false;
			p.handSeat       = ReadTriple(val);
			p.handSeatStated = true;
		}
		else if (key == "take")
		{
			String t = Unquote(val).MakeLower();
			p.handTake   = !(t == "no" || t == "false" || t == "0");
			p.takeStated = true;
		}
		else if (key == "cock")
		{
			// What cocks a hammer (card.zs WM_Part.cockByTrigger).
			String ck = Unquote(val).MakeLower();
			if (ck == "trigger")     p.cockByTrigger = true;
			else if (ck == "action") p.cockByTrigger = false;
			else return false;
		}
		else if (key == "roundsurface")
		{
			// `<surface>, <store>, <slot|any>` -- a surface of this part drawn only while
			// that slot holds a case. The store is checked once the card is whole.
			Array<String> rsw;
			String rsv = Unquote(val);
			rsv.Split(rsw, ",", TOK_SKIPEMPTY);
			if (rsw.Size() != 3) return false;
			String rsName  = rsw[0]; rsName.StripLeftRight();
			String rsStore = rsw[1]; rsStore.StripLeftRight();
			String rsSlot  = rsw[2]; rsSlot.StripLeftRight(); rsSlot = rsSlot.MakeLower();
			if (rsName == "" || rsStore == "") return false;
			int rsAt = -1;
			if (rsSlot != "any")
			{
				if (!IsWhole(rsSlot)) return false;
				rsAt = rsSlot.ToInt();
			}
			p.surfaceNames.Push(rsName);
			p.roundSurfName.Push(rsName);
			p.roundSurfStore.Push(rsStore);
			p.roundSurfSlot.Push(rsAt);
		}
		// A PART THAT SPINS (card.zs WM_Part.spinBy). What it may be is checked once the card is
		// whole (FinishCard, SpinProblem).
		else if (key == "spin")
		{
			String spinWord = Unquote(val).MakeLower();
			if (spinWord == "trigger")   p.spinBy = WM_Part.SPIN_TRIGGER;
			else if (spinWord == "fire") p.spinBy = WM_Part.SPIN_FIRE;
			else if (spinWord == "none") p.spinBy = WM_Part.SPIN_NONE;
			else return false;
		}
		else if (key == "spinrate")
		{
			String spinRateWord = Unquote(val);
			if (!IsNumber(spinRateWord)) return false;
			p.spinRate = spinRateWord.ToDouble();
		}
		else if (key == "spinup" || key == "spindown")
		{
			String spinTicWord = Unquote(val);
			if (!IsWhole(spinTicWord)) return false;
			if (key == "spinup") p.spinUpTics   = spinTicWord.ToInt();
			else                 p.spinDownTics = spinTicWord.ToInt();
		}
		// A PART THAT FLIPS (card.zs WM_Part.flipBy). Checked once the card is whole (FlipProblem).
		else if (key == "flip")
		{
			String flipWord = Unquote(val).MakeLower();
			if (flipWord == "trigger")   p.flipBy = WM_Part.FLIP_TRIGGER;
			else if (flipWord == "fire") p.flipBy = WM_Part.FLIP_FIRE;
			else if (flipWord == "none") p.flipBy = WM_Part.FLIP_NONE;
			else return false;
		}
		else if (key == "fliptics" || key == "flipphase")
		{
			String flipNumber = Unquote(val);
			if (!IsWhole(flipNumber)) return false;
			if (key == "fliptics") p.flipTics  = flipNumber.ToInt();
			else                   p.flipPhase = flipNumber.ToInt();
		}
		// A SURFACE THAT SHOWS THE MAGAZINE'S FILL (card.zs WM_Part.meterSurface). Checked once the
		// card is whole (MeterProblem).
		else if (key == "metersurface") p.meterSurface = Unquote(val);
		else if (key == "meterskins")
		{
			ReadPair(val, p.meterSkinPath, p.meterSkinFile);
			if (p.meterSkinFile == "") return false;
		}
		else if (key == "metersteps")
		{
			String meterNumber = Unquote(val);
			if (!IsWhole(meterNumber)) return false;
			p.meterSteps = meterNumber.ToInt();
		}
		else return false;
		return true;
	}

	private static bool DofKey(WM_Dof d, String key, String val)
	{
		if      (key == "kind")      d.moveKind  = (val.MakeLower() == "hinge") ? WM_Dof.MOVE_HINGE : WM_Dof.MOVE_SLIDE;
		else if (key == "axis")      d.axis      = Unit(ReadTriple(val));
		else if (key == "distance")  d.distance  = val.ToDouble();
		else if (key == "degrees")   d.degrees   = val.ToDouble();
		else if (key == "pivot")     d.pivot     = ReadTriple(val);
		else if (key == "detach")    d.detach    = val.ToDouble();
		else if (key == "rest")      d.rest      = val.ToDouble();
		else if (key == "twist")     d.twist     = val.ToDouble();
		else if (key == "twistaxis") d.twistAxis = Unit(ReadTriple(val));
		else return false;
		return true;
	}

	// A PART'S SECOND STAGE, fresh (WM_Part.dof2): a slide until `kind` says hinge, and
	// the pull split evenly until `split` says otherwise. detach, rest and twist are the
	// part's own, on its `dof`; a stage has none of its own.
	private static WM_Dof NewStageTwo()
	{
		let d = new("WM_Dof");
		d.moveKind = WM_Dof.MOVE_SLIDE;
		d.split    = 0.5;
		return d;
	}

	// Returns WHY a dof2 key is refused, or "" when it is taken. A reason and not a bool,
	// because `twist` is a real key that belongs one block up.
	private static String Dof2Key(WM_Dof d, String key, String val)
	{
		if (key == "kind")
		{
			String kindWord = val.MakeLower();
			if (kindWord != "slide" && kindWord != "hinge") return "kind is slide or hinge";
			d.moveKind = (kindWord == "hinge") ? WM_Dof.MOVE_HINGE : WM_Dof.MOVE_SLIDE;
		}
		else if (key == "axis")     d.axis     = Unit(ReadTriple(val));
		else if (key == "distance") d.distance = val.ToDouble();
		else if (key == "degrees")  d.degrees  = val.ToDouble();
		else if (key == "pivot")    d.pivot    = ReadTriple(val);
		else if (key == "split")    d.split    = val.ToDouble();
		else if (key == "detach" || key == "rest" || key == "twist" || key == "twistaxis")
			return String.Format("%s belongs on the part's dof -- a dof2 takes kind, axis, distance or degrees and pivot, and split", key);
		else return "unknown key in a dof2 block -- kind, axis, distance, degrees, pivot, split";
		return "";
	}

	// WHAT Actor.SetModelSurfaceDriveStage WOULD REFUSE AT THE GRAB, refused at load: no
	// axis, a zero amount, a hinge of half a turn or more, a split that leaves a stage
	// less than a thousandth of the pull -- and a stage one that is not itself a drive
	// that moves, since the stage rides it. "" for a part with no dof2.
	private static String StageTwoProblem(WM_Part p)
	{
		let d2 = p.dof2;
		if (d2 == null) return "";
		if (!(d2.split >= 0.001 && d2.split <= 0.999))
			return String.Format("dof2 split %.4f is outside 0.001..0.999 -- it is the share of the pull the dof gets, and each stage needs some", d2.split);
		if (d2.axis.Length() < 1e-6) return "dof2 has no axis -- `axis = x, y, z` in the gun's model space";
		if (d2.moveKind == WM_Dof.MOVE_HINGE)
		{
			if (d2.degrees == 0 || abs(d2.degrees) >= 180)
				return String.Format("dof2 hinge degrees %.2f must be non-zero and under 180", d2.degrees);
		}
		else if (d2.distance == 0) return "dof2 slide has no distance -- `distance = N` in model units";
		let d1 = p.dof;
		if (d1.axis.Length() < 1e-6) return "a part with a dof2 needs an axis on its dof -- the dof is stage one";
		if (d1.moveKind == WM_Dof.MOVE_HINGE)
		{
			if (d1.degrees == 0 || abs(d1.degrees) >= 180)
				return String.Format("the dof is stage one of a dof2, and its hinge degrees %.2f must be non-zero and under 180", d1.degrees);
		}
		else if (d1.distance == 0) return "the dof is stage one of a dof2, and a slide with no distance is not a drive the engine takes";
		return "";
	}

	private static WM_Store NewStore(String id)
	{
		let s = new("WM_Store");
		s.id       = id;
		s.kind     = WM_Store.UNSTATED;   // said by `kind =`, or refused at `end`
		s.attached = true;
		return s;
	}

	// Returns WHY a store key is refused, or "" when it is taken. A reason and
	// not a bool, because a store key can be known and still wrong -- `kind =
	// countd` -- and "unknown key" would send the card's author to the wrong line
	// of the wrong page.
	private static String StoreKey(WM_Store s, String key, String val)
	{
		String v = Unquote(val).MakeLower();
		if (key == "kind")
		{
			if      (v == "counted") s.kind = WM_Store.COUNTED;
			else if (v == "slotted") s.kind = WM_Store.SLOTTED;
			else return "kind is counted or slotted";
		}
		else if (key == "capacity")
		{
			int capN = v.ToInt();
			if (capN < 1) return "capacity is a whole number, at least 1";
			s.capacity = capN;
		}
		else if (key == "detach")
		{
			int detachYN = ReadYesNo(v);
			if (detachYN < 0) return "detach is yes or no";
			s.detach = (detachYN > 0);
		}
		else if (key == "family")
		{
			s.family = v;
		}
		else if (key == "slots")
		{
			int slotN = v.ToInt();
			if (slotN < 1 || slotN > WM_Store.MAX_SLOTS)
				return String.Format("slots is a whole number from 1 to %d", WM_Store.MAX_SLOTS);
			s.SetSlotCount(slotN);
		}
		else if (key == "indexed")
		{
			int indexedYN = ReadYesNo(v);
			if (indexedYN < 0) return "indexed is yes or no";
			s.indexed = (indexedYN > 0);
		}
		else if (key == "advance")
		{
			if      (v == "onshot") s.advanceOnShot = true;
			else if (v == "none")   s.advanceOnShot = false;
			else return "advance is onshot or none";
		}
		else return "unknown key in a store block";
		return "";
	}

	// A STORE BLOCK THAT CLOSES INCOMPLETE OR CONTRADICTING ITSELF IS REFUSED, for
	// the reason an unknown key is: a slotted store given a capacity would
	// otherwise ignore the number with nothing said.
	private static String StoreProblem(WM_Card card, WM_Store s)
	{
		if (s.kind == WM_Store.UNSTATED) return "a store needs kind = counted or kind = slotted";
		if (card.FindStore(s.id) != null) return "the card already has a store by that name";
		if (s.kind == WM_Store.COUNTED)
		{
			if (s.capacity < 1) return "a counted store needs capacity";
			if (s.slots.Size() > 0 || s.indexed || s.advanceOnShot)
				return "slots, indexed and advance belong to a slotted store";
		}
		else
		{
			if (s.slots.Size() == 0) return "a slotted store needs slots";
			if (s.capacity > 0) return "capacity belongs to a counted store -- a slotted one says slots";
			if (s.advanceOnShot && !s.indexed) return "advance = onshot needs indexed = yes";
		}
		if (s.family != "" && !s.detach)
			return "family says which detachable stores interchange -- this one is not detach = yes";
		return "";
	}

	// ---- SECOND BARREL KEYS (card.zs WM_Barrel) ---------------------------------------------

	private static WM_Barrel NewBarrel(String id)
	{
		let b = new("WM_Barrel");
		b.id           = id;
		b.input        = WM_Barrel.INPUT_UNSTATED;
		b.triggerIndex = -1;
		return b;
	}

	// Returns WHY a barrel key is refused, or "" when it is taken. What each key names is checked
	// once the card is whole (FinishCard, BarrelProblem): its store and verbs may come after it.
	private static String BarrelKey(WM_Barrel b, String key, String val)
	{
		String word = Unquote(val);
		String lw = word.MakeLower();
		if (key == "input")
		{
			if (lw != "altfire") return "input is altfire -- the holding hand's second button, the one input a second barrel takes";
			b.input = WM_Barrel.INPUT_ALTFIRE;
		}
		else if (key == "trigger")   b.triggerId     = word;
		else if (key == "from")      b.fromStore     = word;
		else if (key == "shotclass") b.shotClassName = word;
		else if (key == "ammo")      b.ammoClassName = word;
		else if (key == "firesound") b.fireSound     = word;
		else if (key == "muzzle")
		{
			if (!IsTriple(word)) return "muzzle is x, y, z in model space";
			b.muzzle       = ReadTriple(word);
			b.muzzleStated = true;
		}
		else if (key == "barrel")
		{
			if (!IsTriple(word)) return "barrel is the way the bore points, x, y, z in model space";
			Vector3 bore = Unit(ReadTriple(word));
			if (bore.Length() < 0.5) return "barrel is a direction -- x, y and z cannot all be zero";
			b.dir       = bore;
			b.dirStated = true;
		}
		else if (key == "needs")
		{
			if (lw == "none") b.needsShut = "";
			else if (lw.Length() > 5 && lw.Left(5) == "shut:")
			{
				String gate = word.Mid(5);
				gate.StripLeftRight();
				if (gate == "") return "needs is shut:<an open verb's id>, or none";
				b.needsShut = gate;
			}
			else return "needs is shut:<an open verb's id> -- the barrel fires only while that verb is shut -- or none";
		}
		else if (key == "firetics")
		{
			if (!IsWhole(lw) || lw.ToInt() < 1 || lw.ToInt() > 350) return "firetics is a whole number of tics, 1 to 350";
			b.fireTicCount = lw.ToInt();
		}
		else if (key == "casing")
		{
			if (lw == "yes") b.noCasing = false;
			else if (lw == "none" || lw == "no") b.noCasing = true;
			else return "casing is yes (its spent cases are thrown when its store is emptied -- the default) or none (its store holds no cases)";
		}
		else return "unknown key in a barrel block -- input, trigger, from, shotclass, ammo, muzzle, barrel, firesound, needs, firetics or casing";
		return "";
	}

	// ---- A THROWN WEAPON'S KEYS (throw.zs) ------------------------------------------
	//
	// Each returns WHY a key is refused, or "" when it is taken. Words and numbers are checked here; how
	// the blocks fit together, once the card is whole (ThrowableProblem).
	private static String ThrowKey(WM_Throw t, String key, String val)
	{
		String w  = Unquote(val);
		String lw = w.MakeLower();
		if (key == "on")
		{
			if (lw == "trigger")   t.on = WM_Throw.ON_TRIGGER;
			else if (lw == "grip") t.on = WM_Throw.ON_GRIP;
			else return "on is trigger (letting go of fire throws it) or grip (letting go of the grip throws it)";
		}
		else if (key == "minspeed")
		{
			if (!IsNumber(lw) || lw.ToDouble() <= 0 || lw.ToDouble() > 20)
				return "minspeed is metres a second at release, above 0, at most 20 -- slower is a drop";
			t.minSpeed = lw.ToDouble();
		}
		else if (key == "flight")
		{
			if (w == "") return "flight names the actor that flies, in quotes";
			t.flightClass = w;
		}
		else if (key == "speedband")
		{
			Array<String> band;
			lw.Split(band, ",", TOK_SKIPEMPTY);
			if (band.Size() != 2) return "speedband is two numbers, lo, hi -- the release speed clamped to that share of the flight's own speed";
			String lo = band[0]; lo.StripLeftRight();
			String hi = band[1]; hi.StripLeftRight();
			if (!IsNumber(lo) || !IsNumber(hi) || lo.ToDouble() <= 0 || hi.ToDouble() < lo.ToDouble() || hi.ToDouble() > 10)
				return "speedband is lo, hi -- lo above 0, hi at least lo and at most 10";
			t.speedBandLo     = lo.ToDouble();
			t.speedBandHi     = hi.ToDouble();
			t.speedBandStated = true;
		}
		else if (key == "spin" || key == "plane")
		{
			bool fromWrist = false;
			if (lw == "wrist") fromWrist = true;
			else if (lw != "none") return String.Format("%s is wrist or none", key);
			if (key == "spin") t.spinFromWrist  = fromWrist;
			else               t.planeFromWrist = fromWrist;
		}
		else if (key == "spends")
		{
			if (!IsWhole(lw) || lw.ToInt() > 100) return "spends is a whole number of rounds a throw spends from the reserve, 0 to 100";
			t.spends       = lw.ToInt();
			t.spendsStated = true;
		}
		else if (key == "after")
		{
			if (lw == "empty")         t.after = WM_Throw.AFTER_EMPTY;
			else if (lw == "next")     t.after = WM_Throw.AFTER_NEXT;
			else if (lw == "previous") t.after = WM_Throw.AFTER_PREVIOUS;
			else return "after is empty (the hand holds nothing: reach the pouch), next (the next one at once) or previous (the weapon held before it)";
		}
		else if (key == "returns")
		{
			int returnsYn = ReadYesNo(lw);
			if (returnsYn < 0) return "returns is yes or no";
			t.returns = (returnsYn > 0);
		}
		else if (key == "catch" || key == "recall")
		{
			bool byGrip = false;
			if (lw == "grip") byGrip = true;
			else if (lw != "none") return String.Format("%s is grip or none", key);
			if (key == "catch") t.catchByGrip  = byGrip;
			else                t.recallByGrip = byGrip;
		}
		else if (key == "catchat")
		{
			if (!IsNumber(lw) || lw.ToDouble() <= 0 || lw.ToDouble() > 64)
				return "catchat is map units, above 0, at most 64 -- how near the hand a returning weapon is caught";
			t.catchAt       = lw.ToDouble();
			t.catchAtStated = true;
		}
		else if (key == "miss")
		{
			if (lw == "stow")      t.miss = WM_Throw.MISS_STOW;
			else if (lw == "drop") t.miss = WM_Throw.MISS_DROP;
			else return "miss is stow (back on its mount) or drop (it falls)";
			t.missStated = true;
		}
		else return "unknown key in a throw block -- on, minspeed, flight, speedband, spin, plane, spends, after, returns, catch, catchat, miss or recall";
		return "";
	}

	private static String RouteKey(WM_Route r, String key, String val)
	{
		String w  = Unquote(val);
		String lw = w.MakeLower();
		if (key == "paint")
		{
			if (lw != "fire") return "paint is fire -- the route is painted while fire is held";
			r.paintByFire = true;
		}
		else if (key == "range")
		{
			if (!IsNumber(lw) || lw.ToDouble() < 64 || lw.ToDouble() > 8192) return "range is map units from the hand, 64 to 8192";
			r.range = lw.ToDouble();
		}
		else if (key == "cone")
		{
			if (!IsNumber(lw) || lw.ToDouble() <= 0 || lw.ToDouble() > 90) return "cone is degrees off the hand's aim, above 0, at most 90";
			r.cone = lw.ToDouble();
		}
		else if (key == "max")
		{
			if (!IsWhole(lw) || lw.ToInt() < 1 || lw.ToInt() > WM_Route.MOST_TARGETS)
				return String.Format("max is a whole number of targets, 1 to %d", WM_Route.MOST_TARGETS);
			r.mostTargets = lw.ToInt();
		}
		else if (key == "every")
		{
			if (!IsWhole(lw) || lw.ToInt() < 1 || lw.ToInt() > 35) return "every is a whole number of tics between scans, 1 to 35";
			r.everyTics = lw.ToInt();
		}
		else if (key == "mark")
			r.markClass = (lw == "none") ? "" : w;
		else return "unknown key in a route block -- paint, range, cone, max, every or mark";
		return "";
	}

	private static String FuseKey(WM_Fuse f, String key, String val)
	{
		String w  = Unquote(val);
		String lw = w.MakeLower();
		if (key == "tics")
		{
			if (!IsWhole(lw) || lw.ToInt() < 1 || lw.ToInt() > 1050) return "tics is a whole number from its start to the blast, 1 to 1050 (30 seconds)";
			f.tics = lw.ToInt();
		}
		else if (key == "starts")
		{
			if (lw == "pulloff")      f.starts = WM_Fuse.STARTS_PULLOFF;
			else if (lw == "release") f.starts = WM_Fuse.STARTS_RELEASE;
			else if (lw == "throw")   f.starts = WM_Fuse.STARTS_THROW;
			else return "starts is pulloff (the pin coming out), release (the lever flying) or throw (leaving the hand)";
		}
		else if (key == "blast")
		{
			if (w == "") return "blast names the actor that goes off, in quotes";
			f.blastClass = w;
		}
		else if (key == "cookoff")
		{
			if (lw == "player")    f.cookOffAtPlayer = true;
			else if (lw == "none") f.cookOffAtPlayer = false;
			else return "cookoff is player (run out in the hand, it goes off at the player) or none";
		}
		else if (key == "dud")
			f.dudClass = (lw == "none") ? "" : w;
		else return "unknown key in a fuse block -- tics, starts, blast, cookoff or dud";
		return "";
	}

	private static String MountKey(WM_Mount m, String key, String val)
	{
		String lw = Unquote(val).MakeLower();
		if (key == "at")
		{
			int atKind = WM_Mount.AtFromWord(lw);
			if (atKind == WM_Mount.AT_UNSTATED) return "at is back_left, back_right (reached over that shoulder) or forearm_off (riding the off hand's arm)";
			m.at = atKind;
		}
		else if (key == "holds")
		{
			if (lw != "weapon") return "holds is weapon -- the weapon itself lives there";
			m.holdsWeapon = true;
		}
		else return "unknown key in a mount block -- at or holds";
		return "";
	}

	// ---- VERB KEYS ---------------------------------------------------------------
	//
	// Returns WHY a verb key is refused, or "" when it is taken -- and keeps every
	// taken key and its value on the verb, in order, so a card block laid over an
	// archetype's verb can be replayed onto a copy of it (FinishCard).
	private static String VerbKey(WM_Verb v, String key, String val)
	{
		String why = VerbKeyBody(v, key, val);
		if (why == "")
		{
			v.keys.Push(key);
			v.vals.Push(val);
		}
		return why;
	}

	private static String VerbKeyBody(WM_Verb v, String key, String val)
	{
		String kn = WM_Verb.KindName(v.kind);
		String owners = VerbKeyOwners(key);
		if (owners == "") return String.Format("unknown key in a %s block", kn);
		if (!VerbTakesKey(v.kind, key)) return String.Format("%s belongs to %s, not a %s block", key, owners, kn);

		String w  = Unquote(val);
		String lw = w.MakeLower();
		double frac = ReadFraction(lw);    // -1 unless a plain number from 0 to 1

		if (key == "part")
		{
			if (w == "") return "part names a part of this card";
			v.partId = w;
		}
		else if (key == "latch")
		{
			if (w == "") return "latch names a part of this card, or none";
			v.latchId = (lw == "none") ? "" : w;
		}
		else if (key == "latchat")
		{
			if (frac <= 0) return "latchat is a number above 0, at most 1 -- how far the latch must be thrown";
			v.latchAt = frac;
		}
		else if (key == "latchreturn")
		{
			if (lw == "spring")    v.latchReturnSpring = true;
			else if (lw == "stay") v.latchReturnSpring = false;
			else return "latchreturn is spring (it goes home when let go) or stay (it stays where the hand leaves it)";
		}
		else if (key == "outat")
		{
			if (frac <= 0) return "outat is a number above 0, at most 1 -- how far out the stroke counts as worked";
			v.outAt = frac;
		}
		else if (key == "apex")
		{
			if (frac <= 0) return "apex is a number above 0, at most 1 -- where the hand feels it stop";
			v.apex = frac;
		}
		else if (key == "homeat")
		{
			if (frac < 0 || frac >= 1) return "homeat is a number from 0, below 1 -- how far out still counts as home";
			v.homeAt = frac;
			v.homeAtStated = true;
		}
		else if (key == "openat")
		{
			if (frac <= 0) return "openat is a number above 0, at most 1";
			v.openAt = frac;
		}
		else if (key == "closeat")
		{
			if (frac < 0 || frac >= 1) return "closeat is a number from 0, below 1 -- back to here the part is shut again";
			v.closeAt = frac;
			v.closeAtStated = true;
		}
		else if (key == "rides")
		{
			if (w == "") return "rides names a part of this card, or none";
			v.ridesId = (lw == "none") ? "" : w;
		}
		else if (key == "by" && v.kind == WM_Verb.PULLOFF)
		{
			if (lw == "hand")      v.pullByHead = false;
			else if (lw == "head") v.pullByHead = true;
			else return "a pulloff's by is hand (the other hand pulls it) or head (it is brought to the mouth)";
		}
		else if (key == "by")
		{
			if (lw == "hand")          { v.ejectByTilt = false; v.tiltAlongBarrel = false; }
			else if (lw == "muzzleup") { v.ejectByTilt = true;  v.tiltAlongBarrel = true; }
			else if (lw == "tilt")     v.ejectByTilt = true;
			else return "by is hand (a part worked past at), tilt (an axis of the gun pointed up past at -- tiltaxis says which) or muzzleup (a tilt along the bore)";
		}
		else if (key == "tiltaxis")
		{
			if (lw == "barrel")    { v.tiltAlongBarrel = true;  v.tiltAxis = (0, 0, 0); }
			else if (lw == "up")   { v.tiltAlongBarrel = false; v.tiltAxis = (0, 0, 1); }
			else if (lw == "down") { v.tiltAlongBarrel = false; v.tiltAxis = (0, 0, -1); }
			else if (IsTriple(w))
			{
				Vector3 tiltDir = Unit(ReadTriple(w));
				if (tiltDir.Length() < 0.5) return "tiltaxis is a direction -- x, y and z cannot all be zero";
				v.tiltAlongBarrel = false;
				v.tiltAxis = tiltDir;
			}
			else return "tiltaxis is barrel, up, down, or x, y, z in the gun's model axes";
			v.tiltAxisStated = true;
		}
		else if (key == "seatat")
		{
			if (frac <= 0 || frac >= 1) return "seatat is a number between 0 and 1 -- how far in the catch takes the magazine";
			v.seatAt = frac;
		}
		else if (key == "detachat")
		{
			if (frac <= 0) return "detachat is a number above 0, at most 1 -- let go past it and the container drops";
			v.detachAt = frac;
		}
		else if (key == "pullout")
		{
			if (frac <= 0) return "pullout is a number above 0, at most 1 -- pulled to it, the container is in the hand";
			v.pullOutAt = frac;
		}
		else if (key == "at")
		{
			if (v.kind == WM_Verb.LOAD)
			{
				if (!IsTriple(w)) return "at is a point: x, y, z in the gun's model space";
				v.loadAt = ReadTriple(w);
			}
			else
			{
				if (frac <= 0) return "at is a number above 0, at most 1 -- how far the part travels before it throws";
				v.at = frac;
			}
		}
		else if (key == "size")
		{
			if (!IsTriple(w)) return "size is three half-sizes: x, y, z";
			v.loadSize = ReadTriple(w);
		}
		else if (key == "dir")
		{
			if (!IsTriple(w)) return "dir is a direction: x, y, z in the gun's model space -- the way a round travels going in";
			Vector3 loadWay = ReadTriple(w);
			if (loadWay.Length() < 1e-6) return "dir cannot be 0, 0, 0 -- it is the way a round travels going in";
			v.loadDir = loadWay.Unit();
		}
		else if (key == "onout")
		{
			if (lw == "eject") v.onOutEject = true;
			else if (lw == "none") { v.onOutEject = false; v.fromStore = ""; }
			else return "onout is eject or none";
		}
		else if (key == "onhome")
		{
			if (lw == "feed") v.onHomeFeed = true;
			else if (lw == "none") { v.onHomeFeed = false; v.feedStore = ""; v.intoStore = ""; }
			else return "onhome is feed or none";
		}
		else if (key == "onopen")
		{
			if (lw == "ejectall") v.onOpenEjectAll = true;
			else if (lw == "none") { v.onOpenEjectAll = false; v.fromStore = ""; }
			else return "onopen is ejectall or none";
		}
		else if (key == "from")
		{
			if (w == "") return "from names a store";
			v.fromStore = w;
		}
		else if (key == "feed")
		{
			if (w == "") return "feed names a store";
			v.feedStore = w;
		}
		else if (key == "into")
		{
			if (w == "") return "into names a store";
			v.intoStore = w;
		}
		else if (key == "store")
		{
			if (w == "") return "store names a store";
			v.storeId = w;
		}
		else if (key == "return" || key == "rest")
		{
			if      (lw == "spring") v.ret = WM_Verb.RET_SPRING;
			else if (lw == "hand")   v.ret = WM_Verb.RET_HAND;
			else if (lw == "stay")   v.ret = WM_Verb.RET_STAY;
			else return String.Format("%s is spring, hand or stay", key);
		}
		else if (key == "holdopen")
		{
			if (lw == "whenempty") v.holdOpenWhenEmpty = true;
			else if (lw == "never" || lw == "no" || lw == "none") v.holdOpenWhenEmpty = false;
			else return "holdopen is whenempty or never";
		}
		else if (key == "auto")
		{
			if (lw == "onshot") { v.autoOnShot = true; v.autoOnShotStill = false; }
			else if (lw == "onshotstill") { v.autoOnShot = true; v.autoOnShotStill = true; }
			else if (lw == "none" || lw == "no") { v.autoOnShot = false; v.autoOnShotStill = false; }
			else return "auto is onshot, onshotstill or none";
		}
		else if (key == "close")
		{
			if (lw == "flick" || lw == "hand") v.closeBy = lw;
			else if (lw == "none") v.closeBy = "";
			else return "close is flick, hand or none";
		}
		else if (key == "flickaxis")
		{
			if (lw == "up")        { v.flickAxis = (0, 0, 1); v.flickAxisSide = false; }
			else if (lw == "side") { v.flickAxis = (0, 0, 0); v.flickAxisSide = true; }
			else if (IsTriple(w))
			{
				Vector3 flickDir = Unit(ReadTriple(w));
				if (flickDir.Length() < 0.5) return "flickaxis is a direction -- x, y and z cannot all be zero";
				v.flickAxis = flickDir;
				v.flickAxisSide = false;
			}
			else return "flickaxis is up, side, or x, y, z in the gun's model axes -- the way a flick shuts it";
			v.flickStated = true;
		}
		else if (key == "flickscale")
		{
			if (!IsNumber(lw) || lw.ToDouble() <= 0 || lw.ToDouble() > 4)
				return "flickscale is a number above 0, at most 4 -- how hard a flick, as a multiple of wm_flick_speed";
			v.flickScale  = lw.ToDouble();
			v.flickStated = true;
		}
		else if (key == "button" || key == "handtake" || key == "all")
		{
			int yn = ReadYesNo(lw);
			if (yn < 0) return String.Format("%s is yes or no", key);
			if (key == "button") v.button = (yn > 0);
			else if (key == "all") v.all = (yn > 0);
			else
			{
				v.handTake = (yn > 0);
				v.handTakeStated = true;
			}
		}
		else if (key == "slot")
		{
			if (lw == "next") { v.slotNext = true; v.slot = -1; }
			else if (IsWhole(lw)) { v.slotNext = false; v.slot = lw.ToInt(); }
			else return "slot is a whole number from 0, or next";
		}
		else if (key == "subject")
		{
			// Only a load takes this key: what a hand brings to a load point -- one shell,
			// one cartridge, or a loader holding several.
			if (lw != "shell" && lw != "round" && lw != "loader")
				return "a load's subject is shell, round or loader -- what the hand brings to it";
			v.subject = lw;
		}
		else if (key == "offat")
		{
			if (frac <= 0) return "offat is a number above 0, at most 1 -- pulled past it along its dof, the part comes away";
			v.offAt = frac;
		}
		else if (key == "arms")
		{
			int armsYn = ReadYesNo(lw);
			if (armsYn < 0) return "arms is yes (a throw after the pin is out is live) or no";
			v.arms = (armsYn > 0);
		}
		else if (key == "heldby")
		{
			if (lw != "grip") return "heldby is grip -- the holding hand's grip keeps it shut";
			v.heldByGrip = true;
		}
		else if (key == "needs" && v.kind == WM_Verb.PULLOFF)
		{
			if (lw == "trigger")   v.needsTrigger = true;
			else if (lw == "none") v.needsTrigger = false;
			else return "a pulloff's needs is trigger (only while the holding hand's trigger is held) or none";
		}
		else if (key == "needs")
		{
			if (lw == "none") v.needsOpen = "";
			else if (lw.Length() > 5 && lw.Left(5) == "open:")
			{
				String gate = w.Mid(5);
				gate.StripLeftRight();
				if (gate == "") return "needs is open:<an open verb's id>, or none";
				v.needsOpen = gate;
			}
			else return "needs is open:<an open verb's id>, or none";
		}
		return "";
	}

	// WHICH VERBS TAKE WHICH KEYS. One table, read by the key check and by the
	// refusal that says where a misplaced key belongs.
	private static bool VerbTakesKey(int verbKind, String key)
	{
		if (verbKind == WM_Verb.CYCLE)
			return key == "part" || key == "outat" || key == "apex" || key == "homeat"
				|| key == "onout" || key == "from" || key == "onhome" || key == "feed" || key == "into"
				|| key == "return" || key == "holdopen" || key == "auto";
		if (verbKind == WM_Verb.OPEN)
			return key == "part" || key == "latch" || key == "openat" || key == "closeat" || key == "rest" || key == "return"
				|| key == "onopen" || key == "from" || key == "close" || key == "button" || key == "flickaxis" || key == "flickscale"
				|| key == "latchat" || key == "latchreturn";
		if (verbKind == WM_Verb.SWAP)
			return key == "part" || key == "store" || key == "seatat" || key == "detachat" || key == "pullout"
				|| key == "button" || key == "handtake" || key == "needs" || key == "latch" || key == "latchat" || key == "latchreturn";
		if (verbKind == WM_Verb.LOAD)
			return key == "into" || key == "slot" || key == "at" || key == "size" || key == "dir" || key == "subject" || key == "needs"
				|| key == "rides";
		if (verbKind == WM_Verb.EJECT)
			return key == "part" || key == "at" || key == "from" || key == "all" || key == "needs" || key == "by"
				|| key == "tiltaxis" || key == "button";
		if (verbKind == WM_Verb.START)
			return key == "part" || key == "outat";
		if (verbKind == WM_Verb.PULLOFF)
			return key == "part" || key == "offat" || key == "by" || key == "needs" || key == "arms";
		if (verbKind == WM_Verb.RELEASE)
			return key == "part" || key == "heldby";
		return false;
	}

	// "a cycle / open block" -- every verb that takes this key -- or "" for none.
	private static String VerbKeyOwners(String key)
	{
		String owners = "";
		for (int k = WM_Verb.CYCLE; k <= WM_Verb.RELEASE; k++)
			if (VerbTakesKey(k, key)) owners = owners .. ((owners == "") ? "" : " / ") .. WM_Verb.KindName(k);
		if (owners == "") return "";
		return "a " .. owners .. " block";
	}

	// A plain number from 0 to 1, or -1 for anything else -- so a typo is refused
	// rather than read by ToDouble as 0.
	private static double ReadFraction(String v)
	{
		if (!IsNumber(v)) return -1.0;
		double d = v.ToDouble();
		if (d < 0.0 || d > 1.0) return -1.0;
		return d;
	}

	private static bool IsNumber(String v)
	{
		int n = v.Length();
		if (n == 0) return false;
		int digits = 0;
		int dots = 0;
		for (int i = 0; i < n; i++)
		{
			int c = v.ByteAt(i);
			if (c >= 48 && c <= 57) digits++;                 // 0-9
			else if (c == 46) { dots++; if (dots > 1) return false; }   // .
			else if ((c == 45 || c == 43) && i == 0) continue; // - or + leading
			else return false;
		}
		return digits > 0;
	}

	private static bool IsWhole(String v)
	{
		int n = v.Length();
		if (n == 0) return false;
		for (int i = 0; i < n; i++)
		{
			int c = v.ByteAt(i);
			if (c < 48 || c > 57) return false;
		}
		return true;
	}

	private static bool IsTriple(String v)
	{
		Array<String> n;
		v.Split(n, ",", TOK_SKIPEMPTY);
		if (n.Size() != 3) return false;
		for (int i = 0; i < 3; i++)
		{
			String t = n[i];
			t.StripLeftRight();
			if (!IsNumber(t)) return false;
		}
		return true;
	}

	// 1 yes, 0 no, -1 neither.
	private static int ReadYesNo(String v)
	{
		if (v == "yes" || v == "true"  || v == "1") return 1;
		if (v == "no"  || v == "false" || v == "0") return 0;
		return -1;
	}

	private static void Refuse(String src, int line, String what, String why)
	{
		Console.Printf("\c[Red]WM ERROR\c- refused %s line %d -- \"%s\": %s. That weapon is skipped; the rest load.",
			src, line, what, why);
	}

	private static String Unquote(String s)
	{
		s.StripLeftRight();
		if (s.Length() >= 2 && s.Left(1) == "\"" && s.Mid(s.Length() - 1) == "\"")
			return s.Mid(1, s.Length() - 2);
		return s;
	}

	// The two-part `"path" "file"` shape A_ChangeModel itself takes.
	private static void ReadPair(String val, out String path, out String file)
	{
		Array<String> q;
		val.Split(q, "\"", TOK_SKIPEMPTY);
		int n = 0;
		for (int i = 0; i < q.Size(); i++)
		{
			String t = q[i]; t.StripLeftRight();
			if (t.Length() == 0) continue;
			if (n == 0) path = t;
			else if (n == 1) file = t;
			n++;
		}
	}

	private static Vector3 ReadTriple(String v)
	{
		Array<String> n;
		v.Split(n, ",", TOK_SKIPEMPTY);
		double x = n.Size() > 0 ? n[0].ToDouble() : 0.0;
		double y = n.Size() > 1 ? n[1].ToDouble() : 0.0;
		double z = n.Size() > 2 ? n[2].ToDouble() : 0.0;
		return (x, y, z);
	}

	// Axes are normalised on the way in, so a card can be written with
	// rounded numbers and every consumer still gets a unit vector.
	private static Vector3 Unit(Vector3 v)
	{
		return v.Length() > 1e-9 ? v.Unit() : v;
	}
}
