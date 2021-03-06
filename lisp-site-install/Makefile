#
#    Create system-wide lisp libraries.
#

#
# get sbcl and install it.
#
# The binary-release & source-dir variables should be updated
# as new versions of sbcl are released.
#
# If you want to install sbcl in a directory other than /usr/local
# Set environment variable INSTALL_ROOT before compiling the
# sbcl source code.
#
ifeq ($(shell uname),Darwin)
ifeq ($(shell uname -p),powerpc)
  binary-release = sbcl-1.0.47-powerpc-darwin-binary.tar.bz2
endif
ifeq ($(shell uname -m),x86_64)
  binary-release = sbcl-1.1.8-x86-64-darwin-binary.tar.bz2
  binary-dir = sbcl-1.1.8-x86-64-darwin
else
ifeq ($(shell uname -p),i386)
  binary-release = sbcl-1.0.55-x86-darwin-binary.tar.bz2
  # work-around for bug in make-config.sh which guesses the wrong platform
  # on OSX 10.4.11, MacBook Pro.
  platform = SBCL_ARCH=x86; export SBCL_ARCH;
endif
endif
endif

ifeq ($(shell uname),Linux)
ifeq ($(shell uname -p),i686)
  binary-release = sbcl-1.0.58-x86-linux-binary.tar.bz2 
  binary-dir = sbcl-1.0.58-x86-linux
endif
ifeq ($(shell uname -m),i686)
  binary-release = sbcl-1.0.58-x86-linux-binary.tar.bz2
  binary-dir = sbcl-1.0.58-x86-linux
endif
ifeq ($(shell uname -p),pentium4) # Andrew linux at CMU
  binary-release = sbcl-1.0.58-x86-linux-binary.tar.bz2
  binary-dir = sbcl-1.0.58-x86-linux
endif 
ifeq ($(shell uname -p),x86_64)
  binary-release = sbcl-1.1.14-x86-64-linux-binary.tar.bz2
  binary-dir = sbcl-1.1.14-x86-64-linux
endif 
ifeq ($(shell uname -m),x86_64)
  binary-release = sbcl-1.1.14-x86-64-linux-binary.tar.bz2
  binary-dir = sbcl-1.1.14-x86-64-linux
endif
endif
ifndef binary-release
  $(error "Unknown architecture")
endif 

# RedHat custom wget returns an error if file exists
get-binary:
ifeq ($(shell uname),Darwin)
	-curl -L http://prdownloads.sourceforge.net/sbcl/$(binary-release) -O
else
	-wget -nc http://prdownloads.sourceforge.net/sbcl/$(binary-release)
endif
	tar jxf $(binary-release)
	@echo "changing to directory $(binary-dir):"
	cd $(binary-dir); chmod u+x run-sbcl.sh

# The binary version of sbcl should not be used
# to run the Andes help server.  Use the custom version below.
binary-install:
	@echo "Needs superuser privileges for install into /usr/local"
	cd $(binary-dir); sh install.sh
thread-test:
	cd $(binary-dir); echo '(format t "Threading is~:[ not~;~] supported on binary release.~%" (find :sb-thread *features*)) (quit)' | ./run-sbcl.sh --noinform --noprint

source-dir = sbcl-1.1.14
source-release = $(source-dir)-source.tar.bz2
get-source:
ifeq ($(shell uname),Darwin)
	-curl -L http://prdownloads.sourceforge.net/sbcl/$(source-release) -O
else
	-wget -nc http://prdownloads.sourceforge.net/sbcl/$(source-release)
endif
	tar jxf $(source-release)
	# enable thread support (for OS X) and :sb-hash-table-debug
	cp customize-target-features.lisp $(source-dir)
	#  Use "diff -u old-file new-file" to create patch
	patch -p 1 -d $(source-dir) < backend-parms.lisp-x86-1.0.55-patch 
	patch -p 1 -d $(source-dir) < backend-parms.lisp-x86_64-1.1.14-patch
	patch -p 1 -d $(source-dir) < parms.lisp-1.0.55-patch
ifdef INSTALL_ROOT 
	$(platform) cd $(source-dir); sh make.sh --prefix ${INSTALL_ROOT} $(shell echo "../$(binary-dir)/run-sbcl.sh")
	@echo "Install directory ${INSTALL_ROOT}"
else
	$(platform) cd $(source-dir); sh make.sh $(shell echo "../$(binary-dir)/run-sbcl.sh")
endif

ifdef SUDO_USER
username=$(SUDO_USER)
else
username=$(USER)
endif

ifndef INSTALL_ROOT 
INSTALL_ROOT=/usr/local
endif

source-install:
	@echo "Install into ${INSTALL_ROOT}/bin and ${INSTALL_ROOT}/lib"
	cd $(source-dir); sh install.sh
	$(MAKE) quicklisp-install

quicklisp-install: quicklisp.lisp
	sbcl --load quicklisp.lisp   --eval "(quicklisp-quickstart:install :path \"${INSTALL_ROOT}/quicklisp/\")"  --load install-libraries.lisp
	chown -R $(username) ${INSTALL_ROOT}/quicklisp
	@echo "User $(username) can modify quicklisp"

sbclrc: quicklisp.lisp
	cat sbclrc-sample >> ~/.sbclrc
	echo "(pushnew #P\"`cd ..;pwd`/\" asdf:*central-registry*)" >> ~/.sbclrc
	sbcl --eval "(load \"${INSTALL_ROOT}/quicklisp/setup.lisp\")" --eval "(ql:add-to-init-file)" --quit
	cat sbclrc-sample-end >> ~/.sbclrc

quicklisp.lisp:
ifeq ($(shell uname),Darwin)
	curl -L http://beta.quicklisp.org/quicklisp.lisp -O
else
	wget -nc http://beta.quicklisp.org/quicklisp.lisp
endif

# A good version test is to see if sbcl is using ASDF version 2.
update:
	@sbcl --noinform --eval "(pprint #+asdf2 'asdf2 #-asdf2 0)" --quit | grep -i -o "asdf2" || (echo "Wrong version of sbcl:  see INSTALL for installing new version." && test  0 -eq 1)
