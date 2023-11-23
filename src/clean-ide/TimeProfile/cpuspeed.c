
#include <stdio.h>

#include <windows.h>

#define N_TICKS 1000

#if 1
#define CPUID _asm _emit 0x0f _asm _emit 0xa2
#define RDTSC _asm _emit 0x0f _asm _emit 0x31

#ifndef _WIN64
static int has_time_stamp_counter (void)
{
_asm {
	push	ebx
	push	ecx
	push	edx

	pushfd
	mov	eax,200000h
	pop	ebx
	xor	eax,ebx
	push	eax
	popfd
	pushfd
	pop	eax
	
	xor	eax,ebx
	jz	no_cpuid_instruction

	mov	eax,1

	CPUID
	
	shr	edx,4
	mov	eax,1
	and	eax,edx

no_cpuid_instruction:
	pop	edx
	pop	ecx
	pop	ebx
	}
}

static void read_time_stamp_counter (LARGE_INTEGER *large_int_p)
{
_asm{
	push	ecx
	push	edx
	mov	ecx,large_int_p

	RDTSC

	mov	dword ptr 0[ecx],eax
	mov	dword ptr 4[ecx],edx
	pop	edx
	pop	ecx
	}
}
#else
unsigned __int64 __rdtsc(void);
#pragma intrinsic(__rdtsc)
#endif

# ifdef _WIN64

__int64 p_time=0;
int g_time_hi=0,g_time_lo=0;

extern void compute_profile_overhead (LARGE_INTEGER *large_int_p);

# else

int p_time_hi=0,p_time_lo=0,g_time_hi=0,g_time_lo=0;

extern void compute_profile_overhead (LARGE_INTEGER *large_int_p)
{
_asm {
	jmp	compute_profile_overhead_

profile_:
	push	eax
	push	edx

	RDTSC

	sub	eax,g_time_lo
	sbb	edx,g_time_hi
	add	p_time_lo,eax
	adc	p_time_hi,edx

	RDTSC

	mov	g_time_hi,edx
	pop	edx
	mov	g_time_lo,eax
	pop	eax
	ret

compute_profile_overhead_:
	mov	eax,large_int_p
	push	ebx
	push	ecx
	push	edx
	push	ebp
	
	xor	ecx,ecx
	xor	edx,edx
	mov	ebx,100000
	
	call	profile_
	mov	p_time_lo,ecx
	mov	p_time_hi,edx

compute_profile_overhead_lp1:
	lea	ebp,p_time_lo
	call	profile_

	add	ecx,ecx
	add	edx,edx
	
	sub	ebx,1
	jne	compute_profile_overhead_lp1

	mov	ecx,p_time_lo
	mov	edx,p_time_hi
	mov	dword ptr 0[eax],ecx
	mov	dword ptr 4[eax],edx

	xor	ecx,ecx
	xor	edx,edx
	mov	ebx,100000
	
	call	profile_
	mov	p_time_lo,ecx
	mov	p_time_hi,edx

compute_profile_overhead_lp2:
	add	ecx,ecx
	add	edx,edx
	
	sub	ebx,1
	jne	compute_profile_overhead_lp2

	call	profile_

	mov	ecx,p_time_lo
	mov	edx,p_time_hi
	mov	dword ptr 8[eax],ecx
	mov	dword ptr 12[eax],edx

	pop	ebp
	pop	edx
	pop	ecx
	pop	ebx
	}
}

# endif

#else

extern int has_time_stamp_counter (void);
extern void read_time_stamp_counter (LARGE_INTEGER *);
extern void compute_profile_overhead (LARGE_INTEGER *);

#endif

#ifdef _WIN64
# define float_div(a,b) ((a)/(b))
#else
double float_div (double a,double b)
{
	_asm {
	fld	a
	fdiv b
	}
}
#endif

#define N_TIME_SAMPLES 40
#define N_PROFILE_SAMPLES 40

static void swap_bytes (unsigned char *p1,unsigned char *p2,int n)
{
	while (n!=0){
		unsigned char b;
		b=*p1;
		*p1=*p2;
		*p2=b;
		++p1;
		++p2;
		--n;
	}
}

#define qsort hsort

