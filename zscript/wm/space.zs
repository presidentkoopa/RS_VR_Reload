// ============================================================================
// TWO SPACES, AND THE ONE PLACE THEY MEET.
//
// A CARD IS WRITTEN IN MD3 AXES: x along the barrel, y across it, z up. That
// is what md3.py measures, what a mesh viewer shows, and what anyone writing a
// card will read off the art.
//
// THE RENDERER DOES NOT USE THOSE AXES. models_md3.cpp:328 loads every vertex
// as Set(vert->x, vert->z, vert->y) -- y and z swapped, because the GL side is
// y-up. Every surface offset, every drive axis, every rotation and every
// ModelPointToWorld input is in THAT space.
//
// This was a real bug before it was a comment. Offsets went through in MD3
// order, so the slide -- whose axis is pure -X -- moved correctly by luck, and
// the magazine, whose axis is mostly -Z, travelled SIDEWAYS out of the gun.
// Nothing errored. It simply moved the wrong way, which is the worst way for a
// part to fail.
//
// So the conversion happens here and nowhere else. Cards stay in the axes a
// human reads; the engine gets the axes it uses; nothing in between has to
// remember which is which.
// ============================================================================

class WM_Space
{
	// MD3 (x, y, z) -> the renderer's model space (x, z, y).
	static Vector3 Eng(Vector3 v)
	{
		return (v.x, v.z, v.y);
	}
	// Turn v about unit axis a by deg degrees, right-handed, in MD3 space.
	// Rodrigues, written out rather than routed through a quaternion so the
	// pivot arithmetic below stays in one space from end to end.
	static Vector3 Rotate(Vector3 v, Vector3 a, double deg)
	{
		double c = cos(deg), s = sin(deg);
		return v * c + (a cross v) * s + a * ((a dot v) * (1.0 - c));
	}

	// THE SAME TURN, AS THE ENGINE NEEDS IT.
	//
	// Swapping two axes is a REFLECTION, not a rotation, and a reflection turns
	// a clockwise turn into an anticlockwise one. So the axis is swizzled like
	// every other vector AND the angle changes sign. Forget the sign and every
	// hinge on every gun swings the wrong way -- a hammer that cocks into the
	// grip instead of away from it.
	static Quat EngRot(Vector3 a, double deg)
	{
		if (deg == 0 || a.Length() < 1e-6) return Quat(0, 0, 0, 1);
		return Quat.AxisAngle(Eng(a.Unit()), -deg);
	}
}
