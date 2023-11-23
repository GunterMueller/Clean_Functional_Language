#pragma data_seg("Shared")
static int g_lModuleUsage = /*~0*/ -1;
#pragma data_seg()

#pragma comment(linker, "/section:Shared,rws")

int is_first_instance() {
	return( (InterlockedIncrement((int) &g_lModuleUsage)) ? 0 : 1);
}
