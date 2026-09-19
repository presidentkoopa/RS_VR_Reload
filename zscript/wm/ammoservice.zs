// ============================================================================
// WHAT A WM GUN HOLDS, FOR A WEAPON HUD (RS_WeaponAmmoService).
//
// For the gun HUD in RS_VRPanels -- the weapon HUD from Ermac's Rusted Legacy (iAmErmac, MIT), kept with his visuals and
// credited to him -- which finds it with ServiceIterator.Find("RS_WeaponAmmoService"), so neither package compiles
// against the other. It asks by weapon:
//
//   GetInt("rounds",  "", 0, 0, weapon)  READY TO FIRE: every live round in the gun's own stores for its main barrel --
//                                        a magazine and its chamber, a tube and its chamber, a cylinder, a pair of
//                                        barrels -- a magazine out of the gun not counted. A gun that fires from the
//                                        reserve: that reserve. -1: not a WM gun, one that fires nothing (a saw), or
//                                        one never yet in a hand on this machine (its rounds are made at its first bind).
//   GetInt("reserve", "", 0, 0, weapon)  SPARE rounds of its ammo in its owner's inventory. -1 for none: a gun that
//                                        fires nothing, one with no ammo type, or one whose reserve IS its rounds.
//   GetInt("state",   "", 0, 0, weapon)  BITS: 1 its chamber is empty (a gun that fires from one), 2 its magazine is out
//                                        (a gun whose magazine detaches), 4 its action is locked back.
//
// GetIntUI and GetIntData answer the same, for a HUD drawing in ui scope or reading from anywhere.
//
// READS ONLY, PRESENTATION ONLY. It reads the gun's own WM_Ammo -- made where that player's hands are worked
// (WM_Rig.Bind), which is why a HUD asks about its own player's guns -- and never writes, spawns or rolls anything.
// ============================================================================

class RS_WeaponAmmoService : Service
{
	override int GetInt(String request, string stringArg, int intArg, double doubleArg, Object objectArg, Name nameArg)
	{
		return RS_WeaponAmmoService.Answer(request, objectArg);
	}

	override int GetIntUI(String request, string stringArg, int intArg, double doubleArg, Object objectArg, Name nameArg)
	{
		return RS_WeaponAmmoService.Answer(request, objectArg);
	}

	override int GetIntData(String request, string stringArg, int intArg, double doubleArg, Object objectArg, Name nameArg)
	{
		return RS_WeaponAmmoService.Answer(request, objectArg);
	}

	clearscope static int Answer(String request, Object objectArg)
	{
		let g = WM_Gun(objectArg);
		if (!g) return -1;
		let a = g.wmAmmo;
		bool firesNothing = a && a.firesFrom == WM_Card.FIRES_NOTHING;
		bool firesReserve = a && a.firesFrom == WM_Card.FIRES_RESERVE;

		if (request ~== "reserve")
		{
			if (firesNothing || firesReserve) return -1;
			return RS_WeaponAmmoService.Carried(g);
		}
		if (request ~== "rounds")
		{
			if (!a || firesNothing) return -1;
			if (firesReserve) return RS_WeaponAmmoService.Carried(g);
			int live = 0;
			for (int i = 0; i < a.stores.Size(); i++)
			{
				let s = a.stores[i];
				if (!s || s.barrelStore || s.placeholder || s.Detached()) continue;
				live += s.Live();
			}
			return live;
		}
		if (request ~== "state")
		{
			if (!a) return 0;
			int bits = 0;
			if (a.firesFrom == WM_Card.FIRES_CHAMBER && !a.chambered) bits |= 1;
			if (!a.magIn && a.MagDetaches()) bits |= 2;
			if (a.actionLock) bits |= 4;
			return bits;
		}
		return 0;
	}

	// ITS AMMO IN ITS OWNER'S INVENTORY (Weapon.AmmoType1); -1 with no ammo type or no owner.
	clearscope static int Carried(WM_Gun g)
	{
		if (!g || !g.Owner || !g.AmmoType1) return -1;
		let inv = g.Owner.FindInventory(g.AmmoType1);
		return inv ? inv.Amount : 0;
	}
}
