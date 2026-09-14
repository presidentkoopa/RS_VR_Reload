// ============================================================================
// WHAT THE RELOAD SYSTEM STILL DRAWS ITSELF: a belt link, and the markers that show
// where a hand can take hold. The shot's own looks -- the flash, the smoke, the
// round, its impacts and the spent brass -- are RS_Ballistics'. The WM_ copies
// that drew them went in RSB_CALL_SITES_HANDOFF.md section 8.
//
// Every sprite here is from RS_Main's licensed pool (sprites/combatfx), copied
// under this package's own four-letter names so nothing else in a load order
// can shadow them. Every sound is from RS_Main's sounds/combatfx and
// sounds/rs_weapon, likewise copied -- RS_Main is not in the load order, and a
// sound or sprite that resolves to nothing is silent.
// ============================================================================

class WM_FX
{
	static double Cvf(String n, double d)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetFloat() : d;
	}
	static bool Cvb(String n, bool d)
	{
		let c = CVar.GetCVar(n, players[consoleplayer]);
		return c ? c.GetBool() : d;
	}
}

// A BELT LINK (card `linkmodel`, G16): thrown with each case a belt-fed gun throws on the shot.
//
// A projectile, for the engine's own bounce: it rattles off the floor, skips off a wall and settles.
// THRUACTORS so it never hits anything, and no impact activation so it can never press a switch. It
// follows RS Ballistics' Casings switch (WM_Rig.Brass). Its mesh is the card's, worn by A_ChangeModel --
// which needs a MODELDEF block for this class, the weapon package's (`FrameIndex WMCS A 0 0`), as the
// loose magazine's is. With no block in the load order there is no mesh to wear, and it goes at once
// rather than drawing as a sprite blown up to a link's scale. Looks only, spawned where the brass is.
//
// It was a WM_Casing until RSB_CALL_SITES_HANDOFF.md section 8 took the brass to RS_Ballistics. What it
// kept is the bounce, the tumble and the fade. What it lost is the casing's size slider (a link is its
// card's size) and the hot-brass glow, which lit a link for its first tics after Wear had put it out.
class WM_BeltLink : Actor
{
	Default
	{
		Projectile;
		-NOGRAVITY
		-ACTIVATEIMPACT
		-ACTIVATEPCROSS
		+THRUACTORS
		+NOTELEPORT
		+DONTSPLASH
		+USEBOUNCESTATE
		BounceType "Doom";
		BounceFactor 0.45;
		WallBounceFactor 0.3;
		BounceCount 4;
		BounceSound "wm/casing";
		Gravity 0.6;
		Speed 0;
		Damage 0;
		Radius 1;
		Height 1;
	}

	double linkScale;
	private int life;
	private int tumbleSeq;  // bounces so far, for its tumble's jitter

	// ITS GUN'S LINK. Called once, right after it is spawned and thrown. May destroy it.
	void Wear(WM_Card card)
	{
		linkScale = (card.linkScale > 0) ? card.linkScale : 0.34;
		if (card.linkModelFile != "")
			A_ChangeModel(GetClassName(), 0, card.linkModelPath, card.linkModelFile, 0, card.linkSkinPath, card.linkSkinFile);
		A_SetScale(linkScale);
		if (!HasModelFrame())
		{
			WM_Log.Once(WM_Log.LV_WARN, "beltlink:nomodel", String.Format(
				"%s: no belt link is thrown -- no MODELDEF block for WM_BeltLink is loaded, so it has no mesh to wear (the weapon package declares it, FrameIndex WMCS A 0 0)",
				card.weaponClass));
			Destroy();
		}
	}

	States
	{
	Spawn:
		WMCS A 2;
		Loop;
	Bounce:
		// NOT frandom: a link exists for the console player only, and a playsim draw here
		// desyncs a netgame (jitter.zs). The same +-60 degrees.
		WMCS A 0 { angle += WM_Jitter.Between(-60.0, 60.0, level.maptime, ++tumbleSeq, int(pos.x * 16) ^ int(pos.y * 16) ^ int(pos.z * 16)); }
		Goto Spawn;
	Death:
		WMCS A -1;
		Stop;
	}

