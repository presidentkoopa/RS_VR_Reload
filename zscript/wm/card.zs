// ============================================================================
// THE CARD -- what a weapon says about itself, and the only thing it says.
//
// A weapon opts into this system by shipping a text lump. No ZScript, no
// per-weapon mechanism code. The lump names the weapon's moving parts and how
// each one travels; grabbing, driving, dropping, seating and firing are this
// system's job and are written exactly once.
//
// ------------------------------------------------------------ WHY TEXT
//
// A ZScript class reference across pk3 boundaries resolves at COMPILE time,
// and a miss does not skip that weapon -- it refuses every pk3 loaded after
// it. A text lump cannot do that: worst case one card is refused, one line is
// printed naming the lump and line, and every other weapon carries on.
//
// ---------------------------------------------------- WHY NO FRAME NUMBERS
//
// Because the frames lie. On m4a3.md3 the RECEIVER drifts 24.41 units from
// frame 8, so "play the magazine-out frames" hurls the whole pistol sideways.
// On pistolet.md3 the second magazine piece collapses to a point five frames
// before the first. A card names an AXIS and a DISTANCE, measured by rigid fit
// with the receiver's own motion divided out, and the part is driven live.
//
// ------------------------------------------------------------ UNITS
//
// Every point and axis is in MD3 MODEL SPACE -- x along the barrel, y across,
// z up -- in the mesh's own units. WM_Space converts to the renderer's axes at
// the one boundary where that is needed. Grab radii are MAP units, because
// they are compared against where your hand is in the room.
// ============================================================================

class WM_Dof
{
	// A slide translates; a hinge rotates about a pivot. Kept apart because
	// the measurement that describes them differs -- a hammer reads as 7.48
	// units of "travel" by centroid and 62 degrees of rotation, and only the
	// second number means anything.
	const MOVE_SLIDE = 0;
	const MOVE_HINGE = 1;
	int moveKind;

	Vector3 axis;        // unit. Slide: direction of travel. Hinge: the pin.
	double  distance;    // slide: model units from rest to fully out
	double  degrees;     // hinge: the whole turn
	Vector3 pivot;       // hinge: a point on the pin, model space

	// 0..1. Past this, letting go releases the part rather than springing it.
	double  detach;
	double  rest;

	// A SLIDE THAT ALSO TURNS, about `pivot`, in step with its travel. Zero on
	// both cards shipped today, deliberately: a magazine inside its well is
	// constrained to translate, and the tilt both meshes animate happens after
	// it has cleared -- free fall, which the loose magazine does for itself.
	double  twist;
	Vector3 twistAxis;

	// dof2 ONLY (WM_Part.dof2): the share of the pull given to the part's `dof`. The one
	// drawn value 0..1 is [0, split] for the dof and [split, 1] for the dof2. Unused on a
	// part's `dof`.
	double  split;
}

class WM_Part
{
	String  id;

	// What it DOES:  action | feed | hammer | trigger | support | hidden
	//   action   cycles on a shot, is racked by hand
	//   feed     the magazine: dropped, pulled, seated
	//   hammer   cocked by the action, falls on the shot
	//   trigger  follows the analog trigger of the hand holding the gun
	//   support  not a moving part -- a place for the other hand to brace
	//   hidden   never drawn (animation-only pieces such as baked brass)
	String  role;

	// What SHAPE a hand makes on it, in the engine's vocabulary. A pump's
	// forend and a pistol's slide are both the action and are held completely
	// differently, so this is not inferred from the role.
	//   slide | forend | foregrip | magazine | shell | round | support
	String  subject;

	Array<int>    surfaces;       // resolved from names at load
	Array<String> surfaceNames;   // a part may be several surfaces
	int     modelIndex;

	Vector3 grabAt;      // where a hand reaches for it, model space
	double  grabRadius;  // how close, MAP units -- a ball, when no grabsize
	// THE OVAL, in the gun's own axes: along the barrel, across it, up. A grab
	// is rarely a ball -- a slide is long and thin, a magazine well is a slot --
	// and a ball drawn for it promises reach where there is none. Zero means
	// "no oval stated", and grabRadius is used for all three.
	Vector3 grabSize;

	// WHERE THE HAND SITS ON IT: `handseat = x, y, z`, a point on the mesh in model
	// space, carried with the part as it moves. A pump's forend is held under the gun
	// toward the muzzle and a pistol's slide on top at the back -- one seat for both
	// put a hand gripping a forend on the pistol's slide. Stated, the drawn hand is
	// seated ON THIS POINT (Actor.FollowActorOfsInModel, riding the part's drive
	// slot), and its per-hand seat sliders (wm_main_<kind> / wm_off_<kind>) trim it
	// live. Unstated, the hand is seated exactly as it always was: at the gun's frame
	// origin, placed entirely by those sliders -- which is every pistol part.
	Vector3 handSeat;
	bool    handSeatStated;

	// WHETHER A HAND TAKES IT. "take = no" in the card. A pistol magazine is
	// dropped by its button and seated by the hand carrying one -- a grab point
	// on it only sits where the other hand steadies the gun or takes it over, and
	// turns those squeezes into pulling the magazine. It still has its oval: that
	// is where the well is, and its sliders still move the well.
	bool    handTake;
	// Whether the card said `take` at all. A swap verb's `handtake` may say it
	// instead; said in both places and disagreeing, the card is refused.
	bool    takeStated;

	// A PART THAT IS A JOINT: `joint = <name>`. On a rigged model (an IQM) a gun's parts are bones, not separate
	// surfaces -- a slide, its frame and the magazine may all be one mesh. A part naming a joint is moved by that joint
	// (Actor.SetModelJointOffset and the SetModelJointDrive family, the engine's bone drive) with the same dof, verbs,
	// grabs and hand drive as any part. Surface-only extras -- roundsurface, metersurface, flip -- need surfaces.
	// "" (unset): a surface part, as before.
	String  jointName;

