// PyBridge.m - embedded CPython 3.13 runtime for exteraGram-style plugins (stage 1).
// Python is loaded with dlopen at runtime, so the tweak never hard-links it:
// if the runtime is missing or fails, Telegram keeps working and we just report the error.
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <roothide.h>

typedef void (*fn_InitEx)(int);
typedef int (*fn_IsInit)(void);
typedef int (*fn_RunSimple)(const char *);
typedef void *(*fn_SaveThread)(void);
typedef int (*fn_GILEnsure)(void);
typedef void (*fn_GILRelease)(int);

static fn_RunSimple pRun;
static fn_GILEnsure pEnsure;
static fn_GILRelease pRelease;
static NSString *gStatus = @"not started";
static BOOL gReady = NO;
static dispatch_queue_t gQ;

NSString *TGXPyHome(void) { return jbroot(@"/Library/Application Support/TGExtra/Python"); }
static NSString *TGXPyDataDir(void) {
	NSString *d = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"TGExtra"];
	[[NSFileManager defaultManager] createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:nil];
	return d;
}
NSString *TGXPyOutputPath(void) { return [TGXPyDataDir() stringByAppendingPathComponent:@"python.log"]; }
NSString *TGXPyStatus(void) { return gStatus; }
BOOL TGXPyReady(void) { return gReady; }

static void startLocked(void) {
	if (gReady) return;
	NSString *home = TGXPyHome();
	NSString *lib = [home stringByAppendingPathComponent:@"Python.framework/Python"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:lib]) { gStatus = [@"runtime missing: " stringByAppendingString:lib]; return; }
	void *h = dlopen(lib.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL);
	if (!h) { gStatus = [NSString stringWithFormat:@"dlopen failed: %s", dlerror()]; return; }
	fn_InitEx init = (fn_InitEx)dlsym(h, "Py_InitializeEx");
	fn_IsInit isInit = (fn_IsInit)dlsym(h, "Py_IsInitialized");
	fn_SaveThread save = (fn_SaveThread)dlsym(h, "PyEval_SaveThread");
	pRun = (fn_RunSimple)dlsym(h, "PyRun_SimpleString");
	pEnsure = (fn_GILEnsure)dlsym(h, "PyGILState_Ensure");
	pRelease = (fn_GILRelease)dlsym(h, "PyGILState_Release");
	if (!init || !isInit || !save || !pRun || !pEnsure || !pRelease) { gStatus = @"missing Python symbols"; return; }

	NSString *stdlib = [home stringByAppendingPathComponent:@"lib/python3.13"];
	NSString *path = [NSString stringWithFormat:@"%@:%@/lib-dynload:%@/plugins", stdlib, stdlib, TGXPyDataDir()];
	setenv("PYTHONHOME", home.fileSystemRepresentation, 1);
	setenv("PYTHONPATH", path.fileSystemRepresentation, 1);
	setenv("PYTHONDONTWRITEBYTECODE", "1", 1);
	setenv("PYTHONNOUSERSITE", "1", 1);
	setenv("PYTHONIOENCODING", "utf-8", 1);
	init(0); // 0 = don't install signal handlers inside Telegram
	if (!isInit()) { gStatus = @"Py_InitializeEx failed"; return; }

	NSString *boot = [NSString stringWithFormat:
		@"import sys, io\n"
		 "_f = open(%@, 'a', buffering=1, encoding='utf-8')\n"
		 "sys.stdout = sys.stderr = _f\n"
		 "import platform, time\n"
		 "print('--- TGExtra Python', sys.version.split()[0], 'on', sys.platform, platform.machine(), time.ctime())\n",
		[NSString stringWithFormat:@"r'''%@'''", TGXPyOutputPath()]];
	int r = pRun(boot.UTF8String);
	save(); // release the GIL; every later call goes through PyGILState
	gReady = (r == 0);
	gStatus = gReady ? @"running" : @"boot script failed (see python.log)";
}

void TGXPyStart(void (^done)(NSString *status)) {
	static dispatch_once_t once;
	dispatch_once(&once, ^{ gQ = dispatch_queue_create("tgx.python", DISPATCH_QUEUE_SERIAL); });
	dispatch_async(gQ, ^{
		@autoreleasepool { startLocked(); }
		if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(gStatus); });
	});
}

// Run source on the Python thread; result = everything it printed.
void TGXPyRun(NSString *code, void (^done)(BOOL ok, NSString *output)) {
	TGXPyStart(nil);
	dispatch_async(gQ, ^{
		if (!gReady) { if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(NO, gStatus); }); return; }
		NSString *outPath = TGXPyOutputPath();
		unsigned long long before = [[[NSFileManager defaultManager] attributesOfItemAtPath:outPath error:nil] fileSize];
		int st = pEnsure();
		int r = pRun(code.UTF8String);
		pRun("import sys; sys.stdout.flush()");
		pRelease(st);
		NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:outPath];
		[fh seekToFileOffset:before];
		NSString *out = [[NSString alloc] initWithData:[fh readDataToEndOfFile] encoding:NSUTF8StringEncoding] ?: @"";
		[fh closeFile];
		if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(r == 0, out); });
	});
}

NSString *const TGXPySelfTest =
	@"import sys, json, threading, datetime, time, hashlib, ssl, sqlite3, zlib, ctypes\n"
	 "print('python', sys.version.split()[0])\n"
	 "print('ssl', ssl.OPENSSL_VERSION)\n"
	 "print('sqlite', sqlite3.sqlite_version)\n"
	 "res = []\n"
	 "t = threading.Thread(target=lambda: res.append(sum(range(10**6))))\n"
	 "t.start(); t.join()\n"
	 "print('thread ok', res[0] == 499999500000)\n"
	 "print('json', json.dumps({'ok': True, 'now': datetime.datetime.now().isoformat(timespec='seconds')}))\n"
	 "print('ctypes', ctypes.sizeof(ctypes.c_void_p) * 8, 'bit')\n"
	 "print('SELF-TEST PASSED')\n";
