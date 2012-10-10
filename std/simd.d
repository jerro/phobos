module std.simd;

/*pure:
nothrow:
@safe:*/
import std.stdio;

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
import std.traits, std.typetuple;
import std.range;


///////////////////////////////////////////////////////////////////////////////
// Define available versions of vector hardware
///////////////////////////////////////////////////////////////////////////////

version(X86_OR_X64)
{
	enum SIMDVer
	{
		SSE,
		SSE2,
		SSE3,	// Later Pentium4 + Athlon64
		SSSE3,	// Introduced in Intel 'Core' series, AMD 'Bobcat'
		SSE41,	// (Intel) Introduced in 45nm 'Core' series
		SSE42,	// (Intel) Introduced in i7
		SSE4a,	// (AMD) Introduced to 'Bobcat' (includes SSSE3 and below)
		AVX,	// 128x2/256bit, 3 operand opcodes
		SSE5,	// (AMD) XOP, FMA4 and CVT16. Introduced to 'Bulldozer' (includes ALL prior architectures)
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
		VFP,	// should we implement this? it's deprecated on modern ARM chips
		NEON,	// added to Cortex-A8, Snapdragon
		VFPv4	// added to Cortex-A15
	}

	immutable SIMDVer sseVer = SIMDVer.NEON;
}
else
{
	static assert(0, "Unsupported architecture.");

	// TODO: I think it would be worth emulating this API with pure FPU on unsupported architectures...
}

///////////////////////////////////////////////////////////////////////////////
// LLVM instructions and intrinsics for LDC.
///////////////////////////////////////////////////////////////////////////////