	WM_Dof  dof;

	// A SECOND, SEQUENTIAL STAGE: `dof2 ... end` (kind, axis, distance or degrees and
	// pivot, split). NULL UNLESS THE CARD STATES ONE, and every consumer asks for null
	// first, so a part without it runs the single-stage code exactly as it always did.
	// With it, ONE drawn value 0..1 drives both: up to dof2.split the part is its `dof`
	// at value / split; past it the dof is held fully applied and the dof2 runs at
	// (value - split) / (1 - split), on top of it, in the gun's model space. The engine
	// drives it (Actor.SetModelSurfaceDriveStage) and WM_Rig.TwoStagePoint poses it by
	// the engine's own rule. A bolt: dof hinge (the handle lifts), dof2 slide (it draws).
	WM_Dof  dof2;

	// A HAMMER COCKED BY THE FINGER: `cock = trigger`. The hammer follows the analog
	// trigger of the hand holding the gun back, and falls on the shot or the click, and
	// stays down until the finger comes off -- a double action. Unstated (`action`), a
	// hammer is cocked by the action and falls on the shot, which is every pistol.
	bool    cockByTrigger;

	// A PART THAT SPINS (G11): `spin = trigger | fire`, `spinrate`, `spinup`, `spindown`. A
	// chaingun's barrels. It turns about its hinge -- one `dof` of kind = hinge, whose `degrees`
	// is ONE PERIOD of its pattern, 60 for six barrels -- at spinrate degrees a tic at full speed,
	// easing up over spinup tics while the trigger of the hand holding the gun is down (trigger)
	// or while it is firing (fire), and down over spindown tics after. No role, no verb, no dof2
	// (WM_Parser.SpinProblem). The card's spinupsound / spinsound / spindownsound play with it
	// (WM_Rig.Spin). Presentation only.
	const SPIN_NONE    = 0;
	const SPIN_TRIGGER = 1;
	const SPIN_FIRE    = 2;
	int     spinBy;
	double  spinRate;      // degrees a tic at full speed; negative turns it the other way
	int     spinUpTics;    // tics from still to full speed; 0 is at once
	int     spinDownTics;  // tics from full speed to still; 0 is at once

	// A PART THAT FLIPS (CS-G4): `flip = trigger | fire`, `fliptics`, `flipphase`. Two poses of one
	// thing, modelled as two parts -- a heavy saw's `chain` and `chain2` -- shown in turn while the
	// trigger of the hand holding the gun is down (trigger) or the gun is firing (fire): each on its
	// own phase, 0 or 1, of every 2 x fliptics tics; at rest only phase 0 shows. No role, and not a
	// spinning part too (WM_Parser.FlipProblem). Presentation only (WM_Rig.FlipShown).
	const FLIP_NONE    = 0;
	const FLIP_TRIGGER = 1;
	const FLIP_FIRE    = 2;
	int     flipBy;
	int     flipTics;      // tics each pose shows while it runs; 0 (unset) is 2
	int     flipPhase;     // 0: shown at rest and on even beats; 1: shown on odd beats only

	// A SURFACE THAT SHOWS THE MAGAZINE'S FILL -- a BFG's charge gauge: `metersurface = <surface>`,
	// `meterskins = "<path>" "<file with %d>"`, `metersteps = N`. That surface of this part wears skin
	// number ceil(fill x N), 1 to N -- 1 with the magazine out or empty -- as its surface skin
	// (A_ChangeModel with CMDL_USESURFACESKIN), changed only when the step changes (WM_Rig.Meter).
	// A pose override slot has no skin of its own, so the gauge rides a moving part unchanged.
	String  meterSurface;
	String  meterSkinPath, meterSkinFile;
	int     meterSteps;

	// A MAGAZINE THAT INDEXES ON THE SHOT (G13): `index ... end` inside the feed part -- kind
	// (slide | hinge), axis, pivot, and degrees or distance PER STEP, with `from` and `steps`.
	// Steps taken = clamp(from - rounds in the magazine, 0, steps); both unset are the magazine's
	// capacity. An RPG's drum turns a chamber a shot; a rack (from 3, steps 2) holds still down to
	// three left, then steps its next rocket into the bore. Applied UNDER the part's dof, so it
	// rides the swap slide; read off the count as it is drawn, so a partial magazine seats already
	// stepped. While a hand or a seat drives the part, the renderer draws the dof alone and the
	// index shows again once the drive ends (WM_Rig.PartOffset). Null unless stated.
	WM_Dof  indexDof;
	int     indexFrom;     // 0: unset -- the magazine's capacity
	int     indexSteps;    // 0: unset -- the magazine's capacity

	// SURFACES THAT SHOW A STORE: `roundsurface = <surface>, <store>, <slot|any>`. Each
	// is one more surface of this part -- it moves with it, in the same drive -- drawn only
	// while that slot of that slotted store holds a case, live or spent (slot -1: any). On a
	// COUNTED store the number is a count: drawn while the store holds more than it (-1: any
	// round) -- a rocket rack's rockets going one by one (WM_Ammo.RoundShows).
	// Parallel arrays, in card order; the names are also in surfaceNames.
	Array<String> roundSurfName;
	Array<String> roundSurfStore;
	Array<int>    roundSurfSlot;
	// Resolved with surfaces (WM_Rig.Resolve): per entry of `surfaces`, its index into
	// the three arrays above, or -1 for a surface that always shows.
	Array<int>    surfaceRound;

