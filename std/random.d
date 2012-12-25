// Written in the D programming language.

/**
Facilities for random number generation.

The new-style generator objects hold their own state so they are
immune of threading issues. The generators feature a number of
well-known and well-documented methods of generating random
numbers. An overall fast and reliable means to generate random numbers
is the $(D_PARAM Mt19937) generator, which derives its name from
"$(LUCKY Mersenne Twister) with a period of 2 to the power of
19937". In memory-constrained situations, $(LUCKY linear congruential)
generators such as $(D MinstdRand0) and $(D MinstdRand) might be
useful. The standard library provides an alias $(D_PARAM Random) for
whichever generator it considers the most fit for the target
environment.

Example:

----
// Generate a uniformly-distributed integer in the range [0, 14]
auto i = uniform(0, 15);
// Generate a uniformly-distributed real in the range [0, 100$(RPAREN)
// using a specific random generator
Random gen;
auto r = uniform(0.0L, 100.0L, gen);
----

In addition to random number generators, this module features
distributions, which skew a generator's output statistical
distribution in various ways. So far the uniform distribution for
integers and real numbers have been implemented.

Source:    $(PHOBOSSRC std/_random.d)

Macros:

WIKI = Phobos/StdRandom


Copyright: Copyright Andrei Alexandrescu 2008 - 2009, Joseph Rushton Wakeling 2012.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB erdani.org, Andrei Alexandrescu)
           Masahiro Nakagawa (Xorshift randome generator)
           $(WEB braingam.es, Joseph Rushton Wakeling) (Algorithm D for random sampling)
Credits:   The entire random number library architecture is derived from the
           excellent $(WEB open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf, C++0X)
           random number facility proposed by Jens Maurer and contributed to by
           researchers at the Fermi laboratory(excluding Xorshift).
*/
/*
         Copyright Andrei Alexandrescu 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.random;

import std.algorithm, std.c.time, std.conv, std.exception,
       std.math, std.numeric, std.range, std.traits, 
       std.typecons, std.mathspecial,
       core.thread, core.time, core.bitop;
import std.string : format;

version(unittest) import std.typetuple;


// Segments of the code in this file Copyright (c) 1997 by Rick Booth
// From "Inner Loops" by Rick Booth, Addison-Wesley

// Work derived from:

/*
   A C-program for MT19937, with initialization improved 2002/1/26.
   Coded by Takuji Nishimura and Makoto Matsumoto.

   Before using, initialize the state by using init_genrand(seed)
   or init_by_array(init_key, key_length).

   Copyright (C) 1997 - 2002, Makoto Matsumoto and Takuji Nishimura,
   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

     1. Redistributions of source code must retain the above copyright
        notice, this list of conditions and the following disclaimer.

     2. Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in the
        documentation and/or other materials provided with the distribution.

     3. The names of its contributors may not be used to endorse or promote
        products derived from this software without specific prior written
        permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


   Any feedback is very welcome.
   http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html
   email: m-mat @ math.sci.hiroshima-u.ac.jp (remove space)
*/


/**
 * Test if Rng is a random-number generator. The overload
 * taking a ElementType also makes sure that the Rng generates
 * values of that type.
 *
 * A random-number generator has at least the following features:
 * $(UL
 *   $(LI it's an InputRange)
 *   $(LI it has a 'bool isUniformRandom' field readable in CTFE)
 * )
 */
template isUniformRNG(Rng, ElementType)
{
    enum bool isUniformRNG = isInputRange!Rng &&
        is(typeof(Rng.front) == ElementType) &&
        is(typeof(
        {
            static assert(Rng.isUniformRandom); //tag
        }));
}

/**
 * ditto
 */
template isUniformRNG(Rng)
{
    enum bool isUniformRNG = isInputRange!Rng &&
        is(typeof(
        {
            static assert(Rng.isUniformRandom); //tag
        }));
}

/**
 * Test if Rng is seedable. The overload
 * taking a SeedType also makes sure that the Rng can be seeded with SeedType.
 *
 * A seedable random-number generator has the following additional features:
 * $(UL
 *   $(LI it has a 'seed(ElementType)' function)
 * )
 */
template isSeedable(Rng, SeedType)
{
    enum bool isSeedable = isUniformRNG!(Rng) &&
        is(typeof(
        {
            Rng r = void;              // can define a Rng object
            r.seed(SeedType.init);     // can seed a Rng
        }));
}

///ditto
template isSeedable(Rng)
{
    enum bool isSeedable = isUniformRNG!Rng &&
        is(typeof(
        {
            Rng r = void;                     // can define a Rng object
            r.seed(typeof(r.front).init);     // can seed a Rng
        }));
}

unittest
{
    struct NoRng
    {
        @property uint front() {return 0;}
        @property bool empty() {return false;}
        void popFront() {}
    }
    assert(!isUniformRNG!(NoRng, uint));
    assert(!isUniformRNG!(NoRng));
    assert(!isSeedable!(NoRng, uint));
    assert(!isSeedable!(NoRng));

    struct NoRng2
    {
        @property uint front() {return 0;}
        @property bool empty() {return false;}
        void popFront() {}

        enum isUniformRandom = false;
    }
    assert(!isUniformRNG!(NoRng2, uint));
    assert(!isUniformRNG!(NoRng2));
    assert(!isSeedable!(NoRng2, uint));
    assert(!isSeedable!(NoRng2));

    struct NoRng3
    {
        @property bool empty() {return false;}
        void popFront() {}

        enum isUniformRandom = true;
    }
    assert(!isUniformRNG!(NoRng3, uint));
    assert(!isUniformRNG!(NoRng3));
    assert(!isSeedable!(NoRng3, uint));
    assert(!isSeedable!(NoRng3));

    struct validRng
    {
        @property uint front() {return 0;}
        @property bool empty() {return false;}
        void popFront() {}

        enum isUniformRandom = true;
    }
    assert(isUniformRNG!(validRng, uint));
    assert(isUniformRNG!(validRng));
    assert(!isSeedable!(validRng, uint));
    assert(!isSeedable!(validRng));

    struct seedRng
    {
        @property uint front() {return 0;}
        @property bool empty() {return false;}
        void popFront() {}
        void seed(uint val){}
        enum isUniformRandom = true;
    }
    assert(isUniformRNG!(seedRng, uint));
    assert(isUniformRNG!(seedRng));
    assert(isSeedable!(seedRng, uint));
    assert(isSeedable!(seedRng));
}

/**
Linear Congruential generator.
 */
struct LinearCongruentialEngine(UIntType, UIntType a, UIntType c, UIntType m)
    if(isUnsigned!UIntType)
{
    ///Mark this as a Rng
    enum bool isUniformRandom = true;
    /// Does this generator have a fixed range? ($(D_PARAM true)).
    enum bool hasFixedRange = true;
    /// Lowest generated value ($(D 1) if $(D c == 0), $(D 0) otherwise).
    enum UIntType min = ( c == 0 ? 1 : 0 );
    /// Highest generated value ($(D modulus - 1)).
    enum UIntType max = m - 1;
/**
The parameters of this distribution. The random number is $(D_PARAM x
= (x * multipler + increment) % modulus).
 */
    enum UIntType multiplier = a;
    ///ditto
    enum UIntType increment = c;
    ///ditto
    enum UIntType modulus = m;

    static assert(isIntegral!(UIntType));
    static assert(m == 0 || a < m);
    static assert(m == 0 || c < m);
    static assert(m == 0 ||
            (cast(ulong)a * (m-1) + c) % m == (c < a ? c - a + m : c - a));

    // Check for maximum range
    private static ulong gcd(ulong a, ulong b)
    {
        while (b)
        {
            auto t = b;
            b = a % b;
            a = t;
        }
        return a;
    }

    private static ulong primeFactorsOnly(ulong n)
    {
        ulong result = 1;
        ulong iter = 2;
        for (; n >= iter * iter; iter += 2 - (iter == 2))
        {
            if (n % iter) continue;
            result *= iter;
            do
            {
                n /= iter;
            } while (n % iter == 0);
        }
        return result * n;
    }

    unittest
    {
        static assert(primeFactorsOnly(100) == 10);
        //writeln(primeFactorsOnly(11));
        static assert(primeFactorsOnly(11) == 11);
        static assert(primeFactorsOnly(7 * 7 * 7 * 11 * 15 * 11) == 7 * 11 * 15);
        static assert(primeFactorsOnly(129 * 2) == 129 * 2);
        // enum x = primeFactorsOnly(7 * 7 * 7 * 11 * 15);
        // static assert(x == 7 * 11 * 15);
    }

    private static bool properLinearCongruentialParameters(ulong m,
            ulong a, ulong c)
    {
        if (m == 0)
        {
            static if (is(UIntType == uint))
            {
                // Assume m is uint.max + 1
                m = (1uL << 32);
            }
            else
            {
                return false;
            }
        }
        // Bounds checking
        if (a == 0 || a >= m || c >= m) return false;
        // c and m are relatively prime
        if (c > 0 && gcd(c, m) != 1) return false;
        // a - 1 is divisible by all prime factors of m
        if ((a - 1) % primeFactorsOnly(m)) return false;
        // if a - 1 is multiple of 4, then m is a  multiple of 4 too.
        if ((a - 1) % 4 == 0 && m % 4) return false;
        // Passed all tests
        return true;
    }

    // check here
    static assert(c == 0 || properLinearCongruentialParameters(m, a, c),
            "Incorrect instantiation of LinearCongruentialEngine");

/**
Constructs a $(D_PARAM LinearCongruentialEngine) generator seeded with
$(D x0).
 */
    this(UIntType x0)
    {
        seed(x0);
    }

/**
   (Re)seeds the generator.
*/
    void seed(UIntType x0 = 1)
    {
        static if (c == 0)
        {
            enforce(x0, "Invalid (zero) seed for "
                    ~ LinearCongruentialEngine.stringof);
        }
        _x = modulus ? (x0 % modulus) : x0;
        popFront();
    }

/**
   Advances the random sequence.
*/
    void popFront()
    {
        static if (m)
        {
            static if (is(UIntType == uint) && m == uint.max)
            {
                immutable ulong
                    x = (cast(ulong) a * _x + c),
                    v = x >> 32,
                    w = x & uint.max;
                immutable y = cast(uint)(v + w);
                _x = (y < v || y == uint.max) ? (y + 1) : y;
            }
            else static if (is(UIntType == uint) && m == int.max)
            {
                immutable ulong
                    x = (cast(ulong) a * _x + c),
                    v = x >> 31,
                    w = x & int.max;
                immutable uint y = cast(uint)(v + w);
                _x = (y >= int.max) ? (y - int.max) : y;
            }
            else
            {
                _x = cast(UIntType) ((cast(ulong) a * _x + c) % m);
            }
        }
        else
        {
            _x = a * _x + c;
        }
    }

/**
   Returns the current number in the random sequence.
*/
    @property UIntType front()
    {
        return _x;
    }

///
    @property typeof(this) save()
    {
        return this;
    }

/**
Always $(D false) (random generators are infinite ranges).
 */
    enum bool empty = false;

/**
   Compares against $(D_PARAM rhs) for equality.
 */
    bool opEquals(ref const LinearCongruentialEngine rhs) const
    {
        return _x == rhs._x;
    }

    private UIntType _x = m ? (a + c) % m : (a + c);
}

