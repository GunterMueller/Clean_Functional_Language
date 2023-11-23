/* This file is written by Martin Wierich (martinw@cs.kun.nl) on 15.5.2000.
   It is "work based on the GMP library" (under terms of the GNU Library General
   Public License) because it contains source code from that library, so:

This file is work based on the GNU MP Library.

The GNU MP Library is free software; you can redistribute it and/or modify
it under the terms of the GNU Library General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at your
option) any later version.

The GNU MP Library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Library General Public
License for more details.

You should have received a copy of the GNU Library General Public License
along with the GNU MP Library; see the file COPYING.LIB.  If not, write to
the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
MA 02111-1307, USA. */

#include <stdio.h>
#include "gmp.h"

#if 0
#include "gmp-impl.h"
#include "longlong.h" /* for count_leading_zeros */
#else

static float my_chars_per_bit_exactly[256] =
{
 /*  0 */ 0.0,        /*  1 */ 1e38,       /*  2 */ 1.00000000, /*  3 */ 0.63092975,
 /*  4 */ 0.50000000, /*  5 */ 0.43067656, /*  6 */ 0.38685281, /*  7 */ 0.35620719,
 /*  8 */ 0.33333333, /*  9 */ 0.31546488, /* 10 */ 0.30103000, /* 11 */ 0.28906483,
 /* 12 */ 0.27894295, /* 13 */ 0.27023815, /* 14 */ 0.26264954, /* 15 */ 0.25595802,
 /* 16 */ 0.25000000, /* 17 */ 0.24465054, /* 18 */ 0.23981247, /* 19 */ 0.23540891,
 /* 20 */ 0.23137821, /* 21 */ 0.22767025, /* 22 */ 0.22424382, /* 23 */ 0.22106473,
 /* 24 */ 0.21810429, /* 25 */ 0.21533828, /* 26 */ 0.21274605, /* 27 */ 0.21030992,
 /* 28 */ 0.20801460, /* 29 */ 0.20584683, /* 30 */ 0.20379505, /* 31 */ 0.20184909,
 /* 32 */ 0.20000000, /* 33 */ 0.19823986, /* 34 */ 0.19656163, /* 35 */ 0.19495902,
 /* 36 */ 0.19342640, /* 37 */ 0.19195872, /* 38 */ 0.19055141, /* 39 */ 0.18920036,
 /* 40 */ 0.18790182, /* 41 */ 0.18665241, /* 42 */ 0.18544902, /* 43 */ 0.18428883,
 /* 44 */ 0.18316925, /* 45 */ 0.18208790, /* 46 */ 0.18104260, /* 47 */ 0.18003133,
 /* 48 */ 0.17905223, /* 49 */ 0.17810359, /* 50 */ 0.17718382, /* 51 */ 0.17629143,
 /* 52 */ 0.17542506, /* 53 */ 0.17458343, /* 54 */ 0.17376534, /* 55 */ 0.17296969,
 /* 56 */ 0.17219543, /* 57 */ 0.17144160, /* 58 */ 0.17070728, /* 59 */ 0.16999162,
 /* 60 */ 0.16929381, /* 61 */ 0.16861310, /* 62 */ 0.16794878, /* 63 */ 0.16730018,
 /* 64 */ 0.16666667, /* 65 */ 0.16604765, /* 66 */ 0.16544255, /* 67 */ 0.16485086,
 /* 68 */ 0.16427205, /* 69 */ 0.16370566, /* 70 */ 0.16315122, /* 71 */ 0.16260831,
 /* 72 */ 0.16207652, /* 73 */ 0.16155547, /* 74 */ 0.16104477, /* 75 */ 0.16054409,
 /* 76 */ 0.16005307, /* 77 */ 0.15957142, /* 78 */ 0.15909881, /* 79 */ 0.15863496,
 /* 80 */ 0.15817959, /* 81 */ 0.15773244, /* 82 */ 0.15729325, /* 83 */ 0.15686177,
 /* 84 */ 0.15643779, /* 85 */ 0.15602107, /* 86 */ 0.15561139, /* 87 */ 0.15520856,
 /* 88 */ 0.15481238, /* 89 */ 0.15442266, /* 90 */ 0.15403922, /* 91 */ 0.15366189,
 /* 92 */ 0.15329049, /* 93 */ 0.15292487, /* 94 */ 0.15256487, /* 95 */ 0.15221035,
 /* 96 */ 0.15186115, /* 97 */ 0.15151715, /* 98 */ 0.15117821, /* 99 */ 0.15084420,
 /*100 */ 0.15051500, /*101 */ 0.15019048, /*102 */ 0.14987054, /*103 */ 0.14955506,
 /*104 */ 0.14924394, /*105 */ 0.14893706, /*106 */ 0.14863434, /*107 */ 0.14833567,
 /*108 */ 0.14804096, /*109 */ 0.14775011, /*110 */ 0.14746305, /*111 */ 0.14717969,
 /*112 */ 0.14689994, /*113 */ 0.14662372, /*114 */ 0.14635096, /*115 */ 0.14608158,
 /*116 */ 0.14581551, /*117 */ 0.14555268, /*118 */ 0.14529302, /*119 */ 0.14503647,
 /*120 */ 0.14478295, /*121 */ 0.14453241, /*122 */ 0.14428479, /*123 */ 0.14404003,
 /*124 */ 0.14379807, /*125 */ 0.14355885, /*126 */ 0.14332233, /*127 */ 0.14308844,
 /*128 */ 0.14285714, /*129 */ 0.14262838, /*130 */ 0.14240211, /*131 */ 0.14217828,
 /*132 */ 0.14195685, /*133 */ 0.14173777, /*134 */ 0.14152100, /*135 */ 0.14130649,
 /*136 */ 0.14109421, /*137 */ 0.14088412, /*138 */ 0.14067617, /*139 */ 0.14047033,
 /*140 */ 0.14026656, /*141 */ 0.14006482, /*142 */ 0.13986509, /*143 */ 0.13966731,
 /*144 */ 0.13947147, /*145 */ 0.13927753, /*146 */ 0.13908545, /*147 */ 0.13889521,
 /*148 */ 0.13870677, /*149 */ 0.13852011, /*150 */ 0.13833519, /*151 */ 0.13815199,
 /*152 */ 0.13797047, /*153 */ 0.13779062, /*154 */ 0.13761241, /*155 */ 0.13743580,
 /*156 */ 0.13726078, /*157 */ 0.13708732, /*158 */ 0.13691539, /*159 */ 0.13674498,
 /*160 */ 0.13657605, /*161 */ 0.13640859, /*162 */ 0.13624257, /*163 */ 0.13607797,
 /*164 */ 0.13591477, /*165 */ 0.13575295, /*166 */ 0.13559250, /*167 */ 0.13543338,
 /*168 */ 0.13527558, /*169 */ 0.13511908, /*170 */ 0.13496386, /*171 */ 0.13480991,
 /*172 */ 0.13465720, /*173 */ 0.13450572, /*174 */ 0.13435545, /*175 */ 0.13420637,
 /*176 */ 0.13405847, /*177 */ 0.13391173, /*178 */ 0.13376614, /*179 */ 0.13362168,
 /*180 */ 0.13347832, /*181 */ 0.13333607, /*182 */ 0.13319491, /*183 */ 0.13305481,
 /*184 */ 0.13291577, /*185 */ 0.13277777, /*186 */ 0.13264079, /*187 */ 0.13250483,
 /*188 */ 0.13236988, /*189 */ 0.13223591, /*190 */ 0.13210292, /*191 */ 0.13197089,
 /*192 */ 0.13183981, /*193 */ 0.13170967, /*194 */ 0.13158046, /*195 */ 0.13145216,
 /*196 */ 0.13132477, /*197 */ 0.13119827, /*198 */ 0.13107265, /*199 */ 0.13094791,
 /*200 */ 0.13082402, /*201 */ 0.13070099, /*202 */ 0.13057879, /*203 */ 0.13045743,
 /*204 */ 0.13033688, /*205 */ 0.13021715, /*206 */ 0.13009822, /*207 */ 0.12998007,
 /*208 */ 0.12986271, /*209 */ 0.12974613, /*210 */ 0.12963031, /*211 */ 0.12951524,
 /*212 */ 0.12940092, /*213 */ 0.12928734, /*214 */ 0.12917448, /*215 */ 0.12906235,
 /*216 */ 0.12895094, /*217 */ 0.12884022, /*218 */ 0.12873021, /*219 */ 0.12862089,
 /*220 */ 0.12851224, /*221 */ 0.12840428, /*222 */ 0.12829698, /*223 */ 0.12819034,
 /*224 */ 0.12808435, /*225 */ 0.12797901, /*226 */ 0.12787431, /*227 */ 0.12777024,
 /*228 */ 0.12766680, /*229 */ 0.12756398, /*230 */ 0.12746176, /*231 */ 0.12736016,
 /*232 */ 0.12725915, /*233 */ 0.12715874, /*234 */ 0.12705891, /*235 */ 0.12695967,
 /*236 */ 0.12686100, /*237 */ 0.12676290, /*238 */ 0.12666537, /*239 */ 0.12656839,
 /*240 */ 0.12647197, /*241 */ 0.12637609, /*242 */ 0.12628075, /*243 */ 0.12618595,
 /*244 */ 0.12609168, /*245 */ 0.12599794, /*246 */ 0.12590471, /*247 */ 0.12581200,
 /*248 */ 0.12571980, /*249 */ 0.12562811, /*250 */ 0.12553692, /*251 */ 0.12544622,
 /*252 */ 0.12535601, /*253 */ 0.12526629, /*254 */ 0.12517705, /*255 */ 0.12508829
};