	int     line;        // the line its block opened on, for a refusal found after parsing

	// The round binding a surface name has, or -1.
	int RoundBindFor(String surfName)
	{
		for (int r = 0; r < roundSurfName.Size(); r++)
			if (roundSurfName[r] ~== surfName) return r;
		return -1;
	}

	// Live state
	double  value;       // 0..1 along the dof
	bool    present;     // false once it has left the weapon
	int     driveSlot;   // the hand drive's first slot, -1 when not held
	int     poseSlot;    // its first surface-override slot, for life; -1 if none fit
	bool    jointDriven; // a joint part (jointName) that the hand drive holds right now
	bool    pastSplit;   // dof2 only: the value last posed was past dof2.split -- one log line per crossing
	double  spinSpeed;   // spin only (spinBy): 0 still .. 1 full speed
	double  spinAngle;   // spin only: degrees into one period of its hinge
}

// A SECOND BARREL ON ONE GUN: `barrel <id>` ... `end` on a card -- an underbarrel grenade
// launcher under a machine gun, with its own input, its own store and its own shot. The card's
// own keys (firesfrom, muzzle, barrel, firesound) and the weapon class's WM_Gun.Shot* stay the
// MAIN barrel's.
//
//   input     = altfire          the holding hand's second button. The only input; one barrel
//                                per card takes it.
//   trigger   = <part>           optional: a part drawn pulled while that button is held
//   from      = <store>          the declared store it fires from. Slotted: a live slot is
//                                fired and left SPENT -- nothing cycles a barrel, so its case
//                                stays until something empties the store (an open verb's
//                                ejectall). Counted: one round less. Never `mag` or `chamber`,
//                                never detach = yes, never two barrels' store.
//   shotclass = "<actor>"        found by name as it fires; unset or unknown is RSB_Bullet
//   ammo      = "<Ammo class>"   by name: what the pouch hands for a load into `from`, and
//                                where a loose round of it goes back to. Unset: the weapon's
//                                Weapon.AmmoType1. Named and not loaded, the pouch hands none.
//   muzzle    = x, y, z          its flash and sparks, model space; unset is the card's muzzle
//   barrel    = x, y, z          the way it points, model space; unset is the card's barrel
//   firesound = "<sound>"        unset is the card's firesound
//   needs     = shut:<open id>   it fires only while that open verb is shut -- and that open
//                                verb stops only this barrel, never the main one
//   firetics  = N                tics from its shot until the gun is ready again; unset 19
//   casing    = yes | none       none: its store holds no cases, so emptying it throws no brass
//
// CARD DATA, shared and never changed once the cards are loaded. Its rounds are in the gun's
// own store copies (WM_Ammo), as every store's are; the rig and the system fire it
// (WM_Rig.OnBarrelShot, WM_System.CanAltFire), the weapon's AltFire state asks them.
class WM_Barrel
{
	const INPUT_UNSTATED = 0;
	const INPUT_ALTFIRE  = 1;

	String  id;
	int     line;             // the line its block opened on, for a refusal found once the card is whole
	int     input;            // INPUT_*
	String  triggerId;
	int     triggerIndex;     // into card.parts, resolved by WM_Parser.FinishCard; -1 for none
	String  fromStore;
	String  shotClassName;
	String  ammoClassName;
	Vector3 muzzle;
	bool    muzzleStated;
	Vector3 dir;
	bool    dirStated;
	String  fireSound;
	String  needsShut;        // an open verb's id; "" for none
	int     fireTicCount;
	bool    noCasing;

	int CycleTics() const { return (fireTicCount > 0) ? clamp(fireTicCount, 1, 350) : 19; }

	static String InputWord(int inputKind) { return (inputKind == INPUT_ALTFIRE) ? "altfire" : "unstated"; }

	// Its classes are looked up by name where they are used, in play code: the shot by
	// WM_Gun.BarrelShotActor, the ammo by WM_System.BarrelAmmoClass. This is a data class, and
	// the log and WM_LooseMag.ReserveFor are play functions it cannot call.
}

class WM_Card
{
	String weaponClass;
	// THE MODEL CARD THIS ONE IS A COPY OF: a weapon sheet's `model = <id>` (sheet.zs BorrowModels), or "" for a gun's
	// own card. The copy is this gun's alone, so no live part state is shared with the model's own gun.
	String modelId;
	// The WMCARD lump this card was read from (WM_System.LoadCards), so a gun that borrows it can read its own copy.
	int    sourceLump;
	// THE CARD THIS ONE STARTS FROM: card `base = <id>` (WM_Parser.ResolveBases and FreshCard), or "". Built whole as the
	// cards load, from a fresh copy of that card with this card's own lines laid over it; baseLine is that key's line.
	String baseId;
	int    baseLine;

	// AN ENGINE'S EXHAUST PORT (card `exhaustport = x, y, z`, `exhaustdir = x, y, z`, model space like ejectport): where
	// a motor's smoke leaves the gun and the way it blows, for RS_Ballistics' RSB_Exhaust while the engine runs
	// (WM_Rig.ExhaustLook). Unstated, the gun has no exhaust.
	Vector3 exhaustPort;
	Vector3 exhaustDir;
	bool    exhaustStated;
	// WHICH MAGAZINES AND ROUNDS FIT. A family, not a gun: every gun in "pistol" takes every
	// "pistol" magazine. The magazine mesh is shared across guns, so a rule that
	// only let a magazine back into the gun it came out of could not be followed
	// from a headset -- two magazines on the floor look identical. A card that takes a
	// magazine or a round from a hand (TakesFromHand) must state it (WM_Parser FinishCard 3g:
	// warned now, refused once every card states one). Unstated still reads as "pistol", which
	// only matters to a card that takes something -- and those are the ones the check names.
	String magFamily;

