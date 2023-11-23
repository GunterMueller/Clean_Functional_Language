implementation module Semaphore;

import StdEnv;

INFINITE :== -1;

// add CreateSemaphoreA@16 and ReleaseSemaphore@12 to kernel_library for Clean 2.2 and older

CreateSemaphore :: !Int !Int !Int !{#Char} !*World -> (!Int,!*World);
CreateSemaphore semaphoreAttributes initialCount maximumCount name world = code {
	ccall CreateSemaphoreA@16 "PIIIs:I:A"
}

WaitForSingleObject :: !Int !Int !*World -> (!Int,!*World);
WaitForSingleObject handle milliseconds world = code {
	ccall WaitForSingleObject@8 "PII:I:A"
}

ReleaseSemaphore :: !Int !Int !Int !*World -> (!Int,!*World);
ReleaseSemaphore semaphore releaseCount previousCount_p world = code {
	ccall ReleaseSemaphore@12 "PIII:I:A"
}

CloseHandle :: !Int !*World -> (!Int,!*World);
CloseHandle handle world = code {
	ccall CloseHandle@4 "PI:I:A"
}

Start w
	# semaphore_name = "MySemaphoreName";

	# (semaphore,world) = CreateSemaphore 0 1 1 semaphore_name w;
	| semaphore==0
		= abort "CreateSemaphore failed";
	
	# (r,world) = WaitForSingleObject semaphore INFINITE world;

	# (stdout,world) = stdio world;
	# (ok,c,stdout) = freadc stdout;
	# (ok,world) = fclose stdout world;

	# (ok,world) = ReleaseSemaphore semaphore 1 0 world;
	
	# (ok,world) = CloseHandle semaphore world;
	| ok==0
		= abort "CloseHandle failed";