static unsigned char n_leading_zeros[256] = {
  8,7,6,6,5,5,5,5,4,4,4,4,4,4,4,4,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
};

#endif

int get_max_string_sizeC(unsigned int base, unsigned int msize) {
#if 1
      return (int) ( msize * 32
		 * my_chars_per_bit_exactly[base]) + 3;
#else
      return (int) ( msize * BITS_PER_MP_LIMB
		 * __mp_bases[base].chars_per_bit_exactly) + 3;
#endif
	}

void add_1C (register mp_ptr res_ptr,
	   register mp_srcptr s1_ptr,
	   register mp_size_t s1_size,
	   register mp_limb_t s2_limb)
{
  register mp_limb_t x;
  mp_ptr res_ptr_save;
  
  res_ptr_save = res_ptr;
  x = *s1_ptr++;
  s2_limb = x + s2_limb;
  *res_ptr++ = s2_limb;
  if (s2_limb < x)
    {
      while (--s1_size != 0)
	{
	  x = *s1_ptr++ + 1;
	  *res_ptr++ = x;
	  if (x != 0)
	    goto fin;
	}
		*res_ptr = 1;
		return;
    }

 fin:
  if (res_ptr != s1_ptr)
    {
      mp_size_t i;
      for (i = 0; i < s1_size - 1; i++)
	res_ptr[i] = s1_ptr[i];
    }
  (res_ptr_save[-2])--;
}

