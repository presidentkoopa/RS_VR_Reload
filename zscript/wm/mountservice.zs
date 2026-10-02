// ============================================================================
// WHAT A MOUNT NEEDS TO KNOW ABOUT A WM GUN (RS_WeaponMountService).
//
// For RS_HardPoints, which parks weapons on the body -- shoulders, forearm, the holsters --
// and has to draw, bind and reload guns it does not own the rules for. It finds this with
// ServiceIterator.Find("RS_WeaponMountService"), so neither package names the other at
// compile time and either can ship alone. HardPoints keeps its existing behaviour when this
// is absent; nothing here is required for it to work, only for it to work WELL.
//
// THE FOUR QUESTIONS, and the bug each one answers:
//
//   GetString("wm.look", "", 0, 0, weapon)
//       WHAT TO DRAW ON THE MOUNT. A WM gun's Ready state is TNT1 -- deliberately, because
//       the thing you see in a hand is a separate PROP actor carrying the model, not the
//       weapon. So a mount that asked the weapon to draw itself got nothing, and stored
//       guns were invisible on their mounts (B3). This returns the prop's class name, and
//       "" for a weapon this system has no card for -- which is the honest answer and the
//       signal to fall back to the weapon's own Spawn state.
//
//   GetString("wm.model", "", 0, 0, weapon)   "path|file", for a caller that would rather
//       build the model itself than spawn the prop class. "" when the card names no model.
//
//   GetInt("wm.mountable", "", 0, 0, weapon)
//       WHERE THIS GUN SAYS IT BELONGS -- its card's `mount` block (WM_Mount.AT_*):
//       1 back left, 2 back right, 3 off-hand forearm. 0 means the card states no mount,
//       which is not the same as "cannot be mounted" and must not be read as a refusal.
//       -1 means this is not a WM gun at all.
//
//   GetInt("wm.bindnow", "", hand, 0, weapon)
//       BIND THE RIG NOW, BEFORE FIRING IT. A gun seated on a mount and fired in place has
//       never been in a hand, so its rig was never bound -- and the first shot was then
//       charged against whatever card the rig last held, which is the previous gun's (B8).
//       Returns 1 if the rig is bound and ready afterwards, 0 if it could not be.
//       hand: 0 main, 1 off.
//
//   GetInt("wm.topup", "", 0, budget, weapon)
//       RELOAD A GUN THAT IS ON A MOUNT, under the reload modes that have a snap fill
//       (3 and 4). Returns the number of rounds actually loaded, 0 if none, -1 if this gun
//       is not a WM gun or the current mode has no snap fill. budget is the most it may
//       take from the reserve; 0 or less means "as much as it needs".
//
// READS, PLUS TWO DELIBERATE WRITES. wm.look, wm.model and wm.mountable are pure reads.
// wm.bindnow and wm.topup change the gun, which is the point of them -- they exist so a
// mount does not have to reach into this system's internals to do it, which is how two
// packages end up with two copies of one rule that then drift.
//
// NETPLAY. wm.bindnow and wm.topup are play-scoped and act on the gun the caller names;
// neither reads a controller, a cvar or consoleplayer, so they are as safe as the same
// calls made from a hand. Everything here is PLAY scoped: the card set is only reachable
// through a play function, and the only caller is an EventHandler, which is play.
// ============================================================================

class RS_WeaponMountService : Service
{
	// ---- the readers ----------------------------------------------------

	override String GetString(String request, string stringArg, int intArg, double doubleArg, Object objectArg, Name nameArg)
	{
		return RS_WeaponMountService.AnswerString(request, objectArg);
	}

	// NO UI OR DATA VARIANTS, and that is not an oversight. Every answer here needs the
	// loaded card set, and reaching it goes through WM_System.CardForWeapon, which is a
	// PLAY function -- a data-scoped copy of these cannot call it. RS_HardPoints is an
	// EventHandler and asks from play, which is the only caller there is. Adding ui
	// variants would mean caching the card set somewhere clearscope, i.e. a second copy of
	// the truth, for a caller that does not exist.

	// THE CARD WITHOUT A RIG, which is the whole difficulty. A gun on a mount is not in a
	// hand, so it has no rig and no prop -- the usual route to a card (WM_Gun.DrawnRig) is
	// null for exactly the weapons a mount cares about. Looked up by class off the loaded
	// set instead.
	play static WM_Card CardOf(Object objectArg)
	{
		let w = Weapon(objectArg);
		if (!w) return null;
		let sys = WM_System(EventHandler.Find("WM_System"));
		if (!sys) return null;
		return sys.CardForWeapon(w.GetClassName());
	}

