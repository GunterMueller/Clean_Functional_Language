#include <stdlib.h>
#include <signal.h>

static long signal_state[NSIG] = {0};

#ifdef _WIN32
static void signal_handler(int sig)
{
#else
static void signal_handler(int sig, siginfo_t *si, void *unused)
{
	(void)si;
	(void)unused;
#endif
	signal_state[sig] = 1;
}

void signal_install(long signum, long *ok, long *handler)
{
#ifdef _WIN32
	*ok = signal(signum, signal_handler) == SIG_ERR;
#else
	struct sigaction act;

	act.sa_flags = SA_SIGINFO;
	sigemptyset(&act.sa_mask);
	act.sa_sigaction = signal_handler;

	*ok = sigaction(signum, &act, NULL);
#endif
	*handler = signum;
}

void signal_poll(long handler, long *ok, long *state, long *handlerr)
{
	*ok = 1;
	if(0 < handler && handler < NSIG){
		*handlerr = handler;
		*state = signal_state[handler];
		signal_state[handler] = 0;
		*ok = 0;
	}
}

int signal_ignore(long signum)
{
	return signal(signum, SIG_IGN) == SIG_ERR;
}
