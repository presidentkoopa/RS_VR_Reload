// A MAP'S CLIP, TAKEN IN A HAND, IS ONE OF OUR MAGAZINES.
//
// RS_WorldHands asks every "...GrabBecomeService" what a thing a hand closes on
// should be held as (RS_GrabPolicy.Become). A loose clip becomes a WM_LooseMag
// with the same rounds, dressed as the magazine of a gun that fires them -- so
// it can be seated, which a sprite of a clip never could be. Once it is in the
// hand the system re-dresses it for the gun that hand works, as it does any
// magazine.
//
// A SPRITE OR A VOXEL CLIP BECOMES OURS; A MODEL CLIP STAYS. A mod that gives its
// clips a MODELDEF model keeps them exactly as it made them. A sprite clip -- stock,
// or a mod's own sprite -- has no shape a well could take, and a voxel pack's clip is
// a picture of one: both become ours (the owner's rule: the magazine outranks the
// voxel). Only a magazine's worth: a box of fifty stays a box.
// wm_clip_becomes_mag off leaves every clip alone.
//
// NETPLAY: no RNG, and no local render setting decides it -- a sprite clip and a voxel
// clip both become ours, a model clip stays, on every machine alike. The grab itself
// is RS_WorldHands' local hand input (FEEL_PLAN section 10).
class WM_GrabBecomeService : Service
{
	override Object GetObject(String request, string stringArg, int intArg, double doubleArg, Object objectArg, Name nameArg)
	{
		if (request != "grab.become") return null;
		let inv = Ammo(objectArg);
		if (!inv || inv.Owner || inv is "WM_LooseMag") return null;
		// A MOD'S OWN MODEL keeps its clip. A VOXEL does not: HasModelFrame is true for a
		// voxel too, so the test is "has a model, and that model is not a voxel". With a
		// voxel pack loaded (RS_Main's has clipa), a grabbed clip becomes our magazine the
		// way a sprite clip does.
		if (inv.HasModelFrame() && !inv.HasVoxelFrame()) return null;

		let cv = CVar.GetCVar("wm_clip_becomes_mag", players[consoleplayer]);
		if (cv && !cv.GetBool()) return null;

		let sys = WM_System(EventHandler.Find("WM_System"));
		let card = sys ? sys.CardForAmmo(inv.GetParentAmmo()) : null;
		if (!card || inv.Amount <= 0 || inv.Amount > card.capacity) return null;

		let m = WM_LooseMag(Actor.Spawn("WM_LooseMag", inv.Pos, ALLOW_REPLACE));
		if (!m) return null;
		m.Setup(inv.Amount, card);
		// OUR MESH FROM ITS FIRST TIC, even where the engine keeps VoxelOverride on held and
		// grabbed actors. The clip, override and all, is destroyed by RS_GrabPolicy.Become;
		// RS_Held re-derives the flag each tic from HasVoxelFrame, which is false for WMMG.
		m.VoxelOverride = false;
		m.angle = inv.angle;
		WM_Log.Info(String.Format("a %s in your hand became a magazine -- %d rounds%s",
			inv.GetClassName(), inv.Amount, inv.HasVoxelFrame() ? " (it was a voxel clip)" : ""));
		return m;
	}
}
