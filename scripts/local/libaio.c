/*
 * Minimal libaio implementation for the portable MySQL server.
 * Real libaio is a thin syscall wrapper; we provide the three versioned
 * symbols mysqld 5.7 requires: io_setup@LIBAIO_0.4, io_getevents@LIBAIO_0.4,
 * io_submit@LIBAIO_0.1 (see libaio.map version script).
 */
#define _GNU_SOURCE
#include <sys/syscall.h>
#include <unistd.h>

int io_setup(int maxevents, void *ctxp)
{
	return (int)syscall(SYS_io_setup, maxevents, ctxp);
}

int io_destroy(void *ctx)
{
	return (int)syscall(SYS_io_destroy, ctx);
}

int io_submit(void *ctx, long nr, void **iocbpp)
{
	return (int)syscall(SYS_io_submit, ctx, nr, iocbpp);
}

int io_getevents(void *ctx, long min_nr, long nr, void *events, void *timeout)
{
	return (int)syscall(SYS_io_getevents, ctx, min_nr, nr, events, timeout);
}

int io_cancel(void *ctx, void *iocb, void *event)
{
	return (int)syscall(SYS_io_cancel, ctx, iocb, event);
}

int io_pgetevents(void *ctx, long min_nr, long nr, void *events, void *sig)
{
	return (int)syscall(SYS_io_pgetevents, ctx, min_nr, nr, events, sig);
}