/**
Define $(D_PARAM LinearCongruentialEngine) generators with well-chosen
parameters. $(D MinstdRand0) implements Park and Miller's "minimal
standard" $(WEB
wikipedia.org/wiki/Park%E2%80%93Miller_random_number_generator,
generator) that uses 16807 for the multiplier. $(D MinstdRand)
implements a variant that has slightly better spectral behavior by
using the multiplier 48271. Both generators are rather simplistic.

Example:

----
// seed with a constant
auto rnd0 = MinstdRand0(1);
auto n = rnd0.front; // same for each run
// Seed with an unpredictable value
rnd0.seed(unpredictableSeed);
n = rnd0.front; // different across runs
----
 */
alias LinearCongruentialEngine!(uint, 16807, 0, 2147483647) MinstdRand0;
/// ditto
alias LinearCongruentialEngine!(uint, 48271, 0, 2147483647) MinstdRand;

unittest
{
    assert(isForwardRange!MinstdRand);
    assert(isUniformRNG!MinstdRand);
    assert(isUniformRNG!MinstdRand0);
    assert(isUniformRNG!(MinstdRand, uint));
    assert(isUniformRNG!(MinstdRand0, uint));
    assert(isSeedable!MinstdRand);
    assert(isSeedable!MinstdRand0);
    assert(isSeedable!(MinstdRand, uint));
    assert(isSeedable!(MinstdRand0, uint));

    // The correct numbers are taken from The Database of Integer Sequences
    // http://www.research.att.com/~njas/sequences/eisBTfry00128.txt
    auto checking0 = [
        16807UL,282475249,1622650073,984943658,1144108930,470211272,
        101027544,1457850878,1458777923,2007237709,823564440,1115438165,
        1784484492,74243042,114807987,1137522503,1441282327,16531729,
        823378840,143542612 ];
    //auto rnd0 = MinstdRand0(1);
    MinstdRand0 rnd0;

    foreach (e; checking0)
    {
        assert(rnd0.front == e);
        rnd0.popFront();
    }
    // Test the 10000th invocation
    // Correct value taken from:
    // http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf
    rnd0.seed();
    popFrontN(rnd0, 9999);
    assert(rnd0.front == 1043618065);

    // Test MinstdRand
    auto checking = [48271UL,182605794,1291394886,1914720637,2078669041,
                     407355683];
    //auto rnd = MinstdRand(1);
    MinstdRand rnd;
    foreach (e; checking)
    {
        assert(rnd.front == e);
        rnd.popFront();
    }

    // Test the 10000th invocation
    // Correct value taken from:
    // http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf
    rnd.seed();
    popFrontN(rnd, 9999);
    assert(rnd.front == 399268537);
}

/**
The $(LUCKY Mersenne Twister) generator.
 */
struct MersenneTwisterEngine(UIntType, size_t w, size_t n, size_t m, size_t r,
                             UIntType a, size_t u, size_t s,
                             UIntType b, size_t t,
                             UIntType c, size_t l)
    if(isUnsigned!UIntType)
{
    ///Mark this as a Rng
    enum bool isUniformRandom = true;
/**
Parameter for the generator.
*/
    enum size_t wordSize = w;
    enum size_t stateSize = n;
    enum size_t shiftSize = m;
    enum size_t maskBits = r;
    enum UIntType xorMask = a;
    enum UIntType temperingU = u;
    enum size_t temperingS = s;
    enum UIntType temperingB = b;
    enum size_t temperingT = t;
    enum UIntType temperingC = c;
    enum size_t temperingL = l;

    /// Smallest generated value (0).
    enum UIntType min = 0;
    /// Largest generated value.
    enum UIntType max =
        w == UIntType.sizeof * 8 ? UIntType.max : (1u << w) - 1;
    /// The default seed value.
    enum UIntType defaultSeed = 5489u;

    static assert(1 <= m && m <= n);
    static assert(0 <= r && 0 <= u && 0 <= s && 0 <= t && 0 <= l);
    static assert(r <= w && u <= w && s <= w && t <= w && l <= w);
    static assert(0 <= a && 0 <= b && 0 <= c);
    static assert(a <= max && b <= max && c <= max);

/**
   Constructs a MersenneTwisterEngine object.
*/
    this(UIntType value)
    {
        seed(value);
    }

/**
   Seeds a MersenneTwisterEngine object.
   Note:
   This seed function gives 2^32 starting points. To allow the RNG to be started in any one of its
   internal states use the seed overload taking an InputRange.
*/
    void seed()(UIntType value = defaultSeed)
    {
        static if (w == UIntType.sizeof * 8)
        {
            mt[0] = value;
        }
        else
        {
            static assert(max + 1 > 0);
            mt[0] = value % (max + 1);
        }
        for (mti = 1; mti < n; ++mti)
        {
            mt[mti] =
                cast(UIntType)
                (1812433253UL * (mt[mti-1] ^ (mt[mti-1] >> (w - 2))) + mti);
            /* See Knuth TAOCP Vol2. 3rd Ed. P.106 for multiplier. */
            /* In the previous versions, MSBs of the seed affect   */
            /* only MSBs of the array mt[].                        */
            /* 2002/01/09 modified by Makoto Matsumoto             */
            //mt[mti] &= ResultType.max;
            /* for >32 bit machines */
        }
        popFront();
    }

/**
   Seeds a MersenneTwisterEngine object using an InputRange.

   Throws:
   $(D Exception) if the InputRange didn't provide enough elements to seed the generator.
   The number of elements required is the 'n' template parameter of the MersenneTwisterEngine struct.
   
   Examples:
   ----------------
   Mt19937 gen;
   gen.seed(map!((a) => unpredictableSeed)(repeat(0)));
   ----------------
 */
    void seed(T)(T range) if(isInputRange!T && is(Unqual!(ElementType!T) == UIntType))
    {
        size_t j;
        for(j = 0; j < n && !range.empty; ++j, range.popFront())
        {
            mt[j] = range.front;
        }

        mti = n;
        if(range.empty && j < n)
        {
            throw new Exception(format("MersenneTwisterEngine.seed: Input range didn't provide enough"
                " elements: Need %s elemnets.", n));
        }

        popFront();
    }

/**
   Advances the generator.
*/
    void popFront()
    {
        if (mti == size_t.max) seed();
        enum UIntType
            upperMask = ~((cast(UIntType) 1u <<
                           (UIntType.sizeof * 8 - (w - r))) - 1),
            lowerMask = (cast(UIntType) 1u << r) - 1;
        static immutable UIntType mag01[2] = [0x0UL, a];

        ulong y = void;

        if (mti >= n)
        {
            /* generate N words at one time */

            int kk = 0;
            const limit1 = n - m;
            for (; kk < limit1; ++kk)
            {
                y = (mt[kk] & upperMask)|(mt[kk + 1] & lowerMask);
                mt[kk] = cast(UIntType) (mt[kk + m] ^ (y >> 1)
                        ^ mag01[cast(UIntType) y & 0x1U]);
            }
            const limit2 = n - 1;
            for (; kk < limit2; ++kk)
            {
                y = (mt[kk] & upperMask)|(mt[kk + 1] & lowerMask);
                mt[kk] = cast(UIntType) (mt[kk + (m -n)] ^ (y >> 1)
                                         ^ mag01[cast(UIntType) y & 0x1U]);
            }
            y = (mt[n -1] & upperMask)|(mt[0] & lowerMask);
            mt[n - 1] = cast(UIntType) (mt[m - 1] ^ (y >> 1)
                                        ^ mag01[cast(UIntType) y & 0x1U]);

            mti = 0;
        }

        y = mt[mti++];

        /* Tempering */
        y ^= (y >> temperingU);
        y ^= (y << temperingS) & temperingB;
        y ^= (y << temperingT) & temperingC;
        y ^= (y >> temperingL);

        _y = cast(UIntType) y;
    }

/**
   Returns the current random value.
 */
    @property UIntType front()
    {
        if (mti == size_t.max) seed();
        return _y;
    }

///
    @property typeof(this) save()
    {
        return this;
    }

/**
Always $(D false).
 */
    enum bool empty = false;

    private UIntType mt[n];
    private size_t mti = size_t.max; /* means mt is not initialized */
    UIntType _y = UIntType.max;
}