	play static String AnswerString(String request, Object objectArg)
	{
		let c = CardOf(objectArg);
		if (!c) return "";

		// The prop class is what a hand sees; a mount showing the same thing is the point.
		if (request == "wm.look") return c.propClass;

		// "path|file". A caller that would rather drive A_ChangeModel itself gets the same
		// two strings the rig uses, rather than guessing at a naming convention.
		if (request == "wm.model")
		{
			if (c.modelFile.Length() == 0) return "";
			return c.modelPath .. "|" .. c.modelFile;
		}

		return "";
	}

	// ---- the readers that answer with a number, and the two that act ----

	override int GetInt(String request, string stringArg, int intArg, double doubleArg, Object objectArg, Name nameArg)
	{
		// The two that CHANGE the gun live here, in the play override, and there is no ui
		// or data variant of this class at all -- so nothing outside play can reach them.
		if (request == "wm.bindnow") return BindNow(objectArg, intArg);
		if (request == "wm.topup")   return TopUp(objectArg, int(doubleArg));
		return RS_WeaponMountService.AnswerInt(request, objectArg);
	}

	play static int AnswerInt(String request, Object objectArg)
	{
		let c = CardOf(objectArg);
		if (!c) return -1;

		if (request == "wm.mountable")
		{
			// 0 (AT_UNSTATED) is "the card does not say", NOT "no". A gun with no mount
			// block is still perfectly mountable; it simply expresses no preference, and a
			// mount that treats 0 as a refusal would reject most of the fleet.
			return c.mountSpec ? c.mountSpec.at : WM_Mount.AT_UNSTATED;
		}

		return -1;
	}

	// ---- bind a mounted gun before it fires (B8) -------------------------
	//
	// A gun fired while seated has never been in a hand, so WM_Rig.Bind has never run for
	// it. The rig is per HAND, not per gun, and it holds the LAST card it was given -- so
	// the first shot off a mount was measured, charged and sounded against the previous
	// gun's card. Binding first is the fix, and it has to happen before the shot rather
	// than as a side effect of one.
	private play static int BindNow(Object objectArg, int hand)
	{
		let w = Weapon(objectArg);
		if (!w) return 0;
		let sys = WM_System(EventHandler.Find("WM_System"));
		if (!sys) return 0;

		let c = sys.CardForWeapon(w.GetClassName());
		if (!c) return 0;

		let rig = sys.RigForGun(w);
		if (!rig) return 0;

		// Already this gun's rig: nothing to do, and re-binding would throw away state the
		// gun legitimately holds (its part values, its drive slots).
		if (rig.card == c) return 1;

		rig.Bind(c, w);
		return (rig.card == c) ? 1 : 0;
	}

	// ---- top up a gun sitting on a mount --------------------------------
	//
	// Reload modes 3 and 4 are the ones with a snap fill -- the player does not work the
	// gun's parts, the rounds go in. A gun on a mount is exactly that case: there is no hand
	// on it to rack anything. Modes with verbs are refused rather than faked, because a
	// magazine that fills itself on a shoulder is not the feature anyone asked for.
	private play static int TopUp(Object objectArg, int budget)
	{
		let w = Weapon(objectArg);
		if (!w) return -1;
		let sys = WM_System(EventHandler.Find("WM_System"));
		if (!sys) return -1;

		// PER PLAYER, because the reload mode is a per-player setting -- read it off the
		// gun's OWNER rather than consoleplayer, or in a netgame this answers for whoever
		// happens to be looking at the screen instead of whoever owns the mount.
		let pmo = PlayerPawn(w.Owner);
		if (!pmo || !pmo.player) return -1;
		int mode = WM_System.ReloadMode(pmo.PlayerNumber());
		if (mode != 3 && mode != 4) return -1;

		let rig = sys.RigForGun(w);
		if (!rig || !rig.ammo) return -1;

		// 0 or less: as much as it needs. SnapFill takes the budget as a cap on what it may
		// draw from the reserve, so a large number is "unlimited" in its own terms.
		if (budget <= 0) budget = 0x7FFFFFF;
		return rig.ammo.SnapFill(budget);
	}
}