	String FamilyOfMags() const { return (magFamily == "") ? "pistol" : magFamily; }

	// WHICH HAND IT BELONGS IN: 0 main, 1 off. Said by the card, so the system
	// that equips a gun into each hand names no gun anywhere in its own code.
	int hand;

	// THE ACTOR THAT IS DRAWN. A MODELDEF block is per class and is the only
	// way to put a mesh on an actor -- A_ChangeModel can swap which mesh, not
	// turn a sprite actor into a model actor -- so each gun names the class
	// whose block carries its placement.
	String propClass;

	// PARTS OF THE MODEL NEVER DRAWN, gun-wide: `hidesurface = <mesh name>` hides a surface of the model (model index
	// 0) -- a rig's own arms mesh; `hidejoint = <joint name>` collapses a joint and everything under it (Actor.MJP_Hide)
	// -- a duplicate magazine the artist parked for an animation. Either may repeat. Re-asserted every tic (WM_Rig.Pose).
	Array<String> hideSurfaces;
	Array<String> hideJoints;
	// The line each was said on, in step with the names -- the card checker (cardvalidator.zs) cites it.
	Array<int>    hideSurfaceLines;
	Array<int>    hideJointLines;

	String modelPath, modelFile;
	String skinPath,  skinFile;

	int    capacity;

	// WHERE ITS ROUNDS ARE: named stores (store.zs). The DECLARATION only, never
	// filled -- this card is one shared object, and each gun keeps its own
	// copies in its WM_Ammo. A card that declares none has the pistol pair
	// synthesised as the parser accepts it (SynthesiseStores), so every card
	// written before stores existed runs exactly as it did.
	Array<WM_Store> stores;

	// Where things come out of the gun, model space. Measured off the mesh.
	Vector3 muzzle;      // front of the bore
	Vector3 barrel;      // the direction the bore points
	Vector3 ejectPort;   // where the brass leaves
	Vector3 ejectDir;    // which way it goes

	// THE MAGAZINE, ONCE IT HAS LEFT. Its own mesh, lifted out of this gun's
	// own model by tools/md3_write.py so the magazine on the floor IS the one
	// that was in the gun.
	String magModelPath, magModelFile;
	String magSkinPath,  magSkinFile;
	double magScale;     // on the FLOOR, map units per model unit
	Vector3 magCenter;   // the extracted mesh's origin, in the GUN's model space

	// A LIVE ROUND racked out of a loaded gun.
	String roundModelPath, roundModelFile;
	String roundSkinPath,  roundSkinFile;
	double roundScale;

	// A BELT LINK thrown with every case the main barrel throws on the shot (G16): `linkmodel`,
	// `linkskin`, `linkscale`. A belt-fed gun's links. No linkmodel, no links -- every card before
	// it. Drawn by fx.zs WM_BeltLink, whose MODELDEF block is the weapon package's, as the loose
	// magazine's is.
	String linkModelPath, linkModelFile;
	String linkSkinPath,  linkSkinFile;
	double linkScale;    // on the floor, map units per model unit; unset 0.34

	// THE MAGAZINE'S SPENT SKIN: `magskinempty = "<path>" "<file>"`, worn by a loose magazine with no
	// rounds in it (WM_LooseMag.Setup) -- a BFG's dead cell. Unset, an empty magazine wears magskin.
	String magSkinEmptyPath, magSkinEmptyFile;

	String fireSound, drySound;
	// A SPINNING PART'S SOUNDS (WM_Part.spinBy, WM_Rig.Spin): the wind-up from still, the loop at
	// full speed, the run-down leaving it. Silent unless stated, like every gun sound.
	String spinUpSound, spinSound, spinDownSound;
	// A GUN WITH AN ENGINE (verb.zs START, a chainsaw's ripcord): the pull beginning, the engine
	// catching, its idle LOOPED while it runs with the trigger up, and it stopping as the gun leaves
	// the hand (WM_Rig.StartEngine, EngineIdle, Unbind). Silent unless stated.
	String pullSound, startSound, idleSound, stopSound;
	String magOutSound, magInSound;
	String slideBackSound, slideFwdSound;
	// THE RACK, AT THE TWO MOMENTS A HAND FEELS IT: the slide hitting full travel
	// (the apex) and slamming home when let go (the reset). Unstated, they borrow
	// the magazine's sounds -- the owner's call for now, until real rack sounds
	// exist; a card that names them gets them with no code change.
	String rackApexSound, rackResetSound;
	String magDropSound, casingSound;

	// A MANUAL ACTION AND A LOAD, AT THE MOMENTS A HAND FEELS THEM: a cycle returned
	// by hand reaching the far end (cycleoutsound) and coming home (cyclehomesound),
	// and a round going into a store (loadsound).
	//
	// EVERY SOUND ON A CARD IS SILENT UNTIL STATED, except the two the reload
	// system itself ships (drysound wm/dry, magdropsound wm/magdrop -- WM_Parser.NewCard).
	// casingsound is empty unless stated: a spent casing then sounds as its RS_Ballistics
	// ejecta profile does, and a loose round lands on wm/casing. The system names no gun's sounds: a shotgun
	// that omits one and plays a pistol noise is a bug nobody reports; silence is.
	String cycleOutSound, cycleHomeSound, loadSound;
	// AN EJECT VERB THROWING ITS ROUNDS OUT: a revolver's rod pushed, an extractor kicking (WM_Rig.ThrowOutAll,
	// once a stroke; slot `eject` in VR Weapon Sound Selection). The cases and rounds landing are casingsound.
	String ejectSound;
	// AN OPEN VERB OPENING AND SHUTTING: a break-top tipping down, a crane swinging out.
	String openSound, closeSound;

