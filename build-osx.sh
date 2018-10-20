#! /bin/bash

brew update || exit 1
brew cask uninstall oclint
brew install ffmpeg opencv curl expat libffi fftw glib zlib openexr librsvg

export PATH="/usr/local/opt/curl/bin:/usr/local/opt/zlib/bin:$PATH"
export PKG_CONFIG_PATH="/usr/local/opt/curl/lib/pkgconfig:/usr/local/opt/zlib/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="/usr/local/opt/curl/lib:/usr/local/opt/zlib/lib:$LD_LIBRARY_PATH"


if [ ! -e gmic-qt ]; then
	echo "Running git clone https://github.com/c-koi/gmic-qt.git"
	git clone https://github.com/c-koi/gmic-qt.git || exit 1
	echo "... finished"
fi
cd gmic-qt || exit 1
if [ ! -e gmic-clone ]; then
	#echo "Running git clone --depth=1 https://framagit.org/dtschump/gmic.git gmic-clone"
	#git clone --depth=1 https://framagit.org/dtschump/gmic.git gmic-clone || exit 1
	echo "Running git clone https://github.com/dtschump/gmic.git gmic-clone"
	git clone https://github.com/dtschump/gmic.git gmic-clone || exit 1
	echo "... finished"
	patch -p1 < ../../GMIC/gmic-plugins-path.patch
fi

echo "Generating GMIC headers"
make -C gmic-clone/src CImg.h gmic_stdlib.h || exit 1


export CC="gcc -mmacosx-version-min=10.8 -fno-stack-protector -march=nocona -mno-sse3 -mtune=generic"
export CXX="g++ -mmacosx-version-min=10.8 -fno-stack-protector -march=nocona -mno-sse3 -mtune=generic"

make -B cli "SUBLIBS=-lX11"
makedir /tmp/gmic-cli
cp gmic /tmp/gmic-cli/

cd "$TRAVIS_BUILD_DIR"
if [ ! -e macdylibbundler ]; then
	git clone https://github.com/aferrero2707/macdylibbundler.git || exit 1
	(cd macdylibbundler && make) || exit 1
fi


cd /tmp/gmic-cli
"$TRAVIS_BUILD_DIR"/macdylibbundler/dylibbundler -b -od -x gmic -cd -p "@rpath" > /dev/null
install_name_tool -add_rpath "@loader_path/libs" gmic
cd …
tar czf "$TRAVIS_BUILD_DIR"/gmic-cli.tgz gmic-cli
