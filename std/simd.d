module std.simd;

///////////////////////////////////////////////////////////////////////////////
// Version mess
///////////////////////////////////////////////////////////////////////////////

version(X86)
{
	version = X86_OR_X64;
}
else version(X86_64)
{
	version = X86_OR_X64;
}

version(PPC)
{
	version = PowerPC;
}
else version(PPC64)
{
	version = PowerPC;
}


///////////////////////////////////////////////////////////////////////////////
// Platform specific imports
///////////////////////////////////////////////////////////////////////////////

version(DigitalMars)
{
	// DMD intrinsics
}
else version(GNU)
{
	// GDC intrinsics
	import gcc.builtins;
}

import core.simd;
import std.traits;


///////////////////////////////////////////////////////////////////////////////
// Define available versions of vector hardware
///////////////////////////////////////////////////////////////////////////////

version(X86_OR_X64)
{
	enum SIMDVer
	{
		SSE,
		SSE2,
		SSE3,
		SSSE3,
		SSE4,	// Intel only :(
		SSE41,
		SSE42,
		SSE5,	// AMD's competition to SSE4
		AVX,	// 128x2/256bit, 3 operand opcodes
		AVX2
	}

	// we source this from the compiler flags, ie. -msse2 for instance
	immutable SIMDVer sseVer = SIMDVer.SSE2;
}
else version(PowerPC)
{
	enum SIMDVer
	{
		VMX,
		VMX128 // extended register file (128 regs), and some awesome bonus opcodes
	}

	immutable SIMDVer sseVer = SIMDVer.VMX;
}
else version(ARM)
{
	enum SIMDVer
	{
		NEON
	}

	immutable SIMDVer sseVer = SIMDVer.NEON;
}
else
{
	static assert(0, "Unsupported architecture.");

	// TODO: I think it would be worth emulating this API with pure FPU on unsupported architectures...
}


///////////////////////////////////////////////////////////////////////////////
// Internal constants
///////////////////////////////////////////////////////////////////////////////

private
{
	enum ulong2 signMask2 = 0x8000_0000_0000_0000;
	enum uint4 signMask4 = 0x8000_0000;
	enum ushort8 signMask8 = 0x8000;
	enum ubyte16 signMask16 = 0x80;
}

///////////////////////////////////////////////////////////////////////////////
// Internal functions
///////////////////////////////////////////////////////////////////////////////

private
{
	/**** <WORK AROUNDS> ****/
	template isVector(T) // TODO: REMOVE BRUTAL WORKAROUND
	{
		static if(is(T == double2) || is(T == float4) ||
				  is(T == long2) || is(T == ulong2) ||
				  is(T == int4) || is(T == uint4) ||
				  is(T == short8) || is(T == ushort8) ||
				  is(T == byte16) || is(T == ubyte16))
			enum bool isVector = true;
		else
			enum bool isVector = false;
	}
	template VectorType(T)
	{
		static if(is(T == double2))
			alias double VectorType;
		else static if(is(T == float4))
			alias float VectorType;
		else static if(is(T == long2))
			alias long VectorType;
		else static if(is(T == ulong2))
			alias ulong VectorType;
		else static if(is(T == int4))
			alias int VectorType;
		else static if(is(T == uint4))
			alias uint VectorType;
		else static if(is(T == short8))
			alias short VectorType;
		else static if(is(T == ushort8))
			alias ushort VectorType;
		else static if(is(T == byte16))
			alias byte VectorType;
		else static if(is(T == ubyte16))
			alias ubyte VectorType;
		else
			static assert(0, "Incorrect type");
	}
	template NumElements(T)
	{
		static if(is(T == double2) || is(T == long2) || is(T == ulong2))
			enum size_t NumElements = 2;
		else static if(is(T == float4) || is(T == int4) || is(T == uint4))
			enum size_t NumElements = 4;
		else static if(is(T == short8) || is(T == ushort8))
			enum size_t NumElements = 8;
		else static if(is(T == byte16) || is(T == ubyte16))
			enum size_t NumElements = 16;
		else
			static assert(0, "Incorrect type");
	}
	/**** </WORK AROUNDS> ****/


	// a template to test if a type is a vector type
	//	template isVector(T : __vector(U[N]), U, size_t N) { enum bool isVector = true; }
	//	template isVector(T) { enum bool isVector = false; }

	// pull the base type from a vector, array, or primitive type
	template ArrayType(T : T[]) { alias T ArrayType; }
	//	template VectorType(T : Vector!T) { alias T VectorType; }
	template BaseType(T)
	{
		static if(isVector!T)
			alias VectorType!T BaseType;
		else static if(isArray!T)
			alias ArrayType!T BaseType;
		else static if(isScalar!T)
			alias T BaseType;
		else
			static assert(0, "Unsupported type");
	}

	template isScalarFloat(T)
	{
		enum bool isScalarFloat = is(T == float) || is(T == double);
	}

	template isScalarInt(T)
	{
		enum bool isScalarInt = is(T == long) || is(T == ulong) || is(T == int) || is(T == uint) || is(T == short) || is(T == ushort) || is(T == byte) || is(T == ubyte);
	}

	template isScalarUnsigned(T)
	{
		enum bool isScalarUnsigned = is(T == ulong) || is(T == uint) || is(T == ushort) || is(T == ubyte);
	}

	template isScalar(T)
	{
		enum bool isScalar = isScalarFloat!T || isScalarInt!T;
	}

	template isFloatArray(T)
	{
		enum bool isFloatArray = isArray!T && isScalarFloat!(BaseType!T);
	}

	template isIntArray(T)
	{
		enum bool isIntArray = isArray!T && isScalarInt!(BaseType!T);
	}

	template isFloatVector(T)
	{
		enum bool isFloatVector = isVector!T && isScalarFloat(BaseType!T);
	}

	template isIntVector(T)
	{
		enum bool isIntVector = isVector!T && isScalarInt(BaseType!T);
	}

	template isUnsigned(T)
	{
		enum bool isUnsigned = isScalarUnsigned!(BaseType!T);
	}

	template is64bitElement(T)
	{
		enum bool is64bitElement = (BaseType!(T).sizeof == 8);
	}

	template is32bitElement(T)
	{
		enum bool is32bitElement = (BaseType!(T).sizeof == 4);
	}

	template is16bitElement(T)
	{
		enum bool is16bitElement = (BaseType!(T).sizeof == 2);
	}

	template is8bitElement(T)
	{
		enum bool is8bitElement = (BaseType!(T).sizeof == 1);
	}
}