	// THE SHOT IS NOT ON THE CARD. Pellets, spread and damage are the weapon class's
	// (WM_Gun.ShotPellets / ShotSpread / ShotDamage, weapon.zs); a card that still
	// says `pellets`, `spread` or `damage` is refused with where they went.

	Array<WM_Part> parts;

	// WHAT THE GUN DOES WITH ITS PARTS (verb.zs). Declared by the card, supplied
	// by its archetype, or -- for a card that says neither -- synthesised from its
	// `role = action` and `role = feed` parts once every lump has been read
	// (WM_Parser.Finish). Card data: nothing here changes after load, and what a
	// verb is doing right now lives on the WM_Rig.
	Array<WM_Verb> verbs;
	String mechanism;       // `mechanism = <archetype>`; empty for none
	int    mechanismLine;
	String sourceName;      // the lump it was read from, for a refusal found after parsing

	// WHAT KIND OF GUN IT IS, which says whose hand seats its hands read
	// (handprofile.zs): `type = <word>` -- pistol, shotgun, breakaction, revolver,
	// rifle, smg, chaingun, plasma, launcher, bfg, railgun, flamethrower, chainsaw, or
	// any word a weapon package declares seats for. Unstated, WM_Parser.FinishCard
	// derives it: its archetype's `type`, or "pistol" for a card on pistol grammar, or
	// none -- the uncalibrated seats. gunTypeFrom says which, for the bind log.
	String gunType;
	String gunTypeFrom;
	// ITS OWN HAND SEATS: `handprofile = <word>` reads wm_hs_<word>_* where a weapon
	// package declares them, before its type's. A seat that package leaves out falls
	// back to the type's, then to wm_hs_default_*.
	String handProfile;

	// WHAT A TRIGGER PULL SPENDS: `firesfrom = chamber | magazine | reserve | none`.
	//   chamber   unstated: a round in the chamber store, which an action feeds -- every
	//             card written before this, exactly
	//   magazine  NO CHAMBER. A pull takes WM_Gun.RoundsPerShot straight out of the gun's
	//             counted store, so a magazine seated is a gun ready to fire, with nothing to
	//             rack: a chaingun's box, a plasma rifle's cells. Such a card has no cycle
	//             (WM_Parser.FinishCard refuses one) and gets a placeholder chamber.
	//   reserve   NO STORES. A pull takes RoundsPerShot from the owner's own Weapon.AmmoType1,
	//             in the weapon's fire action, which runs on every machine -- a flamethrower.
	//             No swap, load, cycle, eject or store (FinishCard refuses each).
	//   none      NO AMMUNITION. The trigger fires whenever the gun is in hand and in battery
	//             -- a chainsaw. The same refusals as reserve.
	// `none` is a keyword of this compiler, so its constant is FIRES_NOTHING.
	// Read on both wm_verbs paths: the switch chooses how a CHAMBER gun is worked, and a gun
	// with no chamber has nothing for it to choose between.
	const FIRES_CHAMBER  = 0;
	const FIRES_MAGAZINE = 1;
	const FIRES_RESERVE  = 2;
	const FIRES_NOTHING  = 3;
	int firesFrom;
	int firesFromLine;     // the line it was said on, for a refusal found once the card is whole

	bool FiresFromChamber() const  { return firesFrom == FIRES_CHAMBER; }
	bool FiresFromMagazine() const { return firesFrom == FIRES_MAGAZINE; }
	// No rounds of its own: the reserve pays for a pull, or nothing does.
	bool KeepsNoRounds() const     { return firesFrom == FIRES_RESERVE || firesFrom == FIRES_NOTHING; }

	String FiresFromWord() const
	{
		if (firesFrom == FIRES_MAGAZINE) return "magazine";
		if (firesFrom == FIRES_RESERVE)  return "reserve";
		if (firesFrom == FIRES_NOTHING)  return "none";
		return "chamber";
	}

	// NO CASE LEAVES THIS GUN: `casing = none` -- plasma, a rail, a rocket, flame, a saw. No
	// brass on the shot, and no brass when a store is emptied (WM_Rig.Brass, ThrowOutAll).
	// Unstated (false) is every card before it.
	bool noCasing;

	// HOW MANY HANDS IT TAKES TO FIRE: `hands = 1 | 2`. 2 is a gun the other hand must hold
	// by its `role = support` part for the trigger to fire -- a chaingun, a rocket launcher, a
	// BFG. 0 or 1 (unstated) is one hand, every card before it. The aim does not change: the
	// shot still leaves the gun hand. Aiming along the line between the two hands is an
	// engine piece, not this.
	int  handsNeeded;
	int  handsLine;        // the line it was said on, for FinishCard's refusal
	bool NeedsTwoHands() const { return handsNeeded >= 2; }

	// ITS SECOND BARRELS (WM_Barrel): `barrel <id>` blocks, checked once the card is whole
	// (WM_Parser.FinishCard). None on every card before them.
	Array<WM_Barrel> barrels;

	// A WEAPON THAT LEAVES THE HAND (throw.zs): its `throw`, `route` and `fuse` blocks, its `mount`,
	// and `pouch = whole`, checked once the card is whole (WM_Parser.ThrowableProblem). Null and
	// false on every card before them.
	WM_Throw throwSpec;
	WM_Route routeSpec;
	WM_Fuse  fuseSpec;
	WM_Mount mountSpec;
	bool     pouchWhole;
	int      pouchLine;     // the line it was said on, for a refusal found once the card is whole

	bool IsThrowable() const { return throwSpec != null; }