static void hsort (void *a_,unsigned int high,unsigned int element_size,int compare (void*,void*))
{
	unsigned int low,father,son;
	unsigned char *a;
	a=(unsigned char*)a_;

	low=high/2;
	while (high>1){
		father=low;
		for (;;){
			son=2*father+1;
			if (son>=high)
				break;
			if (son==high-1){
				if (compare (&a[element_size*father],&a[element_size*son])<0)
					swap_bytes (&a[element_size*son],&a[element_size*father],element_size);
				break;
			}
			if (compare (&a[element_size*son],&a[element_size*(son+1)])<0)
				++son;
			if (compare (&a[element_size*father],&a[element_size*son])>=0)
				break;
			swap_bytes (&a[element_size*son],&a[element_size*father],element_size);
			father=son;
		}
		if (low>0){
			--low;
		} else {
			--high;
			swap_bytes (&a[0],&a[element_size*high],element_size);
		}
	}
}

static int double_compare (const double *r1_p,const double *r2_p)
{
	if (*r1_p<*r2_p)
		return -1;
	else if (*r1_p>*r2_p)
		return 1;
	else
		return 0;
}

static double compute_average_frequency (double time_results[])
{
	int n,begin_n,end_n;
	double sum;

	begin_n=N_TIME_SAMPLES>>2;
	end_n=N_TIME_SAMPLES-begin_n;

	sum=0.0;
	for (n=begin_n; n<end_n; ++n)
		sum += time_results[n];

	return float_div (sum,(double)(end_n-begin_n));
}

static int compare_large_integer (const LARGE_INTEGER *large_int_p1,const LARGE_INTEGER *large_int_p2)
{
	if (large_int_p1->HighPart < large_int_p2->HighPart)
		return -1;
	else if (large_int_p1->HighPart > large_int_p2->HighPart)
		return 1;
	else if (large_int_p1->LowPart < large_int_p2->LowPart)
		return -1;
	else if (large_int_p1->LowPart > large_int_p2->LowPart)
		return 1;
	else
		return 0;
}

static double determine_cpu_clock_speed (double frequency)
{
	LARGE_INTEGER begin_time0,begin_time,end_time;
	LARGE_INTEGER tsc_begin_time,tsc_end_time;
	double time_results [N_TIME_SAMPLES];
	int n;

	for (n=0; n<N_TIME_SAMPLES; ++n){
		QueryPerformanceCounter (&begin_time0);
		do {
			QueryPerformanceCounter (&begin_time);
#ifdef _WIN64
			tsc_begin_time.QuadPart=__rdtsc();
#else
			read_time_stamp_counter (&tsc_begin_time);
#endif
		} while (begin_time0.HighPart==begin_time.HighPart && begin_time0.LowPart==begin_time.LowPart);

		do {
			QueryPerformanceCounter (&end_time);
#ifdef _WIN64
			tsc_end_time.QuadPart=__rdtsc();
#else
			read_time_stamp_counter (&tsc_end_time);
#endif
		} while (		(end_time.HighPart==begin_time.HighPart)
					?	(end_time.LowPart-begin_time.LowPart<N_TICKS)
					:	(end_time.HighPart==begin_time.HighPart+1 && end_time.LowPart-(unsigned)N_TICKS<begin_time.LowPart));

		tsc_end_time.HighPart -= tsc_begin_time.HighPart;
		if (tsc_end_time.LowPart<tsc_begin_time.LowPart)
			--tsc_end_time.HighPart;
		tsc_end_time.LowPart -= tsc_begin_time.LowPart;

		end_time.HighPart -= begin_time.HighPart;
		if (end_time.LowPart<begin_time.LowPart)
			--end_time.HighPart;
		end_time.LowPart -= begin_time.LowPart;

		time_results[n]=(float_div ((double)tsc_end_time.LowPart,(double)end_time.LowPart))*frequency;

/*		printf ("%-8d %-8d %-8d %-8d %g\n",
					tsc_end_time.HighPart,tsc_end_time.LowPart,
					end_time.HighPart,end_time.LowPart,
					time_results[n]);
*/
	}

	qsort (time_results,N_TIME_SAMPLES,sizeof (double),double_compare);

	return compute_average_frequency (time_results);
}