///////////////////////////////////////////////////////////////////////////////
// Public API
///////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////
// Load and store

// load scalar into all components (!! or just X?)
Vector!T loadScalar(SIMDVer Ver = sseVer, T)(T s)
{
	return null;
}

// load scaler from memory
Vector!T loadScalar(SIMDVer Ver = sseVer, T)(T* pS)
{
	return null;
}

// load vector from an unaligned address
Vector!T loadUnaligned(SIMDVer Ver = sseVer, T)(T* pV)
{
	return null;
}

// load a 3d vector from an unaligned address
Vector!T loadUnaligned3(SIMDVer Ver = sseVer, T)(T* pV)
{
	return null;
}

// return the X element in a scalar register
T getScalar(SIMDVer Ver = sseVer, T)(Vector!T v)
{
	return null;
}

// store the X element to the address provided
void storeScalar(SIMDVer Ver = sseVer, T)(Vector!T v, T* pS)
{
	return null;
}

// store the vector to an unaligned address
void storeUnaligned(SIMDVer Ver = sseVer, T)(Vector!T v, T* pV)
{
	return null;
}

// store a 3d vector to an unaligned address
void storeUnaligned3(SIMDVer Ver = sseVer, T)(Vector!T v, T* pV)
{
	return null;
}


///////////////////////////////////////////////////////////////////////////////
// Shuffle, swizzle, permutation

// broadcast X to all elements
T getX(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is64bitElement!(T))
			return swizzle!("XX", Ver)(v);
		else static if(is32bitElement!(T))
			return swizzle!("XXXX", Ver)(v);
		else static if(is16bitElement!(T))
		{
			// TODO: we should use permute to perform this operation when immediates work >_<
			static if(false)// Ver >= SIMDVer.SSSE3)
			{
				immutable ubyte16 permuteControl = [1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0];
				return __builtin_ia32_pshufb128(v, permuteControl);
			}
			else
			{
				T t = __builtin_ia32_pshufd(v, 0x00);
				t = __builtin_ia32_pshuflw(t, 0x00);
				return __builtin_ia32_pshufhw(t, 0x00);
			}
		}
		else static if(is8bitElement!(T))
		{
			static if(Ver >= SIMDVer.SSSE3)
			{
				immutable ubyte16 permuteControl = __builtin_ia32_xorps(v, v); // generate a zero register
				return __builtin_ia32_pshufb128(v, permuteControl);
			}
			else
				static assert(0, "Only supported in SSSE3 and above");
		}
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// broadcast Y to all elements
T getY(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is64bitElement!(T))
			return swizzle!("YY", Ver)(v);
		else static if(is32bitElement!(T))
			return swizzle!("YYYY", Ver)(v);
		else static if(is16bitElement!(T))
		{
			// TODO: we should use permute to perform this operation when immediates work >_<
			static if(false)// Ver >= SIMDVer.SSSE3)
			{
				immutable ubyte16 permuteControl = [3,2,3,2,3,2,3,2,3,2,3,2,3,2,3,2];
				return __builtin_ia32_pshufb128(v, permuteControl);
			}
			else
			{
				T t = __builtin_ia32_pshufd(v, 0x00);
				t = __builtin_ia32_pshuflw(t, 0x55);
				return __builtin_ia32_pshufhw(t, 0x55);
			}
		}
		else static if(is8bitElement!(T))
		{
			static if(Ver >= SIMDVer.SSSE3)
			{
				immutable ubyte16 permuteControl = __builtin_ia32_xorps(v, v); // generate a ones register
				return __builtin_ia32_pshufb128(v, permuteControl);
			}
			else
				static assert(0, "Only supported in SSSE3 and above");
		}
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// broadcast Z to all elements
T getZ(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is32bitElement!(T))
			return swizzle!("ZZZZ", Ver)(v);
		else static if(is16bitElement!(T))
		{
			// TODO: we should use permute to perform this operation when immediates work >_<
			static if(false)// Ver >= SIMDVer.SSSE3)
			{
				immutable ubyte16 permuteControl = [5,4,5,4,5,4,5,4,5,4,5,4,5,4,5,4];
				return __builtin_ia32_pshufb128(v, permuteControl);
			}
			else
			{
				T t = __builtin_ia32_pshufd(v, 0x55);
				t = __builtin_ia32_pshuflw(t, 0x00);
				return __builtin_ia32_pshufhw(t, 0x00);
			}
		}
		else static if(is8bitElement!(T))
		{
			static if(Ver >= SIMDVer.SSSE3)
			{
				immutable ubyte16 permuteControl = __builtin_ia32_xorps(v, v); // generate a twos register
				return __builtin_ia32_pshufb128(v, permuteControl);
			}
			else
				static assert(0, "Only supported in SSSE3 and above");
		}
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// broadcast W to all elements
T getW(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is32bitElement!(T))
			return swizzle!("WWWW", Ver)(v);
		else static if(is16bitElement!(T))
		{
			// TODO: we should use permute to perform this operation when immediates work >_<
			static if(false)// Ver >= SIMDVer.SSSE3)
			{
				immutable ubyte16 permuteControl = [7,6,7,6,7,6,7,6,7,6,7,6,7,6,7,6];
				return __builtin_ia32_pshufb128(v, permuteControl);
			}
			else
			{
				T t = __builtin_ia32_pshufd(v, 0x55);
				t = __builtin_ia32_pshuflw(t, 0x55);
				return __builtin_ia32_pshufhw(t, 0x55);
			}
		}
		else static if(is8bitElement!(T))
		{
			static if(Ver >= SIMDVer.SSSE3)
			{
				immutable ubyte16 permuteControl = __builtin_ia32_xorps(v, v); // generate a threes register
				return __builtin_ia32_pshufb128(v, permuteControl);
			}
			else
				static assert(0, "Only supported in SSSE3 and above");
		}
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// set the X element
T setX(SIMDVer Ver = sseVer, T)(T v, T x)
{
	return v;
}