#include "Clean.h"

#define true (!0)
#define false 0

#define CleanArraySize(x) x[-2]
#define errorMessage "Error in module BigInt: a Clean function allocated unsufficient memory before calling GMP"

#define get_mp_size(sign, limbs, size)	((size==1 && limbs[0]==0) ? 0 : (sign>0 ? size : (-size)))

int allocationIsDefault=true;

void setSizeC(unsigned int* array, int newSize)
{
 	CleanArraySize(array)	= newSize;
}

void setStringSizeC(CleanString cs, int newSize)
{
 	CleanStringLength(cs)	= newSize;
}

void countLeadingZeros(unsigned int word, int *pResult)
// flip arguments for interfacing with Clean
{
#if 0
        count_leading_zeros(*pResult, word);
#else
	if (word>=0x10000u){
		if (word>=0x1000000u)
			*pResult=n_leading_zeros[word>>24];
		else
			*pResult=n_leading_zeros[word>>16]+8;
	} else {
		if (word>=0x100u)
			*pResult=n_leading_zeros[word>>8]+16;
		else
			*pResult=n_leading_zeros[word]+24;
	}
#endif
}

int set_strC(mp_limb_t *R1P, CleanString digits, int base)
{
	return mpn_set_str(R1P, (const unsigned char *) CleanStringCharacters(digits),
	                   CleanStringLength(digits),base);
}

void init_set_limbs(mpz_ptr p_gmp_var, int sign, mp_limb_t *limbs, int size)
{
	p_gmp_var->_mp_alloc	= size;
	p_gmp_var->_mp_size	= get_mp_size(sign, limbs, size);
	p_gmp_var->_mp_d	= limbs;
}