	WM_Barrel FindBarrel(String barrelId)
	{
		for (int i = 0; i < barrels.Size(); i++)
			if (barrels[i].id ~== barrelId) return barrels[i];
		return null;
	}

	// The barrel the holding hand's second button fires, or null -- every card without one.
	WM_Barrel AltBarrel()
	{
		for (int i = 0; i < barrels.Size(); i++)
			if (barrels[i].input == WM_Barrel.INPUT_ALTFIRE) return barrels[i];
		return null;
	}

	// THE SECOND BARREL THAT FIRES FROM A STORE, or null. Such a store is never the main
	// barrel's magazine or chamber (FacadeStoreId, WM_Ammo.Build).
	WM_Barrel BarrelForStore(String storeId)
	{
		if (storeId == "") return null;
		for (int i = 0; i < barrels.Size(); i++)
			if (barrels[i].fromStore ~== storeId) return barrels[i];
		return null;
	}

	bool IsBarrelStore(String storeId) { return BarrelForStore(storeId) != null; }

	// AN OPEN VERB A SECOND BARREL WAITS ON (its `needs = shut:<id>`): open, it stops only that
	// barrel, never the main one (WM_Rig.OutOfBattery).
	bool OpenStopsOnlyABarrel(int verbIndex)
	{
		if (verbIndex < 0 || verbIndex >= verbs.Size()) return false;
		for (int i = 0; i < barrels.Size(); i++)
			if (barrels[i].needsShut != "" && barrels[i].needsShut ~== verbs[verbIndex].id) return true;
		return false;
	}

	// A VERB THAT WORKS ONLY A SECOND BARREL'S STORE: a load into it, an eject from it, an open
	// verb whose ejectall empties it. Not the main barrel's business -- it makes the pouch hand
	// no magazine or round for the main barrel, keeps no case on the main shot, and is not
	// refused under firesfrom = reserve | none.
	bool VerbWorksOnlyABarrel(WM_Verb v)
	{
		if (!v || barrels.Size() == 0) return false;
		if (v.kind == WM_Verb.LOAD)  return IsBarrelStore(v.intoStore);
		if (v.kind == WM_Verb.EJECT) return IsBarrelStore(v.fromStore);
		if (v.kind == WM_Verb.OPEN)  return v.onOpenEjectAll && IsBarrelStore(v.fromStore);
		return false;
	}

	WM_Part FindRole(String role)
	{
		for (int i = 0; i < parts.Size(); i++)
			if (parts[i].role == role) return parts[i];
		return null;
	}

	int FindRoleIndex(String role)
	{
		for (int i = 0; i < parts.Size(); i++)
			if (parts[i].role == role) return i;
		return -1;
	}

	// THE PART A HAND WORKS THE ACTION BY: the first `role = action` part, as it
	// always was, else the part the first cycle verb works -- a pump's forend has no
	// role. For both pistols the first answer is found and the second never asked.
	int ActionPartIndex()
	{
		int ai = FindRoleIndex("action");
		if (ai >= 0) return ai;
		for (int i = 0; i < verbs.Size(); i++)
			if (verbs[i].kind == WM_Verb.CYCLE && verbs[i].partIndex >= 0 && verbs[i].partIndex < parts.Size())
				return verbs[i].partIndex;
		// A GUN WITH NO CYCLE -- a revolver -- is worked by what opens it: a break-top's
		// barrel, a crane. Asked only when neither answer above exists.
		for (int i = 0; i < verbs.Size(); i++)
			if (verbs[i].kind == WM_Verb.OPEN && verbs[i].partIndex >= 0 && verbs[i].partIndex < parts.Size())
				return verbs[i].partIndex;
		return -1;
	}

	// A declared store by name, case-insensitively. Null when the card has none.
	WM_Store FindStore(String storeId)
	{
		for (int i = 0; i < stores.Size(); i++)
			if (stores[i].id ~== storeId) return stores[i];
		return null;
	}

	// THE PISTOL PAIR, for a card that declared no stores: a COUNTED detachable
	// `mag` of this card's capacity in its magazine family, and a SLOTTED
	// one-slot `chamber` -- what every card written before stores meant. A card
	// that declares ANY store is taken at its word and gets nothing added here.
	void SynthesiseStores()
	{
		if (stores.Size() > 0) return;
		// A GUN THAT KEEPS NO ROUNDS (firesfrom = reserve | none): placeholders only, so the
		// facade has its two stores and nothing fills, shows or drops.
		if (KeepsNoRounds())
		{
			stores.Push(WM_Store.SynthPlaceholder(FamilyOfMags()));
			stores.Push(WM_Store.SynthPlaceholderChamber());
			return;
		}
		stores.Push(WM_Store.SynthMag(capacity, FamilyOfMags()));
		// A GUN WITH NO CHAMBER (firesfrom = magazine) gets a placeholder one: the facade needs
		// a slotted store, and a live synthesised chamber would show and never fire.
		if (FiresFromMagazine()) stores.Push(WM_Store.SynthPlaceholderChamber());
		else stores.Push(WM_Store.SynthChamber());
	}

	// ---- PARTS AND VERBS BY NAME ----------------------------------------------

	// A CARD THAT TAKES A MAGAZINE OR A ROUND FROM A HAND: a swap, a load (the main barrel's or a second barrel's), or a
	// detachable counted store -- the cards whose magFamily decides what fits (WM_Parser FinishCard 3g). Asked once the
	// card is whole, after Finish synthesised any verbs.
	bool TakesFromHand()
	{
		for (int i = 0; i < verbs.Size(); i++)
			if (verbs[i].kind == WM_Verb.SWAP || verbs[i].kind == WM_Verb.LOAD) return true;
		for (int i = 0; i < stores.Size(); i++)
			if (!stores[i].placeholder && stores[i].kind == WM_Store.COUNTED && stores[i].detach) return true;
		return false;
	}