/**
A $(D MersenneTwisterEngine) instantiated with the parameters of the
original engine $(WEB math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html,
MT19937), generating uniformly-distributed 32-bit numbers with a
period of 2 to the power of 19937. Recommended for random number
generation unless memory is severely restricted, in which case a $(D
LinearCongruentialEngine) would be the generator of choice.

Example:

----
// seed with a constant
Mt19937 gen;
auto n = gen.front; // same for each run
// Seed with an unpredictable value
gen.seed(unpredictableSeed);
n = gen.front; // different across runs
----
 */
alias MersenneTwisterEngine!(uint, 32, 624, 397, 31, 0x9908b0df, 11, 7,
                             0x9d2c5680, 15, 0xefc60000, 18)
    Mt19937;

unittest
{
    assert(isUniformRNG!Mt19937);
    assert(isUniformRNG!(Mt19937, uint));
    assert(isSeedable!Mt19937);
    assert(isSeedable!(Mt19937, uint));
    assert(isSeedable!(Mt19937, typeof(map!((a) => unpredictableSeed)(repeat(0)))));
    Mt19937 gen;
    popFrontN(gen, 9999);
    assert(gen.front == 4123659995);
}

unittest
{
    Mt19937 gen;

    assertThrown(gen.seed(map!((a) => unpredictableSeed)(repeat(0, 623))));

    gen.seed(map!((a) => unpredictableSeed)(repeat(0, 624)));
    //infinite Range
    gen.seed(map!((a) => unpredictableSeed)(repeat(0)));
}

unittest
{
    uint a, b;
    {
        Mt19937 gen;
        a = gen.front;
    }
    {
        Mt19937 gen;
        gen.popFront();
        //popFrontN(gen, 1);  // skip 1 element
        b = gen.front;
    }
    assert(a != b);
}


/**
 * Xorshift generator using 32bit algorithm.
 *
 * Implemented according to $(WEB www.jstatsoft.org/v08/i14/paper, Xorshift RNGs).
 *
 * $(BOOKTABLE $(TEXTWITHCOMMAS Supporting bits are below, $(D bits) means second parameter of XorshiftEngine.),
 *  $(TR $(TH bits) $(TH period))
 *  $(TR $(TD 32)   $(TD 2^32 - 1))
 *  $(TR $(TD 64)   $(TD 2^64 - 1))
 *  $(TR $(TD 96)   $(TD 2^96 - 1))
 *  $(TR $(TD 128)  $(TD 2^128 - 1))
 *  $(TR $(TD 160)  $(TD 2^160 - 1))
 *  $(TR $(TD 192)  $(TD 2^192 - 2^32))
 * )
 */
struct XorshiftEngine(UIntType, UIntType bits, UIntType a, UIntType b, UIntType c)
    if(isUnsigned!UIntType)
{
    static assert(bits == 32 || bits == 64 || bits == 96 || bits == 128 || bits == 160 || bits == 192,
                  "Supporting bits are 32, 64, 96, 128, 160 and 192. " ~ to!string(bits) ~ " is not supported.");


  public:
    ///Mark this as a Rng
    enum bool isUniformRandom = true;
    /// Always $(D false) (random generators are infinite ranges).
    enum empty = false;
    /// Smallest generated value.
    enum UIntType min = 0;
    /// Largest generated value.
    enum UIntType max = UIntType.max;


  private:
    enum size = bits / 32;

    static if (bits == 32)
        UIntType[size] seeds_ = [2463534242];
    else static if (bits == 64)
        UIntType[size] seeds_ = [123456789, 362436069];
    else static if (bits == 96)
        UIntType[size] seeds_ = [123456789, 362436069, 521288629];
    else static if (bits == 128)
        UIntType[size] seeds_ = [123456789, 362436069, 521288629, 88675123];
    else static if (bits == 160)
        UIntType[size] seeds_ = [123456789, 362436069, 521288629, 88675123, 5783321];
    else
    { // 192bits
        UIntType[size] seeds_ = [123456789, 362436069, 521288629, 88675123, 5783321, 6615241];
        UIntType       value_;
    }


  public:
    /**
     * Constructs a $(D XorshiftEngine) generator seeded with $(D_PARAM x0).
     */
    @safe
    this(UIntType x0)
    {
        seed(x0);
    }


    /**
     * (Re)seeds the generator.
     */
    @safe
    nothrow void seed(UIntType x0)
    {
        // Initialization routine from MersenneTwisterEngine.
        foreach (i, e; seeds_)
            seeds_[i] = x0 = cast(UIntType)(1812433253U * (x0 ^ (x0 >> 30)) + i + 1);

        // All seeds must not be 0.
        sanitizeSeeds(seeds_);

        popFront();
    }


    /**
     * Returns the current number in the random sequence.
     */
    @property @safe
    nothrow UIntType front()
    {
        static if (bits == 192)
            return value_;
        else
            return seeds_[size - 1];
    }


    /**
     * Advances the random sequence.
     */
    @safe
    nothrow void popFront()
    {
        UIntType temp;

        static if (bits == 32)
        {
            temp      = seeds_[0] ^ (seeds_[0] << a);
            temp      = temp >> b;
            seeds_[0] = temp ^ (temp << c);
        }
        else static if (bits == 64)
        {
            temp      = seeds_[0] ^ (seeds_[0] << a);
            seeds_[0] = seeds_[1];
            seeds_[1] = seeds_[1] ^ (seeds_[1] >> c) ^ temp ^ (temp >> b);
        }
        else static if (bits == 96)
        {
            temp      = seeds_[0] ^ (seeds_[0] << a);
            seeds_[0] = seeds_[1];
            seeds_[1] = seeds_[2];
            seeds_[2] = seeds_[2] ^ (seeds_[2] >> c) ^ temp ^ (temp >> b);
        }
        else static if (bits == 128)
        {
            temp      = seeds_[0] ^ (seeds_[0] << a);
            seeds_[0] = seeds_[1];
            seeds_[1] = seeds_[2];
            seeds_[2] = seeds_[3];
            seeds_[3] = seeds_[3] ^ (seeds_[3] >> c) ^ temp ^ (temp >> b);
        }
        else static if (bits == 160)
        {
            temp      = seeds_[0] ^ (seeds_[0] >> a);
            seeds_[0] = seeds_[1];
            seeds_[1] = seeds_[2];
            seeds_[2] = seeds_[3];
            seeds_[3] = seeds_[4];
            seeds_[4] = seeds_[4] ^ (seeds_[4] >> c) ^ temp ^ (temp >> b);
        }
        else
        { // 192bits
            temp      = seeds_[0] ^ (seeds_[0] >> a);
            seeds_[0] = seeds_[1];
            seeds_[1] = seeds_[2];
            seeds_[2] = seeds_[3];
            seeds_[3] = seeds_[4];
            seeds_[4] = seeds_[4] ^ (seeds_[4] << c) ^ temp ^ (temp << b);
            value_    = seeds_[4] + (seeds_[5] += 362437);
        }
    }


    /**
     * Captures a range state.
     */
    @property
    typeof(this) save()
    {
        return this;
    }


    /**
     * Compares against $(D_PARAM rhs) for equality.
     */
    @safe
    nothrow bool opEquals(ref const XorshiftEngine rhs) const
    {
        return seeds_ == rhs.seeds_;
    }


  private:
    @safe
    static nothrow void sanitizeSeeds(ref UIntType[size] seeds)
    {
        for (uint i; i < seeds.length; i++)
        {
            if (seeds[i] == 0)
                seeds[i] = i + 1;
        }
    }


    unittest
    {
        static if (size  ==  4)  // Other bits too
        {
            UIntType[size] seeds = [1, 0, 0, 4];

            sanitizeSeeds(seeds);

            assert(seeds == [1, 2, 3, 4]);
        }
    }
}


/**
 * Define $(D XorshiftEngine) generators with well-chosen parameters. See each bits examples of "Xorshift RNGs".
 * $(D Xorshift) is a Xorshift128's alias because 128bits implementation is mostly used.
 *
 * Example:
 * -----
 * // Seed with a constant
 * auto rnd = Xorshift(1);
 * auto num = rnd.front;  // same for each run
 *
 * // Seed with an unpredictable value
 * rnd.seed(unpredictableSeed());
 * num = rnd.front; // different across runs
 * -----
 */
alias XorshiftEngine!(uint, 32,  13, 17, 5)  Xorshift32;
alias XorshiftEngine!(uint, 64,  10, 13, 10) Xorshift64;   /// ditto
alias XorshiftEngine!(uint, 96,  10, 5,  26) Xorshift96;   /// ditto
alias XorshiftEngine!(uint, 128, 11, 8,  19) Xorshift128;  /// ditto
alias XorshiftEngine!(uint, 160, 2,  1,  4)  Xorshift160;  /// ditto
alias XorshiftEngine!(uint, 192, 2,  1,  4)  Xorshift192;  /// ditto
alias Xorshift128 Xorshift;                                /// ditto


