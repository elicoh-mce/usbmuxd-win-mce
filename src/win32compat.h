/*
 * win32compat.h - Windows compatibility definitions
 *
 * This file provides Windows-specific definitions and compatibility
 * wrappers for UNIX/POSIX functions used in usbmuxd.
 */

#ifndef WIN32COMPAT_H
#define WIN32COMPAT_H

#ifdef _WIN32

#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <io.h>
#include <stdint.h>

// Socket compatibility
#define close closesocket
#ifndef EWOULDBLOCK
#define EWOULDBLOCK WSAEWOULDBLOCK
#endif
#ifndef EAGAIN
#define EAGAIN WSAEWOULDBLOCK
#endif

// Type compatibility
typedef unsigned int nfds_t;

// timespec for ppoll
struct timespec {
	long tv_sec;
	long tv_nsec;
};

// ppoll implementation using WSAPoll
static inline int ppoll(WSAPOLLFD *fds, nfds_t nfds, const struct timespec *timeout, const sigset_t *sigmask) {
	int to = timeout ? (int)(timeout->tv_sec * 1000 + timeout->tv_nsec / 1000000) : -1;
	return WSAPoll(fds, (ULONG)nfds, to);
}

// gai_strerror for Windows
#define gai_strerror(err) "getaddrinfo error"

// errno compatibility
#define EINTR WSAEINTR
#define ENOENT 2

// TCP header structure (BSD-style)
struct tcphdr {
	uint16_t th_sport;	/* source port */
	uint16_t th_dport;	/* destination port */
	uint32_t th_seq;		/* sequence number */
	uint32_t th_ack;		/* acknowledgement number */
	uint8_t th_off;		/* data offset */
	uint8_t th_flags;	/* flags */
	uint16_t th_win;		/* window */
	uint16_t th_sum;		/* checksum */
	uint16_t th_urp;		/* urgent pointer */
};

// TCP flags
#define TH_FIN  0x01
#define TH_SYN  0x02
#define TH_RST  0x04
#define TH_PUSH 0x08
#define TH_ACK  0x10
#define TH_URG  0x20

// usleep replacement
#define usleep(x) Sleep((x)/1000)

// fcntl/ioctl
#define O_NONBLOCK 1
#define F_GETFL 1
#define F_SETFL 2
static inline int fcntl(int fd, int cmd, ...) {
	// Stub - non-blocking is handled via ioctlsocket elsewhere
	return 0;
}

// Signal handling (stubs for Windows)
#define SIGUSR1 10
#define SIGUSR2 12
#define SIGQUIT 3
typedef int sigset_t;
struct sigaction {
	void (*sa_handler)(int);
};
#define sigemptyset(set) (*(set) = 0)
#define sigaddset(set, sig) (0)
#define sigprocmask(how, set, oldset) (0)
#define sigaction(sig, act, oldact) (0)
#define SIG_SETMASK 0

// Daemon functions (not supported on Windows)
#define fork() (-1)
#define setsid() (-1)
#define getppid() (0)
#define pipe(fds) (-1)

// File/path functions
#define chmod(path, mode) (0)
#define stat(path, buf) (-1)
#define unlink(path) (-1)
#define S_ISSOCK(m) (0)

// User/group functions
struct passwd { int pw_uid; int pw_gid; };
struct group { int gr_gid; };
#define getpwnam(name) (NULL)
#define getgrnam(name) (NULL)
#define setgroups(size, list) (-1)
#define setgid(gid) (-1)
#define setuid(uid) (-1)
#define initgroups(user, group) (-1)

// Resource limits
struct rlimit { unsigned long rlim_cur; unsigned long rlim_max; };
#define RLIMIT_NOFILE 0
#define getrlimit(resource, rlim) (-1)
#define setrlimit(resource, rlim) (-1)

// Other Unix-specific
#define bzero(s, n) memset((s), 0, (n))
#define AF_UNIX AF_INET
struct sockaddr_un { int sun_family; char sun_path[108]; };

// File I/O
#define O_WRONLY _O_WRONLY
#define O_CREAT _O_CREAT
#define O_TRUNC _O_TRUNC
#define O_EXCL _O_EXCL
#define open _open
#define read _read
#define write _write
#define chdir _chdir
#define mkdir(path) _mkdir(path)
#define getpid _getpid
#define chown(path, owner, group) (0)
#define getuid() (0)
#define getgid() (0)

// Signals
#define SIGTERM 15
#define SIGINT 2
#define SIGPIPE 13
#define signal(sig, handler) (0)

// File locking
struct flock { int l_type; int l_whence; long l_start; long l_len; int l_pid; };
#define F_SETLK 8
#define F_WRLCK 1

// More type compatibility
struct stat { int st_mode; };

#endif /* _WIN32 */

#endif /* WIN32COMPAT_H */