version(LDC)
{
    template RepeatType(T, size_t n, R...)
    {
        static if(n == 0)
            alias R RepeatType;
        else
            alias RepeatType!(T, n - 1, T, R) RepeatType;
    }

    template llvmInstructions(string v)
    {
        enum llvmInstructions = `
            pragma(shufflevector)
                `~v~` shufflevector(`~v~`, `~v~`, RepeatType!(int, `~v~`.init.length));

            pragma(insertelement)
                `~v~` insertelement(`~v~`, typeof(`~v~`.init.ptr[0]), int);

            pragma(extractelement)
                typeof(`~v~`.init.ptr[0]) extractelement(`~v~`, int);`;
    } 

    mixin( 
        llvmInstructions!"float4" ~
        llvmInstructions!"double2" ~
        llvmInstructions!"ubyte16" ~
        llvmInstructions!"byte16" ~
        llvmInstructions!"ushort8" ~
        llvmInstructions!"short8" ~
        llvmInstructions!"uint4" ~
        llvmInstructions!"int4" ~
        llvmInstructions!"ulong2" ~
        llvmInstructions!"long2");

   
    version(X86_OR_X64)
    { 
        // These should probably be in a separate file, possibly distributed
        // with LDC.        

        pragma (intrinsic, "llvm.x86.sse.add.ss")
            float4 __builtin_ia32_addss(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.sub.ss")
            float4 __builtin_ia32_subss(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.mul.ss")
            float4 __builtin_ia32_mulss(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.div.ss")
            float4 __builtin_ia32_divss(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.sqrt.ss")
            float4 __builtin_ia32_sqrtss(float4);

        pragma (intrinsic, "llvm.x86.sse.sqrt.ps")
            float4 __builtin_ia32_sqrtps(float4);

        pragma (intrinsic, "llvm.x86.sse.rcp.ss")
            float4 __builtin_ia32_rcpss(float4);

        pragma (intrinsic, "llvm.x86.sse.rcp.ps")
            float4 __builtin_ia32_rcpps(float4);

        pragma (intrinsic, "llvm.x86.sse.rsqrt.ss")
            float4 __builtin_ia32_rsqrtss(float4);

        pragma (intrinsic, "llvm.x86.sse.rsqrt.ps")
            float4 __builtin_ia32_rsqrtps(float4);

        pragma (intrinsic, "llvm.x86.sse.min.ss")
            float4 __builtin_ia32_minss(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.min.ps")
            float4 __builtin_ia32_minps(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.max.ss")
            float4 __builtin_ia32_maxss(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.max.ps")
            float4 __builtin_ia32_maxps(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.cmp.ss")
            float4 __builtin_ia32_cmpss(float4, float4, byte);

        pragma (intrinsic, "llvm.x86.sse.cmp.ps")
            float4 __builtin_ia32_cmpps(float4, float4, byte);

        pragma (intrinsic, "llvm.x86.sse.comieq.ss")
            int __builtin_ia32_comieq(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.comilt.ss")
            int __builtin_ia32_comilt(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.comile.ss")
            int __builtin_ia32_comile(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.comigt.ss")
            int __builtin_ia32_comigt(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.comige.ss")
            int __builtin_ia32_comige(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.comineq.ss")
            int __builtin_ia32_comineq(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.ucomieq.ss")
            int __builtin_ia32_ucomieq(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.ucomilt.ss")
            int __builtin_ia32_ucomilt(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.ucomile.ss")
            int __builtin_ia32_ucomile(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.ucomigt.ss")
            int __builtin_ia32_ucomigt(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.ucomige.ss")
            int __builtin_ia32_ucomige(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.ucomineq.ss")
            int __builtin_ia32_ucomineq(float4, float4);

        pragma (intrinsic, "llvm.x86.sse.cvtss2si")
            int __builtin_ia32_cvtss2si(float4);

        pragma (intrinsic, "llvm.x86.sse.cvtss2si64")
            long __builtin_ia32_cvtss2si64(float4);

        pragma (intrinsic, "llvm.x86.sse.cvttss2si")
            int __builtin_ia32_cvttss2si(float4);

        pragma (intrinsic, "llvm.x86.sse.cvttss2si64")
            long __builtin_ia32_cvttss2si64(float4);

        pragma (intrinsic, "llvm.x86.sse.cvtsi2ss")
            float4 __builtin_ia32_cvtsi2ss(float4, int);

        pragma (intrinsic, "llvm.x86.sse.cvtsi642ss")
            float4 __builtin_ia32_cvtsi642ss(float4, long);

        pragma (intrinsic, "llvm.x86.sse.storeu.ps")
            void __builtin_ia32_storeups(void*, float4);

        pragma (intrinsic, "llvm.x86.sse.sfence")
            void __builtin_ia32_sfence();

        pragma (intrinsic, "llvm.x86.sse.movmsk.ps")
            int __builtin_ia32_movmskps(float4);

        pragma (intrinsic, "llvm.x86.sse2.add.sd")
            double2 __builtin_ia32_addsd(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.sub.sd")
            double2 __builtin_ia32_subsd(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.mul.sd")
            double2 __builtin_ia32_mulsd(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.div.sd")
            double2 __builtin_ia32_divsd(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.sqrt.sd")
            double2 __builtin_ia32_sqrtsd(double2);

        pragma (intrinsic, "llvm.x86.sse2.sqrt.pd")
            double2 __builtin_ia32_sqrtpd(double2);

        pragma (intrinsic, "llvm.x86.sse2.min.sd")
            double2 __builtin_ia32_minsd(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.min.pd")
            double2 __builtin_ia32_minpd(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.max.sd")
            double2 __builtin_ia32_maxsd(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.max.pd")
            double2 __builtin_ia32_maxpd(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.cmp.sd")
            double2 __builtin_ia32_cmpsd(double2, double2, byte);

        pragma (intrinsic, "llvm.x86.sse2.cmp.pd")
            double2 __builtin_ia32_cmppd(double2, double2, byte);

        pragma (intrinsic, "llvm.x86.sse2.comieq.sd")
            int __builtin_ia32_comisdeq(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.comilt.sd")
            int __builtin_ia32_comisdlt(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.comile.sd")
            int __builtin_ia32_comisdle(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.comigt.sd")
            int __builtin_ia32_comisdgt(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.comige.sd")
            int __builtin_ia32_comisdge(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.comineq.sd")
            int __builtin_ia32_comisdneq(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.ucomieq.sd")
            int __builtin_ia32_ucomisdeq(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.ucomilt.sd")
            int __builtin_ia32_ucomisdlt(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.ucomile.sd")
            int __builtin_ia32_ucomisdle(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.ucomigt.sd")
            int __builtin_ia32_ucomisdgt(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.ucomige.sd")
            int __builtin_ia32_ucomisdge(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.ucomineq.sd")
            int __builtin_ia32_ucomisdneq(double2, double2);

        pragma (intrinsic, "llvm.x86.sse2.padds.b")
            byte16 __builtin_ia32_paddsb128(byte16, byte16);

        pragma (intrinsic, "llvm.x86.sse2.padds.w")
            short8 __builtin_ia32_paddsw128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.paddus.b")
            byte16 __builtin_ia32_paddusb128(byte16, byte16);

        pragma (intrinsic, "llvm.x86.sse2.paddus.w")
            short8 __builtin_ia32_paddusw128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.psubs.b")
            byte16 __builtin_ia32_psubsb128(byte16, byte16);

        pragma (intrinsic, "llvm.x86.sse2.psubs.w")
            short8 __builtin_ia32_psubsw128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.psubus.b")
            byte16 __builtin_ia32_psubusb128(byte16, byte16);

        pragma (intrinsic, "llvm.x86.sse2.psubus.w")
            short8 __builtin_ia32_psubusw128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.pmulhu.w")
            short8 __builtin_ia32_pmulhuw128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.pmulh.w")
            short8 __builtin_ia32_pmulhw128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.pmulu.dq")
            long2 __builtin_ia32_pmuludq128(int4, int4);

        pragma (intrinsic, "llvm.x86.sse2.pmadd.wd")
            int4 __builtin_ia32_pmaddwd128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.pavg.b")
            byte16 __builtin_ia32_pavgb128(byte16, byte16);

        pragma (intrinsic, "llvm.x86.sse2.pavg.w")
            short8 __builtin_ia32_pavgw128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.pmaxu.b")
            byte16 __builtin_ia32_pmaxub128(byte16, byte16);

        pragma (intrinsic, "llvm.x86.sse2.pmaxs.w")
            short8 __builtin_ia32_pmaxsw128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.pminu.b")
            byte16 __builtin_ia32_pminub128(byte16, byte16);

        pragma (intrinsic, "llvm.x86.sse2.pmins.w")
            short8 __builtin_ia32_pminsw128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.psad.bw")
            long2 __builtin_ia32_psadbw128(byte16, byte16);

        pragma (intrinsic, "llvm.x86.sse2.psll.w")
            short8 __builtin_ia32_psllw128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.psll.d")
            int4 __builtin_ia32_pslld128(int4, int4);

        pragma (intrinsic, "llvm.x86.sse2.psll.q")
            long2 __builtin_ia32_psllq128(long2, long2);

        pragma (intrinsic, "llvm.x86.sse2.psrl.w")
            short8 __builtin_ia32_psrlw128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.psrl.d")
            int4 __builtin_ia32_psrld128(int4, int4);

        pragma (intrinsic, "llvm.x86.sse2.psrl.q")
            long2 __builtin_ia32_psrlq128(long2, long2);

        pragma (intrinsic, "llvm.x86.sse2.psra.w")
            short8 __builtin_ia32_psraw128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.psra.d")
            int4 __builtin_ia32_psrad128(int4, int4);

        pragma (intrinsic, "llvm.x86.sse2.pslli.w")
            short8 __builtin_ia32_psllwi128(short8, int);

        pragma (intrinsic, "llvm.x86.sse2.pslli.d")
            int4 __builtin_ia32_pslldi128(int4, int);

        pragma (intrinsic, "llvm.x86.sse2.pslli.q")
            long2 __builtin_ia32_psllqi128(long2, int);

        pragma (intrinsic, "llvm.x86.sse2.psrli.w")
            short8 __builtin_ia32_psrlwi128(short8, int);

        pragma (intrinsic, "llvm.x86.sse2.psrli.d")
            int4 __builtin_ia32_psrldi128(int4, int);

        pragma (intrinsic, "llvm.x86.sse2.psrli.q")
            long2 __builtin_ia32_psrlqi128(long2, int);

        pragma (intrinsic, "llvm.x86.sse2.psrai.w")
            short8 __builtin_ia32_psrawi128(short8, int);

        pragma (intrinsic, "llvm.x86.sse2.psrai.d")
            int4 __builtin_ia32_psradi128(int4, int);

        pragma (intrinsic, "llvm.x86.sse2.psll.dq")
            long2 __builtin_ia32_pslldqi128(long2, int);

        pragma (intrinsic, "llvm.x86.sse2.psrl.dq")
            long2 __builtin_ia32_psrldqi128(long2, int);

        pragma (intrinsic, "llvm.x86.sse2.psll.dq.bs")
            long2 __builtin_ia32_pslldqi128_byteshift(long2, int);

        pragma (intrinsic, "llvm.x86.sse2.psrl.dq.bs")
            long2 __builtin_ia32_psrldqi128_byteshift(long2, int);

        pragma (intrinsic, "llvm.x86.sse2.cvtdq2pd")
            double2 __builtin_ia32_cvtdq2pd(int4);

        pragma (intrinsic, "llvm.x86.sse2.cvtdq2ps")
            float4 __builtin_ia32_cvtdq2ps(int4);

        pragma (intrinsic, "llvm.x86.sse2.cvtpd2dq")
            int4 __builtin_ia32_cvtpd2dq(double2);

        pragma (intrinsic, "llvm.x86.sse2.cvttpd2dq")
            int4 __builtin_ia32_cvttpd2dq(double2);

        pragma (intrinsic, "llvm.x86.sse2.cvtpd2ps")
            float4 __builtin_ia32_cvtpd2ps(double2);

        pragma (intrinsic, "llvm.x86.sse2.cvtps2dq")
            int4 __builtin_ia32_cvtps2dq(float4);

        pragma (intrinsic, "llvm.x86.sse2.cvttps2dq")
            int4 __builtin_ia32_cvttps2dq(float4);

        pragma (intrinsic, "llvm.x86.sse2.cvtps2pd")
            double2 __builtin_ia32_cvtps2pd(float4);

        pragma (intrinsic, "llvm.x86.sse2.cvtsd2si")
            int __builtin_ia32_cvtsd2si(double2);

        pragma (intrinsic, "llvm.x86.sse2.cvtsd2si64")
            long __builtin_ia32_cvtsd2si64(double2);

        pragma (intrinsic, "llvm.x86.sse2.cvttsd2si")
            int __builtin_ia32_cvttsd2si(double2);

        pragma (intrinsic, "llvm.x86.sse2.cvttsd2si64")
            long __builtin_ia32_cvttsd2si64(double2);

        pragma (intrinsic, "llvm.x86.sse2.cvtsi2sd")
            double2 __builtin_ia32_cvtsi2sd(double2, int);

        pragma (intrinsic, "llvm.x86.sse2.cvtsi642sd")
            double2 __builtin_ia32_cvtsi642sd(double2, long);

        pragma (intrinsic, "llvm.x86.sse2.cvtsd2ss")
            float4 __builtin_ia32_cvtsd2ss(float4, double2);

        pragma (intrinsic, "llvm.x86.sse2.cvtss2sd")
            double2 __builtin_ia32_cvtss2sd(double2, float4);

        pragma (intrinsic, "llvm.x86.sse2.storeu.pd")
            void __builtin_ia32_storeupd(void*, double2);

        pragma (intrinsic, "llvm.x86.sse2.storeu.dq")
            void __builtin_ia32_storedqu(void*, byte16);

        pragma (intrinsic, "llvm.x86.sse2.storel.dq")
            void __builtin_ia32_storelv4si(void*, int4);

        pragma (intrinsic, "llvm.x86.sse2.packsswb.128")
            byte16 __builtin_ia32_packsswb128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.packssdw.128")
            short8 __builtin_ia32_packssdw128(int4, int4);

        pragma (intrinsic, "llvm.x86.sse2.packuswb.128")
            byte16 __builtin_ia32_packuswb128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse2.movmsk.pd")
            int __builtin_ia32_movmskpd(double2);

        pragma (intrinsic, "llvm.x86.sse2.pmovmskb.128")
            int __builtin_ia32_pmovmskb128(byte16);

        pragma (intrinsic, "llvm.x86.sse2.maskmov.dqu")
            void __builtin_ia32_maskmovdqu(byte16, byte16, void*);

        pragma (intrinsic, "llvm.x86.sse2.clflush")
            void __builtin_ia32_clflush(void*);

        pragma (intrinsic, "llvm.x86.sse2.lfence")
            void __builtin_ia32_lfence();

        pragma (intrinsic, "llvm.x86.sse2.mfence")
            void __builtin_ia32_mfence();

        pragma (intrinsic, "llvm.x86.sse3.addsub.ps")
            float4 __builtin_ia32_addsubps(float4, float4);

        pragma (intrinsic, "llvm.x86.sse3.addsub.pd")
            double2 __builtin_ia32_addsubpd(double2, double2);

        pragma (intrinsic, "llvm.x86.sse3.hadd.ps")
            float4 __builtin_ia32_haddps(float4, float4);

        pragma (intrinsic, "llvm.x86.sse3.hadd.pd")
            double2 __builtin_ia32_haddpd(double2, double2);

        pragma (intrinsic, "llvm.x86.sse3.hsub.ps")
            float4 __builtin_ia32_hsubps(float4, float4);

        pragma (intrinsic, "llvm.x86.sse3.hsub.pd")
            double2 __builtin_ia32_hsubpd(double2, double2);

        pragma (intrinsic, "llvm.x86.sse3.ldu.dq")
            byte16 __builtin_ia32_lddqu(void*);

        pragma (intrinsic, "llvm.x86.sse3.monitor")
            void __builtin_ia32_monitor(void*, int, int);

        pragma (intrinsic, "llvm.x86.sse3.mwait")
            void __builtin_ia32_mwait(int, int);

        pragma (intrinsic, "llvm.x86.ssse3.phadd.w.128")
            short8 __builtin_ia32_phaddw128(short8, short8);

        pragma (intrinsic, "llvm.x86.ssse3.phadd.d.128")
            int4 __builtin_ia32_phaddd128(int4, int4);

        pragma (intrinsic, "llvm.x86.ssse3.phadd.sw.128")
            short8 __builtin_ia32_phaddsw128(short8, short8);

        pragma (intrinsic, "llvm.x86.ssse3.phsub.w.128")
            short8 __builtin_ia32_phsubw128(short8, short8);

        pragma (intrinsic, "llvm.x86.ssse3.phsub.d.128")
            int4 __builtin_ia32_phsubd128(int4, int4);

        pragma (intrinsic, "llvm.x86.ssse3.phsub.sw.128")
            short8 __builtin_ia32_phsubsw128(short8, short8);

        pragma (intrinsic, "llvm.x86.ssse3.pmadd.ub.sw.128")
            short8 __builtin_ia32_pmaddubsw128(byte16, byte16);

        pragma (intrinsic, "llvm.x86.ssse3.pmul.hr.sw.128")
            short8 __builtin_ia32_pmulhrsw128(short8, short8);

        pragma (intrinsic, "llvm.x86.ssse3.pshuf.b.128")
            byte16 __builtin_ia32_pshufb128(byte16, byte16);

        pragma (intrinsic, "llvm.x86.ssse3.psign.b.128")
            byte16 __builtin_ia32_psignb128(byte16, byte16);

        pragma (intrinsic, "llvm.x86.ssse3.psign.w.128")
            short8 __builtin_ia32_psignw128(short8, short8);

        pragma (intrinsic, "llvm.x86.ssse3.psign.d.128")
            int4 __builtin_ia32_psignd128(int4, int4);

        pragma (intrinsic, "llvm.x86.ssse3.pabs.b.128")
            byte16 __builtin_ia32_pabsb128(byte16);

        pragma (intrinsic, "llvm.x86.ssse3.pabs.w.128")
            short8 __builtin_ia32_pabsw128(short8);

        pragma (intrinsic, "llvm.x86.ssse3.pabs.d.128")
            int4 __builtin_ia32_pabsd128(int4);

        pragma (intrinsic, "llvm.x86.sse41.round.ss")
            float4 __builtin_ia32_roundss(float4, float4, int);

        pragma (intrinsic, "llvm.x86.sse41.round.ps")
            float4 __builtin_ia32_roundps(float4, int);

        pragma (intrinsic, "llvm.x86.sse41.round.sd")
            double2 __builtin_ia32_roundsd(double2, double2, int);

        pragma (intrinsic, "llvm.x86.sse41.round.pd")
            double2 __builtin_ia32_roundpd(double2, int);

        pragma (intrinsic, "llvm.x86.sse41.pmovsxbd")
            int4 __builtin_ia32_pmovsxbd128(byte16);

        pragma (intrinsic, "llvm.x86.sse41.pmovsxbq")
            long2 __builtin_ia32_pmovsxbq128(byte16);

        pragma (intrinsic, "llvm.x86.sse41.pmovsxbw")
            short8 __builtin_ia32_pmovsxbw128(byte16);

        pragma (intrinsic, "llvm.x86.sse41.pmovsxdq")
            long2 __builtin_ia32_pmovsxdq128(int4);

        pragma (intrinsic, "llvm.x86.sse41.pmovsxwd")
            int4 __builtin_ia32_pmovsxwd128(short8);

        pragma (intrinsic, "llvm.x86.sse41.pmovsxwq")
            long2 __builtin_ia32_pmovsxwq128(short8);

        pragma (intrinsic, "llvm.x86.sse41.pmovzxbd")
            int4 __builtin_ia32_pmovzxbd128(byte16);

        pragma (intrinsic, "llvm.x86.sse41.pmovzxbq")
            long2 __builtin_ia32_pmovzxbq128(byte16);

        pragma (intrinsic, "llvm.x86.sse41.pmovzxbw")
            short8 __builtin_ia32_pmovzxbw128(byte16);

        pragma (intrinsic, "llvm.x86.sse41.pmovzxdq")
            long2 __builtin_ia32_pmovzxdq128(int4);

        pragma (intrinsic, "llvm.x86.sse41.pmovzxwd")
            int4 __builtin_ia32_pmovzxwd128(short8);

        pragma (intrinsic, "llvm.x86.sse41.pmovzxwq")
            long2 __builtin_ia32_pmovzxwq128(short8);

        pragma (intrinsic, "llvm.x86.sse41.phminposuw")
            short8 __builtin_ia32_phminposuw128(short8);

        pragma (intrinsic, "llvm.x86.sse41.pmaxsb")
            byte16 __builtin_ia32_pmaxsb128(byte16, byte16);

        pragma (intrinsic, "llvm.x86.sse41.pmaxsd")
            int4 __builtin_ia32_pmaxsd128(int4, int4);

        pragma (intrinsic, "llvm.x86.sse41.pmaxud")
            int4 __builtin_ia32_pmaxud128(int4, int4);

        pragma (intrinsic, "llvm.x86.sse41.pmaxuw")
            short8 __builtin_ia32_pmaxuw128(short8, short8);

        pragma (intrinsic, "llvm.x86.sse41.pminsb")
            byte16 __builtin_ia32_pminsb128(byte16, byte16);

        pragma (intrinsic, "llvm.x86.sse41.pminsd")
            int4 __builtin_ia32_pminsd128(int4, int4);

        pragma (intrinsic, "llvm.x86.sse41.pminud")
            int4 __builtin_ia32_pminud128(int4, int4);

        pragma (intrinsic, "llvm.x86.sse41.pminuw")
            short8 __builtin_ia32_pminuw128(short8, short8);

        pragma (intrinsic, "llvm.x86.aesni.aesimc")
            long2 __builtin_ia32_aesimc128(long2);

        pragma (intrinsic, "llvm.x86.aesni.aesenc")
            long2 __builtin_ia32_aesenc128(long2, long2);

        pragma (intrinsic, "llvm.x86.aesni.aesenclast")
            long2 __builtin_ia32_aesenclast128(long2, long2);

        pragma (intrinsic, "llvm.x86.aesni.aesdec")
            long2 __builtin_ia32_aesdec128(long2, long2);

        pragma (intrinsic, "llvm.x86.aesni.aesdeclast")
            long2 __builtin_ia32_aesdeclast128(long2, long2);

        pragma (intrinsic, "llvm.x86.aesni.aeskeygenassist")
            long2 __builtin_ia32_aeskeygenassist128(long2, byte);

        pragma (intrinsic, "llvm.x86.sse41.packusdw")
            short8 __builtin_ia32_packusdw128(int4, int4);

        pragma (intrinsic, "llvm.x86.sse41.pmuldq")
            long2 __builtin_ia32_pmuldq128(int4, int4);

        pragma (intrinsic, "llvm.x86.sse41.extractps")
            int __builtin_ia32_extractps128(float4, int);

        pragma (intrinsic, "llvm.x86.sse41.insertps")
            float4 __builtin_ia32_insertps128(float4, float4, int);

        pragma (intrinsic, "llvm.x86.sse41.pblendvb")
            byte16 __builtin_ia32_pblendvb128(byte16, byte16, byte16);

        pragma (intrinsic, "llvm.x86.sse41.pblendw")
            short8 __builtin_ia32_pblendw128(short8, short8, int);

        pragma (intrinsic, "llvm.x86.sse41.blendpd")
            double2 __builtin_ia32_blendpd(double2, double2, int);

        pragma (intrinsic, "llvm.x86.sse41.blendps")
            float4 __builtin_ia32_blendps(float4, float4, int);

        pragma (intrinsic, "llvm.x86.sse41.blendvpd")
            double2 __builtin_ia32_blendvpd(double2, double2, double2);

        pragma (intrinsic, "llvm.x86.sse41.blendvps")
            float4 __builtin_ia32_blendvps(float4, float4, float4);

        pragma (intrinsic, "llvm.x86.sse41.dppd")
            double2 __builtin_ia32_dppd(double2, double2, int);

        pragma (intrinsic, "llvm.x86.sse41.dpps")
            float4 __builtin_ia32_dpps(float4, float4, int);

        pragma (intrinsic, "llvm.x86.sse41.mpsadbw")
            short8 __builtin_ia32_mpsadbw128(byte16, byte16, int);

        pragma (intrinsic, "llvm.x86.sse41.movntdqa")
            long2 __builtin_ia32_movntdqa(void*);

        pragma (intrinsic, "llvm.x86.sse41.ptestz")
            int __builtin_ia32_ptestz128(long2, long2);

        pragma (intrinsic, "llvm.x86.sse41.ptestc")
            int __builtin_ia32_ptestc128(long2, long2);

        pragma (intrinsic, "llvm.x86.sse41.ptestnzc")
            int __builtin_ia32_ptestnzc128(long2, long2);

        pragma (intrinsic, "llvm.x86.sse42.crc32.32.8")
            int __builtin_ia32_crc32qi(int, byte);

        pragma (intrinsic, "llvm.x86.sse42.crc32.32.16")
            int __builtin_ia32_crc32hi(int, short);

        pragma (intrinsic, "llvm.x86.sse42.crc32.32.32")
            int __builtin_ia32_crc32si(int, int);

        pragma (intrinsic, "llvm.x86.sse42.crc32.64.64")
            long __builtin_ia32_crc32di(long, long);

        pragma (intrinsic, "llvm.x86.sse42.pcmpistrm128")
            byte16 __builtin_ia32_pcmpistrm128(byte16, byte16, byte);

        pragma (intrinsic, "llvm.x86.sse42.pcmpistri128")
            int __builtin_ia32_pcmpistri128(byte16, byte16, byte);

        pragma (intrinsic, "llvm.x86.sse42.pcmpistria128")
            int __builtin_ia32_pcmpistria128(byte16, byte16, byte);

        pragma (intrinsic, "llvm.x86.sse42.pcmpistric128")
            int __builtin_ia32_pcmpistric128(byte16, byte16, byte);

        pragma (intrinsic, "llvm.x86.sse42.pcmpistrio128")
            int __builtin_ia32_pcmpistrio128(byte16, byte16, byte);

        pragma (intrinsic, "llvm.x86.sse42.pcmpistris128")
            int __builtin_ia32_pcmpistris128(byte16, byte16, byte);

        pragma (intrinsic, "llvm.x86.sse42.pcmpistriz128")
            int __builtin_ia32_pcmpistriz128(byte16, byte16, byte);

        pragma (intrinsic, "llvm.x86.sse42.pcmpestrm128")
            byte16 __builtin_ia32_pcmpestrm128(byte16, int, byte16, int, byte);

        pragma (intrinsic, "llvm.x86.sse42.pcmpestri128")
            int __builtin_ia32_pcmpestri128(byte16, int, byte16, int, byte);

        pragma (intrinsic, "llvm.x86.sse42.pcmpestria128")
            int __builtin_ia32_pcmpestria128(byte16, int, byte16, int, byte);

        pragma (intrinsic, "llvm.x86.sse42.pcmpestric128")
            int __builtin_ia32_pcmpestric128(byte16, int, byte16, int, byte);

        pragma (intrinsic, "llvm.x86.sse42.pcmpestrio128")
            int __builtin_ia32_pcmpestrio128(byte16, int, byte16, int, byte);

        pragma (intrinsic, "llvm.x86.sse42.pcmpestris128")
            int __builtin_ia32_pcmpestris128(byte16, int, byte16, int, byte);

        pragma (intrinsic, "llvm.x86.sse42.pcmpestriz128")
            int __builtin_ia32_pcmpestriz128(byte16, int, byte16, int, byte);

        pragma (intrinsic, "llvm.x86.avx.addsub.pd.256")
            double4 __builtin_ia32_addsubpd256(double4, double4);

        pragma (intrinsic, "llvm.x86.avx.addsub.ps.256")
            float8 __builtin_ia32_addsubps256(float8, float8);

        pragma (intrinsic, "llvm.x86.avx.max.pd.256")
            double4 __builtin_ia32_maxpd256(double4, double4);

        pragma (intrinsic, "llvm.x86.avx.max.ps.256")
            float8 __builtin_ia32_maxps256(float8, float8);

        pragma (intrinsic, "llvm.x86.avx.min.pd.256")
            double4 __builtin_ia32_minpd256(double4, double4);

        pragma (intrinsic, "llvm.x86.avx.min.ps.256")
            float8 __builtin_ia32_minps256(float8, float8);

        pragma (intrinsic, "llvm.x86.avx.sqrt.pd.256")
            double4 __builtin_ia32_sqrtpd256(double4);

        pragma (intrinsic, "llvm.x86.avx.sqrt.ps.256")
            float8 __builtin_ia32_sqrtps256(float8);

        pragma (intrinsic, "llvm.x86.avx.rsqrt.ps.256")
            float8 __builtin_ia32_rsqrtps256(float8);

        pragma (intrinsic, "llvm.x86.avx.rcp.ps.256")
            float8 __builtin_ia32_rcpps256(float8);

        pragma (intrinsic, "llvm.x86.avx.round.pd.256")
            double4 __builtin_ia32_roundpd256(double4, int);

        pragma (intrinsic, "llvm.x86.avx.round.ps.256")
            float8 __builtin_ia32_roundps256(float8, int);

        pragma (intrinsic, "llvm.x86.avx.hadd.pd.256")
            double4 __builtin_ia32_haddpd256(double4, double4);

        pragma (intrinsic, "llvm.x86.avx.hsub.ps.256")
            float8 __builtin_ia32_hsubps256(float8, float8);

        pragma (intrinsic, "llvm.x86.avx.hsub.pd.256")
            double4 __builtin_ia32_hsubpd256(double4, double4);

        pragma (intrinsic, "llvm.x86.avx.hadd.ps.256")
            float8 __builtin_ia32_haddps256(float8, float8);

        pragma (intrinsic, "llvm.x86.avx.vpermilvar.pd")
            double2 __builtin_ia32_vpermilvarpd(double2, long2);

        pragma (intrinsic, "llvm.x86.avx.vpermilvar.ps")
            float4 __builtin_ia32_vpermilvarps(float4, int4);

        pragma (intrinsic, "llvm.x86.avx.vpermilvar.pd.256")
            double4 __builtin_ia32_vpermilvarpd256(double4, long4);

        pragma (intrinsic, "llvm.x86.avx.vpermilvar.ps.256")
            float8 __builtin_ia32_vpermilvarps256(float8, int8);

        pragma (intrinsic, "llvm.x86.avx.vperm2f128.pd.256")
            double4 __builtin_ia32_vperm2f128_pd256(double4, double4, byte);

        pragma (intrinsic, "llvm.x86.avx.vperm2f128.ps.256")
            float8 __builtin_ia32_vperm2f128_ps256(float8, float8, byte);

        pragma (intrinsic, "llvm.x86.avx.vperm2f128.si.256")
            int8 __builtin_ia32_vperm2f128_si256(int8, int8, byte);

        pragma (intrinsic, "llvm.x86.avx.blend.pd.256")
            double4 __builtin_ia32_blendpd256(double4, double4, int);

        pragma (intrinsic, "llvm.x86.avx.blend.ps.256")
            float8 __builtin_ia32_blendps256(float8, float8, int);

        pragma (intrinsic, "llvm.x86.avx.blendv.pd.256")
            double4 __builtin_ia32_blendvpd256(double4, double4, double4);

        pragma (intrinsic, "llvm.x86.avx.blendv.ps.256")
            float8 __builtin_ia32_blendvps256(float8, float8, float8);

        pragma (intrinsic, "llvm.x86.avx.dp.ps.256")
            float8 __builtin_ia32_dpps256(float8, float8, int);

        pragma (intrinsic, "llvm.x86.avx.cmp.pd.256")
            double4 __builtin_ia32_cmppd256(double4, double4, byte);

        pragma (intrinsic, "llvm.x86.avx.cmp.ps.256")
            float8 __builtin_ia32_cmpps256(float8, float8, byte);

        pragma (intrinsic, "llvm.x86.avx.vextractf128.pd.256")
            double2 __builtin_ia32_vextractf128_pd256(double4, byte);

        pragma (intrinsic, "llvm.x86.avx.vextractf128.ps.256")
            float4 __builtin_ia32_vextractf128_ps256(float8, byte);

        pragma (intrinsic, "llvm.x86.avx.vextractf128.si.256")
            int4 __builtin_ia32_vextractf128_si256(int8, byte);

        pragma (intrinsic, "llvm.x86.avx.vinsertf128.pd.256")
            double4 __builtin_ia32_vinsertf128_pd256(double4, double2, byte);

        pragma (intrinsic, "llvm.x86.avx.vinsertf128.ps.256")
            float8 __builtin_ia32_vinsertf128_ps256(float8, float4, byte);

        pragma (intrinsic, "llvm.x86.avx.vinsertf128.si.256")
            int8 __builtin_ia32_vinsertf128_si256(int8, int4, byte);

        pragma (intrinsic, "llvm.x86.avx.cvtdq2.pd.256")
            double4 __builtin_ia32_cvtdq2pd256(int4);

        pragma (intrinsic, "llvm.x86.avx.cvtdq2.ps.256")
            float8 __builtin_ia32_cvtdq2ps256(int8);

        pragma (intrinsic, "llvm.x86.avx.cvt.pd2.ps.256")
            float4 __builtin_ia32_cvtpd2ps256(double4);

        pragma (intrinsic, "llvm.x86.avx.cvt.ps2dq.256")
            int8 __builtin_ia32_cvtps2dq256(float8);

        pragma (intrinsic, "llvm.x86.avx.cvt.ps2.pd.256")
            double4 __builtin_ia32_cvtps2pd256(float4);

        pragma (intrinsic, "llvm.x86.avx.cvtt.pd2dq.256")
            int4 __builtin_ia32_cvttpd2dq256(double4);

        pragma (intrinsic, "llvm.x86.avx.cvt.pd2dq.256")
            int4 __builtin_ia32_cvtpd2dq256(double4);

        pragma (intrinsic, "llvm.x86.avx.cvtt.ps2dq.256")
            int8 __builtin_ia32_cvttps2dq256(float8);

        pragma (intrinsic, "llvm.x86.avx.vtestz.pd")
            int __builtin_ia32_vtestzpd(double2, double2);

        pragma (intrinsic, "llvm.x86.avx.vtestc.pd")
            int __builtin_ia32_vtestcpd(double2, double2);

        pragma (intrinsic, "llvm.x86.avx.vtestnzc.pd")
            int __builtin_ia32_vtestnzcpd(double2, double2);

        pragma (intrinsic, "llvm.x86.avx.vtestz.ps")
            int __builtin_ia32_vtestzps(float4, float4);

        pragma (intrinsic, "llvm.x86.avx.vtestc.ps")
            int __builtin_ia32_vtestcps(float4, float4);

        pragma (intrinsic, "llvm.x86.avx.vtestnzc.ps")
            int __builtin_ia32_vtestnzcps(float4, float4);

        pragma (intrinsic, "llvm.x86.avx.vtestz.pd.256")
            int __builtin_ia32_vtestzpd256(double4, double4);

        pragma (intrinsic, "llvm.x86.avx.vtestc.pd.256")
            int __builtin_ia32_vtestcpd256(double4, double4);

        pragma (intrinsic, "llvm.x86.avx.vtestnzc.pd.256")
            int __builtin_ia32_vtestnzcpd256(double4, double4);

        pragma (intrinsic, "llvm.x86.avx.vtestz.ps.256")
            int __builtin_ia32_vtestzps256(float8, float8);

        pragma (intrinsic, "llvm.x86.avx.vtestc.ps.256")
            int __builtin_ia32_vtestcps256(float8, float8);

        pragma (intrinsic, "llvm.x86.avx.vtestnzc.ps.256")
            int __builtin_ia32_vtestnzcps256(float8, float8);

        pragma (intrinsic, "llvm.x86.avx.ptestz.256")
            int __builtin_ia32_ptestz256(long4, long4);

        pragma (intrinsic, "llvm.x86.avx.ptestc.256")
            int __builtin_ia32_ptestc256(long4, long4);

        pragma (intrinsic, "llvm.x86.avx.ptestnzc.256")
            int __builtin_ia32_ptestnzc256(long4, long4);

        pragma (intrinsic, "llvm.x86.avx.movmsk.pd.256")
            int __builtin_ia32_movmskpd256(double4);

        pragma (intrinsic, "llvm.x86.avx.movmsk.ps.256")
            int __builtin_ia32_movmskps256(float8);

        pragma (intrinsic, "llvm.x86.avx.vzeroall")
            void __builtin_ia32_vzeroall();

        pragma (intrinsic, "llvm.x86.avx.vzeroupper")
            void __builtin_ia32_vzeroupper();

        pragma (intrinsic, "llvm.x86.avx.vbroadcast.ss")
            float4 __builtin_ia32_vbroadcastss(void*);

        pragma (intrinsic, "llvm.x86.avx.vbroadcast.sd.256")
            double4 __builtin_ia32_vbroadcastsd256(void*);

        pragma (intrinsic, "llvm.x86.avx.vbroadcast.ss.256")
            float8 __builtin_ia32_vbroadcastss256(void*);

        pragma (intrinsic, "llvm.x86.avx.vbroadcastf128.pd.256")
            double4 __builtin_ia32_vbroadcastf128_pd256(void*);

        pragma (intrinsic, "llvm.x86.avx.vbroadcastf128.ps.256")
            float8 __builtin_ia32_vbroadcastf128_ps256(void*);

        pragma (intrinsic, "llvm.x86.avx.ldu.dq.256")
            byte32 __builtin_ia32_lddqu256(void*);

        pragma (intrinsic, "llvm.x86.avx.storeu.pd.256")
            void __builtin_ia32_storeupd256(void*, double4);

        pragma (intrinsic, "llvm.x86.avx.storeu.ps.256")
            void __builtin_ia32_storeups256(void*, float8);

        pragma (intrinsic, "llvm.x86.avx.storeu.dq.256")
            void __builtin_ia32_storedqu256(void*, byte32);

        pragma (intrinsic, "llvm.x86.avx.movnt.dq.256")
            void __builtin_ia32_movntdq256(void*, long4);

        pragma (intrinsic, "llvm.x86.avx.movnt.pd.256")
            void __builtin_ia32_movntpd256(void*, double4);

        pragma (intrinsic, "llvm.x86.avx.movnt.ps.256")
            void __builtin_ia32_movntps256(void*, float8);

        pragma (intrinsic, "llvm.x86.avx.maskload.pd")
            double2 __builtin_ia32_maskloadpd(void*, double2);

        pragma (intrinsic, "llvm.x86.avx.maskload.ps")
            float4 __builtin_ia32_maskloadps(void*, float4);

        pragma (intrinsic, "llvm.x86.avx.maskload.pd.256")
            double4 __builtin_ia32_maskloadpd256(void*, double4);

        pragma (intrinsic, "llvm.x86.avx.maskload.ps.256")
            float8 __builtin_ia32_maskloadps256(void*, float8);

        pragma (intrinsic, "llvm.x86.avx.maskstore.pd")
            void __builtin_ia32_maskstorepd(void*, double2, double2);

        pragma (intrinsic, "llvm.x86.avx.maskstore.ps")
            void __builtin_ia32_maskstoreps(void*, float4, float4);

        pragma (intrinsic, "llvm.x86.avx.maskstore.pd.256")
            void __builtin_ia32_maskstorepd256(void*, double4, double4);

        pragma (intrinsic, "llvm.x86.avx.maskstore.ps.256")
            void __builtin_ia32_maskstoreps256(void*, float8, float8);

        pragma (intrinsic, "llvm.x86.avx2.padds.b")
            byte32 __builtin_ia32_paddsb256(byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.padds.w")
            short16 __builtin_ia32_paddsw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.paddus.b")
            byte32 __builtin_ia32_paddusb256(byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.paddus.w")
            short16 __builtin_ia32_paddusw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.psubs.b")
            byte32 __builtin_ia32_psubsb256(byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.psubs.w")
            short16 __builtin_ia32_psubsw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.psubus.b")
            byte32 __builtin_ia32_psubusb256(byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.psubus.w")
            short16 __builtin_ia32_psubusw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.pmulhu.w")
            short16 __builtin_ia32_pmulhuw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.pmulh.w")
            short16 __builtin_ia32_pmulhw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.pmulu.dq")
            long4 __builtin_ia32_pmuludq256(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.pmul.dq")
            long4 __builtin_ia32_pmuldq256(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.pmadd.wd")
            int8 __builtin_ia32_pmaddwd256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.pavg.b")
            byte32 __builtin_ia32_pavgb256(byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.pavg.w")
            short16 __builtin_ia32_pavgw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.psad.bw")
            long4 __builtin_ia32_psadbw256(byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.pmaxu.b")
            byte32 __builtin_ia32_pmaxub256(byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.pmaxu.w")
            short16 __builtin_ia32_pmaxuw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.pmaxu.d")
            int8 __builtin_ia32_pmaxud256(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.pmaxs.b")
            byte32 __builtin_ia32_pmaxsb256(byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.pmaxs.w")
            short16 __builtin_ia32_pmaxsw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.pmaxs.d")
            int8 __builtin_ia32_pmaxsd256(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.pminu.b")
            byte32 __builtin_ia32_pminub256(byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.pminu.w")
            short16 __builtin_ia32_pminuw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.pminu.d")
            int8 __builtin_ia32_pminud256(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.pmins.b")
            byte32 __builtin_ia32_pminsb256(byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.pmins.w")
            short16 __builtin_ia32_pminsw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.pmins.d")
            int8 __builtin_ia32_pminsd256(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.psll.w")
            short16 __builtin_ia32_psllw256(short16, short8);

        pragma (intrinsic, "llvm.x86.avx2.psll.d")
            int8 __builtin_ia32_pslld256(int8, int4);

        pragma (intrinsic, "llvm.x86.avx2.psll.q")
            long4 __builtin_ia32_psllq256(long4, long2);

        pragma (intrinsic, "llvm.x86.avx2.psrl.w")
            short16 __builtin_ia32_psrlw256(short16, short8);

        pragma (intrinsic, "llvm.x86.avx2.psrl.d")
            int8 __builtin_ia32_psrld256(int8, int4);

        pragma (intrinsic, "llvm.x86.avx2.psrl.q")
            long4 __builtin_ia32_psrlq256(long4, long2);

        pragma (intrinsic, "llvm.x86.avx2.psra.w")
            short16 __builtin_ia32_psraw256(short16, short8);

        pragma (intrinsic, "llvm.x86.avx2.psra.d")
            int8 __builtin_ia32_psrad256(int8, int4);

        pragma (intrinsic, "llvm.x86.avx2.pslli.w")
            short16 __builtin_ia32_psllwi256(short16, int);

        pragma (intrinsic, "llvm.x86.avx2.pslli.d")
            int8 __builtin_ia32_pslldi256(int8, int);

        pragma (intrinsic, "llvm.x86.avx2.pslli.q")
            long4 __builtin_ia32_psllqi256(long4, int);

        pragma (intrinsic, "llvm.x86.avx2.psrli.w")
            short16 __builtin_ia32_psrlwi256(short16, int);

        pragma (intrinsic, "llvm.x86.avx2.psrli.d")
            int8 __builtin_ia32_psrldi256(int8, int);

        pragma (intrinsic, "llvm.x86.avx2.psrli.q")
            long4 __builtin_ia32_psrlqi256(long4, int);

        pragma (intrinsic, "llvm.x86.avx2.psrai.w")
            short16 __builtin_ia32_psrawi256(short16, int);

        pragma (intrinsic, "llvm.x86.avx2.psrai.d")
            int8 __builtin_ia32_psradi256(int8, int);

        pragma (intrinsic, "llvm.x86.avx2.psll.dq")
            long4 __builtin_ia32_pslldqi256(long4, int);

        pragma (intrinsic, "llvm.x86.avx2.psrl.dq")
            long4 __builtin_ia32_psrldqi256(long4, int);

        pragma (intrinsic, "llvm.x86.avx2.psll.dq.bs")
            long4 __builtin_ia32_pslldqi256_byteshift(long4, int);

        pragma (intrinsic, "llvm.x86.avx2.psrl.dq.bs")
            long4 __builtin_ia32_psrldqi256_byteshift(long4, int);

        pragma (intrinsic, "llvm.x86.avx2.packsswb")
            byte32 __builtin_ia32_packsswb256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.packssdw")
            short16 __builtin_ia32_packssdw256(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.packuswb")
            byte32 __builtin_ia32_packuswb256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.packusdw")
            short16 __builtin_ia32_packusdw256(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.pabs.b")
            byte32 __builtin_ia32_pabsb256(byte32);

        pragma (intrinsic, "llvm.x86.avx2.pabs.w")
            short16 __builtin_ia32_pabsw256(short16);

        pragma (intrinsic, "llvm.x86.avx2.pabs.d")
            int8 __builtin_ia32_pabsd256(int8);

        pragma (intrinsic, "llvm.x86.avx2.phadd.w")
            short16 __builtin_ia32_phaddw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.phadd.d")
            int8 __builtin_ia32_phaddd256(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.phadd.sw")
            short16 __builtin_ia32_phaddsw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.phsub.w")
            short16 __builtin_ia32_phsubw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.phsub.d")
            int8 __builtin_ia32_phsubd256(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.phsub.sw")
            short16 __builtin_ia32_phsubsw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.pmadd.ub.sw")
            short16 __builtin_ia32_pmaddubsw256(byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.psign.b")
            byte32 __builtin_ia32_psignb256(byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.psign.w")
            short16 __builtin_ia32_psignw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.psign.d")
            int8 __builtin_ia32_psignd256(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.pmul.hr.sw")
            short16 __builtin_ia32_pmulhrsw256(short16, short16);

        pragma (intrinsic, "llvm.x86.avx2.pmovsxbd")
            int8 __builtin_ia32_pmovsxbd256(byte16);

        pragma (intrinsic, "llvm.x86.avx2.pmovsxbq")
            long4 __builtin_ia32_pmovsxbq256(byte16);

        pragma (intrinsic, "llvm.x86.avx2.pmovsxbw")
            short16 __builtin_ia32_pmovsxbw256(byte16);

        pragma (intrinsic, "llvm.x86.avx2.pmovsxdq")
            long4 __builtin_ia32_pmovsxdq256(int4);

        pragma (intrinsic, "llvm.x86.avx2.pmovsxwd")
            int8 __builtin_ia32_pmovsxwd256(short8);

        pragma (intrinsic, "llvm.x86.avx2.pmovsxwq")
            long4 __builtin_ia32_pmovsxwq256(short8);

        pragma (intrinsic, "llvm.x86.avx2.pmovzxbd")
            int8 __builtin_ia32_pmovzxbd256(byte16);

        pragma (intrinsic, "llvm.x86.avx2.pmovzxbq")
            long4 __builtin_ia32_pmovzxbq256(byte16);

        pragma (intrinsic, "llvm.x86.avx2.pmovzxbw")
            short16 __builtin_ia32_pmovzxbw256(byte16);

        pragma (intrinsic, "llvm.x86.avx2.pmovzxdq")
            long4 __builtin_ia32_pmovzxdq256(int4);

        pragma (intrinsic, "llvm.x86.avx2.pmovzxwd")
            int8 __builtin_ia32_pmovzxwd256(short8);

        pragma (intrinsic, "llvm.x86.avx2.pmovzxwq")
            long4 __builtin_ia32_pmovzxwq256(short8);

        pragma (intrinsic, "llvm.x86.avx2.pblendvb")
            byte32 __builtin_ia32_pblendvb256(byte32, byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.pblendw")
            short16 __builtin_ia32_pblendw256(short16, short16, int);

        pragma (intrinsic, "llvm.x86.avx2.pblendd.128")
            int4 __builtin_ia32_pblendd128(int4, int4, int);

        pragma (intrinsic, "llvm.x86.avx2.pblendd.256")
            int8 __builtin_ia32_pblendd256(int8, int8, int);

        pragma (intrinsic, "llvm.x86.avx2.vbroadcast.ss.ps")
            float4 __builtin_ia32_vbroadcastss_ps(float4);

        pragma (intrinsic, "llvm.x86.avx2.vbroadcast.sd.pd.256")
            double4 __builtin_ia32_vbroadcastsd_pd256(double2);

        pragma (intrinsic, "llvm.x86.avx2.vbroadcast.ss.ps.256")
            float8 __builtin_ia32_vbroadcastss_ps256(float4);

        pragma (intrinsic, "llvm.x86.avx2.vbroadcasti128")
            long4 __builtin_ia32_vbroadcastsi256(void*);

        pragma (intrinsic, "llvm.x86.avx2.pbroadcastb.128")
            byte16 __builtin_ia32_pbroadcastb128(byte16);

        pragma (intrinsic, "llvm.x86.avx2.pbroadcastb.256")
            byte32 __builtin_ia32_pbroadcastb256(byte16);

        pragma (intrinsic, "llvm.x86.avx2.pbroadcastw.128")
            short8 __builtin_ia32_pbroadcastw128(short8);

        pragma (intrinsic, "llvm.x86.avx2.pbroadcastw.256")
            short16 __builtin_ia32_pbroadcastw256(short8);

        pragma (intrinsic, "llvm.x86.avx2.pbroadcastd.128")
            int4 __builtin_ia32_pbroadcastd128(int4);

        pragma (intrinsic, "llvm.x86.avx2.pbroadcastd.256")
            int8 __builtin_ia32_pbroadcastd256(int4);

        pragma (intrinsic, "llvm.x86.avx2.pbroadcastq.128")
            long2 __builtin_ia32_pbroadcastq128(long2);

        pragma (intrinsic, "llvm.x86.avx2.pbroadcastq.256")
            long4 __builtin_ia32_pbroadcastq256(long2);

        pragma (intrinsic, "llvm.x86.avx2.permd")
            int8 __builtin_ia32_permvarsi256(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.permps")
            float8 __builtin_ia32_permvarsf256(float8, float8);

        pragma (intrinsic, "llvm.x86.avx2.vperm2i128")
            long4 __builtin_ia32_permti256(long4, long4, byte);

        pragma (intrinsic, "llvm.x86.avx2.vextracti128")
            long2 __builtin_ia32_extract128i256(long4, byte);

        pragma (intrinsic, "llvm.x86.avx2.vinserti128")
            long4 __builtin_ia32_insert128i256(long4, long2, byte);

        pragma (intrinsic, "llvm.x86.avx2.maskload.d")
            int4 __builtin_ia32_maskloadd(void*, int4);

        pragma (intrinsic, "llvm.x86.avx2.maskload.q")
            long2 __builtin_ia32_maskloadq(void*, long2);

        pragma (intrinsic, "llvm.x86.avx2.maskload.d.256")
            int8 __builtin_ia32_maskloadd256(void*, int8);

        pragma (intrinsic, "llvm.x86.avx2.maskload.q.256")
            long4 __builtin_ia32_maskloadq256(void*, long4);

        pragma (intrinsic, "llvm.x86.avx2.maskstore.d")
            void __builtin_ia32_maskstored(void*, int4, int4);

        pragma (intrinsic, "llvm.x86.avx2.maskstore.q")
            void __builtin_ia32_maskstoreq(void*, long2, long2);

        pragma (intrinsic, "llvm.x86.avx2.maskstore.d.256")
            void __builtin_ia32_maskstored256(void*, int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.maskstore.q.256")
            void __builtin_ia32_maskstoreq256(void*, long4, long4);

        pragma (intrinsic, "llvm.x86.avx2.psllv.d")
            int4 __builtin_ia32_psllv4si(int4, int4);

        pragma (intrinsic, "llvm.x86.avx2.psllv.d.256")
            int8 __builtin_ia32_psllv8si(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.psllv.q")
            long2 __builtin_ia32_psllv2di(long2, long2);

        pragma (intrinsic, "llvm.x86.avx2.psllv.q.256")
            long4 __builtin_ia32_psllv4di(long4, long4);

        pragma (intrinsic, "llvm.x86.avx2.psrlv.d")
            int4 __builtin_ia32_psrlv4si(int4, int4);

        pragma (intrinsic, "llvm.x86.avx2.psrlv.d.256")
            int8 __builtin_ia32_psrlv8si(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.psrlv.q")
            long2 __builtin_ia32_psrlv2di(long2, long2);

        pragma (intrinsic, "llvm.x86.avx2.psrlv.q.256")
            long4 __builtin_ia32_psrlv4di(long4, long4);

        pragma (intrinsic, "llvm.x86.avx2.psrav.d")
            int4 __builtin_ia32_psrav4si(int4, int4);

        pragma (intrinsic, "llvm.x86.avx2.psrav.d.256")
            int8 __builtin_ia32_psrav8si(int8, int8);

        pragma (intrinsic, "llvm.x86.avx2.pmovmskb")
            int __builtin_ia32_pmovmskb256(byte32);

        pragma (intrinsic, "llvm.x86.avx2.pshuf.b")
            byte32 __builtin_ia32_pshufb256(byte32, byte32);

        pragma (intrinsic, "llvm.x86.avx2.mpsadbw")
            short16 __builtin_ia32_mpsadbw256(byte32, byte32, int);

        pragma (intrinsic, "llvm.x86.avx2.movntdqa")
            long4 __builtin_ia32_movntdqa256(void*);

        pragma (intrinsic, "llvm.x86.fma4.vfmadd.ss")
            float4 __builtin_ia32_vfmaddss(float4, float4, float4);

        pragma (intrinsic, "llvm.x86.fma4.vfmadd.sd")
            double2 __builtin_ia32_vfmaddsd(double2, double2, double2);

        pragma (intrinsic, "llvm.x86.fma4.vfmadd.ps")
            float4 __builtin_ia32_vfmaddps(float4, float4, float4);

        pragma (intrinsic, "llvm.x86.fma4.vfmadd.pd")
            double2 __builtin_ia32_vfmaddpd(double2, double2, double2);

        pragma (intrinsic, "llvm.x86.fma4.vfmadd.ps.256")
            float8 __builtin_ia32_vfmaddps256(float8, float8, float8);

        pragma (intrinsic, "llvm.x86.fma4.vfmadd.pd.256")
            double4 __builtin_ia32_vfmaddpd256(double4, double4, double4);

        pragma (intrinsic, "llvm.x86.fma4.vfmsub.ss")
            float4 __builtin_ia32_vfmsubss(float4, float4, float4);

        pragma (intrinsic, "llvm.x86.fma4.vfmsub.sd")
            double2 __builtin_ia32_vfmsubsd(double2, double2, double2);

        pragma (intrinsic, "llvm.x86.fma4.vfmsub.ps")
            float4 __builtin_ia32_vfmsubps(float4, float4, float4);

        pragma (intrinsic, "llvm.x86.fma4.vfmsub.pd")
            double2 __builtin_ia32_vfmsubpd(double2, double2, double2);

        pragma (intrinsic, "llvm.x86.fma4.vfmsub.ps.256")
            float8 __builtin_ia32_vfmsubps256(float8, float8, float8);

        pragma (intrinsic, "llvm.x86.fma4.vfmsub.pd.256")
            double4 __builtin_ia32_vfmsubpd256(double4, double4, double4);

        pragma (intrinsic, "llvm.x86.fma4.vfnmadd.ss")
            float4 __builtin_ia32_vfnmaddss(float4, float4, float4);

        pragma (intrinsic, "llvm.x86.fma4.vfnmadd.sd")
            double2 __builtin_ia32_vfnmaddsd(double2, double2, double2);

        pragma (intrinsic, "llvm.x86.fma4.vfnmadd.ps")
            float4 __builtin_ia32_vfnmaddps(float4, float4, float4);

        pragma (intrinsic, "llvm.x86.fma4.vfnmadd.pd")
            double2 __builtin_ia32_vfnmaddpd(double2, double2, double2);

        pragma (intrinsic, "llvm.x86.fma4.vfnmadd.ps.256")
            float8 __builtin_ia32_vfnmaddps256(float8, float8, float8);

        pragma (intrinsic, "llvm.x86.fma4.vfnmadd.pd.256")
            double4 __builtin_ia32_vfnmaddpd256(double4, double4, double4);

        pragma (intrinsic, "llvm.x86.fma4.vfnmsub.ss")
            float4 __builtin_ia32_vfnmsubss(float4, float4, float4);

        pragma (intrinsic, "llvm.x86.fma4.vfnmsub.sd")
            double2 __builtin_ia32_vfnmsubsd(double2, double2, double2);

        pragma (intrinsic, "llvm.x86.fma4.vfnmsub.ps")
            float4 __builtin_ia32_vfnmsubps(float4, float4, float4);

        pragma (intrinsic, "llvm.x86.fma4.vfnmsub.pd")
            double2 __builtin_ia32_vfnmsubpd(double2, double2, double2);

        pragma (intrinsic, "llvm.x86.fma4.vfnmsub.ps.256")
            float8 __builtin_ia32_vfnmsubps256(float8, float8, float8);

        pragma (intrinsic, "llvm.x86.fma4.vfnmsub.pd.256")
            double4 __builtin_ia32_vfnmsubpd256(double4, double4, double4);

        pragma (intrinsic, "llvm.x86.fma4.vfmaddsub.ps")
            float4 __builtin_ia32_vfmaddsubps(float4, float4, float4);

        pragma (intrinsic, "llvm.x86.fma4.vfmaddsub.pd")
            double2 __builtin_ia32_vfmaddsubpd(double2, double2, double2);

        pragma (intrinsic, "llvm.x86.fma4.vfmaddsub.ps.256")
            float8 __builtin_ia32_vfmaddsubps256(float8, float8, float8);

        pragma (intrinsic, "llvm.x86.fma4.vfmaddsub.pd.256")
            double4 __builtin_ia32_vfmaddsubpd256(double4, double4, double4);

        pragma (intrinsic, "llvm.x86.fma4.vfmsubadd.ps")
            float4 __builtin_ia32_vfmsubaddps(float4, float4, float4);

        pragma (intrinsic, "llvm.x86.fma4.vfmsubadd.pd")
            double2 __builtin_ia32_vfmsubaddpd(double2, double2, double2);

        pragma (intrinsic, "llvm.x86.fma4.vfmsubadd.ps.256")
            float8 __builtin_ia32_vfmsubaddps256(float8, float8, float8);

        pragma (intrinsic, "llvm.x86.fma4.vfmsubadd.pd.256")
            double4 __builtin_ia32_vfmsubaddpd256(double4, double4, double4);

        pragma (intrinsic, "llvm.x86.xop.vpermil2pd")
            double2 __builtin_ia32_vpermil2pd(double2, double2, double2, byte);

        pragma (intrinsic, "llvm.x86.xop.vpermil2pd.256")
            double4 __builtin_ia32_vpermil2pd256(double4, double4, double4, byte);

        pragma (intrinsic, "llvm.x86.xop.vpermil2ps")
            float4 __builtin_ia32_vpermil2ps(float4, float4, float4, byte);

        pragma (intrinsic, "llvm.x86.xop.vpermil2ps.256")
            float8 __builtin_ia32_vpermil2ps256(float8, float8, float8, byte);

        pragma (intrinsic, "llvm.x86.xop.vfrcz.pd")
            double2 __builtin_ia32_vfrczpd(double2);

        pragma (intrinsic, "llvm.x86.xop.vfrcz.ps")
            float4 __builtin_ia32_vfrczps(float4);

        pragma (intrinsic, "llvm.x86.xop.vfrcz.sd")
            double2 __builtin_ia32_vfrczsd(double2, double2);

        pragma (intrinsic, "llvm.x86.xop.vfrcz.ss")
            float4 __builtin_ia32_vfrczss(float4, float4);

        pragma (intrinsic, "llvm.x86.xop.vfrcz.pd.256")
            double4 __builtin_ia32_vfrczpd256(double4);

        pragma (intrinsic, "llvm.x86.xop.vfrcz.ps.256")
            float8 __builtin_ia32_vfrczps256(float8);

        pragma (intrinsic, "llvm.x86.xop.vpcmov")
            long2 __builtin_ia32_vpcmov(long2, long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcmov.256")
            long4 __builtin_ia32_vpcmov_256(long4, long4, long4);

        pragma (intrinsic, "llvm.x86.xop.vpcomeqb")
            byte16 __builtin_ia32_vpcomeqb(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomeqw")
            short8 __builtin_ia32_vpcomeqw(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomeqd")
            int4 __builtin_ia32_vpcomeqd(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomeqq")
            long2 __builtin_ia32_vpcomeqq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomequb")
            byte16 __builtin_ia32_vpcomequb(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomequd")
            int4 __builtin_ia32_vpcomequd(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomequq")
            long2 __builtin_ia32_vpcomequq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomequw")
            short8 __builtin_ia32_vpcomequw(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomfalseb")
            byte16 __builtin_ia32_vpcomfalseb(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomfalsed")
            int4 __builtin_ia32_vpcomfalsed(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomfalseq")
            long2 __builtin_ia32_vpcomfalseq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomfalseub")
            byte16 __builtin_ia32_vpcomfalseub(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomfalseud")
            int4 __builtin_ia32_vpcomfalseud(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomfalseuq")
            long2 __builtin_ia32_vpcomfalseuq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomfalseuw")
            short8 __builtin_ia32_vpcomfalseuw(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomfalsew")
            short8 __builtin_ia32_vpcomfalsew(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomgeb")
            byte16 __builtin_ia32_vpcomgeb(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomged")
            int4 __builtin_ia32_vpcomged(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomgeq")
            long2 __builtin_ia32_vpcomgeq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomgeub")
            byte16 __builtin_ia32_vpcomgeub(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomgeud")
            int4 __builtin_ia32_vpcomgeud(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomgeuq")
            long2 __builtin_ia32_vpcomgeuq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomgeuw")
            short8 __builtin_ia32_vpcomgeuw(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomgew")
            short8 __builtin_ia32_vpcomgew(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomgtb")
            byte16 __builtin_ia32_vpcomgtb(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomgtd")
            int4 __builtin_ia32_vpcomgtd(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomgtq")
            long2 __builtin_ia32_vpcomgtq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomgtub")
            byte16 __builtin_ia32_vpcomgtub(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomgtud")
            int4 __builtin_ia32_vpcomgtud(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomgtuq")
            long2 __builtin_ia32_vpcomgtuq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomgtuw")
            short8 __builtin_ia32_vpcomgtuw(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomgtw")
            short8 __builtin_ia32_vpcomgtw(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomleb")
            byte16 __builtin_ia32_vpcomleb(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomled")
            int4 __builtin_ia32_vpcomled(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomleq")
            long2 __builtin_ia32_vpcomleq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomleub")
            byte16 __builtin_ia32_vpcomleub(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomleud")
            int4 __builtin_ia32_vpcomleud(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomleuq")
            long2 __builtin_ia32_vpcomleuq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomleuw")
            short8 __builtin_ia32_vpcomleuw(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomlew")
            short8 __builtin_ia32_vpcomlew(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomltb")
            byte16 __builtin_ia32_vpcomltb(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomltd")
            int4 __builtin_ia32_vpcomltd(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomltq")
            long2 __builtin_ia32_vpcomltq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomltub")
            byte16 __builtin_ia32_vpcomltub(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomltud")
            int4 __builtin_ia32_vpcomltud(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomltuq")
            long2 __builtin_ia32_vpcomltuq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomltuw")
            short8 __builtin_ia32_vpcomltuw(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomltw")
            short8 __builtin_ia32_vpcomltw(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomneb")
            byte16 __builtin_ia32_vpcomneb(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomned")
            int4 __builtin_ia32_vpcomned(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomneq")
            long2 __builtin_ia32_vpcomneq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomneub")
            byte16 __builtin_ia32_vpcomneub(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomneud")
            int4 __builtin_ia32_vpcomneud(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomneuq")
            long2 __builtin_ia32_vpcomneuq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomneuw")
            short8 __builtin_ia32_vpcomneuw(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomnew")
            short8 __builtin_ia32_vpcomnew(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomtrueb")
            byte16 __builtin_ia32_vpcomtrueb(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomtrued")
            int4 __builtin_ia32_vpcomtrued(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomtrueq")
            long2 __builtin_ia32_vpcomtrueq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomtrueub")
            byte16 __builtin_ia32_vpcomtrueub(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpcomtrueud")
            int4 __builtin_ia32_vpcomtrueud(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpcomtrueuq")
            long2 __builtin_ia32_vpcomtrueuq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpcomtrueuw")
            short8 __builtin_ia32_vpcomtrueuw(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpcomtruew")
            short8 __builtin_ia32_vpcomtruew(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vphaddbd")
            int4 __builtin_ia32_vphaddbd(byte16);

        pragma (intrinsic, "llvm.x86.xop.vphaddbq")
            long2 __builtin_ia32_vphaddbq(byte16);

        pragma (intrinsic, "llvm.x86.xop.vphaddbw")
            short8 __builtin_ia32_vphaddbw(byte16);

        pragma (intrinsic, "llvm.x86.xop.vphadddq")
            long2 __builtin_ia32_vphadddq(int4);

        pragma (intrinsic, "llvm.x86.xop.vphaddubd")
            int4 __builtin_ia32_vphaddubd(byte16);

        pragma (intrinsic, "llvm.x86.xop.vphaddubq")
            long2 __builtin_ia32_vphaddubq(byte16);

        pragma (intrinsic, "llvm.x86.xop.vphaddubw")
            short8 __builtin_ia32_vphaddubw(byte16);

        pragma (intrinsic, "llvm.x86.xop.vphaddudq")
            long2 __builtin_ia32_vphaddudq(int4);

        pragma (intrinsic, "llvm.x86.xop.vphadduwd")
            int4 __builtin_ia32_vphadduwd(short8);

        pragma (intrinsic, "llvm.x86.xop.vphadduwq")
            long2 __builtin_ia32_vphadduwq(short8);

        pragma (intrinsic, "llvm.x86.xop.vphaddwd")
            int4 __builtin_ia32_vphaddwd(short8);

        pragma (intrinsic, "llvm.x86.xop.vphaddwq")
            long2 __builtin_ia32_vphaddwq(short8);

        pragma (intrinsic, "llvm.x86.xop.vphsubbw")
            short8 __builtin_ia32_vphsubbw(byte16);

        pragma (intrinsic, "llvm.x86.xop.vphsubdq")
            long2 __builtin_ia32_vphsubdq(int4);

        pragma (intrinsic, "llvm.x86.xop.vphsubwd")
            int4 __builtin_ia32_vphsubwd(short8);

        pragma (intrinsic, "llvm.x86.xop.vpmacsdd")
            int4 __builtin_ia32_vpmacsdd(int4, int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpmacsdqh")
            long2 __builtin_ia32_vpmacsdqh(int4, int4, long2);

        pragma (intrinsic, "llvm.x86.xop.vpmacsdql")
            long2 __builtin_ia32_vpmacsdql(int4, int4, long2);

        pragma (intrinsic, "llvm.x86.xop.vpmacssdd")
            int4 __builtin_ia32_vpmacssdd(int4, int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpmacssdqh")
            long2 __builtin_ia32_vpmacssdqh(int4, int4, long2);

        pragma (intrinsic, "llvm.x86.xop.vpmacssdql")
            long2 __builtin_ia32_vpmacssdql(int4, int4, long2);

        pragma (intrinsic, "llvm.x86.xop.vpmacsswd")
            int4 __builtin_ia32_vpmacsswd(short8, short8, int4);

        pragma (intrinsic, "llvm.x86.xop.vpmacssww")
            short8 __builtin_ia32_vpmacssww(short8, short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpmacswd")
            int4 __builtin_ia32_vpmacswd(short8, short8, int4);

        pragma (intrinsic, "llvm.x86.xop.vpmacsww")
            short8 __builtin_ia32_vpmacsww(short8, short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpmadcsswd")
            int4 __builtin_ia32_vpmadcsswd(short8, short8, int4);

        pragma (intrinsic, "llvm.x86.xop.vpmadcswd")
            int4 __builtin_ia32_vpmadcswd(short8, short8, int4);

        pragma (intrinsic, "llvm.x86.xop.vpperm")
            byte16 __builtin_ia32_vpperm(byte16, byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vprotb")
            byte16 __builtin_ia32_vprotb(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vprotd")
            int4 __builtin_ia32_vprotd(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vprotq")
            long2 __builtin_ia32_vprotq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vprotw")
            short8 __builtin_ia32_vprotw(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpshab")
            byte16 __builtin_ia32_vpshab(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpshad")
            int4 __builtin_ia32_vpshad(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpshaq")
            long2 __builtin_ia32_vpshaq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpshaw")
            short8 __builtin_ia32_vpshaw(short8, short8);

        pragma (intrinsic, "llvm.x86.xop.vpshlb")
            byte16 __builtin_ia32_vpshlb(byte16, byte16);

        pragma (intrinsic, "llvm.x86.xop.vpshld")
            int4 __builtin_ia32_vpshld(int4, int4);

        pragma (intrinsic, "llvm.x86.xop.vpshlq")
            long2 __builtin_ia32_vpshlq(long2, long2);

        pragma (intrinsic, "llvm.x86.xop.vpshlw")
            short8 __builtin_ia32_vpshlw(short8, short8);

        pragma (intrinsic, "llvm.x86.mmx.emms")
            void __builtin_ia32_emms();

        pragma (intrinsic, "llvm.x86.mmx.femms")
            void __builtin_ia32_femms();

        pragma (intrinsic, "llvm.x86.bmi.bextr.32")
            int __builtin_ia32_bextr_u32(int, int);

        pragma (intrinsic, "llvm.x86.bmi.bextr.64")
            long __builtin_ia32_bextr_u64(long, long);

        pragma (intrinsic, "llvm.x86.bmi.bzhi.32")
            int __builtin_ia32_bzhi_si(int, int);

        pragma (intrinsic, "llvm.x86.bmi.bzhi.64")
            long __builtin_ia32_bzhi_di(long, long);

        pragma (intrinsic, "llvm.x86.bmi.pdep.32")
            int __builtin_ia32_pdep_si(int, int);

        pragma (intrinsic, "llvm.x86.bmi.pdep.64")
            long __builtin_ia32_pdep_di(long, long);

        pragma (intrinsic, "llvm.x86.bmi.pext.32")
            int __builtin_ia32_pext_si(int, int);

        pragma (intrinsic, "llvm.x86.bmi.pext.64")
            long __builtin_ia32_pext_di(long, long);

        pragma (intrinsic, "llvm.x86.rdfsbase.32")
            int __builtin_ia32_rdfsbase32();

        pragma (intrinsic, "llvm.x86.rdgsbase.32")
            int __builtin_ia32_rdgsbase32();

        pragma (intrinsic, "llvm.x86.rdfsbase.64")
            long __builtin_ia32_rdfsbase64();

        pragma (intrinsic, "llvm.x86.rdgsbase.64")
            long __builtin_ia32_rdgsbase64();

        pragma (intrinsic, "llvm.x86.wrfsbase.32")
            void __builtin_ia32_wrfsbase32(int);

        pragma (intrinsic, "llvm.x86.wrgsbase.32")
            void __builtin_ia32_wrgsbase32(int);

        pragma (intrinsic, "llvm.x86.wrfsbase.64")
            void __builtin_ia32_wrfsbase64(long);

        pragma (intrinsic, "llvm.x86.wrgsbase.64")
            void __builtin_ia32_wrgsbase64(long);

        pragma (intrinsic, "llvm.x86.vcvtph2ps.128")
            float4 __builtin_ia32_vcvtph2ps(short8);

        pragma (intrinsic, "llvm.x86.vcvtph2ps.256")
            float8 __builtin_ia32_vcvtph2ps256(short8);

        pragma (intrinsic, "llvm.x86.vcvtps2ph.128")
            short8 __builtin_ia32_vcvtps2ph(float4, int);

        pragma (intrinsic, "llvm.x86.vcvtps2ph.256")
            short8 __builtin_ia32_vcvtps2ph256(float8, int);

        alias __builtin_ia32_paddsb128 __builtin_ia32_paddsb;
        alias __builtin_ia32_psubsb128 __builtin_ia32_psubsb;
        alias __builtin_ia32_paddusb128 __builtin_ia32_paddusb;
        alias __builtin_ia32_paddsw128 __builtin_ia32_paddsw;
        alias __builtin_ia32_psubsw128 __builtin_ia32_psubsw;
        alias __builtin_ia32_paddusw128 __builtin_ia32_paddusw;
    }

    template ldcFloatMaskLess(string type, string a, string b, bool includeEqual)
    {
        enum params = a~`, `~b~`, `~(includeEqual ? "2" : "1");
        
        enum ldcFloatMaskLess = `
            static if(is(T == double2))
            {
                return __builtin_ia32_cmppd(`~params~`);
            }
            else static if(is(T == float4))
            {
                return __builtin_ia32_cmpps(`~params~`);
            }
            else
                static assert(0, "Unsupported vector type: " ~ `~type~`);`;
    }

    alias byte16 PblendvbParam;
}
else version(GNU)
{
    alias ubyte16 PblendvbParam;
}

version(GNU)
    version = GNU_OR_LDC;
version(LDC)
    version = GNU_OR_LDC;

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
	template UnsignedOf(T)
	{
		static if(is(T == long2) || is(T == ulong2))
			alias ulong2 UnsignedOf;
		else static if(is(T == int4) || is(T == uint4))
			alias uint4 UnsignedOf;
		else static if(is(T == short8) || is(T == ushort8))
			alias ushort8 UnsignedOf;
		else static if(is(T == byte16) || is(T == ubyte16))
			alias ubyte16 UnsignedOf;
		else static if(is(T == long) || is(T == ulong))
			alias ulong UnsignedOf;
		else static if(is(T == int) || is(T == uint))
			alias uint UnsignedOf;
		else static if(is(T == short) || is(T == ushort))
			alias ushort UnsignedOf;
		else static if(is(T == byte) || is(T == ubyte))
			alias ubyte UnsignedOf;
		else
			static assert(0, "Incorrect type");
	}
	template SignedOf(T)
	{
		static if(is(T == long2) || is(T == ulong2))
			alias long2 SignedOf;
		else static if(is(T == int4) || is(T == uint4))
			alias int4 SignedOf;
		else static if(is(T == short8) || is(T == ushort8))
			alias short8 SignedOf;
		else static if(is(T == byte16) || is(T == ubyte16))
			alias byte16 SignedOf;
		else static if(is(T == long) || is(T == ulong))
			alias long SignedOf;
		else static if(is(T == int) || is(T == uint))
			alias int SignedOf;
		else static if(is(T == short) || is(T == ushort))
			alias short SignedOf;
		else static if(is(T == byte) || is(T == ubyte))
			alias byte SignedOf;
		else
			static assert(0, "Incorrect type");
	}
	template PromotionOf(T)
	{
		static if(is(T == int4))
			alias long2 PromotionOf;
		else static if(is(T == uint4))
			alias ulong2 PromotionOf;
		else static if(is(T == short8))
			alias int4 PromotionOf;
		else static if(is(T == ushort8))
			alias uint4 PromotionOf;
		else static if(is(T == byte16))
			alias short8 PromotionOf;
		else static if(is(T == ubyte16))
			alias ushort8 PromotionOf;
		else static if(is(T == int))
			alias long PromotionOf;
		else static if(is(T == uint))
			alias ulong PromotionOf;
		else static if(is(T == short))
			alias int PromotionOf;
		else static if(is(T == ushort))
			alias uint PromotionOf;
		else static if(is(T == byte))
			alias short PromotionOf;
		else static if(is(T == ubyte))
			alias ushort PromotionOf;
		else
			static assert(0, "Incorrect type");
	}
	template DemotionOf(T)
	{
		static if(is(T == long2))
			alias int4 DemotionOf;
		else static if(is(T == ulong2))
			alias uint4 DemotionOf;
		else static if(is(T == int4))
			alias short8 DemotionOf;
		else static if(is(T == uint4))
			alias ushort8 DemotionOf;
		else static if(is(T == short8))
			alias byte16 DemotionOf;
		else static if(is(T == ushort8))
			alias ubyte16 DemotionOf;
		else static if(is(T == long))
			alias int DemotionOf;
		else static if(is(T == ulong))
			alias uint DemotionOf;
		else static if(is(T == int))
			alias short DemotionOf;
		else static if(is(T == uint))
			alias ushort DemotionOf;
		else static if(is(T == short))
			alias byte DemotionOf;
		else static if(is(T == ushort))
			alias ubyte DemotionOf;
		else
			static assert(0, "Incorrect type");
	}
	/**** </WORK AROUNDS> ****/


	// a template to test if a type is a vector type
	//	template isVector(T : __vector(U[N]), U, size_t N) { enum bool isVector = true; }
	//	template isVector(T) { enum bool isVector = false; }

	// pull the base type from a vector, array, or primitive 
    // type. The first version does not work for vectors.
	template ArrayType(T : T[]) { alias T ArrayType; }
    template ArrayType(T) if(isVector!T)
    {  
        // typeof T.array.init does not work for some reason, so we use this 
        alias typeof(()
        {
            T a;
            return a.array;
        }()) ArrayType;
    }
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

	template isSigned(T)
	{
		enum bool isSigned = !isScalarUnsigned!(BaseType!T);
	}

	template isUnsigned(T)
	{
		enum bool isUnsigned = isScalarUnsigned!(BaseType!T);
	}

	template is64bitElement(T)
	{
		enum bool is64bitElement = (BaseType!(T).sizeof == 8);
	}

	template is64bitInteger(T)
	{
		enum bool is64bitInteger = is64bitElement!T && !is(T == double);
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

	/**** And some helpers for various architectures ****/
	version(X86_OR_X64)
	{
		int shufMask(size_t N)(int[N] elements)
		{
			static if(N == 2)
				return ((elements[0] & 1) << 0) | ((elements[1] & 1) << 1);
			else static if(N == 4)
				return ((elements[0] & 3) << 0) | ((elements[1] & 3) << 2) | ((elements[2] & 3) << 4) | ((elements[3] & 3) << 6);
		}
	}

	version(ARM)
	{
		template ARMOpType(T, bool Rounded = false)
		{
			// NOTE: 0-unsigned, 1-signed, 2-poly, 3-float, 4-unsigned rounded, 5-signed rounded
			static if(is(T == double2) || is(T == float4))
				enum uint ARMOpType = 3;
			else static if(is(T == long2) || is(T == int4) || is(T == short8) || is(T == byte16))
				enum uint ARMOpType = 1 + (Rounded ? 4 : 0);
			else static if(is(T == ulong2) || is(T == uint4) || is(T == ushort8) || is(T == ubyte16))
				enum uint ARMOpType = 0 + (Rounded ? 4 : 0);
			else
				static assert(0, "Incorrect type");
		}
	}

    /**** Templates for generating TypeTuples ****/
    
    template staticIota(int start, int end, int stride = 1)
    {
        static if(start >= end)
            alias TypeTuple!() staticIota;
        else
            alias TypeTuple!(start, staticIota!(start + stride, end, stride)) 
                staticIota;
    }

    template toTypeTuple(alias array, r...)
    {
        static if(array.length == r.length)
            alias r toTypeTuple;
        else
            alias toTypeTuple!(array, r, array[r.length]) toTypeTuple;
    }

    template interleaveTuples(a...)
    {
        static if(a.length == 0)
            alias TypeTuple!() interleaveTuples;
        else
            alias TypeTuple!(a[0], a[$ / 2], 
                interleaveTuples!(a[1 .. $ / 2], a[$ / 2 + 1 .. $]))
                interleaveTuples; 
    } 
}


///////////////////////////////////////////////////////////////////////////////
// Public API
///////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////
// Load and store

// load scalar into all components (!! or just X?). Note: SLOW on many architectures
Vector!T loadScalar(T, SIMDVer Ver = sseVer)(BaseType!T s)
{
	return loadScalar!V(&s);
}

// load scaler from memory
T loadScalar(T, SIMDVer Ver = sseVer)(BaseType!T* pS) if(isVector!T)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == float[4]))         
				return __builtin_ia32_loadss(pS);
			else static if(is(T == double[2])) 
				return __builtin_ia32_loadddup(pV);
			else
				static assert(0, "TODO");
		}
        else version(LDC)
        {
            //TODO: non-optimal
            T r = 0;
            r = insertelement(r, *pS, 0);
            return r;
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// load vector from an unaligned address
T loadUnaligned(T, SIMDVer Ver = sseVer)(BaseType!T* pV) @trusted
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == float4))
				return __builtin_ia32_loadups(pV);
			else static if(is(T == double2))
				return __builtin_ia32_loadupd(pV);
			else
				return cast(Vector!T)__builtin_ia32_loaddqu(cast(char*)pV);
		}
        else version(LDC)
        {
            union U
            {
                T v;
                ArrayType!T a;
            }
 
            U u;
            u.a = *cast(ArrayType!(T)*) pV;
            return u.v; 
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// return the X element in a scalar register
BaseType!T getScalar(SIMDVer Ver = sseVer, T)(T v) if(isVector!T)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(Ver >= SIMDVer.SSE41 && !is16bitElement!T)
			{
				static if(is(T == float4))
					return __builtin_ia32_vec_ext_v4sf(v, 0);
				else static if(is64bitElement!T)
					return __builtin_ia32_vec_ext_v2di(v, 0);
				else static if(is32bitElement!T)
					return __builtin_ia32_vec_ext_v4si(v, 0);
//				else static if(is16bitElement!T)
//					return __builtin_ia32_vec_ext_v8hi(v, 0); // does this opcode exist??
				else static if(is8bitElement!T)
					return __builtin_ia32_vec_ext_v16qi(v, 0);
			}
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
        else version(LDC)
        {
            return extractelement(v, 0);
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// store the X element to the address provided
// If we use BaseType!T* as a parameter type, T can not be infered
// That's why we need to use template parameter S and check that it is
// the base type in the template constraint. We will use this in some other
// functions too.
void storeScalar(SIMDVer Ver = sseVer, T, S)(T v, S* pS) 
if(isVector!T && is(BaseType!T == S))
{
	// TODO: check this optimises correctly!! (opcode writes directly to memory)
	*pS = getScalar(v);
}

// store the vector to an unaligned address
void storeUnaligned(SIMDVer Ver = sseVer, T, S)(T v, S* pV)
if(isVector!T && is(BaseType!T == S))
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == float4))
				__builtin_ia32_storeups(pV, v);
			else static if(is(T == double2))
				__builtin_ia32_storeupd(pV, v);
			else
				__builtin_ia32_storedqu(cast(char*)pV, cast(byte16)v);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}


///////////////////////////////////////////////////////////////////////////////
// Shuffle, swizzle, permutation

// broadcast X to all elements
T getX(SIMDVer Ver = sseVer, T)(T v) if(isVector!T)
{
	version(X86_OR_X64)
	{
		// broadcast the 1st component
		return swizzle!("0", Ver)(v);
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// broadcast Y to all elements
T getY(SIMDVer Ver = sseVer, T)(T v) if(isVector!T)
{
	version(X86_OR_X64)
	{
		// broadcast the second component
		static if(NumElements!T >= 2)
			return swizzle!("1", Ver)(v);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// broadcast Z to all elements
T getZ(SIMDVer Ver = sseVer, T)(T v) if(isVector!T)
{
	version(X86_OR_X64)
	{
		static if(NumElements!T >= 3)
			return swizzle!("2", Ver)(v); // broadcast the 3nd component
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// broadcast W to all elements
T getW(SIMDVer Ver = sseVer, T)(T v) if(isVector!T)
{
	version(X86_OR_X64)
	{
		static if(NumElements!T >= 4)
			return swizzle!("3", Ver)(v); // broadcast the 4th component
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// set the X element
T setX(SIMDVer Ver = sseVer, T)(T v, T x) 
if(isVector!T)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
			{
				static if(is(T == double2))
					return __builtin_ia32_blendpd(v, x, 1);
				else static if(is(T == float4))
					return __builtin_ia32_blendps(v, x, 1);
				else static if(is64bitElement!T)
					return __builtin_ia32_pblendw128(v, x, 0x0F);
				else static if(is32bitElement!T)
					return __builtin_ia32_pblendw128(v, x, 0x03);
				else static if(is16bitElement!T)
					return __builtin_ia32_pblendw128(v, x, 0x01);
			}
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
        else version(LDC)
        {
            enum int n = NumElements!T;
            return shufflevector(v, x, n, staticIota!(1, n));  
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// set the Y element
T setY(SIMDVer Ver = sseVer, T)(T v, T y)
if(isVector!T)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
			{
				static if(is(T == double2))
					return __builtin_ia32_blendpd(v, y, 2);
				else static if(is(T == float4))
					return __builtin_ia32_blendps(v, y, 2);
				else static if(is64bitElement!T)
					return __builtin_ia32_pblendw128(v, y, 0xF0);
				else static if(is32bitElement!T)
					return __builtin_ia32_pblendw128(v, y, 0x0C);
				else static if(is16bitElement!T)
					return __builtin_ia32_pblendw128(v, y, 0x02);
			}
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
        else version(LDC)
        {
            enum int n = NumElements!T;
            static assert(n >= 2);
            return shufflevector(v, y, 0, n + 1, staticIota!(2, n));  
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// set the Z element
T setZ(SIMDVer Ver = sseVer, T)(T v, T z)
if(isVector!T)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
			{
				static if(is(T == float4))
					return __builtin_ia32_blendps(v, z, 4);
				else static if(is32bitElement!T)
					return __builtin_ia32_pblendw128(v, z, 0x30);
				else static if(is16bitElement!T)
					return __builtin_ia32_pblendw128(v, z, 0x04);
				else
					static assert(0, "Unsupported vector type: " ~ T.stringof);
			}
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
        else version(LDC)
        {
            enum int n = NumElements!T;
            static assert(n >= 3);
            return shufflevector(v, z, 0, 1,  n + 2, staticIota!(3, n));  
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// set the W element
T setW(SIMDVer Ver = sseVer, T)(T v, T w)
if(isVector!T)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(Ver >= SIMDVer.SSE41 && !is8bitElement!T)
			{
				static if(is(T == float4))
					return __builtin_ia32_blendps(v, w, 8);
				else static if(is32bitElement!T)
					return __builtin_ia32_pblendw128(v, w, 0xC0);
				else static if(is16bitElement!T)
					return __builtin_ia32_pblendw128(v, w, 0x08);
				else
					static assert(0, "Unsupported vector type: " ~ T.stringof);
			}
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
        else version(LDC)
        {
            enum int n = NumElements!T;
            static assert(n >= 4);
            return shufflevector(v, w, 0, 1, 2, n + 3, staticIota!(4, n));  
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// swizzle a vector: r = swizzle!"ZZWX"(v); // r = v.zzwx
T swizzle(string swiz, SIMDVer Ver = sseVer, T)(T v)
{
	// parse the string into elements
	int[N] parseElements(string swiz, size_t N)(string[] elements)
	{
		import std.string;
		auto swizzleKey = toLower(swiz);

		// initialise the element list to 'identity'
		int[N] r;
		foreach(int i; 0..N)
			r[i] = i;

        static int countUntil(R, T)(R r, T a)
        {
            int i = 0;
            for(; !r.empty; r.popFront(), i++)
                if(r.front == a)
                    return i; 

            return -1;
        }    

		if(swizzleKey.length == 1)
		{
			// broadcast
			foreach(s; elements)
			{
                auto i = countUntil(s, swizzleKey[0]); 
				if(i != -1)
				{
					// set all elements to 'i'
					r[] = i;
					break;
				}
			}
		}
		else
		{
			// regular swizzle
			bool bFound = false;
			foreach(s; elements) // foreach swizzle naming convention
			{
				foreach(i; 0..swizzleKey.length) // foreach char in swizzle string
				{
					foreach(int j, c; s) // find the offset of the 
					{
						if(swizzleKey[i] == c)
						{
							bFound = true;
							r[i] = j;
							break;
						}
					}
				}

				if(bFound)
					break;
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

	bool isBroadcast(size_t N)(int[N] elements)
	{
		foreach(i; 1..N)
		{
			if(elements[i] != elements[i-1])
				return false;
		}
		return true;
	}

	enum size_t Elements = NumElements!T;

	static assert(swiz.length > 0 && swiz.length <= Elements, "Invalid number of components in swizzle string");

	static if(Elements == 2)
		enum elementNames = ["xy", "01"];
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
		version(X86_OR_X64)
		{
			version(DigitalMars)
			{
				static assert(0, "TODO");
			}
			else version(GNU)
			{
				// broadcasts can usually be implemented more efficiently...
				static if(isBroadcast!Elements(elements) && !is32bitElement!T)
				{
					static if(is(T == double2))
					{
						// unpacks are more efficient than shuffd
						static if(elements[0] == 0)
						{
							static if(0)//Ver >= SIMDVer.SSE3) // TODO: *** WHY DOESN'T THIS WORK?!
								return __builtin_ia32_movddup(v);
							else
								return __builtin_ia32_unpcklpd(v, v);
						}
						else
							return __builtin_ia32_unpckhpd(v, v);
					}
					else static if(is64bitElement!(T)) // (u)long2
					{
						// unpacks are more efficient than shuffd
						static if(elements[0] == 0)
							return __builtin_ia32_punpcklqdq128(v, v);
						else
							return __builtin_ia32_punpckhqdq128(v, v);
					}
					else static if(is16bitElement!T)
					{
						// TODO: we should use permute to perform this operation when immediates work >_<
						static if(false)// Ver >= SIMDVer.SSSE3)
						{
//							immutable ubyte16 permuteControl = [1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0];
//							return __builtin_ia32_pshufb128(v, permuteControl);
						}
						else
						{
							// TODO: is this most efficient?
							// No it is not... we should use a single shuflw/shufhw followed by a 64bit unpack...
							enum int[] shufValues = [0x00, 0x55, 0xAA, 0xFF];
							T t = __builtin_ia32_pshufd(v, shufValues[elements[0] >> 1]);
							t = __builtin_ia32_pshuflw(t, (elements[0] & 1) ? 0x55 : 0x00);
							return __builtin_ia32_pshufhw(t, (elements[0] & 1) ? 0x55 : 0x00);
						}
					}
					else static if(is8bitElement!T)
					{
						static if(Ver >= SIMDVer.SSSE3)
						{
							static if(elements[0] == 0)
								immutable ubyte16 permuteControl = __builtin_ia32_xorps(v, v); // generate a zero register
							else
								immutable ubyte16 permuteControl = cast(ubyte)elements[0]; // load a permute constant
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
					static if(is(T == double2))
						return __builtin_ia32_shufpd(v, v, shufMask!Elements(elements)); // swizzle: YX
					else static if(is64bitElement!(T)) // (u)long2
						// use a 32bit integer shuffle for swizzle: YZ
						return __builtin_ia32_pshufd(v, shufMask!4([elements[0]*2, elements[0]*2 + 1, elements[1]*2, elements[1]*2 + 1]));
					else static if(is(T == float4))
					{
						static if(elements == [0,0,2,2] && Ver >= SIMDVer.SSE3)
							return __builtin_ia32_movsldup(v);
						else static if(elements == [1,1,3,3] && Ver >= SIMDVer.SSE3)
							return __builtin_ia32_movshdup(v);
						else
							return __builtin_ia32_shufps(v, v, shufMask!Elements(elements));
					}
					else static if(is32bitElement!(T))
						return __builtin_ia32_pshufd(v, shufMask!Elements(elements));
					else
					{
						// TODO: 16 and 8bit swizzles...
						static assert(0, "Unsupported vector type: " ~ T.stringof);
					}
				}
			}
            else version(LDC)
            {
                return shufflevector(v, v, toTypeTuple!elements);
            }
		}
		else version(ARM)
		{
			static assert(0, "TODO");
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
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(Ver >= SIMDVer.SSE3)
				return cast(T)__builtin_ia32_pshufb128(cast(ubyte16)v, control);
			else
				static assert(0, "Only supported in SSSE3 and above");
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// interleave low elements from 2 vectors
T interleaveLow(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	// this really requires multiple return values >_<

	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == float4))
				return __builtin_ia32_unpcklps(v1, v2);
			else static if(is(T == double2))
				return __builtin_ia32_unpcklpd(v1, v2);
			else static if(is64bitElement!T)
				return __builtin_ia32_punpcklqdq128(v1, v2);
			else static if(is32bitElement!T)
				return __builtin_ia32_punpckldq128(v1, v2);
			else static if(is16bitElement!T)
				return __builtin_ia32_punpcklwd128(v1, v2);
			else static if(is8bitElement!T)
				return __builtin_ia32_punpcklbw128(v1, v2);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
        else version(LDC)
        {
            enum int n = NumElements!T;
            
            return shufflevector(v1, v2, interleaveTuples!(
                staticIota!(0, n / 2), staticIota!(n, n + n / 2)));
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// interleave high elements from 2 vectors
T interleaveHigh(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	// this really requires multiple return values >_<

	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == float4))
				return __builtin_ia32_unpckhps(v1, v2);
			else static if(is(T == double2))
				return __builtin_ia32_unpckhpd(v1, v2);
			else static if(is64bitElement!T)
				return __builtin_ia32_punpckhqdq128(v1, v2);
			else static if(is32bitElement!T)
				return __builtin_ia32_punpckhdq128(v1, v2);
			else static if(is16bitElement!T)
				return __builtin_ia32_punpckhwd128(v1, v2);
			else static if(is8bitElement!T)
				return __builtin_ia32_punpckhbw128(v1, v2);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
        else version(LDC)
        {
            enum int n = NumElements!T;
            
            return shufflevector(v1, v2, interleaveTuples!(
                staticIota!(n / 2, n), staticIota!(n + n / 2, n + n)));
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

//... there are many more useful permutation ops



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

PromotionOf!T unpackLow(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == int4))
				return cast(PromotionOf!T)interleaveLow!Ver(v, shiftRightImmediate!(31, Ver)(v));
			else static if(is(T == uint4))
				return cast(PromotionOf!T)interleaveLow!Ver(v, 0);
			else static if(is(T == short8))
				return shiftRightImmediate!(16, Ver)(cast(int4)interleaveLow!Ver(v, v));
			else static if(is(T == ushort8))
				return cast(PromotionOf!T)interleaveLow!Ver(v, 0);
			else static if(is(T == byte16))
				return shiftRightImmediate!(8, Ver)(cast(short8)interleaveLow!Ver(v, v));
			else static if(is(T == ubyte16))
				return cast(PromotionOf!T)interleaveLow!Ver(v, 0);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
        else version(LDC)
        {
            enum int n = NumElements!T;
            T zero = 0;
            alias interleaveTuples!(
                staticIota!(0, n / 2), staticIota!(n, n + n / 2)) index;

            return cast(PromotionOf!T) shufflevector(v, zero, index);
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

PromotionOf!T unpackHigh(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == int4))
				return cast(PromotionOf!T)interleaveHigh!Ver(v, shiftRightImmediate!(31, Ver)(v));
			else static if(is(T == uint4))
				return cast(PromotionOf!T)interleaveHigh!Ver(v, cast(uint4)0);
			else static if(is(T == short8))
				return shiftRightImmediate!(16, Ver)(cast(int4)interleaveHigh!Ver(v, v));
			else static if(is(T == ushort8))
				return cast(PromotionOf!T)interleaveHigh!Ver(v, cast(ushort8)0);
			else static if(is(T == byte16))
				return shiftRightImmediate!(8, Ver)(cast(short8)interleaveHigh!Ver(v, v));
			else static if(is(T == ubyte16))
				return cast(PromotionOf!T)interleaveHigh!Ver(v, cast(ubyte16)0);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
        else version(LDC)
        {
            enum int n = NumElements!T;
            T zero = 0;
            alias interleaveTuples!(
                staticIota!(n / 2, n), staticIota!(n + n / 2, n + n)) index;
            
            return cast(PromotionOf!T) shufflevector(v, zero, index);
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

DemotionOf!T pack(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == long2))
				static assert(0, "TODO");
			else static if(is(T == ulong2))
				static assert(0, "TODO");
			else static if(is(T == int4))
			{
				static assert(0, "TODO");
				// return _mm_packs_epi32( _mm_srai_epi32( _mm_slli_epi16( a, 16), 16), _mm_srai_epi32( _mm_slli_epi32( b, 16), 16) );
			}
			else static if(is(T == uint4))
			{
				static assert(0, "TODO");
				// return _mm_packs_epi32( _mm_srai_epi32( _mm_slli_epi32( a, 16), 16), _mm_srai_epi32( _mm_slli_epi32( b, 16), 16) );
			}
			else static if(is(T == short8))
			{
				static assert(0, "TODO");
				// return _mm_packs_epi16( _mm_srai_epi16( _mm_slli_epi16( a, 8), 8), _mm_srai_epi16( _mm_slli_epi16( b, 8), 8) );
			}
			else static if(is(T == ushort8))
			{
				static assert(0, "TODO");
				// return _mm_packs_epi16( _mm_and_si128( a, 0x00FF), _mm_and_si128( b, 0x00FF) );
			}
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
        else version(LDC)
        {
            alias DemotionOf!T D;
            enum int n = NumElements!D;

            return shufflevector(
                cast(D) v1, cast(D) v2, staticIota!(0, 2 * n, 2));
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

DemotionOf!T packSaturate(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == int4))
				return __builtin_ia32_packssdw128(v1, v2);
			else static if(is(T == uint4))
				static assert(0, "TODO: should we emulate this?");
			else static if(is(T == short8))
				return __builtin_ia32_packsswb128(v1, v2);
			else static if(is(T == ushort8))
				return __builtin_ia32_packuswb128(v1, v2);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

///////////////////////////////////////////////////////////////////////////////
// Type conversion

int4 toInt(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == float4))
				return __builtin_ia32_cvtps2dq(v);
			else static if(is(T == double2))
				return __builtin_ia32_cvtpd2dq(v); // TODO: z,w are undefined... should we repeat xy to zw?
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

float4 toFloat(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == int4))
				return __builtin_ia32_cvtdq2ps(v);
			else static if(is(T == double2))
				return __builtin_ia32_cvtpd2ps(v); // TODO: z,w are undefined... should we repeat xy to zw?
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

double2 toDouble(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == int4))
				return __builtin_ia32_cvtdq2pd(v);
			else static if(is(T == float4))
				return __builtin_ia32_cvtps2pd(v);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
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

	/******************************
	* integer abs with no branches
	*   mask = v >> numBits(v)-1;
	*   r = (v + mask) ^ mask;
	******************************/

	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == double2))
            {
                version(GNU)
                    return __builtin_ia32_andnpd(cast(double2)signMask2, v);
                else
                    return cast(double2)(~signMask2 & cast(ulong2)v);
            }
			else static if(is(T == float4))
            {
                version(GNU)
                    return __builtin_ia32_andnps(cast(float4)signMask4, v);
                else
                    return cast(float4)(~signMask4 & cast(uint4)v);
            }
			else static if(Ver >= SIMDVer.SSSE3)
			{
				static if(is64bitElement!(T))
					static assert(0, "Unsupported: abs(" ~ T.stringof ~ "). Should we emulate?");
				else static if(is32bitElement!(T))
					return __builtin_ia32_pabsd128(v);
				else static if(is16bitElement!(T))
					return __builtin_ia32_pabsw128(v);
				else static if(is8bitElement!(T))
					return __builtin_ia32_pabsb128(v);
			}
			else static if(is(T == int4))
			{
				int4 t = shiftRightImmediate!(31, Ver)(v);
				return sub!Ver(xor!Ver(v, t), t);
			}
			else static if(is(T == short8))
			{
				return max!Ver(v, sub!Ver(0, v));
			}
			else static if(is(T == byte16))
			{
				byte16 t = maskGreater!Ver(0, v);
				return sub!Ver(xor!Ver(v, t), t);
			}
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static if(is(T == float4))
			return __builtin_neon_vabsv4sf(v, ARMOpType!T);
		else static if(is(T == int4))
			return __builtin_neon_vabsv4si(v, ARMOpType!T);
		else static if(is(T == short8))
			return __builtin_neon_vabsv8hi(v, ARMOpType!T);
		else static if(is(T == byte16))
			return __builtin_neon_vabsv16qi(v, ARMOpType!T);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
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

	version(X86_OR_X64)
	{
		return -v;
	}
	else version(ARM)
	{
		static if(is(T == float4))
			return __builtin_neon_vnegv4sf(v, ARMOpType!T);
		else static if(is(T == int4))
			return __builtin_neon_vnegv4si(v, ARMOpType!T);
		else static if(is(T == short8))
			return __builtin_neon_vnegv8hi(v, ARMOpType!T);
		else static if(is(T == byte16))
			return __builtin_neon_vnegv16qi(v, ARMOpType!T);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// binary add
T add(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		return v1 + v2;
	}
	else version(ARM)
	{
		static if(is(T == float4))
			return __builtin_neon_vaddv4sf(v1, v2, ARMOpType!T);
		else static if(is64bitInteger!T)
			return __builtin_neon_vaddv2di(v1, v2, ARMOpType!T);
		else static if(is32bitElement!T)
			return __builtin_neon_vaddv4si(v1, v2, ARMOpType!T);
		else static if(is16bitElement!T)
			return __builtin_neon_vaddv8hi(v1, v2, ARMOpType!T);
		else static if(is8bitElement!T)
			return __builtin_neon_vaddv16qi(v1, v2, ARMOpType!T);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// binary add and saturate
T addSaturate(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == short8))
				return __builtin_ia32_paddsw(v1, v2);
			else static if(is(T == ushort8))
				return __builtin_ia32_paddusw(v1, v2);
			else static if(is(T == byte16))
				return __builtin_ia32_paddsb(v1, v2);
			else static if(is(T == ubyte16))
				return __builtin_ia32_paddusb(v1, v2);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// binary subtract
T sub(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		return v1 - v2;
	}
	else version(ARM)
	{
		static if(is(T == float4))
			return __builtin_neon_vsubv4sf(v1, v2, ARMOpType!T);
		else static if(is64bitInteger!T)
			return __builtin_neon_vsubv2di(v1, v2, ARMOpType!T);
		else static if(is32bitElement!T)
			return __builtin_neon_vsubv4si(v1, v2, ARMOpType!T);
		else static if(is16bitElement!T)
			return __builtin_neon_vsubv8hi(v1, v2, ARMOpType!T);
		else static if(is8bitElement!T)
			return __builtin_neon_vsubv16qi(v1, v2, ARMOpType!T);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// binary subtract and saturate
T subSaturate(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == short8))
				return __builtin_ia32_psubsw(v1, v2);
			else static if(is(T == ushort8))
				return __builtin_ia32_psubusw(v1, v2);
			else static if(is(T == byte16))
				return __builtin_ia32_psubsb(v1, v2);
			else static if(is(T == ubyte16))
				return __builtin_ia32_psubusb(v1, v2);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// binary multiply
T mul(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		return v1 * v2;
	}
	else version(ARM)
	{
		static if(is(T == float4))
			return __builtin_neon_vmulv4sf(v1, v2, ARMOpType!T);
		else static if(is64bitInteger!T)
			return __builtin_neon_vmulv2di(v1, v2, ARMOpType!T);
		else static if(is32bitElement!T)
			return __builtin_neon_vmulv4si(v1, v2, ARMOpType!T);
		else static if(is16bitElement!T)
			return __builtin_neon_vmulv8hi(v1, v2, ARMOpType!T);
		else static if(is8bitElement!T)
			return __builtin_neon_vmulv16qi(v1, v2, ARMOpType!T);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// multiply and add: v1*v2 + v3
T madd(SIMDVer Ver = sseVer, T)(T v1, T v2, T v3)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			return v1*v2 + v3;
		}
		else version(GNU_OR_LDC)    // TODO: declare the SSE5 builtins for LDC
		{
			static if(is(T == double2) && Ver == SIMDVer.SSE5)
				return __builtin_ia32_fmaddpd(v1, v2, v3);
			else static if(is(T == float4) && Ver == SIMDVer.SSE5)
				return __builtin_ia32_fmaddps(v1, v2, v3);
			else
				return v1*v2 + v3;
		}
	}
	else version(ARM)
	{
		static if(false)//Ver == SIMDVer.VFPv4)
		{
			// VFPv4 has better opcodes, but i can't find the intrinsics right now >_<
			// VFMA, VFMS, VFNMA, and VFNMS
		}
		else
		{
			static if(is(T == float4))
				return __builtin_neon_vmlav4sf(v3, v1, v2, ARMOpType!T);
			else static if(is64bitInteger!T)
				return __builtin_neon_vmlav2di(v3, v1, v2, ARMOpType!T);
			else static if(is32bitElement!T)
				return __builtin_neon_vmlav4si(v3, v1, v2, ARMOpType!T);
			else static if(is16bitElement!T)
				return __builtin_neon_vmlav8hi(v3, v1, v2, ARMOpType!T);
			else static if(is8bitElement!T)
				return __builtin_neon_vmlav16qi(v3, v1, v2, ARMOpType!T);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// multiply and subtract: v1*v2 - v3
T msub(SIMDVer Ver = sseVer, T)(T v1, T v2, T v3)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			return v1*v2 - v3;
		}
		else version(GNU_OR_LDC)    // TODO: declare the SSE5 builtins for LDC
		{
			static if(is(T == double2) && Ver == SIMDVer.SSE5)
				return __builtin_ia32_fmsubpd(v1, v2, v3);
			else static if(is(T == float4) && Ver == SIMDVer.SSE5)
				return __builtin_ia32_fmsubps(v1, v2, v3);
			else
				return v1*v2 - v3;
		}
	}
	else version(ARM)
	{
		static if(false)//Ver == SIMDVer.VFPv4)
		{
			// VFPv4 has better opcodes, but i can't find the intrinsics right now >_<
			// VFMA, VFMS, VFNMA, and VFNMS
		}
		else
		{
			return sub!Ver(mul!Ver(v1, v2), v3);
		}
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// negate multiply and add: -(v1*v2) + v3
T nmadd(SIMDVer Ver = sseVer, T)(T v1, T v2, T v3)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			return v3 - v1*v2;
		}
		else version(GNU_OR_LDC)    // TODO: declare the SSE5 builtins for LDC
		{
			static if(is(T == double2) && Ver == SIMDVer.SSE5)
				return __builtin_ia32_fnmaddpd(v1, v2, v3);
			else static if(is(T == float4) && Ver == SIMDVer.SSE5)
				return __builtin_ia32_fnmaddps(v1, v2, v3);
			else
				return v3 - (v1*v2);
		}
	}
	else version(ARM)
	{
		static if(false)//Ver == SIMDVer.VFPv4)
		{
			// VFPv4 has better opcodes, but i can't find the intrinsics right now >_<
			// VFMA, VFMS, VFNMA, and VFNMS
		}
		else
		{
			// Note: ARM's msub is backwards, it performs:  r = r - a*b
			// Which is identical to the conventinal nmadd: r = -(a*b) + c

			static if(is(T == float4))
				return __builtin_neon_vmlsv4sf(v3, v1, v2, ARMOpType!T);
			else static if(is64bitInteger!T)
				return __builtin_neon_vmlsv2di(v3, v1, v2, ARMOpType!T);
			else static if(is32bitElement!T)
				return __builtin_neon_vmlsv4si(v3, v1, v2, ARMOpType!T);
			else static if(is16bitElement!T)
				return __builtin_neon_vmlsv8hi(v3, v1, v2, ARMOpType!T);
			else static if(is8bitElement!T)
				return __builtin_neon_vmlsv16qi(v3, v1, v2, ARMOpType!T);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(PowerPC)
	{
		// note PowerPC also has an opcode for this...
		static assert(0, "Unsupported on this architecture");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// negate multiply and subtract: -(v1*v2) - v3
T nmsub(SIMDVer Ver = sseVer, T)(T v1, T v2, T v3)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			return -(v1*v2) - v3;
		}
		else version(GNU_OR_LDC)    // TODO: declare the SSE5 builtins for LDC
		{
			static if(is(T == double2) && Ver == SIMDVer.SSE5)
				return __builtin_ia32_fnmsubpd(v1, v2, v3);
			else static if(is(T == float4) && Ver == SIMDVer.SSE5)
				return __builtin_ia32_fnmsubps(v1, v2, v3);
			else
				return -(v1*v2) - v3;
		}
	}
	else version(ARM)
	{
		static if(false)//Ver == SIMDVer.VFPv4)
		{
			// VFPv4 has better opcodes, but i can't find the intrinsics right now >_<
			// VFMA, VFMS, VFNMA, and VFNMS
		}
		else
		{
			return nmadd!Ver(v1, v2, neg!Ver(v3));
		}
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// min
T min(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
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
					return selectGreater!Ver(v1, v2, v2, v1);
			}
			else static if(is(T == uint4))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pminud128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v2, v1);
			}
			else static if(is(T == short8))
				return __builtin_ia32_pminsw128(v1, v2); // available in SSE2
			else static if(is(T == ushort8))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pminuw128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v2, v1);
			}
			else static if(is(T == byte16))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pminsb128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v2, v1);
			}
			else static if(is(T == ubyte16))
				return __builtin_ia32_pminub128(v1, v2); // available in SSE2
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static if(is(T == float4))
			return __builtin_neon_vminv4sf(v1, v2, ARMOpType!T);
		else static if(is64bitInteger!T)
			return __builtin_neon_vminv2di(v1, v2, ARMOpType!T);
		else static if(is32bitElement!T)
			return __builtin_neon_vminv4si(v1, v2, ARMOpType!T);
		else static if(is16bitElement!T)
			return __builtin_neon_vminv8hi(v1, v2, ARMOpType!T);
		else static if(is8bitElement!T)
			return __builtin_neon_vminv16qi(v1, v2, ARMOpType!T);
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
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
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
					return selectGreater!Ver(v1, v2, v1, v2);
			}
			else static if(is(T == uint4))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pmaxud128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v1, v2);
			}
			else static if(is(T == short8))
				return __builtin_ia32_pmaxsw128(v1, v2); // available in SSE2
			else static if(is(T == ushort8))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pmaxuw128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v1, v2);
			}
			else static if(is(T == byte16))
			{
				static if(Ver >= SIMDVer.SSE41)
					return __builtin_ia32_pmaxsb128(v1, v2);
				else
					return selectGreater!Ver(v1, v2, v1, v2);
			}
			else static if(is(T == ubyte16))
				return __builtin_ia32_pmaxub128(v1, v2); // available in SSE2
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static if(is(T == float4))
			return __builtin_neon_vmaxv4sf(v1, v2, ARMOpType!T);
		else static if(is64bitInteger!T)
			return __builtin_neon_vmaxv2di(v1, v2, ARMOpType!T);
		else static if(is32bitElement!T)
			return __builtin_neon_vmaxv4si(v1, v2, ARMOpType!T);
		else static if(is16bitElement!T)
			return __builtin_neon_vmaxv8hi(v1, v2, ARMOpType!T);
		else static if(is8bitElement!T)
			return __builtin_neon_vmaxv16qi(v1, v2, ARMOpType!T);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// clamp values such that a <= v <= b
T clamp(SIMDVer Ver = sseVer, T)(T a, T v, T b)
{
	return max!Ver(a, min!Ver(v, b));
}

// lerp
T lerp(SIMDVer Ver = sseVer, T)(T a, T b, T t)
{
	return madd!Ver(sub!Ver(b, a), t, a);
}


///////////////////////////////////////////////////////////////////////////////
// Floating point operations

// round to the next lower integer value
T floor(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
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
			{
				static assert(0, "Unsupported vector type: " ~ T.stringof);
/*
				static const vFloat twoTo23 = (vFloat){ 0x1.0p23f, 0x1.0p23f, 0x1.0p23f, 0x1.0p23f };
				vFloat b = (vFloat) _mm_srli_epi32( _mm_slli_epi32( (vUInt32) v, 1 ), 1 ); //fabs(v)
				vFloat d = _mm_sub_ps( _mm_add_ps( _mm_add_ps( _mm_sub_ps( v, twoTo23 ), twoTo23 ), twoTo23 ), twoTo23 ); //the meat of floor
				vFloat largeMaskE = (vFloat) _mm_cmpgt_ps( b, twoTo23 ); //-1 if v >= 2**23
				vFloat g = (vFloat) _mm_cmplt_ps( v, d ); //check for possible off by one error
				vFloat h = _mm_cvtepi32_ps( (vUInt32) g ); //convert positive check result to -1.0, negative to 0.0
				vFloat t = _mm_add_ps( d, h ); //add in the error if there is one

				//Select between output result and input value based on v >= 2**23
				v = _mm_and_ps( v, largeMaskE );
				t = _mm_andnot_ps( largeMaskE, t );

				return _mm_or_ps( t, v );
*/
			}
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// round to the next higher integer value
T ceil(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
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
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// round to the nearest integer value
T round(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
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
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// truncate fraction (round towards zero)
T trunc(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
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
			{
				static assert(0, "Unsupported vector type: " ~ T.stringof);
/*
				static const vFloat twoTo23 = (vFloat){ 0x1.0p23f, 0x1.0p23f, 0x1.0p23f, 0x1.0p23f };
				vFloat b = (vFloat) _mm_srli_epi32( _mm_slli_epi32( (vUInt32) v, 1 ), 1 ); //fabs(v)
				vFloat d = _mm_sub_ps( _mm_add_ps( b, twoTo23 ), twoTo23 ); //the meat of floor
				vFloat largeMaskE = (vFloat) _mm_cmpgt_ps( b, twoTo23 ); //-1 if v >= 2**23
				vFloat g = (vFloat) _mm_cmplt_ps( b, d ); //check for possible off by one error
				vFloat h = _mm_cvtepi32_ps( (vUInt32) g ); //convert positive check result to -1.0, negative to 0.0
				vFloat t = _mm_add_ps( d, h ); //add in the error if there is one

				//put the sign bit back
				vFloat sign = (vFloat) _mm_slli_epi31( _mm_srli128( (vUInt32) v, 31), 31 );
				t = _mm_or_ps( t, sign );

				//Select between output result and input value based on fabs(v) >= 2**23
				v = _mm_and_ps( v, largeMaskE );
				t = _mm_andnot_ps( largeMaskE, t );

				return _mm_or_ps( t, v );
*/
			}
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
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
	version(X86_OR_X64)
	{
		return v1 / v2;
	}
	else version(ARM)
	{
		return mul!Ver(v1, rcp!Ver(v2));
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// reciprocal
T rcp(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == double2))
				return div!Ver(1.0, v);
			else static if(is(T == float4))
				return __builtin_ia32_rcpps(v);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO!");
		static if(is(T == float4))
			return null;
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
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == double2))
				return __builtin_ia32_sqrtpd(v);
			else static if(is(T == float4))
				return __builtin_ia32_sqrtps(v);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO!");
		static if(is(T == float4))
			return null;
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
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == double2))
				return rcp!Ver(sqrt!Ver(v));
			else static if(is(T == float4))
				return __builtin_ia32_rsqrtps(v);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO!");
		static if(is(T == float4))
			return null;
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}


///////////////////////////////////////////////////////////////////////////////
// Vector maths operations

// 2d dot product
T dot2(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == double2))
			{
				static if(Ver >= SIMDVer.SSE41) // 1 op
					return __builtin_ia32_dppd(v1, v2, 0x0F);
				else static if(Ver >= SIMDVer.SSE3) // 2 ops
				{
					double2 t = v1 * v2;
					return __builtin_ia32_haddpd(t, t);
				}
				else // 5 ops
				{
					double2 t = v1 * v2;
					return getX!Ver(t) + getY!Ver(t);
				}
			}
			else static if(is(T == float4))
			{
				static if(Ver >= SIMDVer.SSE41) // 1 op
					return __builtin_ia32_dpps(v1, v2, 0x3F);
				else static if(Ver >= SIMDVer.SSE3) // 3 ops
				{
					float4 t = v1 * v2;
					t = __builtin_ia32_haddps(t, t);
					return swizzle!("XXZZ", Ver)(t);
				}
				else // 5 ops
				{
					float4 t = v1 * v2;
					return getX!Ver(t) + getY!Ver(t);
				}
			}
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// 3d dot product
T dot3(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == float4))
			{
				static if(Ver >= SIMDVer.SSE41) // 1 op
					return __builtin_ia32_dpps(v1, v2, 0x7F);
				else static if(Ver >= SIMDVer.SSE3) // 4 ops
				{
					float4 t = shiftElementsRight!(1, Ver)(v1 * v2);
					t = __builtin_ia32_haddps(t, t);
					return __builtin_ia32_haddps(t, t);
				}
				else // 8 ops!... surely we can do better than this?
				{
					float4 t = shiftElementsRight!(1, Ver)(v1 * v2);
					t = t + swizzle!("yxwz", Ver)(t);
					return t + swizzle!("zzxx", Ver)(t);
				}
			}
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// 4d dot product
T dot4(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == float4))
			{
				static if(Ver >= SIMDVer.SSE41) // 1 op
					return __builtin_ia32_dpps(v1, v2, 0xFF);
				else static if(Ver >= SIMDVer.SSE3) // 3 ops
				{
					float4 t = v1 * v2;
					t = __builtin_ia32_haddps(t, t);
					return __builtin_ia32_haddps(t, t);
				}
				else // 7 ops!... surely we can do better than this?
				{
					float4 t = v1 * v2;
					t = t + swizzle!("yxwz", Ver)(t);
					return t + swizzle!("zzxx", Ver)(t);
				}
			}
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// homogeneous dot product: v1.xyz1 dot v2.xyzw
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

// 3d normalise
T normalise3(SIMDVer Ver = sseVer, T)(T v)
{
	return v * rsqrt!Ver(magSq3!Ver(v));
}

// 4d normalise
T normalise4(SIMDVer Ver = sseVer, T)(T v)
{
	return v * rsqrt!Ver(magSq4!Ver(v));
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


///////////////////////////////////////////////////////////////////////////////
// Fast estimates

// divide estimate
T divEst(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(ARM)
	{
		return mul!Ver(v1, rcpEst!Ver(v2));
	}
	else
	{
		return div!Ver(v1, v2);
	}
}

// reciprocal estimate
T rcpEst(SIMDVer Ver = sseVer, T)(T v)
{
	version(ARM)
	{
		static if(is(T == float4))
			return __builtin_neon_vrecpev4sf(v, ARMOpType!T);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		return rcp!Ver(v);
	}
}

// square root estimate
T sqrtEst(SIMDVer Ver = sseVer, T)(T v)
{
	version(ARM)
	{
		static assert(0, "TODO: I'm sure ARM has a good estimate for this...");
	}
	else
	{
		return sqrt!Ver(v);
	}
}

// reciprocal square root estimate
T rsqrtEst(SIMDVer Ver = sseVer, T)(T v)
{
	version(ARM)
	{
		static if(is(T == float4))
			return __builtin_neon_vrsqrtev4sf(v, ARMOpType!T);
		else
			static assert(0, "Unsupported vector type: " ~ T.stringof);
	}
	else
	{
		return rsqrt!Ver(v);
	}
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

// 3d normalise estimate
T normEst3(SIMDVer Ver = sseVer, T)(T v)
{
	return v * rsqrtEst!Ver(magSq3!Ver(v));
}

// 4d normalise estimate
T normEst4(SIMDVer Ver = sseVer, T)(T v)
{
	return v * rsqrtEst!Ver(magSq4!Ver(v));
}


///////////////////////////////////////////////////////////////////////////////
// Bitwise operations

// unary compliment: ~v
T comp(SIMDVer Ver = sseVer, T)(T v)
{
	version(X86_OR_X64)
	{
		return ~v;
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// bitwise or: v1 | v2
T or(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == double2))
				return __builtin_ia32_orpd(v1, v2);
			else static if(is(T == float4))
				return __builtin_ia32_orps(v1, v2);
			else
				return __builtin_ia32_por128(v1, v2);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// bitwise nor: ~(v1 | v2)
T nor(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	return comp!Ver(or!Ver(v1, v2));
}

// bitwise and: v1 & v2
T and(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
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
        else version(LDC)
        {
            return cast(T)(cast(int4) v1 & cast(int4) v2); 
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// bitwise nand: ~(v1 & v2)
T nand(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	return comp!Ver(and!Ver(v1, v2));
}

// bitwise and with not: v1 & ~v2
T andNot(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(is(T == double2))
				return __builtin_ia32_andnpd(v2, v1);
			else static if(is(T == float4))
				return __builtin_ia32_andnps(v2, v1);
			else
				return __builtin_ia32_pandn128(v2, v1);
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// bitwise xor: v1 ^ v2
T xor(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
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
        else version(LDC)
        {
            return cast(T) (cast(int4) v1 ^ cast(int4) v2); 
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}


///////////////////////////////////////////////////////////////////////////////
// Bit shifts and rotates

// binary shift left
T shiftLeft(SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
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
	}
	else version(ARM)
	{
		static assert(0, "TODO");
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
		return v;
	else
	{
		version(X86_OR_X64)
		{
			version(DigitalMars)
			{
				static assert(0, "TODO");
			}
			else version(GNU_OR_LDC)
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
		}
		else version(ARM)
		{
			static assert(0, "TODO");
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
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
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
	}
	else version(ARM)
	{
		static assert(0, "TODO");
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
		return v;
	else
	{
		version(X86_OR_X64)
		{
			version(DigitalMars)
			{
				static assert(0, "TODO");
			}
			else version(GNU_OR_LDC)
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
		}
		else version(ARM)
		{
			static assert(0, "TODO");
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
		return v;
	else
	{
		version(X86_OR_X64)
		{
			version(DigitalMars)
			{
				static assert(0, "TODO");
			}
			else version(GNU_OR_LDC)
			{
				// little endian reads the bytes into the register in reverse, so we need to flip the operations
				return __builtin_ia32_psrldqi128(v, bytes * 8); // TODO: *8? WAT?
			}
		}
		else version(ARM)
		{
			static assert(0, "TODO");
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
		return v;
	else
	{
		version(X86_OR_X64)
		{
			version(DigitalMars)
			{
				static assert(0, "TODO");
			}
			else version(GNU_OR_LDC)
			{
				// little endian reads the bytes into the register in reverse, so we need to flip the operations
				return __builtin_ia32_pslldqi128(v, bytes * 8); // TODO: *8? WAT?
			}
		}
		else version(ARM)
		{
			static assert(0, "TODO");
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
		return v;
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
		return v;
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
	return shiftBytesLeftImmediate!(n * BaseType!(T).sizeof, Ver)(v);
}

// shift elements right
T shiftElementsRight(size_t n, SIMDVer Ver = sseVer, T)(T v)
{
	return shiftBytesRightImmediate!(n * BaseType!(T).sizeof, Ver)(v);
}

// shift elements left
T shiftElementsLeftPair(size_t n, SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	static if(n == 0) // shift by 0 is a no-op
		return v;
	else
	{
		static assert(n >= 0 && n < NumElements!T, "Invalid shift amount");

		// TODO: detect opportunities to use shuf instead of shifts...
		return or!Ver(shiftElementsLeft!(n, Ver)(v1), shiftElementsRight!(NumElements!T - n, Ver)(v2));
	}
}

// shift elements right
T shiftElementsRightPair(size_t n, SIMDVer Ver = sseVer, T)(T v1, T v2)
{
	static if(n == 0) // shift by 0 is a no-op
		return v;
	else
	{
		static assert(n >= 0 && n < NumElements!T, "Invalid shift amount");

		// TODO: detect opportunities to use shuf instead of shifts...
		return or!Ver(shiftElementsRight!(n, Ver)(v1), shiftElementsLeft!(NumElements!T - n, Ver)(v2));
	}
}

// rotate elements left
T rotateElementsLeft(size_t n, SIMDVer Ver = sseVer, T)(T v)
{
	enum e = n & (NumElements!T - 1); // large rotations should wrap

	static if(e == 0) // shift by 0 is a no-op
		return v;
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
					return swizzle!("YZWX",Ver)(v); // X, [Y, Z, W, X], Y, Z, W
				static if(e == 2)
					return swizzle!("ZWXY",Ver)(v); // X, Y, [Z, W, X, Y], Z, W
				static if(e == 3)
					return swizzle!("WXYZ",Ver)(v); // X, Y, Z, [W, X, Y, Z], W
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
					return cast(T)rotateElementsLeft!(bytes >> 2, Ver)(cast(uint4)v);
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
		return v;
	else
	{
		// just invert the rotation
		return rotateElementsLeft!(NumElements!T - e, Ver)(v);
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
	version(X86_OR_X64)
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
        else version(LDC)
        {
			static if(is(T == double2))
				return __builtin_ia32_cmppd(a, b, 0);
			else static if(is(T == float4))
				return __builtin_ia32_cmpps(a, b, 0);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// generate a bitmask of for elements: Rn = An != Bn ? -1 : 0 (SLOW)
void16 maskNotEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(X86_OR_X64)
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
				return comp!Ver(cast(void16)maskEqual!Ver(a, b));
		}
        else version(LDC)
        {
			static if(is(T == double2))
				return __builtin_ia32_cmppd(a, b, 4);
			else static if(is(T == float4))
				return __builtin_ia32_cmpps(a, b, 4);
	        else
                static assert(0, "Unsupported vector type: " ~ T.stringof);
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// generate a bitmask of for elements: Rn = An > Bn ? -1 : 0
void16 maskGreater(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == double2))
            {
                return __builtin_ia32_cmpgtpd(a, b);
            }
			else static if(is(T == float4))
            {
                return __builtin_ia32_cmpgtps(a, b);
            }
			else static if(is(T == long2))
			{
                return __builtin_ia32_pcmpgtq(a, b);
			}
			else static if(is(T == ulong2))
			{
                return __builtin_ia32_pcmpgtq(a + signMask2, b + signMask2);
			}
			else static if(is(T == int4))
				return __builtin_ia32_pcmpgtd128(a, b);
			else static if(is(T == uint4))
				return __builtin_ia32_pcmpgtd128(a + signMask4, b + signMask4);
			else static if(is(T == short8))
				return __builtin_ia32_pcmpgtw128(a, b);
			else static if(is(T == ushort8))
				return __builtin_ia32_pcmpgtw128(a + signMask8, b + signMask8);
			else static if(is(T == byte16))
				return __builtin_ia32_pcmpgtb128(a, b);
			else
				static assert(0, "Unsupported vector type: " ~ T.stringof);
		}
        else version(LDC)
        {
            mixin(ldcFloatMaskLess!(T.stringof, "b", "a", false));
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// generate a bitmask of for elements: Rn = An >= Bn ? -1 : 0 (SLOW)
void16 maskGreaterEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(X86_OR_X64)
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
				return or!Ver(cast(void16)maskGreater!Ver(a, b), cast(void16)maskEqual!Ver(a, b)); // compound greater OR equal
		}
        else version(LDC)
        {
            mixin(ldcFloatMaskLess!(T.stringof, "b", "a", true));
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// generate a bitmask of for elements: Rn = An < Bn ? -1 : 0 (SLOW)
void16 maskLess(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(X86_OR_X64)
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
        else version(LDC)
        {
            mixin(ldcFloatMaskLess!(T.stringof, "a", "b", false));
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}

// generate a bitmask of for elements: Rn = An <= Bn ? -1 : 0
void16 maskLessEqual(SIMDVer Ver = sseVer, T)(T a, T b)
{
	version(X86_OR_X64)
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
				return maskGreaterEqual!Ver(b, a); // reverse the args
		}
        else version(LDC)
        {
            mixin(ldcFloatMaskLess!(T.stringof, "a", "b", true));
        }
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}


///////////////////////////////////////////////////////////////////////////////
// Branchless selection

// select elements according to: mask == true ? x : y
T select(SIMDVer Ver = sseVer, T)(void16 mask, T x, T y)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU_OR_LDC)
		{
			static if(Ver >= SIMDVer.SSE41)
			{
				static if(is(T == double2))
					return __builtin_ia32_blendvpd(y, x, cast(double2)mask);
				else static if(is(T == float4))
					return __builtin_ia32_blendvps(y, x, cast(float4)mask);
				else
                {
                    alias PblendvbParam P;
					return cast(T)__builtin_ia32_pblendvb128(cast(P)y, cast(P)x, cast(P)mask);
                }
			}
			else
				return xor!Ver(x, and!Ver(cast(T)mask, xor!Ver(y, x)));
		}
	}
	else version(ARM)
	{
		static assert(0, "TODO");
	}
	else
	{
		// simulate on any architecture without an opcode: ((b ^ a) & mask) ^ a
		return xor!Ver(x, cast(T)and!Ver(mask, cast(void16)xor!Ver(y, x)));
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

struct double2x2
{
	double2 xRow;
	double2 yRow;
}

///////////////////////////////////////////////////////////////////////////////
// Matrix functions

T transpose(SIMDVer Ver = sseVer, T)(T m)
{
	version(X86_OR_X64)
	{
		version(DigitalMars)
		{
			static assert(0, "TODO");
		}
		else version(GNU)
		{
			static if(is(T == float4x4))
			{
				float4 b0 = __builtin_ia32_shufps(m.xRow, m.yRow, shufMask!4([0,1,0,1]));
				float4 b1 = __builtin_ia32_shufps(m.zRow, m.wRow, shufMask!4([0,1,0,1]));
				float4 b2 = __builtin_ia32_shufps(m.xRow, m.yRow, shufMask!4([2,3,2,3]));
				float4 b3 = __builtin_ia32_shufps(m.zRow, m.wRow, shufMask!4([2,3,2,3]));
				float4 a0 = __builtin_ia32_shufps(b0, b1, shufMask!4([0,2,0,2]));
				float4 a1 = __builtin_ia32_shufps(b2, b3, shufMask!4([0,2,0,2]));
				float4 a2 = __builtin_ia32_shufps(b0, b1, shufMask!4([1,3,1,3]));
				float4 a3 = __builtin_ia32_shufps(b2, b3, shufMask!4([1,3,1,3]));

				return float4x4(a0, a2, a1, a3);
			}
			else static if (is(T == double2x2))
			{
				static if(Ver >= SIMDVer.SSE2)
				{
					return double2x2(
						__builtin_ia32_unpcklpd(m.xRow, m.yRow),
						__builtin_ia32_unpckhpd(m.xRow, m.yRow));
				}
				else
					static assert(0, "TODO");
			}
			else
				static assert(0, "Unsupported matrix type: " ~ T.stringof);
		}
	}
	else
	{
		static assert(0, "Unsupported on this architecture");
	}
}


// determinant, etc...



///////////////////////////////////////////////////////////////////////////////
// Unit test the lot!

unittest
{
	// test all functions and all types

	// >_< *** EPIC LONG TEST FUNCTION HERE ***
}