unittest
{
    assert(isForwardRange!Xorshift);
    assert(isUniformRNG!Xorshift);
    assert(isUniformRNG!(Xorshift, uint));
    assert(isSeedable!Xorshift);
    assert(isSeedable!(Xorshift, uint));

    // Result from reference implementation.
    auto checking = [
        [2463534242UL, 267649, 551450, 53765, 108832, 215250, 435468, 860211, 660133, 263375],
        [362436069UL, 2113136921, 19051112, 3010520417, 951284840, 1213972223, 3173832558, 2611145638, 2515869689, 2245824891],
        [521288629UL, 1950277231, 185954712, 1582725458, 3580567609, 2303633688, 2394948066, 4108622809, 1116800180, 3357585673],
        [88675123UL, 3701687786, 458299110, 2500872618, 3633119408, 516391518, 2377269574, 2599949379, 717229868, 137866584],
        [5783321UL, 93724048, 491642011, 136638118, 246438988, 238186808, 140181925, 533680092, 285770921, 462053907],
        [0UL, 246875399, 3690007200, 1264581005, 3906711041, 1866187943, 2481925219, 2464530826, 1604040631, 3653403911]
    ];

    foreach (I, Type; TypeTuple!(Xorshift32, Xorshift64, Xorshift96, Xorshift128, Xorshift160, Xorshift192))
    {
        Type rnd;

        foreach (e; checking[I])
        {
            assert(rnd.front == e);
            rnd.popFront();
        }
    }
}


/**
A "good" seed for initializing random number engines. Initializing
with $(D_PARAM unpredictableSeed) makes engines generate different
random number sequences every run.

Example:

----
auto rnd = Random(unpredictableSeed);
auto n = rnd.front;
...
----
*/

@property uint unpredictableSeed()
{
    static bool seeded;
    static MinstdRand0 rand;
    if (!seeded)
    {
        uint threadID = cast(uint) cast(void*) Thread.getThis();
        rand.seed((getpid() + threadID) ^ cast(uint) TickDuration.currSystemTick.length);
        seeded = true;
    }
    rand.popFront();
    return cast(uint) (TickDuration.currSystemTick.length ^ rand.front);
}

unittest
{
    // not much to test here
    auto a = unpredictableSeed;
    static assert(is(typeof(a) == uint));
}

/**
The "default", "favorite", "suggested" random number generator type on
the current platform. It is an alias for one of the previously-defined
generators. You may want to use it if (1) you need to generate some
nice random numbers, and (2) you don't care for the minutiae of the
method being used.
 */

alias Mt19937 Random;

unittest
{
    assert(isUniformRNG!Random);
    assert(isUniformRNG!(Random, uint));
    assert(isSeedable!Random);
    assert(isSeedable!(Random, uint));
}

/**
Global random number generator used by various functions in this
module whenever no generator is specified. It is allocated per-thread
and initialized to an unpredictable value for each thread.
 */
@property ref Random rndGen()
{
    static Random result;
    static bool initialized;
    if (!initialized)
    {
        static if(isSeedable!(Random, typeof(map!((a) => unpredictableSeed)(repeat(0)))))
            result.seed(map!((a) => unpredictableSeed)(repeat(0)));
        else
            result = Random(unpredictableSeed);
        initialized = true;
    }
    return result;
}

/**
Generates a number between $(D a) and $(D b). The $(D boundaries)
parameter controls the shape of the interval (open vs. closed on
either side). Valid values for $(D boundaries) are $(D "[]"), $(D
"$(LPAREN)]"), $(D "[$(RPAREN)"), and $(D "()"). The default interval
is closed to the left and open to the right. The version that does not
take $(D urng) uses the default generator $(D rndGen).

Example:

----
Random gen(unpredictableSeed);
// Generate an integer in [0, 1023]
auto a = uniform(0, 1024, gen);
// Generate a float in [0, 1$(RPAREN)
auto a = uniform(0.0f, 1.0f, gen);
----
 */
auto uniform(string boundaries = "[)", T1, T2)
(T1 a, T2 b)  if (!is(CommonType!(T1, T2) == void))
{
    return uniform!(boundaries, T1, T2, Random)(a, b, rndGen);
}

unittest
{
    MinstdRand0 gen;
    foreach (i; 0 .. 20)
    {
        auto x = uniform(0.0, 15.0, gen);
        assert(0 <= x && x < 15);
    }
    foreach (i; 0 .. 20)
    {
        auto x = uniform!"[]"('a', 'z', gen);
        assert('a' <= x && x <= 'z');
    }

    foreach (i; 0 .. 20)
    {
        auto x = uniform('a', 'z', gen);
        assert('a' <= x && x < 'z');
    }

    foreach(i; 0 .. 20)
    {
        immutable ubyte a = 0;
            immutable ubyte b = 15;
        auto x = uniform(a, b, gen);
            assert(a <= x && x < b);
    }
}

// Implementation of uniform for floating-point types
/// ditto
auto uniform(string boundaries = "[)",
        T1, T2, UniformRandomNumberGenerator)
(T1 a, T2 b, ref UniformRandomNumberGenerator urng)
if (isFloatingPoint!(CommonType!(T1, T2)))
{
    alias Unqual!(CommonType!(T1, T2)) NumberType;
    static if (boundaries[0] == '(')
    {
        NumberType _a = nextafter(cast(NumberType) a, NumberType.infinity);
    }
    else
    {
        NumberType _a = a;
    }
    static if (boundaries[1] == ')')
    {
        NumberType _b = nextafter(cast(NumberType) b, -NumberType.infinity);
    }
    else
    {
        NumberType _b = b;
    }
    enforce(_a <= _b,
            text("std.random.uniform(): invalid bounding interval ",
                    boundaries[0], a, ", ", b, boundaries[1]));
    NumberType result =
        _a + (_b - _a) * cast(NumberType) (urng.front - urng.min)
        / (urng.max - urng.min);
    urng.popFront();
    return result;
}

// Implementation of uniform for integral types
auto uniform(string boundaries = "[)",
        T1, T2, UniformRandomNumberGenerator)
(T1 a, T2 b, ref UniformRandomNumberGenerator urng)
if (isIntegral!(CommonType!(T1, T2)) || isSomeChar!(CommonType!(T1, T2)))
{
    alias Unqual!(CommonType!(T1, T2)) ResultType;
    // We handle the case "[)' as the common case, and we adjust all
    // other cases to fit it.
    static if (boundaries[0] == '(')
    {
        enforce(cast(ResultType) a < ResultType.max,
                text("std.random.uniform(): invalid left bound ", a));
        ResultType min = cast(ResultType) a + 1;
    }
    else
    {
        ResultType min = a;
    }
    static if (boundaries[1] == ']')
    {
        enforce(min <= cast(ResultType) b,
                text("std.random.uniform(): invalid bounding interval ",
                        boundaries[0], a, ", ", b, boundaries[1]));
        if (b == ResultType.max && min == ResultType.min)
        {
            // Special case - all bits are occupied
            return .uniform!ResultType(urng);
        }
        auto count = unsigned(b - min) + 1u;
        static assert(count.min == 0);
    }
    else
    {
        enforce(min < cast(ResultType) b,
                text("std.random.uniform(): invalid bounding interval ",
                        boundaries[0], a, ", ", b, boundaries[1]));
        auto count = unsigned(b - min);
        static assert(count.min == 0);
    }
    assert(count != 0);
    if (count == 1) return min;
    alias typeof(count) CountType;
    static assert(CountType.min == 0);
    auto bucketSize = 1u + (CountType.max - count + 1) / count;
    CountType r;
    do
    {
        r = cast(CountType) (uniform!CountType(urng) / bucketSize);
    }
    while (r >= count);
    return cast(typeof(return)) (min + r);
}

unittest
{
    auto gen = Mt19937(unpredictableSeed);
    static assert(isForwardRange!(typeof(gen)));

    auto a = uniform(0, 1024, gen);
    assert(0 <= a && a <= 1024);
    auto b = uniform(0.0f, 1.0f, gen);
    assert(0 <= b && b < 1, to!string(b));
    auto c = uniform(0.0, 1.0);
    assert(0 <= c && c < 1);

    foreach(T; TypeTuple!(char, wchar, dchar, byte, ubyte, short, ushort,
                          int, uint, long, ulong, float, double, real))
    {
        T lo = 0, hi = 100;
        T init = uniform(lo, hi);
        size_t i = 50;
        while (--i && uniform(lo, hi) == init) {}
        assert(i > 0);
    }
}

/**
Generates a uniformly-distributed number in the range $(D [T.min,
T.max]) for any integral type $(D T). If no random number generator is
passed, uses the default $(D rndGen).
 */
auto uniform(T, UniformRandomNumberGenerator)
(ref UniformRandomNumberGenerator urng)
if (isIntegral!T || isSomeChar!T)
{
    auto r = urng.front;
    urng.popFront();
    static if (T.sizeof <= r.sizeof)
    {
        return cast(T) r;
    }
    else
    {
        static assert(T.sizeof == 8 && r.sizeof == 4);
        T r1 = urng.front | (cast(T)r << 32);
        urng.popFront();
        return r1;
    }
}

/// Ditto
auto uniform(T)()
if (isIntegral!T || isSomeChar!T)
{
    return uniform!T(rndGen);
}

unittest
{
    foreach(T; TypeTuple!(char, wchar, dchar, byte, ubyte, short, ushort,
                          int, uint, long, ulong))
    {
        T init = uniform!T();
        size_t i = 50;
        while (--i && uniform!T() == init) {}
        assert(i > 0);
    }
}

/**
Generates a uniform probability distribution of size $(D n), i.e., an
array of size $(D n) of positive numbers of type $(D F) that sum to
$(D 1). If $(D useThis) is provided, it is used as storage.
 */
F[] uniformDistribution(F = double)(size_t n, F[] useThis = null)
    if(isFloatingPoint!F)
{
    useThis.length = n;
    foreach (ref e; useThis)
    {
        e = uniform(0.0, 1);
    }
    normalize(useThis);
    return useThis;
}