static double determine_profile_overhead (void)
{
	int n,begin_n,end_n;
	LARGE_INTEGER loop_with_profile_time[N_PROFILE_SAMPLES],loop_without_profile_time[N_PROFILE_SAMPLES];
	LARGE_INTEGER with_profile_sum,without_profile_sum;
	
	for (n=0; n<N_PROFILE_SAMPLES; ++n){
		LARGE_INTEGER profile_overhead[2];
		
		compute_profile_overhead (profile_overhead);

		loop_with_profile_time[n]=profile_overhead[0];
		loop_without_profile_time[n]=profile_overhead[1];
/*
		printf ("%d %d %d %d\n",
			profile_overhead[0].HighPart,profile_overhead[0].LowPart,
			profile_overhead[1].HighPart,profile_overhead[1].LowPart
		);
*/
	}

	qsort (loop_with_profile_time,N_PROFILE_SAMPLES,sizeof (LARGE_INTEGER),compare_large_integer);
	qsort (loop_without_profile_time,N_PROFILE_SAMPLES,sizeof (LARGE_INTEGER),compare_large_integer);

	with_profile_sum.HighPart=0;
	with_profile_sum.LowPart=0;
	without_profile_sum.HighPart=0;
	without_profile_sum.LowPart=0;

	begin_n=N_PROFILE_SAMPLES>>2;
	end_n=N_PROFILE_SAMPLES-begin_n;

	for (n=begin_n; n<end_n; ++n){
		with_profile_sum.HighPart += loop_with_profile_time[n].HighPart;
		if (with_profile_sum.LowPart+loop_with_profile_time[n].LowPart < with_profile_sum.LowPart)
			++with_profile_sum.HighPart;
		with_profile_sum.LowPart += loop_with_profile_time[n].LowPart;

		without_profile_sum.HighPart += loop_without_profile_time[n].HighPart;
		if (without_profile_sum.LowPart+loop_without_profile_time[n].LowPart < without_profile_sum.LowPart)
			++without_profile_sum.HighPart;
		without_profile_sum.LowPart += loop_without_profile_time[n].LowPart;		
	}

	with_profile_sum.HighPart -= without_profile_sum.HighPart;
	if (with_profile_sum.LowPart < without_profile_sum.LowPart)
		--with_profile_sum.HighPart;
	with_profile_sum.LowPart -= without_profile_sum.LowPart;

	return float_div
		((double)with_profile_sum.LowPart+(65536.0*65536.0)*(double) with_profile_sum.HighPart,
		 (double)(N_PROFILE_SAMPLES>>1)*100000.0);
}

static void set_thread_priority (HANDLE thread_handle,int old_priority,int new_priority)
{
	if (old_priority!=THREAD_PRIORITY_ERROR_RETURN)
		SetThreadPriority (thread_handle,new_priority);			
}

static void init_fpu (void)
{
#ifndef _WIN64
	_asm {
	finit
	fldz
	fldz
	fldz
	fldz
	fldz
	fldz
	fldz
	}
#endif
}

int measure_clock_speed_and_profile_overhead (double *clock_speed_p,double *profile_overhead_p)
{
	LARGE_INTEGER performance_frequency;
	double frequency,average_frequency;
	HANDLE thread_handle;
	int priority;

#ifndef _WIN64
	if (!has_time_stamp_counter()){
		*clock_speed_p=0.0;
		*profile_overhead_p=0.0;
		init_fpu(); /* for virtualpc */
		return 1;
	}
#endif

	thread_handle=GetCurrentThread();
	priority=GetThreadPriority (thread_handle);
	set_thread_priority (thread_handle,priority,THREAD_PRIORITY_TIME_CRITICAL);
	
	performance_frequency.LowPart=0;
	performance_frequency.HighPart=0;

	if (!QueryPerformanceFrequency (&performance_frequency)){
		set_thread_priority (thread_handle,priority,priority);
		*clock_speed_p=0.0;
		*profile_overhead_p=0.0;
		init_fpu(); /* for virtualpc */
		return 2;
	}

	frequency = (double)performance_frequency.LowPart +
				(double)performance_frequency.HighPart * (65536.0*65536.0);

	average_frequency = determine_cpu_clock_speed (frequency);

	*clock_speed_p = float_div (average_frequency,1.0e6);

	*profile_overhead_p = determine_profile_overhead();

	set_thread_priority (thread_handle,priority,priority);

	init_fpu(); /* for virtualpc */

	return 0;
}
