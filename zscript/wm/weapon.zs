// ============================================================================
// THE WEAPONS. One base that fires; the prop on your controller is what you see.
//
// A weapon exists because GZDoom's idea of "a gun" is a Weapon class -- firing,
// a slot and a trigger live there and nothing script-side can fire without
// one. So each gun is a class, and the class is a name, a hand, an ammo type and
// its SHOT (below). How the gun is worked -- its parts, stores, verbs, every mesh
// number -- is its card.
//
// NO GUN LIVES HERE. This is the reload system; the guns are a weapon package
// loaded after it (RS_VR_Weapons), which derives its classes from WM_Gun and its
// props from WM_Prop. Nothing in this package names any of them.
//
// DUAL-WIELD IS THE ENGINE'S OWN. +WEAPON.OFFHANDWEAPON puts a weapon in
// player.OffhandWeapon and makes its layer PSP_OFFHANDWEAPON; BT_OFFHANDATTACK
// fires it. A_FireBullets from an off-hand weapon leaves the off hand. None of
// that is invented here.
//
// ------------------------------------------------------------ TNT1 VIEW STATES
//
// Every view state is TNT1: the weapon draws nothing. What you look at is the
// model on your controller. Hiding a sprite every tic was a fight with
// RS_WorldHands' StandInForFist; with no picture there is nothing to argue about.
//
// ------------------------------------------------------------ VANILLA
//
// A class that says nothing about its shot fires the Doom pistol's: one round,
// dead on, 5 x 1d3 -- what A_FireBullets(5.6, 0, 1, 5) did for a shot that is not
// a refire. 19 tics a shot, as vanilla's 4 + 6 + 4 + 5 -- with the round leaving
// on the FIRST of them rather than the fifth, because a 114ms wait between
// pulling a trigger and the gun going off is a lag in a headset, not a period
// detail.
//
// ONE PULL, ONE SHOT. The trigger has to come back before the next one. Held
// down, nothing happens -- which is what a semi-automatic pistol does, and what
// a pump does between strokes. A class that says WM_Gun.FullAuto keeps firing
// while held (WM_HoldFire); one that says WM_Gun.ChambersPerPull fires several
// loaded chambers on one pull (a double's two barrels).
//
// VANILLA'S HELD FIRE. A class that says WM_Gun.FullAuto refires while held, as vanilla's A_ReFire;
// one that also says WM_Gun.FirstShotsAccurate N fires the first N shots of each hold dead on and
// scatters the rest, as vanilla's pistol (1) and chaingun (2) do.
// ============================================================================

class WM_Gun : Weapon
{
	Default
	{
		Weapon.SelectionOrder 1900;
		Weapon.AmmoType1 "Clip";
		Weapon.AmmoUse1 0;
		Weapon.AmmoGive1 0;
		+WEAPON.NOAUTOFIRE
		+WEAPON.NOAUTOAIM
		Inventory.PickupMessage "Weapon";
	}