unittest
{
    static assert(is(CommonType!(double, int) == double));
    auto a = uniformDistribution(5);
    enforce(a.length == 5);
    enforce(approxEqual(reduce!"a + b"(a), 1));
    a = uniformDistribution(10, a);
    enforce(a.length == 10);
    enforce(approxEqual(reduce!"a + b"(a), 1));
}

/**
Generates a random floating-point number drawn from a normal (Gaussian)
distribution with specified mean and standard deviation (sigma).

Many different algorithms are available for normal random number generation,
and the optimal choice depends on a variety of different factors [see e.g.
$(LINK2 http://www.cse.cuhk.edu.hk/~phwl/mt/public/archives/papers/grng_acmcs07.pdf,
  Thomas et al. (2007)), $(I ACM Comput. Surv.) $(B 39)(4) 11].  For this reason,
std.random provides a selection of different internal engines implementing different
algorithms.  The default choice is currently a Box-Muller implementation that closely
follows the C++ implementation in Boost.Random.  Alternatives can be specified as
a template parameter.  The function implementations for normal random number generation
use a thread-local static instance of the specified engine type.

Example:

----
// Generate a normally-distributed random number
// with mean 5 and standard deviation 7
auto x = normal(5.0, 7.0);

// Generate a normally-distributed random number
// using the Ziggurat algorithm
auto z = normal!NormalZigguratEngine(5.0, 7.0);
----

The struct implementations for normal random number generation store the mean and
standard deviation and contain their own internal instances of the specified engine.
The convenience function normalRNG() is provided to facilitate construction of Normal
struct instances.

Example:

----
// Create a normal random number generator with mean 0
// and standard deviation 4
auto nrng = normalRNG(0.0, 4.0);

// Generate a number using this generator
auto x = nrng(rndGen);

// Create a normal random number generator that uses
// the Ziggurat algorithm
auto nZig = normalRNG!NormalZigguratEngine(0.0, 4.0);

auto y = nZig(rndGen);
----

Return values for normal random numbers are based on the common type of mean and
standard deviation if at least one is floating point, defaulting to double otherwise.
*/
auto normal(alias NormalRandomNumberEngine = NormalBoxMullerEngine, T1, T2)
(T1 mean, T2 sigma)
if(isNumeric!T1 && isNumeric!T2)
{
    return normal!NormalRandomNumberEngine(mean, sigma, rndGen);
}

private struct StaticInstance(T)
{
    static T instance;

    static if(is(typeof(instance.initialize())))
        static this()
        {
            instance.initialize();
        }
}

/// Ditto
auto normal(alias NormalRandomNumberEngine = NormalBoxMullerEngine, T1, T2,  UniformRandomNumberGenerator)
(T1 mean, T2 sigma, ref UniformRandomNumberGenerator urng)
if (isNumeric!T1 && isNumeric!T2 && isUniformRNG!UniformRandomNumberGenerator)
{
    static if(isFloatingPoint!(CommonType!(T1, T2)))
        alias Unqual!(CommonType!(T1, T2)) ReturnType;
    else
        alias double ReturnType;

    alias StaticInstance!(NormalRandomNumberEngine!ReturnType).instance engine;

    return normal(mean, sigma, urng, engine);
}

/// Ditto
auto normal(UniformRandomNumberGenerator, NormalRandomNumberEngine, T1, T2)
(T1 mean, T2 sigma, ref UniformRandomNumberGenerator urng, ref NormalRandomNumberEngine normalEngine)
if (isNumeric!T1 && isNumeric!T2 && isUniformRNG!UniformRandomNumberGenerator)
{
    enforce(0 <= sigma, text("std.random.normal(): standard deviation ", sigma, " is less than zero"));
    return sigma * normalEngine(urng) + mean;
}

unittest
{
    // Check the type rules for normal()
    assert(is(typeof(normal(0, 1)) == double));
    assert(is(typeof(normal(0.0f, 1.0f)) == float));
    assert(is(typeof(normal(0.0f, 1.0)) == double));
    assert(is(typeof(normal(0.0, 1.0)) == double));
    assert(is(typeof(normal(0.0L, 1.0)) == real));
    assert(is(typeof(normal(0.0L, 1.0L)) == real));

    /* Check that different engines are used for
       double, float and real-valued normal random
       number generation */
    {
        auto rng = Random(0);

        auto normalDouble = normalRNG(0.0, 1.0);
        auto d1 = normalDouble(rng);
        auto d2 = normalDouble(rng);
        assert(is(typeof(d1) == double));
        assert(is(typeof(d2) == double));

        rng.seed(0);
        rng.popFront();
        rng.popFront();
        auto normalFloat = normalRNG(0.0f, 1.0f);
        auto f1 = normalFloat(rng);
        assert(is(typeof(f1) == float));

        rng.seed(0);
        rng.popFront();
        rng.popFront();
        auto normalReal = normalRNG(0.0L, 1.0L);
        auto r1 = normalReal(rng);
        assert(is(typeof(r1) == real));

        rng.seed(0);
        auto t1 = normal(0.0, 1.0, rng);   // these two calls should use
        auto t2 = normal(0.0f, 1.0, rng);  // the same static engine (double)
        assert(is(typeof(t1) == double));
        assert(is(typeof(t2) == double));
        assert(t1 == d1);
        assert(t2 == d2);

        rng.seed(0);
        auto u1 = normal(0.0, 1.0, rng);   // these two calls shoud also use
        auto u2 = normal(0, 1, rng);       // the same static engine (double)
        assert(is(typeof(u1) == double));
        assert(is(typeof(u2) == double));
        assert(u1 == d1);
        assert(u2 == d2);

        rng.seed(0);
        auto v1 = normal(0.0, 1.0, rng);   // should use double engine
        auto v2 = normal(0.0f, 1.0f, rng); // should use new (float) engine
        auto v3 = normal(0.0, 1.0, rng);   // should use double engine
        assert(is(typeof(v1) == double));
        assert(is(typeof(v2) == float));
        assert(v1 == d1);
        assert(v2 != d2);
        assert(v2 == f1);
        assert(v3 == d2);

        rng.seed(0);
        auto w1 = normal(0.0, 1.0, rng);   // should use double engine
        auto w2 = normal(0.0, 1.0L, rng);  // should use new (real) engine
        auto w3 = normal(0.0, 1.0, rng);   // should use double engine
        assert(is(typeof(w1) == double));
        assert(is(typeof(w2) == real));
        assert(w1 == d1);
        assert(w2 != d2);
        assert(w2 != v2);   // because real is higher-precision than float
        assert(w2 == r1);
        assert(w3 == d2);
    }
}

/// Ditto
struct Normal(T = double, alias NormalRandomNumberEngine = NormalBoxMullerEngine)
if (isFloatingPoint!T)
{
    private T _mean, _sigma;
    private NormalRandomNumberEngine!T _engine;

    this(T mean, T sigma)
    {
        enforce(0 <= sigma, text("std.random.normal(): standard deviation ", sigma, " is less than zero"));
        _mean = mean;
        _sigma = sigma;

        static if(is(typeof(_engine.initialize())))
            _engine.initialize();
    }

    @property T mean()
    {
        return _mean;
    }

    @property T stddev()
    {
        return _sigma;
    }

    T opCall(UniformRandomNumberGenerator)(ref UniformRandomNumberGenerator urng)
    if(isUniformRNG!UniformRandomNumberGenerator)
    {
        return _sigma * _engine(urng) + _mean;
    }
}

/// Ditto
auto normalRNG(alias NormalRandomNumberEngine = NormalBoxMullerEngine, T1, T2)
(T1 mean, T2 sigma)
if (isNumeric!T1 && isNumeric!T2)
{
    static if(isFloatingPoint!(CommonType!(T1, T2)))
        alias Unqual!(CommonType!(T1, T2)) ReturnType;
    else
        alias double ReturnType;

    return Normal!(ReturnType, NormalRandomNumberEngine)(mean, sigma);
}

unittest
{
    // Check the type rules for Normal
    {
        auto nrng = normalRNG(0, 1);
        assert(is(typeof(nrng(rndGen)) == double));
    }
    {
        auto nrng = normalRNG(0.0f, 1.0f);
        assert(is(typeof(nrng(rndGen)) == float));
    }
    {
        auto nrng = normalRNG(0.0, 1.0);
        assert(is(typeof(nrng(rndGen)) == double));
    }
    {
        auto nrng = normalRNG(0.0L, 1.0L);
        assert(is(typeof(nrng(rndGen)) == real));
    }
}

/**
Generates a random floating-point number drawn from a
normal (Gaussian) distribution with mean 0 and standard
deviation (sigma) 1, using the Box-Muller Transform method.

This version is closely based on the Boost.Random Box-Muller
implementation by Jens Maurer and Steven Wanatabe, and
should produce identical results within the limits of
floating-point rounding.
*/
struct NormalBoxMullerEngine(T = double)
if(isFloatingPoint!T)
{
    private bool _valid = false;
    private T _rho, _r1, _r2;

    T opCall(UniformRandomNumberGenerator)(ref UniformRandomNumberGenerator urng)
    if(isUniformRNG!UniformRandomNumberGenerator)
    {
        if(_valid)
            _valid = false;
        else
        {
            /* N.B. Traditional Box-Muller asks for random numbers
               in (0, 1], which D can readily provide.  We use this
               form to match the output of Boost.Random. */
            _r1 = fastUniformFloat!T(urng);
            _r2 = fastUniformFloat!T(urng);
            _rho = sqrt(-2 * log((cast(T) 1) - _r2));
            _valid = true;
        }

        return _rho * (_valid ? cos((cast(T) 2) * PI * _r1)
                              : sin((cast(T) 2) * PI * _r1));
    }
}