void *abort1(size_t x)
{
	perror(errorMessage);
	abort();
}

void *abort2(void *x, size_t y, size_t z)
{
	perror(errorMessage);
	abort();
}

void abort3(void *x, size_t y)
{
	perror(errorMessage);
	abort();
}

inline void disableDefaultAllocation()
{
	if (allocationIsDefault) {
		mp_set_memory_functions(abort1,abort2,abort3);
		allocationIsDefault	= false;
		};
}

inline void enableDefaultAllocation()
{
	if (!allocationIsDefault) {
		mp_set_memory_functions(NULL,NULL,NULL);
		allocationIsDefault	= true;
		};
}

void remainderC(mp_limb_t *nomLimbs, int nomSize, mp_limb_t *denomLimbs, int denomSize)
{
	mpn_divrem(nomLimbs+denomSize, 0, nomLimbs, nomSize, denomLimbs, denomSize);
}

int powmC(mp_limb_t *destLimbs	, int baseSign, mp_limb_t *baseLimbs
				, int exponentSign, mp_limb_t *exponentLimbs
				, int modulusSign, mp_limb_t *modulusLimbs)
{
	mpz_t	dest, base, exponent, modulus;
	init_set_limbs(dest, true, destLimbs, CleanArraySize(destLimbs));
	init_set_limbs(base, baseSign, baseLimbs, CleanArraySize(baseLimbs));
	init_set_limbs(exponent, exponentSign, exponentLimbs, CleanArraySize(exponentLimbs));
	init_set_limbs(modulus, modulusSign, modulusLimbs, CleanArraySize(modulusLimbs));
	disableDefaultAllocation();
	mpz_powm(dest, base, exponent, modulus);
	return dest->_mp_size;
}

int gmp_gcdC (mp_limb_t *destLimbs, int uSign, mp_limb_t *uLimbs, int vSign, mp_limb_t *vLimbs)
{
	mpz_t	dest, u, v;
	init_set_limbs(dest, true, destLimbs, CleanArraySize(destLimbs));
	init_set_limbs(u, uSign	, uLimbs, CleanArraySize(uLimbs));
	init_set_limbs(v, vSign	, vLimbs, CleanArraySize(vLimbs));
	disableDefaultAllocation();
	mpz_gcd(dest, u, v);
	return dest->_mp_size;
}

void pow_uiC (int baseSign, mp_limb_t *baseLimbs, unsigned long int exp,
			int *pGMPSize, mpz_t **pResultAdr)
{
	static mpz_t power_result;
	mpz_t	base;
	init_set_limbs(base, baseSign, baseLimbs, CleanArraySize(baseLimbs));
	enableDefaultAllocation();
	mpz_init(power_result);
	mpz_pow_ui(power_result, base, exp);
	*pGMPSize	= power_result->_mp_size;
	*pResultAdr	= &power_result;
}

void transferGMPNumberToCleanC(mp_limb_t *dest, mpz_t *mpz_src, int nr_of_words)
{
	mp_limb_t *src;
	src = (*mpz_src)->_mp_d;
#if 1
	{
		int i,n;

		n=nr_of_words;
		for (i=0; i<nr_of_words; ++i)
			dest[i]=src[i];
	}
#else
	my_memcpy(dest, src, nr_of_words<<2);
#endif
	mpz_clear(*mpz_src);
}

size_t call_mpn_get_str (int offset, CleanString str, int base, mp_ptr mptr, mp_size_t msize)
{
	return mpn_get_str (CleanStringCharacters(str)+offset, base, mptr, msize);
}

double bigIntToRealC(int sign	, mp_limb_t *limbs)
{
	mpz_t	i;

	init_set_limbs(i, sign, limbs, CleanArraySize(limbs));
	disableDefaultAllocation();
	return mpz_get_d(i);
}

double ratioToRealC(int nomSign	, mp_limb_t *nomLimbs, int denomSign	, mp_limb_t *denomLimbs)
{
	mpq_t	q;

	init_set_limbs(&(q->_mp_num), nomSign, nomLimbs, CleanArraySize(nomLimbs));
	init_set_limbs(&(q->_mp_den), denomSign, denomLimbs, CleanArraySize(denomLimbs));
	disableDefaultAllocation();
	return mpq_get_d(q);
}