	// ITS WEAPON SHEET (sheet.zs, WM_System.ApplySheet), for a gun made once the cards are loaded -- a pickup, a
	// drop, a give. A gun made before them (a map's own, a start item) takes it at WorldLoaded instead.
	// Playsim, alike on every machine.
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		let sys = WM_System(EventHandler.Find("WM_System"));
		if (sys) sys.ApplySheet(self);
	}

	// TAKING A WEAPON SHEET: every shot field set back to this class's Default, then the sheet laid over them, so a
	// key taken out of a sheet does not linger in a saved game. s may be null: the gun then holds its class's
	// Default, exactly what it held before sheets existed. Only WM_System.ApplySheet calls it.
	void TakeSheet(WM_Sheet s)
	{
		Class<WM_Gun> gc = (Class<WM_Gun>)(GetClass());
		if (!gc) return;
		let def = GetDefaultByType(gc);
		if (!def) return;
		bool has = (s != null);

		shotPelletCount      = (has && s.shotPelletsStated)      ? s.shotPelletCount      : def.shotPelletCount;
		shotSpreadYaw        = (has && s.shotSpreadStated)       ? s.shotSpreadYaw        : def.shotSpreadYaw;
		shotSpreadPitch      = (has && s.shotSpreadStated)       ? s.shotSpreadPitch      : def.shotSpreadPitch;
		shotDamageLo         = (has && s.shotDamageStated)       ? s.shotDamageLo         : def.shotDamageLo;
		shotDamageHi         = (has && s.shotDamageStated)       ? s.shotDamageHi         : def.shotDamageHi;
		fireTicCount         = (has && s.fireTicsStated)         ? s.fireTicCount         : def.fireTicCount;
		chambersPerPullCount = (has && s.chambersStated)         ? s.chambersPerPullCount : def.chambersPerPullCount;
		fullAutoFire         = (has && s.fullAutoStated)         ? s.fullAutoFire         : def.fullAutoFire;
		firstShotsDeadOn     = (has && s.firstShotsStated)       ? s.firstShotsDeadOn     : def.firstShotsDeadOn;
		roundsPerShotCount   = (has && s.roundsPerShotStated)    ? s.roundsPerShotCount   : def.roundsPerShotCount;
		shotClassName        = (has && s.shotClassStated)        ? s.shotClassName        : def.shotClassName;
		railShotOn           = (has && s.shotRailStated)         ? s.railShotOn           : def.railShotOn;
		railSpiralRGB        = (has && s.railColorsStated)       ? s.railSpiralRGB        : def.railSpiralRGB;
		railCoreRGB          = (has && s.railColorsStated)       ? s.railCoreRGB          : def.railCoreRGB;
		trailProfileName     = (has && s.trailProfileStated)     ? s.trailProfileName     : def.trailProfileName;
		chargeTicCount       = (has && s.chargeTicsStated)       ? s.chargeTicCount       : def.chargeTicCount;
		chargeSoundName      = (has && s.chargeSoundStated)      ? s.chargeSoundName      : def.chargeSoundName;
		sawShotOn            = (has && s.shotSawStated)          ? s.sawShotOn            : def.sawShotOn;
		sawFullSoundName     = (has && s.sawSoundsStated)        ? s.sawFullSoundName     : def.sawFullSoundName;
		sawHitSoundName      = (has && s.sawSoundsStated)        ? s.sawHitSoundName      : def.sawHitSoundName;
		sawPuffName          = (has && s.sawPuffStated)          ? s.sawPuffName          : def.sawPuffName;
		releaseTicCount      = (has && s.releaseTicsStated)      ? s.releaseTicCount      : def.releaseTicCount;
		spinUpTicCount       = (has && s.spinUpTicsStated)       ? s.spinUpTicCount       : def.spinUpTicCount;
		spinDownTicCount     = (has && s.spinDownTicsStated)     ? s.spinDownTicCount     : def.spinDownTicCount;
		altModeName          = (has && s.altModeStated)          ? s.altModeName          : def.altModeName;
		altBurstCount        = (has && s.altBurstStated)         ? s.altBurstCount        : def.altBurstCount;
		altBurstTicCount     = (has && s.altBurstTicsStated)     ? s.altBurstTicCount     : def.altBurstTicCount;
		altRateScaleValue    = (has && s.altRateScaleStated)     ? s.altRateScaleValue    : def.altRateScaleValue;
		altDamageScaleValue  = (has && s.altDamageScaleStated)   ? s.altDamageScaleValue  : def.altDamageScaleValue;
		altFanMaxCount       = (has && s.altFanMaxStated)        ? s.altFanMaxCount       : def.altFanMaxCount;
		spreadShapeName      = (has && s.spreadShapeStated)      ? s.spreadShapeName      : def.spreadShapeName;
		roundProfileName     = (has && s.roundProfileStated)     ? s.roundProfileName     : def.roundProfileName;
		flashProfileName     = (has && s.flashProfileStated)     ? s.flashProfileName     : def.flashProfileName;
		altFlashProfileName  = (has && s.altFlashProfileStated)  ? s.altFlashProfileName  : def.altFlashProfileName;
		ejectaProfileName    = (has && s.ejectaProfileStated)    ? s.ejectaProfileName    : def.ejectaProfileName;
		recoilProfileName    = (has && s.recoilProfileStated)    ? s.recoilProfileName    : def.recoilProfileName;
		altRecoilProfileName = (has && s.altRecoilProfileStated) ? s.altRecoilProfileName : def.altRecoilProfileName;
	}

	// ONE SHOT'S RECOIL (RS_Ballistics' RSB_Recoil, RECOIL_PLAN.md): the turn this shot's rounds take (yaw, pitch, in
	// degrees) and its extra spread, with the gun's kick moved on for its next shot. Once a shot, before its rounds
	// leave, in the weapon's own fire action on every machine: the map clock, the shot count, the owner's crouch and
	// speed -- no RNG, never the console player. With sv_rsb_recoil off, or no profile (the sheet's recoilprofile), it
	// is all zero, the kick is forgotten, and the shot is exactly what it was without recoil.
	double, double, double RecoilStep(String profile)
	{
		double kp = recoilPitch;
		double ky = recoilYaw;
		int    lt = recoilShotTic;
		int    rs = recoilRunShot;
		double shotYaw, shotPitch, bloom;
		[shotYaw, shotPitch, bloom] = RSB_Recoil.Step(profile, Owner, kp, ky, lt, rs);
		recoilPitch   = kp;
		recoilYaw     = ky;
		recoilShotTic = lt;
		recoilRunShot = rs;
		return shotYaw, shotPitch, bloom;
	}

	// ---- THE SHOT ----------------------------------------------------------------
	//
	// What one trigger pull puts in the air, said by the WEAPON CLASS in its Default
	// block -- not by the card. A card describes how a gun is worked by hand; what
	// comes out of the muzzle is the gun's own, and belongs with the rest of what
	// the engine knows about it (ammo, selection, hand). A class that says nothing
	// fires today's pistol shot exactly.
	//
	//   WM_Gun.ShotPellets N        rounds a pull fires. 0 (unset) is 1; at most 64.
	//   WM_Gun.ShotSpread h, v      degrees either side of the aim, sideways then up.
	//                               0, 0 (unset) is dead on.
	//   WM_Gun.ShotDamage min, max  per round, rolled on the hit by the round (RSB_Bullet).
	//                               0, 0 (unset) is its round profile's own, 5 x 1d3 unless it says otherwise.
	//   WM_Gun.FireTics N           tics from one shot until the gun is ready again
	//                               (35 a second). 0 (unset) is vanilla's 19. The
	//                               trigger still has to come back between pulls,
	//                               unless the class is FullAuto.
	//   WM_Gun.ChambersPerPull N    how many LIVE chambers one pull fires at once, up to
	//                               N (at most 8). 0 or 1 (unset) is one, today's pull
	//                               exactly. A double whose pull fires both barrels says
	//                               2: a pull fires every loaded barrel it can, and each
	//                               chamber fired throws ShotPellets pellets -- so a
	//                               double with one barrel loaded fires half the shot.
	//                               Counted over the gun's chamber store (the first
	//                               slotted store, WM_Ammo's facade), in slot order from
	//                               the selected slot, and only with wm_verbs on; off,
	//                               the old path fires one.
	//   WM_Gun.FullAuto true        HOLDING THE TRIGGER KEEPS FIRING, one shot every
	//                               FireTics, for as long as the chamber and the verbs
	//                               allow (WM_TryFire asks the system every shot). The
	//                               first empty pull clicks once and the trigger must
	//                               come back. Unset (false) is one pull, one shot.
	//                               Read off the owner's player cmd (WM_TriggerDown),
	//                               so every machine in a netgame refires alike.
	//                               THIS IS VANILLA'S A_ReFire: a Vanilla pistol or
	//                               chaingun, which refires while held, sets it.
	//   WM_Gun.FirstShotsAccurate N THE FIRST N SHOTS OF A HOLD FLY DEAD ON, and every
	//                               later shot of a held run scatters within ShotSpread --
	//                               vanilla's A_FireBullets, where one bullet and
	//                               !player.refire is accurate. N is the shots before the
	//                               first A_ReFire, for a class firing one shot a cycle:
	//                               vanilla's pistol 1, its chaingun 2 (both A_FireCGun
	//                               frames of the first cycle). Counted per gun
	//                               (refireCount), so each hand's run is its own. One
	//                               pellet a pull only, as vanilla's rule. 0 (unset)
	//                               scatters every shot, as before.
	//   WM_Gun.RoundsPerShot N      what one pull SPENDS from a gun that fires from its
	//                               magazine or the reserve (the card's `firesfrom`). 0
	//                               (unset) is 1; at most 1000. A chamber gun fires
	//                               chambers and never reads it. A BFG: 40 from a 160 cell.
	//   WM_Gun.ShotClass "actor"    the projectile each pellet is, found BY NAME as it fires,
	//                               so a class from another package is never a compile-time
	//                               reference. "" (unset) is RS_Ballistics' RSB_Bullet, flown
	//                               and drawn by the class's RoundProfile. Rocket, PlasmaBall
	//                               and BFGBall bring their own speed, damage and death;
	//                               LaunchRound and ShotDamage touch an RSB_Bullet only.
	//   WM_Gun.RoundProfile "name"  RS_Ballistics profiles (RSBDEFS) for this class's shot: the
	//   WM_Gun.FlashProfile "name"  round's ballistics and look ("default" unset); the muzzle's
	//   WM_Gun.AltFlashProfile "n"  light, cone, sparks, flame and smoke ("default"); a second
	//   WM_Gun.EjectaProfile "name" barrel's muzzle ("" is FlashProfile); what the port throws
	//                               ("default"). Each unset one is RS_Ballistics' plain stand-in,
	//                               never another gun's look. RS_VR_Reload REQUIRES RS_Ballistics, loaded
	//                               before it (RSB_CALL_SITES_HANDOFF.md).
	//   WM_Gun.ShotRail true        a RAIL each pellet instead of a projectile (A_RailAttack):
	//                               ShotDamage rolled per rail, 100 unset; ShotSpread as its
	//                               spread. Unset (false) fires projectiles.
	//   WM_Gun.RailColors s, c      the rail's spiral and core, 0xRRGGBB. 0 (unset) is the
	//                               engine's own colour for that part (a blue spiral, a grey
	//                               core -- p_effect.cpp P_DrawRailTrail).
	//   WM_Gun.TrailProfile "name"  the rail's TRAIL drawn by RS_Ballistics instead (an RSBDEFS
	//                               `trail`: "rail" is the Quake 2 one), from the drawn muzzle
	//                               to where the rail really ended, with the engine's own
	//                               trail switched off. "" (unset) is the engine's, in RailColors.
	//   WM_Gun.ChargeTics N         a WAIT of N tics between the pull and the shot, with
	//                               ChargeSound played as it starts -- the BFG's wind-up
	//                               (vanilla 30). 0 (unset) fires on the pull. An empty gun
	//                               clicks and does not charge; one emptied during the charge
	//                               clicks at its end. At most 350.
	//   WM_Gun.ChargeSound "snd"    the charge's sound. "" (unset) is silent.
	//   WM_Gun.ShotSaw true         A_SAW once a pull instead of any projectile: a chainsaw.
	//                               It never turns or pulls the player toward what it cuts --
	//                               vanilla's does, and in a headset that yanks the view.
	//                               ShotDamage rolled per hit when set, else vanilla's 2 x 1d10.
	//                               No muzzle flash. Idle and draw sounds are the class's own
	//                               Weapon.ReadySound / Weapon.UpSound.
	//   WM_Gun.SawSounds f, h       the saw's running and hitting sounds. "" (unset) is
	//                               weapons/sawfull and weapons/sawhit.
	//   WM_Gun.SawPuff "class"      what the saw's cut spawns where it lands, found BY NAME as it
	//                               cuts. "" (unset) is RS_Ballistics' RSB_SawPuff (the saw impacts);
	//                               a name that is no actor falls back to it, and without
	//                               RS_Ballistics to the engine's BulletPuff.
	//   WM_Gun.ReleaseTics N        A RECOVERY WAIT once a firing run ends: when a shot's cycle
	//                               ends without firing again -- a full-auto trigger up, or any
	//                               semi-automatic shot -- no fire and no switch for N tics more.
	//                               Vanilla's plasma rifle ends a burst `PLSG B 20 A_ReFire`: 20.
	//                               0 (unset) is ready at once, as before. Not after a dry click
	//                               or a second barrel's shot. At most 350.
	//   WM_Gun.SpinUpTics N         A SPIN-UP before a burst: barrels that must turn N tics before a
	//                               round leaves -- a minigun. The trigger, or the holding hand's
	//                               second button, spins them up (SpinStep, from DoEffect); with
	//                               neither down they run down over SpinDownTics. A pull on barrels
	//                               at full speed fires at once, so holding the second button keeps
	//                               the gun ready; a pull on slower ones waits in SpinUp. 0 (unset)
	//                               fires on the pull. At most 350. A gun whose card puts a second
	//                               barrel on that button spins on its trigger alone.
	//   WM_Gun.SpinDownTics N       full-speed barrels to still, in tics. 0 (unset) is twice
	//                               SpinUpTics. At most 350.
	//   WM_Gun.AltMode "mode"       THE GUN'S OWN SECOND BUTTON (Vanilla+ round 1), on a gun whose card puts no second
	//                               barrel there -- a barrel wins. "" (unset) keeps the button blocked, as before.
	//                                 burst        a press fires AltBurst rounds, one every AltBurstTics
	//                                 selectfire   a press steps the trigger: single -> a burst of AltBurst -> full
	//                                              auto -> single. Starts single. Clicks as it steps.
	//                                 shred        held, it fires full auto every FireTics / AltRateScale
	//                                 slamfire     held, the gun fires each time its action comes home by hand
	//                                 onebarrel    a press fires the next loaded chamber alone
	//                                 doubleshell  a press spends two rounds (two chambers) as ONE shot of the usual
	//                                              pellets, each at AltDamageScale; with one left it fires plainly
	//                                 fan          with the trigger held, the OTHER hand sweeping into the card's
	//                                              hammer part fires a round -- at most AltFanMax a second, each in
	//                                              twice the spread (WM_Rig.FanGesture sends it as a network event)
	//                               All off the owner's usercmd and the gun's own saved state, on every machine.
	//   WM_Gun.AltBurst N           burst rounds (burst, and select fire's burst). 0 (unset) is 3; at most 30.
	//   WM_Gun.AltBurstTics N       tics between a burst's rounds. 0 (unset) is 4; at most 350.
	//   WM_Gun.AltRateScale x       shred fires every FireTics / x. 0 (unset) is 2; at most 10.
	//   WM_Gun.AltDamageScale x     doubleshell's damage on each RSB_Bullet pellet whose ShotDamage is set. 0 (unset) is
	//                               2; at most 10.
	//   WM_Gun.AltFanMax N          fanned rounds a second at most. 0 (unset) is 8; at most 35.
	//   WM_Gun.SpreadShape "shape"  "box" or "" (unset): sideways and up drawn apart, as before. "cone": a ROUND cone, a
	//                               point drawn evenly over a disc whose radius is the larger of ShotSpread's two.
	//
	// FIRE HOLD AND RELEASE: a subclass that does something for as long as the trigger is
	// held -- a flamethrower's stream -- overrides FireHeld(int) and FireReleased(int) (below).
	//
	// A SECOND BARREL is not the class's: a card's `barrel <id>` block (card.zs WM_Barrel) puts
	// one on the holding hand's second button -- an underbarrel launcher -- with its own store,
	// shotclass, ammo and gate. AltFire (below) fires it; a class whose card has none never
	// enters AltFire, because WM_Ready keeps that button blocked.
	//
	// Field names differ from the property names on purpose: ZScript is
	// case-insensitive, and a field, a property and a method must never share one.
	const MAX_SHOT_PELLETS = 64;
	const MAX_CHAMBERS_PER_PULL = 8;
	const MAX_ROUNDS_PER_SHOT = 1000;
	// WM_Gun.AltMode's modes, and the kind of shot a Fire cycle is taking (altShotKind).
	const ALT_NONE        = 0;
	const ALT_BURST       = 1;
	const ALT_SELECTFIRE  = 2;
	const ALT_SHRED       = 3;
	const ALT_SLAMFIRE    = 4;
	const ALT_ONEBARREL   = 5;
	const ALT_DOUBLESHELL = 6;
	const ALT_FAN         = 7;
	const ALT_SHOT_NORMAL      = 0;
	const ALT_SHOT_SHRED       = 1;
	const ALT_SHOT_ONEBARREL   = 2;
	const ALT_SHOT_DOUBLESHELL = 3;
	const ALT_SHOT_FAN         = 4;
	const FAN_SPREAD_SCALE = 2.0;
	int    shotPelletCount;
	double shotSpreadYaw;
	double shotSpreadPitch;
	int    shotDamageLo;
	int    shotDamageHi;
	int    fireTicCount;
	int    chambersPerPullCount;
	bool   fullAutoFire;
	int    firstShotsDeadOn;
	int    roundsPerShotCount;
	String shotClassName;
	bool   railShotOn;
	int    railSpiralRGB;
	int    railCoreRGB;
	String trailProfileName;
	int    chargeTicCount;
	int    chargeBeganTic;   // level.maptime as the Charge state began (WM_ChargeWait); read by the charge's look only
	String chargeSoundName;
	bool   sawShotOn;
	String sawFullSoundName;
	String sawHitSoundName;
	String sawPuffName;
	int    releaseTicCount;
	int    spinUpTicCount;
	int    spinDownTicCount;
	// THE BARRELS' SPIN SO FAR (WM_Gun.SpinUpTics), a whole count so every machine keeps it exactly: up by
	// SpinDownTicsEach() a tic toward SpinFull(), down by SpinUpTicsEach() a tic toward 0. Saved with the gun.
	int    spinCount;
	// THE GUN'S OWN SECOND BUTTON (WM_Gun.AltMode and its numbers) and the round cone (WM_Gun.SpreadShape).
	String altModeName;
	int    altBurstCount;
	int    altBurstTicCount;
	double altRateScaleValue;
	double altDamageScaleValue;
	int    altFanMaxCount;
	String spreadShapeName;
	// THEIR PLAYSIM STATE, saved with the gun and stepped alike on every machine: the rounds still to come in a burst; the
	// select-fire mode (0 single, 1 burst, 2 full auto); the second button last tic, for DoEffect's press edge; the kind
	// of shot this Fire cycle is (ALT_SHOT_*); a slamfire and a fanned round waiting for Ready (from the owner's network
	// events); and the map tic of the last fanned round, for the rate cap.
	int    burstShotsLeft;
	int    selectFireMode;
	bool   altWasDown;
	int    altShotKind;
	bool   slamPending;
	bool   fanPending;
	int    fanLastTic;
	String roundProfileName;
	String flashProfileName;
	String altFlashProfileName;
	String ejectaProfileName;
	// RS_Ballistics' recoil profiles, main barrel and second barrel (RS_Ballistics/_staged/RECOIL_PLAN.md), set by a
	// weapon sheet's recoilprofile / altrecoilprofile. Stored only: nothing reads them until the recoil hookup lands.
	String recoilProfileName;
	String altRecoilProfileName;
	// THE GUN'S KICK SO FAR, kept between shots by RS_Ballistics' RSB_Recoil.Step (RecoilStep): its climb and sideways
	// drift in degrees, the map tic of its last shot, and the shot number of the run. Saved with the gun, alike on
	// every machine. The second barrel shares them, so a grenade's thump adds to the gun's climb.
	double recoilPitch;
	double recoilYaw;
	int    recoilShotTic;
	int    recoilRunShot;
	property ShotPellets: shotPelletCount;
	property ShotSpread: shotSpreadYaw, shotSpreadPitch;
	property ShotDamage: shotDamageLo, shotDamageHi;
	property FireTics: fireTicCount;
	property ChambersPerPull: chambersPerPullCount;
	property FullAuto: fullAutoFire;
	property FirstShotsAccurate: firstShotsDeadOn;
	property RoundsPerShot: roundsPerShotCount;
	property ShotClass: shotClassName;
	property ShotRail: railShotOn;
	property RailColors: railSpiralRGB, railCoreRGB;
	property TrailProfile: trailProfileName;
	property ChargeTics: chargeTicCount;
	property ChargeSound: chargeSoundName;
	property ShotSaw: sawShotOn;
	property SawSounds: sawFullSoundName, sawHitSoundName;
	property SawPuff: sawPuffName;
	property ReleaseTics: releaseTicCount;
	property SpinUpTics: spinUpTicCount;
	property SpinDownTics: spinDownTicCount;
	property AltMode: altModeName;
	property AltBurst: altBurstCount;
	property AltBurstTics: altBurstTicCount;
	property AltRateScale: altRateScaleValue;
	property AltDamageScale: altDamageScaleValue;
	property AltFanMax: altFanMaxCount;
	property SpreadShape: spreadShapeName;
	property RoundProfile: roundProfileName;
	property FlashProfile: flashProfileName;
	property AltFlashProfile: altFlashProfileName;
	property EjectaProfile: ejectaProfileName;
	property RecoilProfile: recoilProfileName;
	property AltRecoilProfile: altRecoilProfileName;

	// THE RS_BALLISTICS PROFILES THIS CLASS'S SHOT NAMES, each RS_Ballistics' plain "default" when unset --
	// never a gun's own profile, which RSBDEFS is free to make a showpiece (the pistols' are).
	String RoundProfileOrDefault()    const { return (roundProfileName.Length() > 0) ? roundProfileName : "default"; }
	String FlashProfileOrDefault()    const { return (flashProfileName.Length() > 0) ? flashProfileName : "default"; }
	String AltFlashProfileOrDefault() const { return (altFlashProfileName.Length() > 0) ? altFlashProfileName : FlashProfileOrDefault(); }
	String EjectaProfileOrDefault()   const { return (ejectaProfileName.Length() > 0) ? ejectaProfileName : "default"; }

	// The whole Fire cycle in tics: the shot's own tic plus the wait after it.
	int CycleTics() const { return (fireTicCount > 0) ? clamp(fireTicCount, 1, 350) : 19; }

	// The most chambers one pull may fire: 1 unless the class says more.
	int ChambersEachPull() const { return clamp(chambersPerPullCount, 1, MAX_CHAMBERS_PER_PULL); }

	int    PelletsPerShot() const { return clamp(shotPelletCount, 1, MAX_SHOT_PELLETS); }
	double ShotYawSpread() const   { return clamp(shotSpreadYaw, 0.0, 45.0); }
	double ShotPitchSpread() const { return clamp(shotSpreadPitch, 0.0, 45.0); }
	int    RoundsEachShot() const  { return clamp(roundsPerShotCount, 1, MAX_ROUNDS_PER_SHOT); }
	int    ChargeTicsEach() const  { return clamp(chargeTicCount, 0, 350); }
	// A saw's two sounds, each the owner's pick for this gun (WM_SoundPick: sawfull, sawhit) when one is set.
	String SawFullSound()          { return WM_SoundPick.ForActor(Owner, GetClassName(), "sawfull", (sawFullSoundName != "") ? sawFullSoundName : "weapons/sawfull"); }
	String SawHitSound()           { return WM_SoundPick.ForActor(Owner, GetClassName(), "sawhit", (sawHitSoundName != "") ? sawHitSoundName : "weapons/sawhit"); }
	int    ReleaseTicsEach() const { return clamp(releaseTicCount, 0, 350); }
	int    SpinUpTicsEach() const   { return clamp(spinUpTicCount, 0, 350); }
	int    SpinDownTicsEach() const { int d = clamp(spinDownTicCount, 0, 350); return (d > 0) ? d : max(SpinUpTicsEach() * 2, 1); }
	// Full speed as a whole count, up-tics x down-tics, so a tic's rise and a tic's fall are both whole steps.
	int    SpinFull() const         { return SpinUpTicsEach() * SpinDownTicsEach(); }
	bool   SpunUp() const           { return SpinUpTicsEach() <= 0 || spinCount >= SpinFull(); }
	// 0 still .. 1 full speed, for the barrels' look (WM_Rig.Spin).
	double SpinFraction() const     { int f = SpinFull(); return (f > 0) ? clamp(double(spinCount) / f, 0.0, 1.0) : 0.0; }

	// WM_Gun.AltMode's word as its ALT_* mode: "" is ALT_NONE, a word it does not know -1 (the sheet refuses it).
	// clearscope: the sheet reader asks it from data context.
	clearscope static int AltModeWord(String word)
	{
		if (word == "")             return ALT_NONE;
		if (word ~== "burst")       return ALT_BURST;
		if (word ~== "selectfire")  return ALT_SELECTFIRE;
		if (word ~== "shred")       return ALT_SHRED;
		if (word ~== "slamfire")    return ALT_SLAMFIRE;
		if (word ~== "onebarrel")   return ALT_ONEBARREL;
		if (word ~== "doubleshell") return ALT_DOUBLESHELL;
		if (word ~== "fan")         return ALT_FAN;
		return -1;
	}
	int    AltModeKind() const        { return max(AltModeWord(altModeName), ALT_NONE); }
	int    AltBurstEach() const       { return (altBurstCount > 0) ? clamp(altBurstCount, 1, 30) : 3; }
	int    AltBurstTicsEach() const   { return (altBurstTicCount > 0) ? clamp(altBurstTicCount, 1, 350) : 4; }
	double AltRateScaleEach() const   { return (altRateScaleValue > 0) ? clamp(altRateScaleValue, 0.1, 10.0) : 2.0; }
	double AltDamageScaleEach() const { return (altDamageScaleValue > 0) ? clamp(altDamageScaleValue, 0.1, 10.0) : 2.0; }
	int    AltFanMaxEach() const      { return (altFanMaxCount > 0) ? clamp(altFanMaxCount, 1, 35) : 8; }
	bool   SpreadCone() const         { return spreadShapeName ~== "cone"; }
	// HELD FIRE: the class's FullAuto, or select fire's own mode when the gun has one.
	bool   FiresFullAuto() const      { return (AltModeKind() == ALT_SELECTFIRE) ? (selectFireMode == 2) : fullAutoFire; }

	// THE SAW'S PUFF (WM_Gun.SawPuff), found by name as it cuts, so a class from another package is never a
	// compile-time reference. Unset, or a name that is no actor (said once): RS_Ballistics' RSB_SawPuff; without
	// RS_Ballistics loaded, the engine's BulletPuff. Read off the class's own Default block, alike on every machine.
	Class<Actor> SawPuffActor()
	{
		if (sawPuffName != "")
		{
			Class<Actor> named = (Class<Actor>)(Object.FindClass(sawPuffName, "Actor"));
			if (named) return named;
			WM_Log.Once(WM_Log.LV_ERR, "sawpuff:" .. GetClassName(), String.Format(
				"%s: WM_Gun.SawPuff '%s' is not an actor class -- it cuts with RSB_SawPuff instead", GetClassName(), sawPuffName));
		}
		Class<Actor> house = (Class<Actor>)(Object.FindClass("RSB_SawPuff", "Actor"));
		if (house) return house;
		return (Class<Actor>)(Object.FindClass("BulletPuff", "Actor"));
	}

	// THE PROJECTILE A PELLET IS (WM_Gun.ShotClass), found by name as it fires. A name that is
	// no actor is said once, and the gun fires RSB_Bullet rather than nothing.
	Class<Actor> ShotActor()
	{
		Class<Actor> fallback = "RSB_Bullet";
		if (shotClassName == "") return fallback;
		Class<Actor> named = (Class<Actor>)(Object.FindClass(shotClassName, "Actor"));
		if (named) return named;
		WM_Log.Once(WM_Log.LV_ERR, "shotclass:" .. GetClassName(), String.Format(
			"%s: WM_Gun.ShotClass '%s' is not an actor class -- it fires RSB_Bullet instead", GetClassName(), shotClassName));
		return fallback;
	}

	// ONE RAIL'S DAMAGE (WM_Gun.ShotRail): ShotDamage rolled on a named RNG, so every machine
	// rolls alike; 100 when the class says none.
	int RailDamage()
	{
		if (shotDamageLo <= 0) return 100;
		return random[WMRail](shotDamageLo, max(shotDamageLo, shotDamageHi));
	}

	// A RAIL COLOUR (WM_Gun.RailColors) as A_RailAttack takes it. 0 stays 0, which is the
	// engine's own colour for that part of the rail.
	static color RailColor(int rgb)
	{
		color c = 0;
		if (rgb != 0) c = Color(255, (rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
		return c;
	}

	// NO RAIL PART: -1 as A_RailAttack's colour, which P_DrawRailTrail reads as "draw none of this
	// part" -- how a gun with its own TrailProfile switches the engine's trail off.
	static color RailPartOff() { return Color(255, 255, 255, 255); }

	// A RAIL'S OWN TRAIL (WM_Gun.TrailProfile), laid by RS_Ballistics from the drawn muzzle to where
	// the rail ended. PRESENTATION ONLY: RSB_Trail.Lay draws and reads nothing back, so the drawn
	// muzzle -- placed from the local controller -- may start it. With no drawn gun it starts where
	// the engine's rail did.
	void LayRailTrail(Vector3 railFrom, Vector3 railTo)
	{
		Vector3 muzzle;
		bool drawn;
		[muzzle, drawn] = MuzzleToWorld();
		RSB_Trail.Lay(trailProfileName, Owner, drawn ? muzzle : railFrom, railTo);
	}

	// For the bind log and wm_dump.
	String ShotText()
	{
		int n = PelletsPerShot();
		String s = String.Format("%d pellet%s, spread %.2f x %.2f deg", n, (n == 1) ? "" : "s", ShotYawSpread(), ShotPitchSpread());
		if (railShotOn)
		{
			String railHurt = (shotDamageLo > 0) ? String.Format("%d-%d", shotDamageLo, max(shotDamageLo, shotDamageHi)) : "100 (unset)";
			String railLook = (railSpiralRGB == 0 && railCoreRGB == 0) ? "the engine's own colours" : String.Format("spiral %06x, core %06x", railSpiralRGB, railCoreRGB);
			if (trailProfileName != "") railLook = String.Format("RS_Ballistics' '%s' trail (the engine's switched off)", trailProfileName);
			s = s .. String.Format(", each a RAIL (A_RailAttack), damage %s, %s", railHurt, railLook);
		}
		else if (shotClassName != "")
			s = s .. String.Format(", each a %s with its own damage", shotClassName);
		else if (shotDamageLo > 0)
			s = s .. String.Format(", damage %d-%d a pellet", shotDamageLo, max(shotDamageLo, shotDamageHi));
		else
			s = s .. String.Format(", damage the round profile's own (%s: 5 x 1d3 unless it says otherwise)", RoundProfileOrDefault());
		if (roundsPerShotCount > 1)
			s = s .. String.Format(", %d rounds a shot (spent by a gun that fires from its magazine or the reserve)", RoundsEachShot());
		// Said only by a class that sets them, so every other gun's line reads as it did.
		if (ChambersEachPull() > 1)
			s = s .. String.Format(", per chamber -- a pull fires up to %d loaded chambers at once", ChambersEachPull());
		if (fullAutoFire)
			s = s .. String.Format(", FULL AUTO (held, a shot every %d tics)", CycleTics());
		if (firstShotsDeadOn > 0)
			s = s .. String.Format(", FIRST %d SHOT%s OF A HOLD DEAD ON (the rest scatter)", firstShotsDeadOn, (firstShotsDeadOn == 1) ? "" : "S");
		if (sawShotOn)
			s = s .. String.Format(", a SAW each pull instead (A_Saw, no turn or pull-in, damage %s)",
				(shotDamageLo > 0) ? String.Format("%d-%d", shotDamageLo, max(shotDamageLo, shotDamageHi)) : "vanilla 2 x 1d10");
		if (ChargeTicsEach() > 0)
			s = s .. String.Format(", CHARGES %d tics before each shot%s", ChargeTicsEach(),
				(chargeSoundName != "") ? " (" .. chargeSoundName .. ")" : "");
		if (ReleaseTicsEach() > 0)
			s = s .. String.Format(", RECOVERS %d tics after a firing run", ReleaseTicsEach());
		if (SpinUpTicsEach() > 0)
			s = s .. String.Format(", SPINS UP %d tics before a burst (trigger or second button; runs down over %d)", SpinUpTicsEach(), SpinDownTicsEach());
		switch (AltModeKind())
		{
		case ALT_BURST:       s = s .. String.Format(", ALT: a burst of %d, a round every %d tics", AltBurstEach(), AltBurstTicsEach()); break;
		case ALT_SELECTFIRE:  s = s .. String.Format(", ALT: select fire (single / burst of %d every %d tics / full auto), now %s", AltBurstEach(), AltBurstTicsEach(),
		                              (selectFireMode == 2) ? "full auto" : ((selectFireMode == 1) ? "burst" : "single")); break;
		case ALT_SHRED:       s = s .. String.Format(", ALT: held, full auto every %d tics", max(int(CycleTics() / AltRateScaleEach() + 0.5), 1)); break;
		case ALT_SLAMFIRE:    s = s .. ", ALT: held, SLAMFIRE -- fires each time the action comes home"; break;
		case ALT_ONEBARREL:   s = s .. ", ALT: one barrel at a time"; break;
		case ALT_DOUBLESHELL: s = s .. String.Format(", ALT: two rounds as one shot at %gx damage", AltDamageScaleEach()); break;
		case ALT_FAN:         s = s .. String.Format(", ALT: FAN THE HAMMER with the other hand, at most %d a second", AltFanMaxEach()); break;
		default: break;
		}
		if (SpreadCone()) s = s .. ", a ROUND spread cone";
		return s .. String.Format(" -- from the weapon class %s", GetClassName());
	}

	// The trigger has to come back. Set on every pull; cleared once the
	// button is seen up.
	bool mustRelease;

	// THE HELD RUN'S REFIRES (WM_Gun.FirstShotsAccurate): vanilla's player.refire, kept per gun so each hand's run is
	// its own. 0 on the first shot of a pull; counted up each time WM_HoldFire goes round to Fire again; back to 0 in
	// Ready. Advanced only in this weapon's own states, off the owner's usercmd, so every machine counts alike.
	int refireCount;

	// THE GUN'S OWN ROUNDS, kept on the weapon rather than on the rig that
	// draws it. The rig is rebuilt whenever the hand changes what it holds,
	// and a fresh rig used to mean a fresh 15 + 1: switch to the fist and back
	// for a free reload.
	WM_Ammo wmAmmo;

	int Hand() { return bOffhandWeapon ? 1 : 0; }

	// ---- FIRE HOLD AND RELEASE --------------------------------------------------------
	//
	// For a gun that does something for as long as the trigger is held and something when it
	// comes back -- a flamethrower's stream and its cut-off. A subclass overrides these; here
	// both are empty. Called from DoEffect, which the engine runs for every inventory item every
	// tic on every machine, and decided off the owner's usercmd, so every machine calls them
	// alike.
	//   FireHeld(heldTics)      every tic the trigger stays down after a shot left: 1, 2, 3 ...
	//   FireReleased(heldTics)  once, the tic it comes back or the gun stops firing (a dry
	//                           pull, a switch), with how many tics it was held
	virtual void FireHeld(int heldTics) {}
	virtual void FireReleased(int heldTics) {}

	bool fireStarted;     // a shot left on this pull: a hold from here on is a hold on a fired trigger
	int  fireHeldTics;

	// THE TRIGGER OF THE HAND THIS GUN IS IN, off the owner's usercmd. The plain twin of
	// WM_TriggerDown, which needs an action context; false when the gun is not in a hand.
	bool TriggerIsDown()
	{
		if (!Owner || !Owner.player) return false;
		let pl = Owner.player;
		if (pl.ReadyWeapon != self && pl.OffhandWeapon != self) return false;
		int bit = bOffhandWeapon ? BT_OFFHANDATTACK : BT_ATTACK;
		return (pl.cmd.buttons & bit) != 0;
	}

	// ---- THE SECOND BARREL (card `barrel <id>`, card.zs WM_Barrel) --------------------------
	//
	// A card may give its gun a second barrel on the holding hand's second button -- an
	// underbarrel grenade launcher. The class says nothing about it: the barrel is the card's,
	// and the AltFire state asks the system for it by this class's name. A class whose card has
	// none keeps the second button blocked in Ready, exactly as before (WM_Ready).

	// ONE PULL, ONE SHOT on the second button too: set on every alt pull, cleared once the
	// button is seen up (DoEffect, every tic on every machine).
	bool altMustRelease;

	// THE SECOND BUTTON OF THE HAND THIS GUN IS IN, off the owner's usercmd.
	bool AltIsDown()
	{
		if (!Owner || !Owner.player) return false;
		let pl = Owner.player;
		if (pl.ReadyWeapon != self && pl.OffhandWeapon != self) return false;
		int bit = bOffhandWeapon ? BT_OFFHANDALTATTACK : BT_ALTATTACK;
		return (pl.cmd.buttons & bit) != 0;
	}

	// The barrel this class's card puts on the second button, or null. Card data, read on every
	// machine.
	WM_Barrel AltBarrel()
	{
		let sys = WM_System(EventHandler.Find("WM_System"));
		return sys ? sys.AltBarrelFor(GetClassName()) : null;
	}

	// THE BARRELS' SPIN, A TIC ON (WM_Gun.SpinUpTics): toward full while this hand's trigger is down, or its second
	// button when the card puts no barrel there; toward still otherwise. From DoEffect -- every tic, every machine,
	// off the owner's usercmd -- because WM_Charge holds the shot on it: gameplay, never the console player's.
	void SpinStep()
	{
		int up = SpinUpTicsEach();
		if (up <= 0) { spinCount = 0; return; }
		bool want = TriggerIsDown() || (AltIsDown() && !AltBarrel());
		if (want) spinCount = min(spinCount + SpinDownTicsEach(), SpinFull());
		else      spinCount = max(spinCount - up, 0);
	}

	override void DoEffect()
	{
		Super.DoEffect();
		SpinStep();
		// SELECT FIRE (WM_Gun.AltMode selectfire): a press of this hand's second button steps the trigger's mode, off the
		// owner's usercmd on every machine. Read here rather than in Ready, so it steps mid-run too.
		bool altNow = AltIsDown();
		if (altNow && !altWasDown && AltModeKind() == ALT_SELECTFIRE && !AltBarrel()) StepSelectFire();
		altWasDown = altNow;
		if (altMustRelease && !AltIsDown()) altMustRelease = false;
		if (fireStarted && TriggerIsDown())
		{
			fireHeldTics++;
			FireHeld(fireHeldTics);
			return;
		}
		if (fireStarted || fireHeldTics > 0)
		{
			int heldFor = fireHeldTics;
			fireHeldTics = 0;
			fireStarted  = false;
			if (heldFor > 0) FireReleased(heldFor);
		}
	}

	// SELECT FIRE STEPS: single -> burst -> full auto -> single. A burst under way stops. The click is heard by everyone
	// near; the buzz is the holder's own hand only.
	void StepSelectFire()
	{
		selectFireMode = (selectFireMode + 1) % 3;
		burstShotsLeft = 0;
		if (!Owner) return;
		Owner.A_StartSound("wm/dry", CHAN_AUTO, CHANF_DEFAULT, 0.6);
		if (Owner.player && Owner.PlayerNumber() == consoleplayer) level.VRHaptic(Hand(), 0.4, 8.0 + 6.0 * selectFireMode);
	}

	// A FANNED ROUND (WM_Gun.AltMode fan), from the owner's `wm_fan` network event (WM_System.NetworkProcess), on every
	// machine: waiting for Ready, which fires it while the trigger is held. At most AltFanMax a second, however many
	// events arrive.
	void OnFanEvent()
	{
		if (AltModeKind() != ALT_FAN) return;
		int gap = max(35 / AltFanMaxEach(), 1);
		if (fanLastTic > 0 && level.maptime - fanLastTic < gap) return;
		fanLastTic = level.maptime;
		fanPending = true;
	}

	// A SLAMFIRE ROUND (WM_Gun.AltMode slamfire), from the owner's `wm_slam` network event: the action came home with the
	// second button held. Ready fires it if the button is still held and the gun can fire.
	void OnSlamEvent()
	{
		if (AltModeKind() != ALT_SLAMFIRE) return;
		slamPending = true;
	}

	// A DOUBLESHELL PELLET'S DAMAGE (WM_Gun.AltDamageScale): an RSB_Bullet's own damage, set from the class's ShotDamage,
	// times the scale. A round whose damage is its profile's (ShotDamage unset) cannot be scaled here; said once.
	void ScaleShotDamage(Actor shot, double scale)
	{
		let r = RSB_Bullet(shot);
		if (!r) return;
		if (r.damageMin <= 0)
		{
			WM_Log.Once(WM_Log.LV_WARN, "dblscale:" .. GetClassName(), String.Format(
				"%s: doubleshell's damage scale needs the sheet's shotdamage -- its rounds keep their profile's damage", GetClassName()));
			return;
		}
		r.damageMin = max(int(r.damageMin * scale + 0.5), 1);
		r.damageMax = max(int(r.damageMax * scale + 0.5), r.damageMin);
	}

	// ---- THE DRAWN GUN, FOR EFFECTS ----------------------------------------------------
	//
	// Where things are on the gun as it is DRAWN in the hand, for a subclass's looks -- a
	// flamethrower's stream out of its nozzle and its pilot light (RS_Ballistics'
	// RSB_Flame.Stream / Pilot), from FireHeld / FireReleased. Points and directions are the
	// CARD's: MD3 model space, x along the barrel toward the muzzle, y across, z up -- the same
	// numbers the card's muzzle and grab points are written in.
	//
	// PRESENTATION ONLY. The drawn gun is placed from the local controller, so in a netgame these
	// differ between machines: never let them decide damage, ammo or anything the game compares
	// (Engine docs/NETWORK_HAND_INPUT_PLAN.md). Each returns ok = false while the gun has no drawn
	// prop (not in a hand, or not yet built), with a fallback at the firing hand.
	WM_Rig DrawnRig()
	{
		let sys = WM_System(EventHandler.Find("WM_System"));
		return sys ? sys.RigForGun(self) : null;
	}

	private bool DrawnReady(WM_Rig rig) { return rig && rig.prop && rig.resolved && rig.card; }

	// The firing hand's position, when there is no drawn gun to ask.
	Vector3 HandFallbackPos()
	{
		let pmo = PlayerPawn(Owner);
		if (!pmo) return Owner ? Owner.Pos : (0, 0, 0);
		if (bOffhandWeapon) return pmo.OffhandPos;
		return pmo.AttackPos;
	}

	// The owner's look, when there is no drawn gun to ask.
	Vector3 HandFallbackDir()
	{
		if (!Owner) return (1, 0, 0);
		double cp = cos(Owner.Pitch);
		return (cos(Owner.Angle) * cp, sin(Owner.Angle) * cp, -sin(Owner.Pitch));
	}

	// A CARD POINT on the drawn gun, in the world.
	Vector3, bool CardPointToWorld(Vector3 cardPoint)
	{
		let rig = DrawnRig();
		if (DrawnReady(rig)) return rig.World(cardPoint), true;
		return HandFallbackPos(), false;
	}

	// A CARD DIRECTION at a card point on the drawn gun, in the world, unit length.
	Vector3, bool CardDirToWorld(Vector3 cardPoint, Vector3 cardDir)
	{
		let rig = DrawnRig();
		if (DrawnReady(rig)) return rig.WorldDir(cardPoint, cardDir), true;
		return HandFallbackDir(), false;
	}

	// The card's muzzle (with this hand's muzzle trim sliders), the barrel's direction, and the
	// gun's sideways axis -- a flamethrower's nozzle, its aim and its acrossAxis.
	Vector3, bool MuzzleToWorld()
	{
		let rig = DrawnRig();
		if (DrawnReady(rig)) return rig.MuzzleWorld(), true;
		return HandFallbackPos(), false;
	}

	Vector3, bool BarrelToWorld()
	{
		let rig = DrawnRig();
		if (DrawnReady(rig)) return rig.BarrelWorld(), true;
		return HandFallbackDir(), false;
	}

	Vector3, bool AcrossToWorld()
	{
		let rig = DrawnRig();
		if (DrawnReady(rig)) return rig.AcrossWorld(), true;
		return (0, 0, 0), false;
	}

	// WHAT THE GUN IS MOVING WITH, in map units a tic: the owner's own velocity plus the hand's
	// (AttackVel / OffhandVel are map units a second, and read zero in a netgame -- see above).
	Vector3 CarrierVelocity()
	{
		if (!Owner) return (0, 0, 0);
		Vector3 v = Owner.Vel;
		let pmo = PlayerPawn(Owner);
		if (pmo)
		{
			if (bOffhandWeapon) v += pmo.OffhandVel / 35.0;
			else                v += pmo.AttackVel / 35.0;
		}
		return v;
	}

	// WHAT IS LEFT TO FIRE: the rounds in the gun's own magazine (its WM_Ammo), or the owner's
	// reserve for a gun that fires from it (card `firesfrom = reserve`). A chamber gun counts its
	// magazine. A gun that fires on nothing has 0 and a share of 1.
	int FeedRounds()
	{
		let sys = WM_System(EventHandler.Find("WM_System"));
		let gunCard = sys ? sys.CardForWeapon(GetClassName()) : null;
		if (gunCard && gunCard.firesFrom == WM_Card.FIRES_RESERVE)
		{
			let inv = Owner ? Owner.FindInventory(WM_LooseMag.ReserveFor(GetClassName())) : null;
			return inv ? inv.Amount : 0;
		}
		if (gunCard && gunCard.firesFrom == WM_Card.FIRES_NOTHING) return 0;
		return wmAmmo ? wmAmmo.rounds : 0;
	}

	// THE SAME AS A SHARE, 0..1 -- a flamethrower's fuelShare: the magazine against the card's
	// capacity, or the reserve against its maximum.
	double FeedShare()
	{
		let sys = WM_System(EventHandler.Find("WM_System"));
		let gunCard = sys ? sys.CardForWeapon(GetClassName()) : null;
		if (!gunCard || gunCard.firesFrom == WM_Card.FIRES_NOTHING) return 1.0;
		if (gunCard.firesFrom == WM_Card.FIRES_RESERVE)
		{
			let inv = Owner ? Owner.FindInventory(WM_LooseMag.ReserveFor(GetClassName())) : null;
			if (!inv || inv.MaxAmount <= 0) return 0.0;
			return clamp(double(inv.Amount) / inv.MaxAmount, 0.0, 1.0);
		}
		return clamp(double(FeedRounds()) / max(gunCard.capacity, 1), 0.0, 1.0);
	}

	action bool WM_TriggerDown()
	{
		if (!player) return false;
		int bit = invoker.bOffhandWeapon ? BT_OFFHANDATTACK : BT_ATTACK;
		return (player.cmd.buttons & bit) != 0;
	}

	// READY. The trigger has to come back before the next pull (mustRelease). The second button
	// fires only a card's second barrel (WM_Barrel), once a pull (altMustRelease); a class whose
	// card has none keeps it blocked, as it always was, so pressing it never enters AltFire.
	action State WM_Ready()
	{
		invoker.refireCount = 0;   // back in Ready, any held run has ended
		invoker.burstShotsLeft = 0;
		invoker.altShotKind = ALT_SHOT_NORMAL;
		if (invoker.mustRelease && !WM_TriggerDown()) invoker.mustRelease = false;
		// THE GUN'S OWN SECOND BUTTON (WM_Gun.AltMode), on a gun whose card puts no second barrel there: straight to Fire,
		// with this cycle's kind of shot said, off the owner's usercmd and the gun's own saved state on every machine. Not
		// while this hand has a weapon change pending, so a switch is never held off.
		int mode = invoker.AltModeKind();
		bool switching = player && player.PendingWeapon != WP_NOCHANGE
			&& (player.PendingWeapon ? player.PendingWeapon.bOffhandWeapon : false) == invoker.bOffhandWeapon;
		if (mode != ALT_NONE && !switching && !invoker.AltBarrel())
		{
			bool altDown  = WM_AltDown();
			bool altFresh = altDown && !invoker.altMustRelease;
			if (mode == ALT_BURST && altFresh)
			{
				invoker.altMustRelease = true;
				invoker.burstShotsLeft = invoker.AltBurstEach();
				return ResolveState("Fire");
			}
			if (mode == ALT_SHRED && altDown)
			{
				invoker.altShotKind = ALT_SHOT_SHRED;
				return ResolveState("Fire");
			}
			if ((mode == ALT_ONEBARREL || mode == ALT_DOUBLESHELL) && altFresh)
			{
				invoker.altMustRelease = true;
				invoker.altShotKind = (mode == ALT_ONEBARREL) ? ALT_SHOT_ONEBARREL : ALT_SHOT_DOUBLESHELL;
				return ResolveState("Fire");
			}
			if (mode == ALT_SLAMFIRE && invoker.slamPending)
			{
				invoker.slamPending = false;
				if (altDown) return ResolveState("Fire");
			}
			if (mode == ALT_FAN && invoker.fanPending)
			{
				invoker.fanPending = false;
				if (WM_TriggerDown())
				{
					invoker.altShotKind = ALT_SHOT_FAN;
					return ResolveState("Fire");
				}
			}
		}
		int readyFlags = 0;
		if (invoker.mustRelease) readyFlags |= WRF_NOPRIMARY;
		if (invoker.altMustRelease || !invoker.AltBarrel()) readyFlags |= WRF_NOSECONDARY;
		A_WeaponReady(readyFlags);
		return null;
	}

	// ONE QUESTION TO THE SYSTEM, AND ONE ANNOUNCEMENT. The weapon owns no
	// count: the chamber decides whether it fires, and the system owns the
	// chamber. It announces the shot on the same tic so the flash, the brass
	// and the slide are not a tic late.
	//
	// ASKED FOR THIS WEAPON'S OWNER, by player number -- never the console player.
	// This action runs on every machine in a netgame, and on each it must ask about
	// the hands of the player who pulled the trigger (WM_System.CanFire).
	action State WM_TryFire()
	{
		invoker.mustRelease = true;
		let sys = WM_System(EventHandler.Find("WM_System"));
		int h = invoker.Hand();
		int pn = player ? PlayerNumber() : -1;
		int most = invoker.ChambersEachPull();
		// WHAT THIS PULL SPENDS from a gun with no chamber (WM_Gun.RoundsPerShot): 1 unset.
		int rounds = invoker.RoundsEachShot();
		// THIS CYCLE'S KIND OF SHOT (WM_Gun.AltMode, said by Ready): one barrel fires one chamber; a double shell two
		// chambers, or twice the rounds, as ONE shot -- or the plain shot when there is not that much to fire.
		int shotKind = invoker.altShotKind;
		if (shotKind == ALT_SHOT_ONEBARREL) most = 1;
		bool dbl = (shotKind == ALT_SHOT_DOUBLESHELL) && sys && sys.CanFire(pn, h, 2, rounds * 2, invoker);
		if (dbl)
		{
			most = 2;
			rounds *= 2;
		}
		if (!sys || !sys.CanFire(pn, h, most, rounds, invoker))
		{
			// A gun that stops firing stops holding: FireReleased on the next DoEffect.
			invoker.fireStarted = false;
			// ...and a burst or an alt shot under way ends with it.
			invoker.burstShotsLeft = 0;
			invoker.altShotKind = ALT_SHOT_NORMAL;
			// NOT YET THIS GUN'S RIG (put in the hand since the system last bound one): no click, and no dry told
			// to the gun that was there before. Back to Ready with the trigger free; the next tic's pull finds it bound.
			if (sys && sys.RigBoundElsewhere(pn, h, invoker))
			{
				invoker.mustRelease = false;
				return ResolveState("Ready");
			}
			if (sys) sys.OnDry(pn, h, rounds);
			return ResolveState("Dry");
		}
		// HOW MANY CHAMBERS THIS PULL FIRES (WM_Gun.ChambersPerPull): 1 for every class
		// that does not say more, without asking; otherwise the loaded chambers, up to
		// the class's number. Asked before a pellet leaves, and OnShot spends exactly
		// that many on the same tic, so the pellets and the spent cases always agree.
		int chambers = (most > 1) ? sys.ChambersToFire(pn, h, most) : 1;
		// A double shell on a chamber gun with only one chamber live takes its second shell from the store its cycle feeds
		// from -- a pump's tube (WM_System.DoubleShellFeed) -- spent with the shot below; with none there, it is that
		// chamber's plain shot.
		bool dblFromFeed = false;
		if (dbl && chambers < 2 && sys.FiresFrom(invoker.GetClassName()) == WM_Card.FIRES_CHAMBER)
		{
			dblFromFeed = sys.DoubleShellFeed(pn, h, false);
			dbl = dblFromFeed;
		}
		// SELECT FIRE'S BURST (WM_Gun.AltMode selectfire, mode 1): the first shot of a pull starts a burst of AltBurst.
		if (shotKind == ALT_SHOT_NORMAL && invoker.burstShotsLeft == 0 && invoker.refireCount == 0
			&& invoker.selectFireMode == 1 && invoker.AltModeKind() == ALT_SELECTFIRE)
			invoker.burstShotsLeft = invoker.AltBurstEach();
		// A BURST'S ROUND (burst, or select fire's): one fewer still to come.
		if (invoker.burstShotsLeft > 0) invoker.burstShotsLeft--;
		// A GUN THAT FIRES FROM THE RESERVE (card `firesfrom = reserve`) PAYS HERE, in the
		// weapon's own action, which runs on every machine in a netgame -- never in the rig,
		// which runs on one. RoundsPerShot of Weapon.AmmoType1, by DepleteAmmo, which honours
		// infinite ammo; CanFire has already said the reserve holds that much.
		if (sys.FiresFrom(invoker.GetClassName()) == WM_Card.FIRES_RESERVE)
			invoker.DepleteAmmo(false, true, rounds, true);
		// THE SHOT THIS CLASS DESCRIBES: PelletsPerShot rounds a chamber, each scattered
		// within its spread and dealing its damage. Read off the invoker, so every machine
		// fires the same pellets. A class silent on all three is one round, dead on,
		// 5 x 1d3 -- the pistol shot exactly as it was.
		// A SAW (WM_Gun.ShotSaw): A_Saw once a pull, never a pellet. SF_NOTURN and SF_NOPULLIN,
		// because vanilla's turns and drags the PLAYER toward what it cuts, which in a headset
		// yanks the view. A_Saw picks the off hand itself (invoker == player.OffhandWeapon).
		// ShotDamage, when set, is rolled on a named RNG (SF_NORANDOM keeps it); unset is
		// vanilla's 2 x 1d10. Its puff is the class's WM_Gun.SawPuff (SawPuffActor), unset RS_Ballistics'
		// RSB_SawPuff: a BulletPuff with its sprite hidden that plays the `saw` impact where it cuts.
		if (invoker.sawShotOn)
		{
			int sawDamage = 2;
			int sawFlags = SF_NOUSEAMMO | SF_NOTURN | SF_NOPULLIN;
			if (invoker.shotDamageLo > 0)
			{
				sawDamage = random[WMSaw](invoker.shotDamageLo, max(invoker.shotDamageLo, invoker.shotDamageHi));
				sawFlags |= SF_NORANDOM;
			}
			A_Saw(invoker.SawFullSound(), invoker.SawHitSound(), sawDamage, invoker.SawPuffActor(), sawFlags);
			invoker.fireStarted = true;
			sys.OnShot(pn, h, chambers, rounds);
			return ResolveState(null);
		}
		int    nPellets = invoker.PelletsPerShot() * (dbl ? 1 : chambers);
		double sprH     = invoker.ShotYawSpread();
		double sprV     = invoker.ShotPitchSpread();
		// THE FIRST SHOTS OF A HOLD FLY DEAD ON (WM_Gun.FirstShotsAccurate N): one pellet, and one of the first N shots of a
		// held run -- vanilla A_FireBullets' own test. Every later shot keeps the class's spread, on the same named RNG.
		if (invoker.firstShotsDeadOn > 0 && nPellets == 1 && invoker.refireCount < invoker.firstShotsDeadOn)
		{
			sprH = 0;
			sprV = 0;
		}
		// A FANNED ROUND (WM_Gun.AltMode fan) is never aimed: twice the spread.
		if (shotKind == ALT_SHOT_FAN)
		{
			sprH *= FAN_SPREAD_SCALE;
			sprV *= FAN_SPREAD_SCALE;
		}
		// RECOIL (WM_Gun.RecoilStep), once this shot and after the dead-on test: its bloom widens the spread, and each round
		// below leaves turned by the kick so far. Not for a rail, which aims and scatters itself; a saw returned above.
		// All zero with sv_rsb_recoil off or no recoilprofile, so the shot is exactly what it was.
		double kickYaw   = 0;
		double kickPitch = 0;
		double kickBloom = 0;
		if (!invoker.railShotOn)
		{
			[kickYaw, kickPitch, kickBloom] = invoker.RecoilStep(invoker.recoilProfileName);
			sprH += kickBloom;
			sprV += kickBloom;
		}
		for (int i = 0; i < nPellets; i++)
		{
			// A RAIL (WM_Gun.ShotRail) instead of a projectile. A_RailAttack leaves the hand
			// holding this gun on its own (it asks invoker == player.OffhandWeapon), spends no
			// ammo (useammo false) and scatters by its own named RNG. Colours 0 are the engine's
			// own rail -- a blue spiral round a grey core (p_effect.cpp P_DrawRailTrail). Its puff is
			// RS_Ballistics' RSB_RailPuff: a BulletPuff with its sprite hidden that plays the `rail`
			// impact (a blue-white splash, a glowing ring, a light) where it hits.
			// ITS TRAIL (WM_Gun.TrailProfile): unset, the engine draws its own in RailColors. Set, the
			// engine's is switched off (-1 for both parts) and RS_Ballistics lays the profile's from the
			// drawn muzzle to where the rail ENDED -- the engine's own end point, recorded by
			// WM_System.WorldRailgunFired while A_RailAttack runs, so the trail meets what the rail
			// really hit, scatter and all. Switched by the class, never a local setting.
			if (invoker.railShotOn)
			{
				bool  ownTrail = (invoker.trailProfileName != "");
				color spiral   = WM_Gun.RailColor(invoker.railSpiralRGB);
				color core     = WM_Gun.RailColor(invoker.railCoreRGB);
				if (ownTrail)
				{
					spiral = WM_Gun.RailPartOff();
					core   = WM_Gun.RailPartOff();
				}
				int railsBefore = sys.railsFired;
				A_RailAttack(invoker.RailDamage(), 0, false, spiral, core, 0, 0, "RSB_RailPuff", sprH, sprV);
				// A rail a handler cancelled (WorldRailgunPreFired) never reaches WorldRailgunFired: no trail.
				if (ownTrail && sys.railsFired != railsBefore && sys.lastRailShooter == self)
					invoker.LayRailTrail(sys.lastRailFrom, sys.lastRailTo);
				continue;
			}
			// A REAL ROUND, NOT A HITSCAN LINE: RS_Ballistics' RSB_Bullet unless the class names its
			// own projectile (WM_Gun.ShotClass). The engine spawns it at the firing hand and aims it,
			// as A_FireBullets did; LaunchRound, after the scatter, names its profile, sets its speed and
			// applies ShotDamage, and leaves any other projectile as its class made it. THIS IS THE SEAM
			// a different round comes in at: one call, the class found by name.
			Actor shot, spare;
			[shot, spare] = A_FireProjectile(invoker.ShotActor(), 0, false, 0, 0, FPF_NOAUTOAIM);
			if (shot) RSB_Recoil.Turn(shot, kickYaw, kickPitch);
			if (shot && (sprH > 0 || sprV > 0)) invoker.ScatterShot(shot, sprH, sprV);
			invoker.LaunchRound(shot, player, h, true);
			if (dbl) invoker.ScaleShotDamage(shot, invoker.AltDamageScaleEach());
		}
		invoker.fireStarted = true;
		if (dblFromFeed) sys.DoubleShellFeed(pn, h, true);
		sys.OnShot(pn, h, chambers, rounds);
		return ResolveState(null);
	}

	// FULL AUTO (WM_Gun.FullAuto): the end of a Fire cycle, with the trigger still held,
	// goes straight round to Fire again instead of to Ready. Null -- carry on to Ready,
	// as every other class does -- when the class is not full auto, the trigger is up,
	// the player is dead, or this hand has a weapon change pending (A_ReFire's own test,
	// so a switch is not held off by a held trigger). Whether the next shot happens is
	// still WM_TryFire's: the chamber and the verbs decide, and an empty one clicks once.
	action State WM_HoldFire()
	{
		if (!player || player.health <= 0) { invoker.burstShotsLeft = 0; return null; }
		if (player.PendingWeapon != WP_NOCHANGE && player.PendingWeapon.bOffhandWeapon == invoker.bOffhandWeapon) { invoker.burstShotsLeft = 0; return null; }
		// THE SECOND BARREL BETWEEN SHOTS (card.zs WM_Barrel): a full-auto gun held down never
		// reaches Ready, so its second button is read here too, at the end of every cycle. The
		// card is asked only while that button is down, so a class with no second barrel is not.
		if (!invoker.altMustRelease && WM_AltDown() && invoker.AltBarrel())
		{
			invoker.bAltFire = true;
			return ResolveState("AltFire");
		}
		// A BURST STILL GOING (WM_Gun.AltMode burst, or select fire's): round again, trigger or no trigger.
		if (invoker.burstShotsLeft > 0)
		{
			invoker.bAltFire = false;
			invoker.refireCount++;
			return ResolveState("Fire");
		}
		// SHRED (WM_Gun.AltMode shred): the second button still held, round again at its rate. Any other alt shot is done.
		if (invoker.altShotKind == ALT_SHOT_SHRED && WM_AltDown())
		{
			invoker.bAltFire = false;
			invoker.refireCount++;
			return ResolveState("Fire");
		}
		invoker.altShotKind = ALT_SHOT_NORMAL;
		if (!invoker.FiresFullAuto() || !WM_TriggerDown()) return null;
		invoker.bAltFire = false;
		invoker.refireCount++;   // vanilla A_ReFire's player.refire++: the next shot is a refire
		return ResolveState("Fire");
	}

	action bool WM_AltDown()
	{
		if (!player) return false;
		int bit = invoker.bOffhandWeapon ? BT_OFFHANDALTATTACK : BT_ALTATTACK;
		return (player.cmd.buttons & bit) != 0;
	}

	// THE SECOND BARREL'S SHOT (card `barrel <id>`, card.zs WM_Barrel): the AltFire state's
	// first tic, the same shape as WM_TryFire -- one question to the system for the weapon's
	// OWNER by player number, then the shot and its announcement on the same tic. One round of
	// the barrel's shotclass, spawned at the firing hand as every shot is; its damage is its own
	// class's. Nothing is paid here: the round is in the barrel's store, which OnAltShot spends.
	action State WM_TryAltFire()
	{
		invoker.altMustRelease = true;
		let sys = WM_System(EventHandler.Find("WM_System"));
		let b = sys ? sys.AltBarrelFor(invoker.GetClassName()) : null;
		if (!b) return ResolveState("Ready");
		int h = invoker.Hand();
		int pn = player ? PlayerNumber() : -1;
		if (!sys.CanAltFire(pn, h, invoker))
		{
			// Not yet this gun's rig: no click, as WM_TryFire.
			if (sys.RigBoundElsewhere(pn, h, invoker))
			{
				invoker.altMustRelease = false;
				return ResolveState("Ready");
			}
			sys.OnAltDry(pn, h);
			return ResolveState("Dry");
		}
		// RECOIL: the second barrel's own profile (the sheet's altrecoilprofile), on the gun's one kick. All zero when off.
		double altKickYaw, altKickPitch, altKickBloom;
		[altKickYaw, altKickPitch, altKickBloom] = invoker.RecoilStep(invoker.altRecoilProfileName);
		Actor shot, spare;
		[shot, spare] = A_FireProjectile(invoker.BarrelShotActor(b), 0, false, 0, 0, FPF_NOAUTOAIM);
		if (shot) RSB_Recoil.Turn(shot, altKickYaw, altKickPitch);
		invoker.LaunchRound(shot, player, h, false);
		sys.OnAltShot(pn, h);
		return ResolveState(null);
	}

	// THE PROJECTILE A SECOND BARREL FIRES (WM_Barrel `shotclass`), found by name as it fires.
	// Unset is RSB_Bullet, the gun's own round; a name that is no actor is said once, and it fires
	// RSB_Bullet rather than nothing -- ShotActor's rule for the main barrel.
	Class<Actor> BarrelShotActor(WM_Barrel b)
	{
		Class<Actor> fallback = "RSB_Bullet";
		if (!b || b.shotClassName == "") return fallback;
		Class<Actor> named = (Class<Actor>)(Object.FindClass(b.shotClassName, "Actor"));
		if (named) return named;
		WM_Log.Once(WM_Log.LV_ERR, "barrelshot:" .. GetClassName() .. ":" .. b.id, String.Format(
			"%s barrel %s: shotclass '%s' is not an actor class -- it fires RSB_Bullet instead", GetClassName(), b.id, b.shotClassName));
		return fallback;
	}

	// THE WAIT AFTER THE SECOND BARREL'S SHOT (WM_Barrel `firetics`), as WM_FireWait is the
	// main barrel's.
	action void WM_AltFireWait()
	{
		let b = invoker.AltBarrel();
		A_SetTics(max((b ? b.CycleTics() : 19) - 1, 0));
	}

	// THE WAIT AFTER A SHOT, sized by the class (WM_Gun.FireTics). The Fire state's
	// first tic fires; this state then lasts the rest of the cycle, so an unset
	// class waits 18 more tics -- 19 in all, the cadence the fixed 10 + 4 + 5 gave.
	action void WM_FireWait()
	{
		// A burst's next round comes AltBurstTics after this one; shred cycles FireTics / AltRateScale; a fanned round
		// is ready again as soon as the fan cap allows (WM_Gun.AltMode). Every other shot waits its class's cycle.
		int tics = invoker.CycleTics();
		if (invoker.burstShotsLeft > 0)                         tics = invoker.AltBurstTicsEach();
		else if (invoker.altShotKind == ALT_SHOT_SHRED)         tics = max(int(tics / invoker.AltRateScaleEach() + 0.5), 1);
		else if (invoker.altShotKind == ALT_SHOT_FAN)           tics = max(35 / invoker.AltFanMaxEach(), 1);
		A_SetTics(max(tics - 1, 0));
	}

	// THE RECOVERY AFTER A FIRING RUN (WM_Gun.ReleaseTics). Reached only when WM_HoldFire let the
	// run end -- no refire, no second barrel -- and no tics at all for a class that sets none, so
	// every other gun is ready exactly when it was.
	action void WM_ReleaseWait()
	{
		A_SetTics(invoker.ReleaseTicsEach());
	}

	// THE CHARGE (WM_Gun.ChargeTics), the first state of Fire and a 0-tic one, so a class that
	// does not charge loses no tic and fires exactly as it did -- a FullAuto refire included.
	// A gun that cannot fire clicks and does not charge; one that can starts the charge sound
	// and waits in Charge, then WM_TryFire asks again, so a magazine dropped mid-charge clicks.
	// The trigger coming back mid-charge does not cancel it, as in vanilla.
	action State WM_Charge()
	{
		// THE SPIN-UP FIRST (WM_Gun.SpinUpTics): barrels not yet at full speed hold the shot in SpinUp.
		if (!invoker.SpunUp()) return ResolveState("SpinUp");
		int tics = invoker.ChargeTicsEach();
		if (tics <= 0) return null;
		invoker.mustRelease = true;
		let sys = WM_System(EventHandler.Find("WM_System"));
		int h = invoker.Hand();
		int pn = player ? PlayerNumber() : -1;
		int rounds = invoker.RoundsEachShot();
		if (!sys || !sys.CanFire(pn, h, invoker.ChambersEachPull(), rounds, invoker))
		{
			invoker.fireStarted = false;
			// Not yet this gun's rig: no charge, no click, as WM_TryFire.
			if (sys && sys.RigBoundElsewhere(pn, h, invoker))
			{
				invoker.mustRelease = false;
				return ResolveState("Ready");
			}
			if (sys) sys.OnDry(pn, h, rounds);
			return ResolveState("Dry");
		}
		sys.OnCharge(pn, h, invoker.chargeSoundName, tics);
		return ResolveState("Charge");
	}

	// The charge's own wait, sized by the class. The tic it began is kept (chargeBeganTic) on the same tic its
	// length is set, so the charge's look (WM_Rig.ChargeLook) reads how far along it is off the real wait.
	action void WM_ChargeWait()
	{
		invoker.chargeBeganTic = level.maptime;
		A_SetTics(max(invoker.ChargeTicsEach(), 1));
	}

	// THE SPIN-UP'S WAIT (WM_Gun.SpinUpTics), a tic at a time while DoEffect spins the barrels: at full speed, round
	// to Fire, which now passes; the trigger let go first, or a switch pending for this hand, back to Ready with
	// nothing fired. Off the owner's usercmd, on every machine.
	action State WM_SpinWait()
	{
		if (invoker.SpunUp()) return ResolveState("Fire");
		if (!player || player.health <= 0 || !WM_TriggerDown()) return ResolveState("Ready");
		if (player.PendingWeapon != WP_NOCHANGE && player.PendingWeapon.bOffhandWeapon == invoker.bOffhandWeapon) return ResolveState("Ready");
		return null;
	}

	// THIS CLASS'S DAMAGE ON ONE ROUND. Unset (0), the round keeps its own roll.
	// ONE ROUND LEAVING THE GUN: THE ONE LAUNCH PATH for the pellet loop (WM_TryFire) and a second barrel
	// (WM_TryAltFire), so a network command can wrap this one call (NETPLAY_SPEC). Called straight after
	// A_FireProjectile and any scatter, in the fire action, on every machine. An RSB_Bullet takes the
	// class's RoundProfile, which sets its speed and size from the profile's ballistics and keeps the
	// direction. Any other projectile (a Rocket, a PlasmaBall, a grenade) is left as its class made it.
	// withDamage: the class's ShotDamage on it -- the pellet loop's; a barrel's round keeps its own.
	void LaunchRound(Actor shot, PlayerInfo shooter, int h, bool withDamage)
	{
		if (!shot) return;
		// A BULLET GUN THAT NAMES NO ROUND flies RS_Ballistics' plain "default", and says so once.
		if (shot is "RSB_Bullet" && roundProfileName == "")
			WM_Log.Once(WM_Log.LV_WARN, "noround:" .. GetClassName(), String.Format(
				"%s fires RSB_Bullet but names no WM_Gun.RoundProfile -- it flies as RS_Ballistics' plain \"default\" round", GetClassName()));
		if (shot is "RSB_Bullet") RSB_Bullet.Launch(shot, shooter, h, RoundProfileOrDefault());
		if (withDamage) ApplyShotDamage(shot);
	}

	// THE CLASS'S ShotDamage ON ONE ROUND, rolled on its hit; unset (0) leaves the round profile's own.
	void ApplyShotDamage(Actor shot)
	{
		if (!shot || shotDamageLo <= 0) return;
		int lo = shotDamageLo;
		int hi = max(shotDamageLo, shotDamageHi);
		let r = RSB_Bullet(shot);
		if (r) { r.damageMin = lo; r.damageMax = hi; }
	}

	// ONE PELLET'S OWN LINE. The engine aimed the round down the hand's line; this
	// turns it by up to spreadYaw sideways and spreadPitch up or down -- two uniform
	// draws differenced, so pellets bunch toward the middle the way A_FireBullets'
	// did -- and keeps its speed. Done to the velocity, not through A_FireProjectile's
	// angle and pitch, which offset the player's VIEW rather than the hand the round
	// leaves. A named RNG, so every machine scatters alike.
	void ScatterShot(Actor shot, double spreadYaw, double spreadPitch)
	{
		double spd = shot.Vel.Length();
		if (spd < 0.000001) return;
		Vector3 dir = shot.Vel / spd;
		double yawOff, elevOff;
		if (SpreadCone())
		{
			// A ROUND CONE (WM_Gun.SpreadShape cone): a point drawn evenly over a disc whose radius is the larger spread --
			// sideways and up alike, never a box's corners. The same named RNG.
			double radius = max(spreadYaw, spreadPitch) * sqrt(frandom[WMSpread](0, 1));
			double around = frandom[WMSpread](0, 360);
			yawOff  = radius * cos(around);
			elevOff = radius * sin(around);
		}
		else
		{
			yawOff  = (frandom[WMSpread](0, 1) - frandom[WMSpread](0, 1)) * spreadYaw;
			elevOff = (frandom[WMSpread](0, 1) - frandom[WMSpread](0, 1)) * spreadPitch;
		}
		double yaw  = VectorAngle(dir.X, dir.Y) + yawOff;
		double elev = atan2(dir.Z, dir.XY.Length()) + elevOff;
		double ce = cos(elev);
		shot.Vel = (ce * cos(yaw), ce * sin(yaw), sin(elev)) * spd;
		shot.angle = yaw;
		shot.pitch = -elev;
	}

	States
	{
	Spawn:
		WMPR A -1;
		Stop;
	Ready:
		TNT1 A 1 WM_Ready();
		Loop;
	Deselect:
		TNT1 A 1 A_Lower();
		Loop;
	Select:
		TNT1 A 1 A_Raise();
		Loop;
	Fire:
		// No tic of its own: a class that does not charge passes straight to the shot.
		TNT1 A 0 WM_Charge();
		TNT1 A 1 WM_TryFire();
		TNT1 A 18 WM_FireWait();
		// No tic of its own: a class that is not FullAuto passes straight to Ready.
		TNT1 A 0 WM_HoldFire();
		// The recovery (WM_Gun.ReleaseTics): it sets its own tics, none for a class that sets none.
		TNT1 A 1 WM_ReleaseWait();
		Goto Ready;
	Charge:
		TNT1 A 1 WM_ChargeWait();
		Goto Fire+1;
	SpinUp:
		// The spin-up (WM_Gun.SpinUpTics): a tic at a time until the barrels are at full speed.
		TNT1 A 1 WM_SpinWait();
		Loop;
	AltFire:
		// A card's second barrel (card.zs WM_Barrel): its shot, its wait, then a held full-auto
		// trigger goes round to Fire as at the end of Fire. Reached only when the card has one:
		// WM_Ready blocks the second button otherwise, and WM_HoldFire asks first.
		TNT1 A 1 WM_TryAltFire();
		TNT1 A 18 WM_AltFireWait();
		TNT1 A 0 WM_HoldFire();
		Goto Ready;
	Dry:
		TNT1 A 8;
		Goto Ready;
	}
}

// WHAT A GUN IS DRAWN AS. The card's `prop` names a subclass of this (declared by
// the weapon package, one per gun), rig.zs EnsureProp finds it by name and spawns
// it, and the weapon package's MODELDEF binds the mesh and the hand to it
// (FollowMainHand / FollowOffHand) -- which is the only reason each gun has its
// own class.
//
// ADDED 2026-09-10 BY ANOTHER LANE, not this package's author: MODELDEF and
// both cards already named the prop classes, but nothing declared them, so the
// engine stopped at startup on "MODELDEF: Unknown actor type 'WM_PropM4A3'".
// Written the way WM_Marker is -- a drawing, never a thing in the playsim --
// and deliberately nothing more.
//
// THE HAND SEATS ARE THIS PACKAGE'S, THE BLOCKS THAT READ THEM ARE NOT. wm_main and
// wm_off are placement sets per HAND (CVARINFO.txt, the "Main-hand gun" and
// "Off-hand gun" pages), read by the renderer through `PlacementCVars wm_main` /
// `wm_off` on a weapon package's MODELDEF blocks. No block here names them any
// more, so they are declared to the lint by hand:
// LINT-PREFIXES: wm_main wm_off
class WM_Prop : Actor abstract
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+NOTELEPORT
		+DONTSPLASH
		+NOTONAUTOMAP
		RenderStyle "Normal";
		Radius 1;
		Height 1;
	}

	States
	{
	Spawn:
		WMPR A -1;
		Stop;
	}
}