// set the Y element
T setY(SIMDVer Ver = sseVer, T)(T v, T y)
{
	return v;
}

// set the Z element
T setZ(SIMDVer Ver = sseVer, T)(T v, T z)
{
	return v;
}

// set the W element
T setW(SIMDVer Ver = sseVer, T)(T v, T w)
{
	return v;
}

// swizzle a vector: r = swizzle!"ZZWX"(v); // r = v.zzwx
T swizzle(string swiz, SIMDVer Ver = sseVer, T)(T v)
{
	// parse the string into elements
	int[N] parseElements(string swiz, size_t N)(string[] elements)
	{
		import std.string;
		auto swizzleKey = toLower(swiz);

		int[N] r;
		foreach(i; 0..N)
			r[i] = i;

		foreach(i; 0..swizzleKey.length)
		{
			foreach(s; elements)
			{
				foreach(j, c; s)
				{
					if(swizzleKey[i] == c)
					{
						r[i] = j;
						break;
					}
				}
			}
		}
		return r;
	}

	bool isIdentity(size_t N)(int[N] elements)
	{
		foreach(i, e; elements)
		{
			if(e != i)
				return false;
		}
		return true;
	}

	int sseShufMask(size_t N)(int[N] elements)
	{
		static if(N == 2)
			return ((elements[0] & 1) << 0) | ((elements[1] & 1) << 1);
		else static if(N == 4)
			return ((elements[0] & 3) << 0) | ((elements[1] & 3) << 2) | ((elements[2] & 3) << 4) | ((elements[3] & 3) << 6);
	}

	enum size_t Elements = NumElements!T;

	static assert(swiz.length > 0 && swiz.length <= Elements, "Invalid number of components in swizzle string");

	// TODO: incomplete swizzle strings should follow some rules...

	static if(Elements == 2)
		enum elementNames = ["xy", "ab", "01"];
	else static if(Elements == 4)
		enum elementNames = ["xyzw", "rgba", "0123"];
	else static if(Elements == 8)
		enum elementNames = ["01234567"];
	else static if(Elements == 16)
		enum elementNames = ["0123456789ABCDEF"];

	// parse the swizzle string
	enum int[Elements] elements = parseElements!(swiz, Elements)(elementNames);

	// early out if no actual swizzle
	static if(isIdentity!Elements(elements))
	{
		return v;
	}
	else
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
			{
				static if(elements[0] == elements[1]) // swizzle: XX or YY
				{
					// unpacks are more efficient than shuffd
					static if(elements[0] == 0)
						return __builtin_ia32_unpcklpd(v, v); // swizzle: XX
					else
						return __builtin_ia32_unpckhpd(v, v); // swizzle: YY
				}
				else
					return __builtin_ia32_shufpd(v, v, sseShufMask!Elements(elements)); // swizzle: YX
			}
			else static if(is64bitElement!(T)) // (u)long2
			{
				static if(elements[0] == elements[1]) // swizzle: XX or YY
				{
					// unpacks are more efficient than shuffd
					static if(elements[0] == 0)
						return __builtin_ia32_punpcklqdq128(v, v); // swizzle: XX
					else
						return __builtin_ia32_punpckhqdq128(v, v); // swizzle: YY
				}
				else
				{
					// use a 32bit integer shuffle for swizzle: YZ
					return __builtin_ia32_pshufd(v, sseShufMask!4([elements[0]*2, elements[0]*2 + 1, elements[1]*2, elements[1]*2 + 1]));
				}
			}
			else static if(is(T == float4)) // TODO: use unpack to improve ZZWW, and YYXX
				return __builtin_ia32_shufps(v, v, sseShufMask!Elements(elements));
			else static if(is32bitElement!(T))
				return __builtin_ia32_pshufd(v, sseShufMask!Elements(elements));
			else
			{
				// TODO: 16 and 8bit swizzles...
				static assert(0, "Unsupported vector type: " ~ T.stringof);
			}
		}
		else
		{
			static assert(0, "Unsupported on this architecture");
		}
	}
}