	override void Tick()
	{
		// LYING STILL, it fades once it has lain wm_casing_life tics ("Belt links lie", WM_FireMenu).
		if (InStateSequence(CurState, ResolveState("Death")))
		{
			life++;
			if (life > int(WM_FX.Cvf("wm_casing_life", 700.0)))
			{
				A_SetRenderStyle(Alpha, STYLE_Translucent);
				Alpha -= 0.05;
				if (Alpha <= 0) { Destroy(); return; }
			}
		}
		Super.Tick();
	}
}

// WHERE A HAND CAN TAKE HOLD.
//
// THE DRAWN VOLUME IS THE TESTED VOLUME. A wire sphere, centred exactly on the
// point the reach test measures from and scaled to exactly the radius it tests
// -- so a thing that looks in reach IS in reach. The same wire sphere
// RS_TestPistol drew, for the same reason.
//
// Placed by SetOrigin every tic, never by an attached light's offset: those
// offsets are rotated by the owner's yaw, so a marker hung off the player
// swings round with your body and lands beside the point it was meant to show.
class WM_Marker : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+NOTELEPORT
		+DONTSPLASH
		RenderStyle "Add";
		Alpha 0.7;
		Radius 1;
		Height 1;
	}

	// WHAT IT MARKS, told apart by colour so one glance says which sphere is
	// which: GOLD is the ammo pouch, BLUE is a part of a gun, GREEN is anything
	// your hand is inside right now. A marker also carries a faint light of its
	// own colour, so it can still be found if the wire is hard to see.
	const KIND_PART  = 0;
	const KIND_POUCH = 1;

	private int  shown;   // -1 hidden, else kind * 2 + hot
	const SPHERE_RADIUS = 1.045;   // rs_wiresphere.obj, measured

	// Nothing shown yet. Left at the default 0 it read as "idle part, already
	// shown", so the first idle marker never got its skin or its light.
	override void BeginPlay()
	{
		Super.BeginPlay();
		shown = -1;
	}

	States
	{
	Spawn:
		WMMK A -1;
		Stop;
	}

	// LINT-SEATS: wm_grab_all
	//
	// IN THE GUN'S OWN DRAWN FRAME (Actor.FollowActor), not posted to a world
	// position every tic. The renderer then keeps the sphere on the gun every
	// frame it draws -- including while a menu has the playsim frozen, which is
	// exactly when someone is dragging the slider that moves it. tuneCVar names
	// the live offset set the renderer adds to the seat (FollowActorOfsCVar);
	// script adds the same numbers to the point it tests, so the two agree.
	//
	// The seat and the size are both in FRAME units, so the size divides by the
	// same ratio the seat did -- a sphere seated in the controller's frame at
	// world scale would come out a third of the size it should be.
	void PlaceInFrame(Actor frameOwner, Vector3 seat, double frameUnits, Name tuneCVar,
		Vector3 worldNear, Vector3 axes, bool hot, int kind = KIND_PART, Name radiusCVar = 'None',
		Name ownCVar = 'None', Name shapePrefix = 'None')
	{
		double radius = max(axes.X, max(axes.Y, axes.Z));
		if (!frameOwner) { PlaceAt(worldNear, axes, hot, kind, radiusCVar); return; }
		// THIS PART'S OWN TWO CHANNELS, beside the whole-gun one: its nudge (a
		// second seat set) and its shape (a placement set's three axes). Both
		// renderer-read, so this oval answers its own sliders with the menu
		// open and no other oval moves with it.
		FollowActorOfsCVar2 = ownCVar;
		PlacementPrefix     = shapePrefix;
		FollowActor        = frameOwner;
		FollowActorSlot    = -1;
		FollowActorOfs     = seat;
		FollowActorOfsCVar = tuneCVar;
		// Its own position no longer draws it; it only decides whether the
		// renderer bothers to, so it stays next to the gun.
		SetOrigin(worldNear, true);
		// THE SIZE, HANDED OVER TOO (Actor.ScaleCVar). radiusCVar is the slider
		// that governs this sphere's reach, in map units; the unit says what one
		// of those is worth as a scale here -- the mesh's own radius, and the
		// frame's units on top. While that slider reads zero the renderer leaves
		// the scale set below alone, which is the card's own number for this part.
		ScaleCVar     = radiusCVar;
		ScaleCVarUnit = 1.0 / (SPHERE_RADIUS * max(0.01, frameUnits));
		Shape(axes);
		Dress(max(0.05, axes.X) / max(0.01, frameUnits), radius, hot, kind);
	}

	void PlaceAt(Vector3 at, Vector3 axes, bool hot, int kind = KIND_PART, Name radiusCVar = 'None')
	{
		FollowActor        = null;
		FollowActorOfsCVar = 'None';
		SetOrigin(at, true);
		ScaleCVar     = radiusCVar;
		ScaleCVarUnit = 1.0 / SPHERE_RADIUS;
		Shape(axes);
		Dress(max(0.05, axes.X), max(axes.X, max(axes.Y, axes.Z)), hot, kind);
	}

	// THE OVAL, drawn (Actor.ScaleAxes). The uniform scale below carries the
	// length; these are the other two as ratios of it, because Actor.Scale has
	// only two numbers and a mesh has three. A ball states nothing, so a live
	// size slider can then set all three at once without a shape fighting it.
	private void Shape(Vector3 axes)
	{
		double l = max(0.01, axes.X);
		if (abs(axes.Y - l) < 0.01 && abs(axes.Z - l) < 0.01) ScaleAxes = (0, 0, 0);
		else ScaleAxes = (1.0, axes.Y / l, axes.Z / l);
	}

	// The look: size, fade, skin and light. Shared by both seatings above --
	// drawnRadius is in whatever units the sphere is drawn in, lightRadius is
	// always map units, because a dynamic light is placed in the world.
	private void Dress(double drawnRadius, double lightRadius, bool hot, int kind)
	{
		A_SetScale(drawnRadius / SPHERE_RADIUS);
		// THE FADE, HANDED TO THE RENDERER (Actor.AlphaCVar). Assigned here every
		// tic it would stop answering the moment a menu opened -- which is when
		// the slider is being dragged. Alpha is still set as the fallback for an
		// engine without the field.
		AlphaCVar = 'wm_marker_alpha';
		Alpha = WM_FX.Cvf("wm_marker_alpha", 0.7);
		int want = kind * 2 + (hot ? 1 : 0);
		if (shown != want)
		{
			String skin = hot ? "rs_wire_hot.png" : (kind == KIND_POUCH ? "rs_wire_pouch.png" : "rs_wire_idle.png");
			A_ChangeModel('WM_Marker', 0, "models", "rs_wiresphere.obj", 0, "models", skin);
			Color c = hot ? Color(255, 80, 255, 90) : (kind == KIND_POUCH ? Color(255, 255, 200, 60) : Color(255, 70, 150, 255));
			A_AttachLight("wm_mark", DynamicLight.PointLight, c, int(max(4.0, lightRadius * 1.5)), 0, DynamicLight.LF_ATTENUATE);
			shown = want;
		}
		bINVISIBLE = false;
	}

	// THE ONE BEING EDITED, drawn over the oval itself: the same mesh, shaded to
	// one colour and BREATHING -- a sine fade the renderer runs off the wall
	// clock (Actor.PulseHz), so it keeps breathing while the menu has the game
	// frozen. Never a hard flash: photosensitivity.
	//
	// gate is this part's own cvar, which the page sets as you change part
	// (Actor.VisibleCVar, menu.zs). The renderer reads it every frame, so the
	// mark follows the menu with nothing running on the game side at all.
	// The breathing skin over the oval being edited. Its channels are already
	// set by PlaceInFrame -- this only says which gate shows it and how it
	// breathes.
	void MarkSelected(Name gate, double hz, double depth, Color col)
	{
		VisibleCVar = gate;
		PulseHz     = hz;
		PulseDepth  = depth;
		SetShade(col);
		A_SetRenderStyle(1.0, STYLE_TranslucentStencil);
	}

	void Conceal()
	{
		if (shown != -1) A_RemoveLight("wm_mark");
		// Let go of the gun too: a pooled marker reused for the pouch next tic
		// would otherwise still be seated in a gun's frame, or sized by another
		// sphere's slider.
		FollowActor        = null;
		FollowActorOfsCVar = 'None';
		ScaleCVar          = 'None';
		ScaleAxes          = (0, 0, 0);
		bINVISIBLE = true;
		shown = -1;
	}
}