private template hasCompileTimeMinMax(alias a)
{
    template ct(alias a){ enum ct = a; }

    enum hasCompileTimeMinMax = 
        is(typeof(ct!(a.max))) && is(typeof(ct!(a.min)));
}

private bool isPowerOfTwo(I)(I i){ return (i & (i - 1)) == 0; }

private template rngMask(alias r) 
    if(hasCompileTimeMinMax!r && isPowerOfTwo(r.max - r.min + 1))
{
    enum rngMask = r.max - r.min;
}

private T fastUniformFloat(T, Rng)(ref Rng r)
{
    static if(hasCompileTimeMinMax!r)
    {
        enum denom = 1 / (to!T(1) + r.max - r.min);
        T x = (r.front - r.min) * denom; 
    } 
    else
        T x = cast(T)(r.front - r.min)  / (to!T(1) + r.max - r.min);
    
    r.popFront();
    return x;
}

private int fastUniformInt(int n, Rng)(ref Rng r)
{
    static if(
        is(typeof(rngMask!r)) && isPowerOfTwo(n) && 
        (rngMask!r & (n - 1)) == n - 1)
    {
        auto x = (r.front - r.min) & (n - 1);
        r.popFront();
        return x;
    }
    else 
        return uniform(0, n, r);
}

private void fastUniformIntAndFloat(int n, T, Rng)(ref Rng r, ref int i, ref T a)
{
    static if(
        is(typeof(rngMask!r)) && isPowerOfTwo(n) && 
        bsr(rngMask!r) >= bsr(n - 1) + T.mant_dig)
    {
        auto rand = r.front - r.min;
        r.popFront(); 
        i = rand & (n - 1);
        enum denom = 1 / (to!T(1) + r.max - r.min);
        a = rand * denom;
    }
    else
    {
        i = fastUniformInt!n(r);
        a = fastUniformFloat!T(r);
    }
}

private auto intervalMinMax(alias f, alias fderiv, T)(T x0, T x1)
{
    T d0 = fderiv(x0), d1 = fderiv(x1);
    if(d0 * d1 < 0)
    {
        auto ex = f(findRoot((T x) => fderiv(x), x0, x1));
        return tuple(min(0, ex), max(0, ex)) ;
    }

    T y0 = f(x0), y1 = f(x1);
    while(true)
    {
        T xmid = 0.5 * (x0 + x1);
        T dmid = fderiv(xmid);
        if(dmid * d0 < 0)
        {
            auto ex0 = f(findRoot((T x) => fderiv(x), x0, xmid));
            auto ex1 = f(findRoot((T x) => fderiv(x), xmid, x1));
            return tuple(min(ex0, ex1), max(ex0, ex1));
        }

        T ymid = f(xmid);
        if((ymid - y0) * d0 > 0)
        {
            x0 = xmid;
            y0 = ymid;
            d0 = dmid;
        }
        else
        {
            x1 = xmid;
            y1 = ymid;
            d1 = dmid;
        }
   
        // this can happen if the function is completelly flat on the interval
        // this happens when called from zigguratInitialize using 256 layers 
        // and single precision.
        enforce(x0 == x1, "fderiv has the same sign on the entire interval");
    }
}

// Struct that stores informathion about the layer used in Ziggurat algorithm
// (see http://en.wikipedia.org/wiki/Ziggurat_algorithm)
private struct ZigguratLayer(T)
{
    // X coordinate of the cros section of upper layer bound and f
    T x;

    // Upper bound of an interval from which we will select x
    T xInterval;
   
    // We store lowOffset and highOffset in order to avoid having to compute
    // the normal function in most cases. The two numbers are defined as
    // follows:
    // Consider the rectangle R whose upper left corner is the cross-section
    // between the upper layer bound and f (where f is the distribution we are
    // generating), and whose lower right corner is the cros section between 
    // the lower layer bound and f. I will refer to this rectangle as the outer
    // layer area in the comments below. Let's define k and y0 so that 
    // y0 - k * x is the diagonal from the upper left corner to the lower right.
    // Now let's define xh as the smallest such number that y0 - k * (x - xh) is
    // greater than or equal to f(x) for all x in R. Also define xl as the 
    // smallest number such that y0 - k * (x + xh) is less than or equal to f(x)
    // for all x in R. Then lowOffset is xl / a and highOffset is xh / a, where
    // a is the width of R.
    T lowOffset;
    
    T highOffset;
}

// Initializes layers for generating the distribution described by f,
// with integral fint, derivative fderiv and total area totalArea.
private auto zigguratInitialize(T, U, F)
(ZigguratLayer!(T)[] layers, U totalArea,
    F f, F fint, F fderiv)
{
    // Returns the x coordinate of the cross section between the upper 
    // layer bound and f. Layer bounds are chosen so that the uppermost
    // layer and the lowermost layer have area totalArea / (2 * layers.length)
    // each and all the other layers have area totalArea / layers.length.
    auto zigguratInnerWidth(int i, int nlayers, U totalArea)
    {
        auto ai = totalArea * (cast(U)(nlayers - (i + 1)) + cast(U)0.5) / nlayers;
        auto func = (U x) => fint(x) - x * f(x) - ai; 

        U x0 = 0;
        U x1= 1;

        while(func(x1) < 0)
            x1 += x1;

        return findRoot(func, x0, x1);
    }

    auto zigguratOffsets(U x0, U x1)
    {
        auto y0 = f(x0), y1 = f(x1);
        auto k = (y1 - y0) / (x1 - x0);
        auto n = y0 - x0*k;
        auto mm = intervalMinMax!(
            (U x) => f(x) - (k * x + n), 
            (U x) => fderiv(x) - k)(x0, x1);

        return tuple(-mm[0] / k, -mm[1] / k);
    }

    alias ZigguratLayer!(T) L; 
    auto nlayers = cast(int) layers.length;

    U yprev = 0;
    U xprev;
    foreach(i; 0 .. nlayers)
    {
        U x = zigguratInnerWidth(i, nlayers, totalArea);
        U y = f(x);
        U dy = y - yprev;
        U innerArea = x * dy;
        U xInterval = x * (totalArea / nlayers) / innerArea;
        U dx = xprev - x;
        U scaleY = dy / dx;

        // Index 0 represents both the uppermost and the lowermost layer.
        // We do not compute highOffset and lowOffset for those layers.
        // lowOffset field is reused for a different purpose - we store 
        // xInterval / 2 in it, so that x, randomly chosen between 0 and 
        // xInterval can be used to select between the lowermost and
        // the uppermost layer.
        if(i == 0)
            layers[i] = L(x, xInterval, xInterval / 2, U.nan);
        else
        {
            auto tmp = zigguratOffsets(x, xprev);
            layers[i] = L(x, xInterval, tmp[0] / dx, tmp[1] / dx);
        }
 
        yprev = y;
        xprev = x;
    }
}

private template fraction(T, alias a, alias b)
{
    enum fraction = cast(T) a / cast(T) b;
}

// The implementation of the ziggurat algorithm. Only works on functions
// that are only defined for x > 0. Layer must be a random number between 0
// and zs.nlayers.length and x must be a random number between 0 and 1. For
// the other parameters, see zigguratAlgorithm below.
private auto zigguratAlgorithmImpl
(alias f, alias tail, alias head, alias zs, alias rng)
(int layer, ReturnType!f x) 
{
    alias ReturnType!f T;
    
    x *= zs.layers[layer].xInterval;
    T layerX = zs.layers[layer].x;
    if(x < layerX)
        return x;

    // we must choosee between the topmost and the bottomost later. 
    if(layer == 0)
    {
        if(x < zs.layers[layer].lowOffset)
            // choose the bottomost layer. if x was smaller than layerX,
            // we would have already returned it above, so we know that we
            // ned to choose from the tail here
            return tail(layerX, rng);
        else 
            return head(rng);
    }

    T dx = zs.layers[layer - 1].x - layerX;
    T highOffset = zs.layers[layer].highOffset;
    T lowOffset = zs.layers[layer].lowOffset;
    T uInterval = 1 + highOffset;

    while(true)
    {
        // Choose a random point in the triangle described by
        // ux > 0, uy > -1, uy < highOffset - ux 
        T uy = uInterval * fastUniformFloat!T(rng);
        T ux = uInterval * fastUniformFloat!T(rng);
      
        T tmp = max(ux, uy);
        ux = min(ux, uy);
        uy = highOffset - tmp;

        x = layerX + ux * dx;

        // Force uy to be less than zero and ux to be less than one. This is
        // equivalent to randomly choosing a point in the outer layer area
        // with y < y0 - k * (x - xh) (See the comments for ZigguratLayer)
        if(uy > 0 || ux > 1)
            continue; 

        // This is equivalen to checking that y < y0 - k * (x + xl) 
        // (See the comments for ZigguratLayer). If that is true,
        // y must also be below f, so we don't need to compute f. 
        if(uy < lowOffset - ux)
            return x;
    
        T layerY = f(layerX);
        T dy = layerY - f(layerX + dx);
        T y = layerY + uy * dy;
        if(y < f(x))
            return x;
    }
}