// assign bytes to the target according to a permute control register
T permute(SIMDVer Ver = sseVer, T)(T v, ubyte16 control)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(Ver >= SIMDVer.SSSE3)
			return cast(T)__builtin_ia32_pshufb128(cast(ubyte16)v, control);
		else
			static assert(0, "Only supported in SSSE3 and above");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

//... there are more useful permutation ops


///////////////////////////////////////////////////////////////////////////////
// Pack/unpack

// these are PERFECT examples of functions that would benefit from multiple return values!
/* eg.
short8,short8 unpackBytes(byte16)
{
short8 low,high;
low = bytes[0..4];
high = bytes[4..8];
return low,high;
}
*/

// byte -> short
// short -> int
// int -> long
// long -> int
// int -> short
// short -> byte

// float -> double
// double -> float


///////////////////////////////////////////////////////////////////////////////
// Type conversion

int4 toInt(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == float4))
			return __builtin_ia32_cvtps2dq(v);
		else static if(is(T == double2))
			return __builtin_ia32_cvtpd2dq(v); // TODO: z,w are undefined... should we repeat xy to zw?
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

float4 toFloat(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == int4))
			return __builtin_ia32_cvtdq2ps(v);
		else static if(is(T == double2))
			return __builtin_ia32_cvtpd2ps(v); // TODO: z,w are undefined... should we repeat xy to zw?
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

double2 toDouble(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == int4))
			return __builtin_ia32_cvtdq2pd(v);
		else static if(is(T == float4))
			return __builtin_ia32_cvtps2pd(v);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

///////////////////////////////////////////////////////////////////////////////
// Basic mathematical operations

// unary absolute
T abs(SIMDVer Ver = sseVer, T)(T v)
{
	static assert(!isUnsigned!(T), "Can not take absolute of unsigned value");

	/*
	// integer abs with no branches
	int v;           // we want to find the absolute value of v
	unsigned int r;  // the result goes here 
	int const mask = v >> sizeof(int) * CHAR_BIT - 1;

	r = (v + mask) ^ mask;
	*/

	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_andnpd(cast(double2)signMask2, v);
		else static if(is(T == float4))
			return __builtin_ia32_andnps(cast(float4)signMask4, v);
		else
		{
			static if(Ver < SIMDVer.SSSE3)
			{
				// do something...
				static assert(0, "Only supported in SSSE3 and above");
			}
			else
			{
				// SSSE3 added opcodes for these operations
				static if(is64bitElement!(T))
					static assert(0, "Unsupported: abs(" ~ T.stringof ~ "). Should we emulate?");
				else static if(is32bitElement!(T))
					return __builtin_ia32_pabsd128(v);
				else static if(is16bitElement!(T))
					return __builtin_ia32_pabsw128(v);
				else static if(is8bitElement!(T))
					return __builtin_ia32_pabsb128(v);
			}
		}
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// unary negate
T neg(SIMDVer Ver = sseVer, T)(T v)
{
	static assert(!isUnsigned!(T), "Can not negate unsigned value");

	version(DigitalMars)
	{
		return -v;
	}
	else version(GNU)
	{
		return -v;
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// binary add
T add(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(DigitalMars)
	{
		return v1 + v2;
	}
	else version(GNU)
	{
		return v1 + v2;
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// binary subtract
T sub(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(DigitalMars)
	{
		return v1 - v2;
	}
	else version(GNU)
	{
		return v1 - v2;
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// binary multiply
T mul(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(DigitalMars)
	{
		return v1 * v2;
	}
	else version(GNU)
	{
		return v1 * v2;
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// ternary multiply and add
T madd(SIMDVer Ver = sseVer, T)(T v1, T v2, T v3)
{
	version(DigitalMars)
	{
		return v1*v2 + v3;
	}
	else version(GNU)
	{
		return v1*v2 + v3;
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// min
T min(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_minpd(v1, v2);
		else static if(is(T == float4))
			return __builtin_ia32_minps(v1, v2);
		else static if(is(T == int4))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_pminsd128(v1, v2);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == uint4))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_pminud128(v1, v2);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == short8))
			return __builtin_ia32_pminsw128(v1, v2); // available in SSE2
		else static if(is(T == ushort8))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_pminuw128(v1, v2);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == byte16))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_pminsb128(v1, v2);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == ubyte16))
			return __builtin_ia32_pminub128(v1, v2); // available in SSE2
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// max
T max(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_maxpd(v1, v2);
		else static if(is(T == float4))
			return __builtin_ia32_maxps(v1, v2);
		else static if(is(T == int4))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_pmaxsd128(v1, v2);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == uint4))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_pmaxud128(v1, v2);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == short8))
			return __builtin_ia32_pmaxsw128(v1, v2); // available in SSE2
		else static if(is(T == ushort8))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_pmaxuw128(v1, v2);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == byte16))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_pmaxsb128(v1, v2);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == ubyte16))
			return __builtin_ia32_pmaxub128(v1, v2); // available in SSE2
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// lerp
T lerp(SIMDVer Ver = sseVer, T)(T a, T b, T t)
{
	return madd!Ver(b-a, t, a);
}


