// ============================================================================
// COSMETIC JITTER THAT NEVER TOUCHES THE PLAYSIM RNG.
//
// A bare frandom() draws from the shared playsim RNG. The rig and everything it
// spawns -- brass, a casing's tumble -- run for the CONSOLE player only, so a
// draw there advances that RNG on one machine and not the others, and a netgame
// desyncs on the next thing anywhere that rolls a number. A named RNG is no
// better: it is still playsim state, saved and compared.
//
// So a look that only needs to vary is a HASH of numbers the caller already has
// -- the tic, a per-thing counter, a position -- and is the same on any machine
// that computes it, and changes nothing on the ones that do not.
//
// NOT FOR ANYTHING THAT DECIDES AN OUTCOME. Damage, spread and hits stay on the
// named RNGs in the fire path, which runs on every machine.
// ============================================================================

class WM_Jitter
{
	// 0..1 from three integers. Spatial-hash primes, then an xorshift to spread
	// the bits; the low 16 bits are the answer.
	static double Frac(int a, int b, int c)
	{
		int h = a * 73856093;
		h ^= b * 19349663;
		h ^= c * 83492791;
		h ^= h << 13;
		h ^= h >>> 17;
		h ^= h << 5;
		return double(h & 0xFFFF) / 65535.0;
	}

	// lo..hi, the same range a frandom(lo, hi) at the call site covered.
	static double Between(double lo, double hi, int a, int b, int c)
	{
		return lo + (hi - lo) * Frac(a, b, c);
	}
}