	int FindPartIndex(String partId)
	{
		for (int i = 0; i < parts.Size(); i++)
			if (parts[i].id ~== partId) return i;
		return -1;
	}

	WM_Verb FindVerb(String verbId)
	{
		for (int i = 0; i < verbs.Size(); i++)
			if (verbs[i].id ~== verbId) return verbs[i];
		return null;
	}

	// THE VERB THAT WORKS A PART, as an index into verbs, or -1. One at most: the
	// parser refuses a card that names a part in two.
	int VerbIndexForPart(int partIndex)
	{
		if (partIndex < 0) return -1;
		for (int i = 0; i < verbs.Size(); i++)
			if (verbs[i].partIndex == partIndex) return i;
		return -1;
	}

	WM_Verb VerbForPart(int partIndex)
	{
		int i = VerbIndexForPart(partIndex);
		if (i < 0) return null;
		return verbs[i];
	}

	// A verb's index by id, or -1. For a `needs = open:<id>` gate, whose live state
	// lives on the rig in arrays indexed like verbs.
	int FindVerbIndex(String verbId)
	{
		for (int i = 0; i < verbs.Size(); i++)
			if (verbs[i].id ~== verbId) return i;
		return -1;
	}

	bool HasVerbKind(int verbKind)
	{
		for (int i = 0; i < verbs.Size(); i++)
			if (verbs[i].kind == verbKind) return true;
		return false;
	}

	// A PART A HAND CAN TAKE OR BRACE ON: the three roles the old code worked, or any
	// part a verb works. For a card whose verbs were synthesised from those roles the
	// two halves name the same parts, so the pistols' set is exactly what it was; a
	// pump's forend has no role and is workable because its cycle names it.
	bool PartIsWorkable(int partIndex)
	{
		if (partIndex < 0 || partIndex >= parts.Size()) return false;
		let p = parts[partIndex];
		if (p.role == "action" || p.role == "feed" || p.role == "support") return true;
		// A LEVER THE GRIP HOLDS (verb.zs RELEASE) is never taken by a hand: the grip on the weapon holds it.
		int workedBy = VerbIndexForPart(partIndex);
		if (workedBy >= 0) return verbs[workedBy].kind != WM_Verb.RELEASE;
		// A LATCH A VERB WAITS ON (verb.zs latch, F3): a hand throws it.
		for (int i = 0; i < verbs.Size(); i++)
			if (verbs[i].latchIndex == partIndex) return true;
		return false;
	}

	// A LATCH THAT SPRINGS HOME WHEN LET GO (verb.zs latchreturn = spring).
	bool LatchSprings(int partIndex)
	{
		for (int i = 0; i < verbs.Size(); i++)
			if (verbs[i].latchIndex == partIndex && verbs[i].latchReturnSpring) return true;
		return false;
	}

	// WHAT A LOOSE ROUND OF THIS GUN IS: the subject its first load verb states, else
	// "round". A shell and a cartridge are the same object with a different grip.
	String RoundSubject()
	{
		// A loader is not a round's shape: what comes out of a revolver is a round.
		for (int i = 0; i < verbs.Size(); i++)
			if (verbs[i].kind == WM_Verb.LOAD && verbs[i].subject != "" && verbs[i].subject != "loader") return verbs[i].subject;
		return "round";
	}

	// THE POUCH HANDS ONE ROUND to a gun that is loaded a round at a time -- load verbs
	// and no swap, and no loader. A gun with a swap keeps getting a magazine, topped up
	// off the floor.
	bool PouchGivesRounds()
	{
		return HasMainLoad() && !HasVerbKind(WM_Verb.SWAP) && !PouchGivesLoader();
	}

	// A LOAD VERB FOR THE MAIN BARREL: any load but one into a second barrel's store (WM_Barrel),
	// whose rounds the pouch hands only while that load waits (WM_System.BarrelAwaitingRound).
	bool HasMainLoad()
	{
		for (int i = 0; i < verbs.Size(); i++)
			if (verbs[i].kind == WM_Verb.LOAD && !VerbWorksOnlyABarrel(verbs[i])) return true;
		return false;
	}

	// THE POUCH HANDS A LOADER -- a speedloader of up to this card's capacity, drawn as its
	// magmodel -- to a gun with a load verb whose subject is loader and no swap.
	bool PouchGivesLoader()
	{
		if (HasVerbKind(WM_Verb.SWAP)) return false;
		for (int i = 0; i < verbs.Size(); i++)
			if (verbs[i].kind == WM_Verb.LOAD && verbs[i].subject == "loader" && !VerbWorksOnlyABarrel(verbs[i])) return true;
		return false;
	}

	// THE FIRED CASE STAYS WHERE IT WAS FIRED until something throws it out: nothing
	// cycles on the shot, and a verb here does throw cases out -- a cycle's far end, an
	// open verb's ejectall, an eject. A pump's hull waits for the forend; a revolver's
	// case waits in its chamber for the gun to open. A pistol cycles on the shot, so
	// its brass leaves with the shot, as it always did.
	bool KeepsCaseOnShot()
	{
		bool throwsOut = false;
		for (int i = 0; i < verbs.Size(); i++)
		{
			let v = verbs[i];
			if (v.kind == WM_Verb.CYCLE && v.autoOnShot) return false;
			// A verb that empties only a second barrel's store (WM_Barrel) throws out that barrel's
			// cases, not the main barrel's.
			if (VerbWorksOnlyABarrel(v)) continue;
			if ((v.kind == WM_Verb.CYCLE && v.onOutEject) || (v.kind == WM_Verb.OPEN && v.onOpenEjectAll) || v.kind == WM_Verb.EJECT)
				throwsOut = true;
		}
		return throwsOut;
	}