///////////////////////////////////////////////////////////////////////////////
// Floating point operations

// round to the next lower integer value
T floor(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_roundpd(v, 1);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == float4))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_roundps(v, 1);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// round to the next higher integer value
T ceil(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_roundpd(v, 2);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == float4))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_roundps(v, 2);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// round to the nearest integer value
T round(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_roundpd(v, 0);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == float4))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_roundps(v, 0);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// round towards zero
T roundZero(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_roundpd(v, 3);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == float4))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_roundps(v, 3);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

///////////////////////////////////////////////////////////////////////////////
// Precise mathematical operations

// divide
T div(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	return v1 / v2;
}

// reciprocal
T rcp(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return div!Ver([1,1,1,1], v);
		else static if(is(T == float4))
			return __builtin_ia32_rcpps(v);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// square root
T sqrt(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_sqrtpd(v);
		else static if(is(T == float4))
			return __builtin_ia32_sqrtps(v);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// reciprocal square root
T rsqrt(SIMDVer Ver = sseVer, T)(T v)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return rcp!Ver(sqrt!Ver(v));
		else static if(is(T == float4))
			return __builtin_ia32_rsqrtps(v);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}


///////////////////////////////////////////////////////////////////////////////
// Fast estimates

// divide estimate
T divEst(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	return div!Ver(v1, v2);
}

// reciprocal estimate
T rcpEst(SIMDVer Ver = sseVer, T)(T v)
{
	return rcp!Ver(v);
}

// square root estimate
T sqrtEst(SIMDVer Ver = sseVer, T)(T v)
{
	return sqrt!Ver(v);
}

// reciprocal square root estimate
T rsqrtEst(SIMDVer Ver = sseVer, T)(T v)
{
	return rsqrt!Ver(v);
}


///////////////////////////////////////////////////////////////////////////////
// Vector maths operations

// 2d dot product
T dot2(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
		{
			float4 t = v1 * v2;
			t = __builtin_ia32_haddpd(t, t);
			return getX!Ver(t);
		}
		else static if(is(T == float4))
		{
			float4 t = v1 * v2;
			t = __builtin_ia32_haddps(t, t);
			return getX!Ver(t);
		}
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// 3d dot product
T dot3(SIMDVer Ver = sseVer, T)(T v1, T v2)
{

	return null;
}

// 4d dot product
T dot4(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == float4))
		{
			float4 t = v1 * v2;
			t = __builtin_ia32_haddps(t, t); // x+y, z+w
			t = __builtin_ia32_haddps(t, t); // xy + zw
			return getX!Ver(t);
		}
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// homogeneous dot product: v1.xyzw dot v2.xyz1
T dotH(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	return null;
}

// 3d cross product
T cross3(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	T left = mul!Ver(swizzle!("YZXW", Ver)(v1), swizzle!("ZXYW", Ver)(v2));
	T right = mul!Ver(swizzle!("ZXYW", Ver)(v1), swizzle!("YZXW", Ver)(v2));
	return sub!Ver(left, right);
}

// 3d magnitude
T magnitude3(SIMDVer Ver = sseVer, T)(T v)
{
	return sqrt!Ver(magSq3!Ver(v));
}

// 4d magnitude
T magnitude4(SIMDVer Ver = sseVer, T)(T v)
{
	return sqrt!Ver(magSq4!Ver(v));
}

// 3d magnitude squared
T magSq3(SIMDVer Ver = sseVer, T)(T v)
{
	return dot3!Ver(v, v);
}

// 4d magnitude squared
T magSq4(SIMDVer Ver = sseVer, T)(T v)
{
	return dot4!Ver(v, v);
}

// 3d magnitude estimate
T magEst3(SIMDVer Ver = sseVer, T)(T v)
{
	return sqrtEst!Ver(magSq3!Ver(v));
}

// 4d magnitude estimate
T magEst4(SIMDVer Ver = sseVer, T)(T v)
{
	return sqrtEst!Ver(magSq4!Ver(v));
}

///////////////////////////////////////////////////////////////////////////////
// Bitwise operations

// unary compliment: ~v
T comp(SIMDVer Ver = sseVer, T)(T v)
{
	return ~v;
}

// bitwise or: v1 | v2
T or(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_orpd(v1, v2);
		else static if(is(T == float4))
			return __builtin_ia32_orps(v1, v2);
		else
			return __builtin_ia32_por128(v1, v2);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// bitwise and: v1 & v2
T and(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_andpd(v1, v2);
		else static if(is(T == float4))
			return __builtin_ia32_andps(v1, v2);
		else
			return __builtin_ia32_pand128(v1, v2);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// bitwise and not: ~v1 & v2
T andNot(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_andnpd(v1, v2);
		else static if(is(T == float4))
			return __builtin_ia32_andnps(v1, v2);
		else
			return __builtin_ia32_pandn128(v1, v2);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// bitwise xor: v1 ^ v2
T xor(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_xorpd(v1, v2);
		else static if(is(T == float4))
			return __builtin_ia32_xorps(v1, v2);
		else
			return __builtin_ia32_pxor128(v1, v2);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// bitwise nand: ~(v1 & v2)
T nand(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	return ~and!Ver(v1, v2);
}


///////////////////////////////////////////////////////////////////////////////
// Bit shifts and rotates

// binary shift left
T shiftLeft(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == long2) || is(T == ulong2))
			return __builtin_ia32_psllq128(v1, v2);
		else static if(is(T == int4) || is(T == uint4))
			return __builtin_ia32_psrld128(v1, v2);
		else static if(is(T == short8) || is(T == ushort8))
			return __builtin_ia32_psrlw128(v1, v2);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// binary shift left by immediate
T shiftLeftImmediate(size_t bits, SIMDVer Ver = sseVer, T)(T v)
{
	static if(bits == 0) // shift by 0 is a no-op
	{
		return v;
	}
	else
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == long2) || is(T == ulong2))
				return __builtin_ia32_psllqi128(v, bits);
			else static if(is(T == int4) || is(T == uint4))
				return __builtin_ia32_psrldi128(v, bits);
			else static if(is(T == short8) || is(T == ushort8))
				return __builtin_ia32_psrlwi128(v, bits);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
		else
		{
			static assert(0, "Unsupported on this architecture");
		}
	}
}

// binary shift right (signed types perform arithmatic shift right)
T shiftRight(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == ulong2))
			return __builtin_ia32_psrlq128(v1, v2);
		else static if(is(T == int4))
			return __builtin_ia32_psrad128(v1, v2);
		else static if(is(T == uint4))
			return __builtin_ia32_psrld128(v1, v2);
		else static if(is(T == short8))
			return __builtin_ia32_psraw128(v1, v2);
		else static if(is(T == ushort8))
			return __builtin_ia32_psrlw128(v1, v2);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// binary shift right by immediate (signed types perform arithmatic shift right)