// Returns a random sample using the ziggurat algorithm. f is the distribution,
// tail is the function used to select a sample from the tail area, head
// is the function used to select a sample from the uppermost layer, zs must 
// be something with layers property and zs.layers must be an array of 
// ZigguratLayer.
private auto zigguratAlgorithm
(alias f, alias tail, alias head, alias zs, bool isSymetric, alias rng)()
{
    alias ReturnType!f T;

    int rand;
    T a;
    // choose rand between below 2 * zs.nlayers. This gives us one
    // extra random bit which we will use to choose the sign
    fastUniformIntAndFloat!(2 * zs.nlayers)(rng, rand, a);
 
    auto r = zigguratAlgorithmImpl!(
        f, tail, head, zs, rng)(rand >> 1, a);
 
    static if(isSymetric)
    {
        // randomly choose a sign
        // flip the highest bit to change the sign, if possible
        static if(is(T == float))
        {
            auto rint = (rand << 31) ^ *cast(uint*) &r;
            return *cast(T*) &rint;
        }
        else static if(is(T == double) && is(size_t == ulong))
        {
            auto rint = (cast(ulong)rand << 63) ^ *cast(ulong*) &r;
            return *cast(T*) &rint;
        }
        else
            return rand & 1 ? r : -r;
    }
    else
        return r;
}

/**
Generates a random floating-point number drawn from a
normal (Gaussian) distribution with mean 0 and standard
deviation (sigma) 1, using the Ziggurat algorithm.

This engine has high sampling speed, but uses more memory (a kilobyte or so) 
than the alternatives and has a relatively long initialization time (somewhere 
around a millisecond on a modern X86 CPU).
 */
struct NormalZigguratEngine(T) if(isFloatingPoint!T)
{
    // use 128 layers - I found this to be the best size / performance
    // trade off. We could have multiple NormalZigguratEngines with 
    // different numbers of layers, but if the user isn't willing to trade
    // initialization time and size for sampling speed, he should use
    // some other engine, like Box-Muller
    enum int n = 128;

    /// Initializes the engine. This must be called before the first call to
    /// opCall
    void initialize()
    {
        alias Select!(is(T == float), double, T) U;

        static U f(U x)
        {
            return exp(-x ^^ 2 / 2) / sqrt(2 * PI);
        }

        static U fint(U x)
        {
            return erf(x / sqrt(2.0)) / 2 ;
        }

        static U fderiv(U x)
        {
            return -x * exp(-x ^^ 2 / 2) / sqrt(2 * PI);
        }

        layers = new L[nlayers];
        zigguratInitialize!(T, U)( layers,  0.5, &f, &fint, &fderiv); 
        
        headDx = layers.back.x;
        headDy = cast(T) 1 - exp(- (headDx) ^^ 2 * cast(T) 0.5);
    }
    
    /// Computes a random sample using rng 
    T opCall(Rng)(ref Rng rng)
    if(isUniformRNG!Rng)
    {
        return zigguratAlgorithm!(f, tail, head, this, true, rng)();
    }
  
    private:

    static T f(T x)
    {
        return exp(-x ^^ 2 / 2) / sqrt(2 * PI);
    }

    enum nlayers = n;
    alias ZigguratLayer!T L;

    L[] layers;
    T headDx;
    T headDy;

    auto head(Rng)(ref Rng rng)
    {
        while(true)
        {
            T x = fastUniformFloat!T(rng) * headDx;
            T y = fastUniformFloat!T(rng) * headDy;
            T x2 = x * x;
            // An approximation for 1 - f  using one term of the Taylor series. 
            // This is an upper bound.
            T approx = fraction!(T, 1, 2) * x2;
            if(y > approx)
                return x;

            // An approximation using two terms of the Taylor series
            // This is a lower bound.
            approx -= fraction!(T, 1, 8) * x2 * x2;
            if(y > approx && y > cast(T) 1 - exp(-x * x * cast(T) 0.5))
                return x;
        }
    }
   
    static T tail(Rng)(T x0, ref Rng rng)
    {
        // the new Marsaglia Tail Method
        while(true)
        {
            T x = -log(fastUniformFloat!T(rng)) / x0;
            T y = -log(fastUniformFloat!T(rng));
            if(y + y > x * x)
                return x0 + x;
        }
    }
}

/**
Shuffles elements of $(D r) using $(D gen) as a shuffler. $(D r) must be
a random-access range with length.
 */

void randomShuffle(Range, RandomGen = Random)(Range r,
                                              ref RandomGen gen = rndGen)
    if(isRandomAccessRange!Range && isUniformRNG!RandomGen)
{
    return partialShuffle!(Range, RandomGen)(r, r.length, gen);
}

unittest
{
    // Also tests partialShuffle indirectly.
    auto a = ([ 1, 2, 3, 4, 5, 6, 7, 8, 9 ]).dup;
    auto b = a.dup;
    Mt19937 gen;
    randomShuffle(a, gen);
    assert(a.sort == b.sort);
    randomShuffle(a);
    assert(a.sort == b.sort);
}

/**
Partially shuffles the elements of $(D r) such that upon returning $(D r[0..n]) 
is a random subset of $(D r) and is randomly ordered.  $(D r[n..r.length]) 
will contain the elements not in $(D r[0..n]).  These will be in an undefined 
order, but will not be random in the sense that their order after 
$(D partialShuffle) returns will not be independent of their order before 
$(D partialShuffle) was called.

$(D r) must be a random-access range with length.  $(D n) must be less than
or equal to $(D r.length).  
*/
void partialShuffle(Range, RandomGen = Random)(Range r, size_t n,
                                              ref RandomGen gen = rndGen)
    if(isRandomAccessRange!Range && isUniformRNG!RandomGen)
{
    enforce(n <= r.length, "n must be <= r.length for partialShuffle.");
    foreach (i; 0 .. n)
    {
        swapAt(r, i, i + uniform(0, r.length - i, gen));
    }
}

/**
Rolls a dice with relative probabilities stored in $(D
proportions). Returns the index in $(D proportions) that was chosen.

Example:

----
auto x = dice(0.5, 0.5);   // x is 0 or 1 in equal proportions
auto y = dice(50, 50);     // y is 0 or 1 in equal proportions
auto z = dice(70, 20, 10); // z is 0 70% of the time, 1 20% of the time,
                           // and 2 10% of the time
----
*/
size_t dice(Rng, Num)(ref Rng rnd, Num[] proportions...)
if (isNumeric!Num && isForwardRange!Rng)
{
    return diceImpl(rnd, proportions);
}

/// Ditto
size_t dice(R, Range)(ref R rnd, Range proportions)
if (isForwardRange!Range && isNumeric!(ElementType!Range) && !isArray!Range)
{
    return diceImpl(rnd, proportions);
}

/// Ditto
size_t dice(Range)(Range proportions)
if (isForwardRange!Range && isNumeric!(ElementType!Range) && !isArray!Range)
{
    return diceImpl(rndGen, proportions);
}

/// Ditto
size_t dice(Num)(Num[] proportions...)
if (isNumeric!Num)
{
    return diceImpl(rndGen, proportions);
}

private size_t diceImpl(Rng, Range)(ref Rng rng, Range proportions)
if (isForwardRange!Range && isNumeric!(ElementType!Range) && isForwardRange!Rng)
{
    double sum = reduce!("(assert(b >= 0), a + b)")(0.0, proportions.save);
    enforce(sum > 0, "Proportions in a dice cannot sum to zero");
    immutable point = uniform(0.0, sum, rng);
    assert(point < sum);
    auto mass = 0.0;

    size_t i = 0;
    foreach (e; proportions)
    {
        mass += e;
        if (point < mass) return i;
        i++;
    }
    // this point should not be reached
    assert(false);
}

unittest
{
    auto rnd = Random(unpredictableSeed);
    auto i = dice(rnd, 0.0, 100.0);
    assert(i == 1);
    i = dice(rnd, 100.0, 0.0);
    assert(i == 0);

    i = dice(100U, 0U);
    assert(i == 0);
}

/**
Covers a given range $(D r) in a random manner, i.e. goes through each
element of $(D r) once and only once, just in a random order. $(D r)
must be a random-access range with length.

Example:
----
int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8 ];
auto rnd = Random(unpredictableSeed);
foreach (e; randomCover(a, rnd))
{
    writeln(e);
}
----
 */
struct RandomCover(Range, Random)
    if(isRandomAccessRange!Range && isUniformRNG!Random)
{
    private Range _input;
    private Random _rnd;
    private bool[] _chosen;
    private uint _current;
    private uint _alreadyChosen;

    this(Range input, Random rnd)
    {
        _input = input;
        _rnd = rnd;
        _chosen.length = _input.length;
        popFront();
    }

    static if (hasLength!Range)
        @property size_t length()
        {
            return (1 + _input.length) - _alreadyChosen;
        }

    @property auto ref front()
    {
        return _input[_current];
    }

    void popFront()
    {
        if (_alreadyChosen >= _input.length)
        {
            // No more elements
            ++_alreadyChosen; // means we're done
            return;
        }
        size_t k = _input.length - _alreadyChosen;
        uint i;
        foreach (e; _input)
        {
            if (_chosen[i]) { ++i; continue; }
            // Roll a dice with k faces
            auto chooseMe = uniform(0, k, _rnd) == 0;
            assert(k > 1 || chooseMe);
            if (chooseMe)
            {
                _chosen[i] = true;
                _current = i;
                ++_alreadyChosen;
                return;
            }
            --k;
            ++i;
        }
        assert(false);
    }

    @property typeof(this) save()
    {
        auto ret = this;
        ret._input = _input.save;
        ret._rnd = _rnd.save;
        return ret;
    }

    @property bool empty() { return _alreadyChosen > _input.length; }
}

/// Ditto
RandomCover!(Range, Random) randomCover(Range, Random)(Range r, Random rnd)
    if(isRandomAccessRange!Range && isUniformRNG!Random)
{
    return typeof(return)(r, rnd);
}

unittest
{
    int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8 ];
    auto rnd = Random(unpredictableSeed);
    RandomCover!(int[], Random) rc = randomCover(a, rnd);
    static assert(isForwardRange!(typeof(rc)));

    int[] b = new int[9];
    uint i;
    foreach (e; rc)
    {
        //writeln(e);
        b[i++] = e;
    }
    sort(b);
    assert(a == b, text(b));
}