	// ---- THE STORES THE GUN'S AMMO WILL RUN OVER --------------------------------
	//
	// WM_Ammo picks its magazine and its chamber by name, then by kind, and
	// synthesises either one the card lacks (ammo.zs Build). Verbs are checked
	// against the same choice, so a verb can never name a store the gun will not
	// have -- nor one it will have that the trigger never looks at.
	String FacadeStoreId(int storeKind)
	{
		String wanted = (storeKind == WM_Store.COUNTED) ? "mag" : "chamber";
		// NEVER A SECOND BARREL'S STORE (WM_Barrel) -- the same rule as WM_Ammo.FindOwn, so a
		// verb is checked against the stores the gun will really run its main barrel over.
		for (int i = 0; i < stores.Size(); i++)
			if (stores[i].kind == storeKind && stores[i].id ~== wanted && !IsBarrelStore(stores[i].id)) return stores[i].id;
		for (int i = 0; i < stores.Size(); i++)
			if (stores[i].kind == storeKind && !IsBarrelStore(stores[i].id)) return stores[i].id;
		return wanted;
	}

	// The kind of the store a gun of this card will have under that name --
	// declared, or synthesised by WM_Ammo for want of one of that kind.
	// WM_Store.UNSTATED when it will have none.
	int StoreKindFor(String storeId)
	{
		let s = FindStore(storeId);
		if (s) return s.kind;
		if (storeId ~== FacadeStoreId(WM_Store.COUNTED)) return WM_Store.COUNTED;
		if (storeId ~== FacadeStoreId(WM_Store.SLOTTED)) return WM_Store.SLOTTED;
		return WM_Store.UNSTATED;
	}

	// ---- THE SYNTHESIS RULE ----------------------------------------------------
	//
	// A card with no verbs and no mechanism means what every card written before
	// verbs meant: a CYCLE on its `role = action` part and a SWAP on its
	// `role = feed` part, each with the old role code's own numbers (verb.zs
	// SynthCycle / SynthSwap). The FIRST of each role, because FindRoleIndex --
	// what the old code looked the action and the magazine up by -- returns the
	// first.
	void SynthesiseVerbs()
	{
		if (verbs.Size() > 0 || mechanism != "") return;
		int ai = FindRoleIndex("action");
		if (ai >= 0)
			verbs.Push(WM_Verb.SynthCycle(parts[ai].id, ai,
				FacadeStoreId(WM_Store.COUNTED), FacadeStoreId(WM_Store.SLOTTED)));
		int fi = FindRoleIndex("feed");
		if (fi >= 0)
			verbs.Push(WM_Verb.SynthSwap(parts[fi], fi, FacadeStoreId(WM_Store.COUNTED)));
	}

	// For the load log: where its verbs came from, and what they are.
	String VerbsSummary()
	{
		if (verbs.Size() == 0) return (mechanism != "") ? ("mechanism " .. mechanism .. ", no verbs") : "no verbs";
		String list = "";
		for (int i = 0; i < verbs.Size(); i++)
		{
			let v = verbs[i];
			list = list .. (i > 0 ? ", " : "") .. WM_Verb.KindName(v.kind) .. " " .. v.id;
			if (v.partId != "") list = list .. " on " .. v.partId;
		}
		String from = "declared";
		if (mechanism != "") from = "mechanism " .. mechanism;
		else if (verbs[0].origin == WM_Verb.FROM_SYNTH) from = "synthesised";
		return from .. ": " .. list;
	}
}

// Every card read from every WMCARD lump in the load order. A wrapper rather
// than an out-array so the parser can hand back several without relying on
// array-reference parameters.
class WM_CardSet
{
	Array<WM_Card>      cards;
	// Every archetype from every lump. An archetype may come after the cards that
	// follow it, which is why cards are finished only once all lumps are read.
	Array<WM_Archetype> archetypes;
	// WM_Parser.Finish has run over this set. A set restored from a save written
	// before verbs existed has not, and is read again (WM_System.LoadCards).
	bool                finished;
	// Finish derived every card's gun type (WM_Card.gunType). A set restored from a save
	// written before gun types has not, and is read again the same way.
	bool                typed;
	// Finish read the throwable grammar (throw.zs). A set restored from a save written before it has no
	// throw, route, fuse or mount on its cards, and is read again the same way.
	bool                throwablesRead;
	// Every weapon sheet from every WMSHEET lump (sheet.zs), one a gun, found by its weapon class.
	Array<WM_Sheet>     sheets;
	// WM_System.LoadCards read the WMSHEET lumps and laid them over the cards. A set restored from a save written
	// before weapon sheets has not, and is read again the same way.
	bool                sheetsRead;
	// LoadCards recorded each card's lump and gave every gun that names a model its own copy (sheet.zs BorrowModels).
	// A set restored from a save written before that has not, and is read again the same way.
	bool                modelsRead;
	// LoadCards built every card with a base whole (WM_Parser.ResolveBases). A set restored from a save written before
	// inheritance has not, and is read again the same way.
	bool                basesRead;

	WM_Archetype FindArchetype(String archId)
	{
		for (int i = 0; i < archetypes.Size(); i++)
			if (archetypes[i].id ~== archId) return archetypes[i];
		return null;
	}

	WM_Sheet SheetFor(String weaponClass)
	{
		for (int i = 0; i < sheets.Size(); i++)
			if (sheets[i].weaponClass ~== weaponClass) return sheets[i];
		return null;
	}
}
