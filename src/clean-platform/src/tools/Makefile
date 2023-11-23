DIST_MAC="dist-mac"
DIST_LINUX64="dist-linux64"
DIST_WIN32="dist-win32"
DIST_WIN64="dist-win64"
LIBRARIES="../libraries"

default: dist

dist: $(DIST_MAC) $(DIST_LINUX64) $(DIST_WIN32) $(DIST_WIN64)

$(DIST_MAC):
	mkdir -p $(DIST_MAC)
	cp -Rf $(LIBRARIES)/OS-Independent/* $(DIST_MAC)/
	cp -Rf $(LIBRARIES)/OS-Posix/* $(DIST_MAC)/
	cp -Rf $(LIBRARIES)/OS-Mac/* $(DIST_MAC)/

$(DIST_LINUX64):
	mkdir -p $(DIST_LINUX64)
	cp -Rf $(LIBRARIES)/OS-Independent/* $(DIST_LINUX64)/
	cp -Rf $(LIBRARIES)/OS-Posix/* $(DIST_LINUX64)/
	cp -Rf $(LIBRARIES)/OS-Linux/* $(DIST_LINUX64)/
	cp -Rf $(LIBRARIES)/OS-Linux-64/* $(DIST_LINUX64)/

$(DIST_WIN32):
	mkdir -p $(DIST_WIN32)
	cp -Rf $(LIBRARIES)/OS-Independent/* $(DIST_WIN32)/
	cp -Rf $(LIBRARIES)/OS-Windows/* $(DIST_WIN32)/
	cp -Rf $(LIBRARIES)/OS-Windows-32/* $(DIST_WIN32)/

$(DIST_WIN64):
	mkdir -p $(DIST_WIN64)
	cp -Rf $(LIBRARIES)/OS-Independent/* $(DIST_WIN64)/
	cp -Rf $(LIBRARIES)/OS-Windows/* $(DIST_WIN64)/
	cp -Rf $(LIBRARIES)/OS-Windows-64/* $(DIST_WIN64)/