T shiftRightImmediate(size_t bits, SIMDVer Ver = sseVer, T)(T v)
{
	static if(bits == 0) // shift by 0 is a no-op
	{
		return v;
	}
	else
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == ulong2))
				return __builtin_ia32_psrlqi128(v, bits);
			else static if(is(T == int4))
				return __builtin_ia32_psradi128(v, bits);
			else static if(is(T == uint4))
				return __builtin_ia32_psrldi128(v, bits);
			else static if(is(T == short8))
				return __builtin_ia32_psrawi128(v, bits);
			else static if(is(T == ushort8))
				return __builtin_ia32_psrlwi128(v, bits);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
		else
		{
			static assert(0, "Unsupported on this architecture");
		}
	}
}

// shift bytes left by immediate ('left' as they appear in memory)
T shiftBytesLeftImmediate(size_t bytes, SIMDVer Ver = sseVer, T)(T v)
{
	static assert(bytes >= 0 && bytes < 16, "Invalid shift amount");
	static if(bytes == 0) // shift by 0 is a no-op
	{
		return v;
	}
	else
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			// little endian reads the bytes into the register in reverse, so we need to flip the operations
			return __builtin_ia32_psrldqi128(v, bytes);
		}
		else
		{
			static assert(0, "Unsupported on this architecture");
		}
	}
}

// shift bytes right by immediate ('right' as they appear in memory)
T shiftBytesRightImmediate(size_t bytes, SIMDVer Ver = sseVer, T)(T v)
{
	static assert(bytes >= 0 && bytes < 16, "Invalid shift amount");
	static if(bytes == 0) // shift by 0 is a no-op
	{
		return v;
	}
	else
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			// little endian reads the bytes into the register in reverse, so we need to flip the operations
			return __builtin_ia32_pslldqi128(v, bytes);
		}
		else
		{
			static assert(0, "Unsupported on this architecture");
		}
	}
}

// shift bytes left by immediate
T rotateBytesLeftImmediate(size_t bytes, SIMDVer Ver = sseVer, T)(T v)
{
	enum b = bytes & 15;

	static if(b == 0) // shift by 0 is a no-op
	{
		return v;
	}
	else
	{
		static assert(b >= 0 && b < 16, "Invalid shift amount");

		version(X86_OR_X64)
		{
			return or!Ver(shiftBytesLeftImmediate!(b, Ver)(v), shiftBytesRightImmediate!(16 - b, Ver)(v));
		}
		else
		{
			static assert(0, "Unsupported on this architecture");
		}
	}
}

// shift bytes right by immediate
T rotateBytesRightImmediate(size_t bytes, SIMDVer Ver = sseVer, T)(T v)
{
	enum b = bytes & 15;

	static if(b == 0) // shift by 0 is a no-op
	{
		return v;
	}
	else
	{
		static assert(b >= 0 && b < 16, "Invalid shift amount");

		version(X86_OR_X64)
		{
			return or!Ver(shiftBytesRightImmediate!(b, Ver)(v), shiftBytesLeftImmediate!(16 - b, Ver)(v));
		}
		else
		{
			static assert(0, "Unsupported on this architecture");
		}
	}
}