// RandomSample
/**
Selects a random subsample out of $(D r), containing exactly $(D n)
elements. The order of elements is the same as in the original
range. The total length of $(D r) must be known. If $(D total) is
passed in, the total number of sample is considered to be $(D
total). Otherwise, $(D RandomSample) uses $(D r.length).

If the number of elements is not exactly $(D total), $(D
RandomSample) throws an exception. This is because $(D total) is
essential to computing the probability of selecting elements in the
range.

Example:
----
int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ];
// Print 5 random elements picked off from a
foreach (e; randomSample(a, 5))
{
    writeln(e);
}
----

$(D RandomSample) implements Jeffrey Scott Vitter's Algorithm D
(see Vitter $(WEB dx.doi.org/10.1145/358105.893, 1984), $(WEB
dx.doi.org/10.1145/23002.23003, 1987)), which selects a sample
of size $(D n) in O(n) steps and requiring O(n) random variates,
regardless of the size of the data being sampled.
*/
struct RandomSample(R, Random = void)
    if(isInputRange!R && (isUniformRNG!Random || is(Random == void)))
{
    private size_t _available, _toSelect;
    private immutable ushort _alphaInverse = 13; // Vitter's recommended value.
    private bool _first, _algorithmA;
    private double _Vprime;
    private R _input;
    private size_t _index;

    // If we're using the default thread-local random number generator then
    // we shouldn't store a copy of it here.  Random == void is a sentinel
    // for this.  If we're using a user-specified generator then we have no
    // choice but to store a copy.
    static if(!is(Random == void))
    {
        Random _gen;

        static if (hasLength!R)
        {
            this(R input, size_t howMany, Random gen)
            {
                _gen = gen;
                initialize(input, howMany, input.length);
            }
        }

        this(R input, size_t howMany, size_t total, Random gen)
        {
            _gen = gen;
            initialize(input, howMany, total);
        }
    }
    else
    {
        static if (hasLength!R)
        {
            this(R input, size_t howMany)
            {
                initialize(input, howMany, input.length);
            }
        }

        this(R input, size_t howMany, size_t total)
        {
            initialize(input, howMany, total);
        }
    }

    private void initialize(R input, size_t howMany, size_t total)
    {
        _input = input;
        _available = total;
        _toSelect = howMany;
        enforce(_toSelect <= _available);
        _first = true;
    }

/**
   Range primitives.
*/
    @property bool empty() const
    {
        return _toSelect == 0;
    }

    @property auto ref front()
    {
        assert(!empty);
        // The first sample point must be determined here to avoid
        // having it always correspond to the first element of the
        // input.  The rest of the sample points are determined each
        // time we call popFront().
        if(_first)
        {
            // We can save ourselves a random variate by checking right
            // at the beginning if we should use Algorithm A.
            if((_alphaInverse * _toSelect) > _available)
            {
                _algorithmA = true;
            }
            else
            {
                _Vprime = newVprime(_toSelect);
                _algorithmA = false;
            }
            prime();
            _first = false;
        }
        return _input.front;
    }

/// Ditto
    void popFront()
    {
        _input.popFront();
        --_available;
        --_toSelect;
        ++_index;
        prime();
    }

/// Ditto
    @property typeof(this) save()
    {
        auto ret = this;
        ret._input = _input.save;
        return ret;
    }

/// Ditto
    @property size_t length()
    {
        return _toSelect;
    }

/**
Returns the index of the visited record.
 */
    size_t index()
    {
        return _index;
    }

/*
Vitter's Algorithm A, used when the ratio of needed sample values
to remaining data values is sufficiently large.
*/
    private size_t skipA()
    {
        size_t s;
        double v, quot, top;

        if(_toSelect==1)
        {
            static if(is(Random==void))
            {
                s = uniform(0, _available);
            }
            else
            {
                s = uniform(0, _available, _gen);
            }
        }
        else
        {
            v = 0;
            top = _available - _toSelect;
            quot = top / _available;

            static if(is(Random==void))
            {
                v = uniform!"()"(0.0, 1.0);
            }
            else
            {
                v = uniform!"()"(0.0, 1.0, _gen);
            }

            while (quot > v)
            {
                ++s;
                quot *= (top - s) / (_available - s);
            }
        }

        return s;
    }

/*
Randomly reset the value of _Vprime.
*/
    private double newVprime(size_t remaining)
    {
        static if(is(Random == void))
        {
            double r = uniform!"()"(0.0, 1.0);
        }
        else
        {
            double r = uniform!"()"(0.0, 1.0, _gen);
        }

        return r ^^ (1.0 / remaining);
    }

/*
Vitter's Algorithm D.  For an extensive description of the algorithm
and its rationale, see:

  * Vitter, J.S. (1984), "Faster methods for random sampling",
    Commun. ACM 27(7): 703--718

  * Vitter, J.S. (1987) "An efficient algorithm for sequential random
    sampling", ACM Trans. Math. Softw. 13(1): 58-67.

Variable names are chosen to match those in Vitter's paper.
*/
    private size_t skip()
    {
        // Step D1: if the number of points still to select is greater
        // than a certain proportion of the remaining data points, i.e.
        // if n >= alpha * N where alpha = 1/13, we carry out the
        // sampling with Algorithm A.
        if(_algorithmA)
        {
            return skipA();
        }
        else if((_alphaInverse * _toSelect) > _available)
        {
            _algorithmA = true;
            return skipA();
        }
        // Otherwise, we use the standard Algorithm D mechanism.
        else if ( _toSelect > 1 )
        {
            size_t s;
            size_t qu1 = 1 + _available - _toSelect;
            double x, y1;

            while(true)
            {
                // Step D2: set values of x and u.
                for(x = _available * (1-_Vprime), s = cast(size_t) trunc(x);
                    s >= qu1;
                    x = _available * (1-_Vprime), s = cast(size_t) trunc(x))
                {
                    _Vprime = newVprime(_toSelect);
                }

                static if(is(Random == void))
                {
                    double u = uniform!"()"(0.0, 1.0);
                }
                else
                {
                    double u = uniform!"()"(0.0, 1.0, _gen);
                }

                y1 = (u * (cast(double) _available) / qu1) ^^ (1.0/(_toSelect - 1));

                _Vprime = y1 * ((-x/_available)+1.0) * ( qu1/( (cast(double) qu1) - s ) );

                // Step D3: if _Vprime <= 1.0 our work is done and we return S.
                // Otherwise ...
                if(_Vprime > 1.0)
                {
                    size_t top = _available - 1, limit;
                    double y2 = 1.0, bottom;

                    if(_toSelect > (s+1) )
                    {
                        bottom = _available - _toSelect;
                        limit = _available - s;
                    }
                    else
                    {
                        bottom = _available - (s+1);
                        limit = qu1;
                    }

                    foreach(size_t t; limit.._available)
                    {
                        y2 *= top/bottom;
                        top--;
                        bottom--;
                    }

                    // Step D4: decide whether or not to accept the current value of S.
                    if( (_available/(_available-x)) < (y1 * (y2 ^^ (1.0/(_toSelect-1)))) )
                    {
                        // If it's not acceptable, we generate a new value of _Vprime
                        // and go back to the start of the for(;;) loop.
                        _Vprime = newVprime(_toSelect);
                    }
                    else
                    {
                        // If it's acceptable we generate a new value of _Vprime
                        // based on the remaining number of sample points needed,
                        // and return S.
                        _Vprime = newVprime(_toSelect-1);
                        return s;
                    }
                }
                else
                {
                    // Return if condition D3 satisfied.
                    return s;
                }
            }
        }
        else
        {
            // If only one sample point remains to be taken ...
            return cast(size_t) trunc(_available * _Vprime);
        }
    }

    private void prime()
    {
        if (empty) return;
        assert(_available && _available >= _toSelect);
        immutable size_t s = skip();
        _input.popFrontN(s);
        _index += s;
        _available -= s;
        assert(_available > 0);
        return;
    }
}

/// Ditto
auto randomSample(R)(R r, size_t n, size_t total)
if(isInputRange!R)
{
    return RandomSample!(R, void)(r, n, total);
}

/// Ditto
auto randomSample(R)(R r, size_t n)
    if(isInputRange!R && hasLength!R)
{
    return RandomSample!(R, void)(r, n, r.length);
}

/// Ditto
auto randomSample(R, Random)(R r, size_t n, size_t total, Random gen)
if(isInputRange!R && isUniformRNG!Random)
{
    return RandomSample!(R, Random)(r, n, total, gen);
}

/// Ditto
auto randomSample(R, Random)(R r, size_t n, Random gen)
if (isInputRange!R && hasLength!R && isUniformRNG!Random)
{
    return RandomSample!(R, Random)(r, n, r.length, gen);
}

unittest
{
    Random gen;
    int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ];
    static assert(isForwardRange!(typeof(randomSample(a, 5))));
    static assert(isForwardRange!(typeof(randomSample(a, 5, gen))));

    //int[] a = [ 0, 1, 2 ];
    assert(randomSample(a, 5).length == 5);
    assert(randomSample(a, 5, 10).length == 5);
    assert(randomSample(a, 5, gen).length == 5);
    uint i;
    foreach (e; randomSample(randomCover(a, rndGen), 5))
    {
        ++i;
        //writeln(e);
    }
    assert(i == 5);

    // Bugzilla 8314
    {
        auto sample(uint seed) { return randomSample(a, 1, Random(seed)).front; }

        immutable fst = sample(0);
        uint n;
        while (sample(++n) == fst && n < n.max) {}
        assert(n < n.max);
    }
}
