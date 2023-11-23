definition module System._Signal

from StdMisc import abort

//Windows signals according to signal.h
SIGINT   :== 2
SIGILL   :== 4
SIGFPE   :== 8
SIGSEGV  :== 11
SIGTERM  :== 15
SIGBREAK :== 21
SIGABRT  :== 22

SIGHUP    :== abort "SIGHUP is not supported on Windows\n"
SIGQUIT   :== abort "SIGQUIT is not supported on Windows\n"
SIGTRAP   :== abort "SIGTRAP is not supported on Windows\n"
SIGIOT    :== abort "SIGIOT is not supported on Windows\n"
SIGBUS    :== abort "SIGBUS is not supported on Windows\n"
SIGKILL   :== abort "SIGKILL is not supported on Windows\n"
SIGUSR1   :== abort "SIGUSR1 is not supported on Windows\n"
SIGUSR2   :== abort "SIGUSR2 is not supported on Windows\n"
SIGPIPE   :== abort "SIGPIPE is not supported on Windows\n"
SIGALRM   :== abort "SIGALRM is not supported on Windows\n"
SIGSTKFLT :== abort "SIGSTKFLT is not supported on Windows\n"
SIGCHLD   :== abort "SIGCHLD is not supported on Windows\n"
SIGCONT   :== abort "SIGCONT is not supported on Windows\n"
SIGSTOP   :== abort "SIGSTOP is not supported on Windows\n"
SIGTSTP   :== abort "SIGTSTP is not supported on Windows\n"
SIGTTIN   :== abort "SIGTTIN is not supported on Windows\n"
SIGTTOU   :== abort "SIGTTOU is not supported on Windows\n"
SIGURG    :== abort "SIGURG is not supported on Windows\n"
SIGXCPU   :== abort "SIGXCPU is not supported on Windows\n"
SIGXFSZ   :== abort "SIGXFSZ is not supported on Windows\n"
SIGVTALRM :== abort "SIGVTALRM is not supported on Windows\n"
SIGPROF   :== abort "SIGPROF is not supported on Windows\n"
SIGWINCH  :== abort "SIGWINCH is not supported on Windows\n"
SIGIO     :== abort "SIGIO is not supported on Windows\n"
SIGPOLL   :== abort "SIGPOLL is not supported on Windows\n"
SIGPWR    :== abort "SIGPWR is not supported on Windows\n"
SIGSYS    :== abort "SIGSYS is not supported on Windows\n"
SIGUNUSED :== abort "SIGUNUSED is not supported on Windows\n"