// shift elements left
T shiftElementsLeft(size_t n, SIMDVer Ver = sseVer, T)(T v)
{
	static if(n == 0) // shift by 0 is a no-op
	{
		return v;
	}
	else
	{
		//...
		return v;
	}
}

// shift elements right
T shiftElementsRight(size_t n, SIMDVer Ver = sseVer, T)(T v)
{
	static if(n == 0) // shift by 0 is a no-op
	{
		return v;
	}
	else
	{
		//...
		return v;
	}
}

// shift elements left
T shiftElementsLeftPair(size_t n, SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	static if(n == 0) // shift by 0 is a no-op
	{
		return v;
	}
	else
	{
		//...
		return v;
	}
}

// shift elements right
T shiftElementsRightPair(size_t n, SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	static if(n == 0) // shift by 0 is a no-op
	{
		return v;
	}
	else
	{
		//...
		return v;
	}
}

// rotate elements left
T rotateElementsLeft(size_t n, SIMDVer Ver = sseVer, T)(T v)
{
	enum e = n & (NumElements!T - 1); // large rotations should wrap

	static if(e == 0) // shift by 0 is a no-op
	{
		return v;
	}
	else
	{
		version(X86_OR_X64)
		{
			static if(is64bitElement!T)
			{
				return swizzle!("YX",Ver)(v);
			}
			else static if(is32bitElement!T)
			{
				// we can do this with shuffles more efficiently than rotating bytes
				static if(e == 1)
					return swizzle!("YZWX",Ver)(v); // X, Y, Z, [W, X, Y, Z], W
				static if(e == 2)
					return swizzle!("ZWXY",Ver)(v); // X, Y, [Z, W, X, Y], Z, W
				static if(e == 3)
					return swizzle!("WXYZ",Ver)(v); // X, [Y, Z, W, X], Y, Z, W
			}
			else
			{
				// perform the operation as bytes
				static if(is16bitElement!T)
					enum bytes = e * 2;
				else
					enum bytes = e;

				// we can use a shuf for multiples of 4 bytes
				static if((bytes & 3) == 0)
					return rotateElementsLeft!(bytes >> 2, Ver)(cast(uint4)v);
				else
					return rotateBytesLeftImmediate!(bytes, Ver)(v);
			}
		}
		else
		{
			static assert(0, "Unsupported on this architecture");
		}
	}
}

// rotate elements right
T rotateElementsRight(size_t n, SIMDVer Ver = sseVer, T)(T v)
{
	enum size_t e = n & (NumElements!T - 1); // large rotations should wrap

	static if(e == 0) // shift by 0 is a no-op
	{
		return v;
	}
	else
	{
		// just invert the rotation
		static if(is64bitElement!T)
			return rotateElementsLeft!(2 - e, Ver)(v);
		else static if(is32bitElement!T)
			return rotateElementsLeft!(4 - e, Ver)(v);
		else static if(is16bitElement!T)
			return rotateElementsLeft!(8 - e, Ver)(v);
		else static if(is8bitElement!T)
			return rotateElementsLeft!(16 - e, Ver)(v);
	}
}


///////////////////////////////////////////////////////////////////////////////
// Comparisons

// true if all elements: r = A[n] == B[n] && A[n+1] == B[n+1] && ...
bool allEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	return null;
}

// true if all elements: r = A[n] != B[n] && A[n+1] != B[n+1] && ...
bool allNotEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	return null;
}

// true if all elements: r = A[n] > B[n] && A[n+1] > B[n+1] && ...
bool allGreater(SIMDVer Ver = sseVer, T)(T a, T b)
{
	return null;
}

// true if all elements: r = A[n] >= B[n] && A[n+1] >= B[n+1] && ...
bool allGreaterEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	return null;
}

// true if all elements: r = A[n] < B[n] && A[n+1] < B[n+1] && ...
bool allLess(SIMDVer Ver = sseVer, T)(T a, T b)
{
	return null;
}

// true if all elements: r = A[n] <= B[n] && A[n+1] <= B[n+1] && ...
bool allLessEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	return null;
}

// true if any elements: r = A[n] == B[n] || A[n+1] == B[n+1] || ...
bool anyEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	return null;
}

// true if any elements: r = A[n] != B[n] || A[n+1] != B[n+1] || ...
bool anyNotEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	return null;
}

// true if any elements: r = A[n] > B[n] || A[n+1] > B[n+1] || ...
bool anyGreater(SIMDVer Ver = sseVer, T)(T a, T b)
{
	return null;
}

// true if any elements: r = A[n] >= B[n] || A[n+1] >= B[n+1] || ...
bool anyGreaterEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	return null;
}

// true if any elements: r = A[n] < B[n] || A[n+1] < B[n+1] || ...
bool anyLess(SIMDVer Ver = sseVer, T)(T a, T b)
{
	return null;
}

// true if any elements: r = A[n] <= B[n] || A[n+1] <= B[n+1] || ...
bool anyLessEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	return null;
}


///////////////////////////////////////////////////////////////////////////////
// Generate bit masks

// generate a bitmask of for elements: Rn = An == Bn ? -1 : 0
void16 maskEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_cmpeqpd(a, b);
		else static if(is(T == float4))
			return __builtin_ia32_cmpeqps(a, b);
		else static if(is(T == long2) || is(T == ulong2))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_pcmpeqq(a, b);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == int4) || is(T == uint4))
			return __builtin_ia32_pcmpeqd128(a, b);
		else static if(is(T == short8) || is(T == ushort8))
			return __builtin_ia32_pcmpeqw128(a, b);
		else static if(is(T == byte16) || is(T == ubyte16))
			return __builtin_ia32_pcmpeqb128(a, b);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// generate a bitmask of for elements: Rn = An != Bn ? -1 : 0 (SLOW)
void16 maskNotEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_cmpneqpd(a, b);
		else static if(is(T == float4))
			return __builtin_ia32_cmpneqps(a, b);
		else
			return comp!Ver(cast(uint4)maskEqual!Ver(a, b));
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// generate a bitmask of for elements: Rn = An > Bn ? -1 : 0
void16 maskGreater(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_cmpgtpd(a, b);
		else static if(is(T == float4))
			return __builtin_ia32_cmpgtps(a, b);
		else static if(is(T == long2))
		{
			static if(Ver >= SIMDVer.SSE41)
				return __builtin_ia32_pcmpgtq(a, b);
			else
				static assert(0, "Only supported in SSE4.1 and above");
		}
		else static if(is(T == int4))
			return __builtin_ia32_pcmpgtd128(a, b);
		else static if(is(T == short8))
			return __builtin_ia32_pcmpgtw128(a, b);
		else static if(is(T == byte16))
			return __builtin_ia32_pcmpgtb128(a, b);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// generate a bitmask of for elements: Rn = An >= Bn ? -1 : 0 (SLOW)
void16 maskGreaterEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_cmpgepd(a, b);
		else static if(is(T == float4))
			return __builtin_ia32_cmpgeps(a, b);
		else
			return or!Ver(cast(uint4)maskGreater!Ver(a, b), cast(uint4)maskEqual!Ver(a, b)); // compound greater OR equal
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// generate a bitmask of for elements: Rn = An < Bn ? -1 : 0 (SLOW)
void16 maskLess(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_cmpltpd(a, b);
		else static if(is(T == float4))
			return __builtin_ia32_cmpltps(a, b);
		else
			return maskGreaterEqual!Ver(b, a); // reverse the args
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// generate a bitmask of for elements: Rn = An <= Bn ? -1 : 0
void16 maskLessEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(DigitalMars)
	{
		static assert(0, "TODO");
	}
	else version(GNU)
	{
		static if(is(T == double2))
			return __builtin_ia32_cmplepd(a, b);
		else static if(is(T == float4))
			return __builtin_ia32_cmpleps(a, b);
		else
			return maskGreater!Ver(b, a); // reverse the args
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}


///////////////////////////////////////////////////////////////////////////////
// Branchless selection

// select elements according to bit mask
T select(SIMDVer Ver = sseVer, T)(void16 mask, T x, T y)
{
	version(PowerPC)
	{
		static assert(0, "Better implementations");
	}
	else
	{
		// simulate on any architecture without an opcode: ((b ^ a) & mask) ^ a
		return xor!Ver(x, and!Ver(cast(T)mask, xor!Ver(y, x)));
	}
}

// select elements: Rn = An == Bn ? Xn : Yn
T selectEqual(SIMDVer Ver = sseVer, T)(T a, T b, T x, T y)
{
	return select!Ver(maskEqual!Ver(a, b), x, y);
}

// select elements: Rn = An != Bn ? Xn : Yn
T selectNotEqual(SIMDVer Ver = sseVer, T)(T a, T b, T x, T y)
{
	return select!Ver(maskNotEqual!Ver(a, b), x, y);
}

// select elements: Rn = An > Bn ? Xn : Yn
T selectGreater(SIMDVer Ver = sseVer, T)(T a, T b, T x, T y)
{
	return select!Ver(maskGreater!Ver(a, b), x, y);
}

// select elements: Rn = An >= Bn ? Xn : Yn
T selectGreaterEqual(SIMDVer Ver = sseVer, T)(T a, T b, T x, T y)
{
	return select!Ver(maskGreaterEqual!Ver(a, b), x, y);
}

// select elements: Rn = An < Bn ? Xn : Yn
T selectLess(SIMDVer Ver = sseVer, T)(T a, T b, T x, T y)
{
	return select!Ver(maskLess!Ver(a, b), x, y);
}

// select elements: Rn = An <= Bn ? Xn : Yn
T selectLessEqual(SIMDVer Ver = sseVer, T)(T a, T b, T x, T y)
{
	return select!Ver(maskLessEqual!Ver(a, b), x, y);
}


///////////////////////////////////////////////////////////////////////////////
// Matrix API

// define a/some matrix type(s)
//...

struct float4x4
{
	float4 xRow;
	float4 yRow;
	float4 zRow;
	float4 wRow;
}

///////////////////////////////////////////////////////////////////////////////
// Matrix functions

T transpose(SIMDVer Ver = sseVer, T)(T m)
{
	return null;
}

// determinant, etc...



///////////////////////////////////////////////////////////////////////////////
// Unit test the lot!

unittest
{
	// test all functions and all types

	// >_< *** EPIC LONG TEST FUNCTION HERE ***
}
