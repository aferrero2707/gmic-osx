#! /bin/bash

brew update || exit 1
brew cask uninstall oclint
#brew install ffmpeg curl expat libffi fftw glib zlib openexr cmake #opencv@2 
git clone https://github.com/aferrero2707/homebrew-bottles.git || exit 1
bash homebrew-bottles/install-bottles.sh || exit 1
exit
brew install curl expat glib || exit 1 
brew upgrade cmake || exit 1

export PATH="/usr/local/opt/opencv@2/bin:/usr/local/opt/curl/bin:/usr/local/opt/zlib/bin:$PATH"
export PKG_CONFIG_PATH="/usr/local/opt/opencv@2/lib/pkgconfig:/usr/local/opt/curl/lib/pkgconfig:/usr/local/opt/zlib/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="/usr/local/opt/opencv@2/lib:/usr/local/opt/curl/lib:/usr/local/opt/zlib/lib:$LD_LIBRARY_PATH"


if [ ! -e gmic ]; then
	#echo "Running git clone --depth=1 https://framagit.org/dtschump/gmic.git gmic-clone"
	#git clone --depth=1 https://framagit.org/dtschump/gmic.git gmic-clone || exit 1
	echo "Running git clone https://github.com/dtschump/gmic.git gmic"
	git clone https://github.com/dtschump/gmic.git gmic || exit 1
	echo "... finished"
fi
cd gmic || exit 1

export CC="gcc -mmacosx-version-min=10.8 -fno-stack-protector -march=nocona -mno-sse3 -mtune=generic"
export CXX="g++ -mmacosx-version-min=10.8 -fno-stack-protector -march=nocona -mno-sse3 -mtune=generic"

mkdir build || exit 1
cd build || exit 1
cmake -DBUILD_CLI=ON .. || exit 1
make -j 3 || exit 1
#make -B cli "SUBLIBS=-lX11" || exit 1
mkdir /tmp/gmic-cli || exit 1
cp -a gmic /tmp/gmic-cli/ || exit 1

cd "$TRAVIS_BUILD_DIR"
if [ ! -e macdylibbundler ]; then
	git clone https://github.com/aferrero2707/macdylibbundler.git || exit 1
	(cd macdylibbundler && make) || exit 1
fi


fix_lib()
{
	_LIB="$1"
	DYLIST=$(otool -L "${_LIB}")
	NDY=$(echo "$DYLIST" | wc -l)
	echo "NDY: $NDY"
	
	# patch absolute paths
	I=2
	while [ $I -le $NDY ]; do
		LINE=$(echo "$DYLIST" | sed -n ${I}p)
		DYLIB=$(echo $LINE | sed -e 's/^[ \t]*//' | tr -s ' ' | tr ' ' '\n' | head -n 1)
		PREFIX=$(basename "$DYLIB" | cut -d'.' -f 1)
		echo "PREFIX: $PREFIX"
		DYLIB2=$(find "." -name "$PREFIX"*)
		echo "DYLIB2: $DYLIB2"

		#check if this is a system library, using an ad-hoc euristic
		TEST=$(echo "$DYLIB" | grep '\.framework')
		if [ -n "$TEST" ]; then
			# this looks like a framework, no ned to patch the absolute path
			I=$((I+1)); continue;
		fi
		TEST=$(echo "$DYLIB" | grep '/usr/lib/')
		if [ -n "$TEST" ]; then
			# this looks like a system library, no ned to patch the absolute path
			I=$((I+1)); continue;
		fi
	
		# replace absolute paths for non-system libraries and frameworks
		# at runtime the libraries will be searched through the @rpath list
		if [ -n "$DYLIB2" ]; then
			DYLIBNAME=$(basename "$DYLIB2")
		else
			DYLIBNAME=$(basename "$DYLIB")
		fi
		echo "install_name_tool -change \"$DYLIB\" \"@loader_path/$DYLIBNAME\" \"${_LIB}\""
		install_name_tool -change "$DYLIB" "@loader_path/$DYLIBNAME" "${_LIB}"
		I=$((I+1))
	done
otool -L "${_LIB}"
}


cd /tmp/gmic-cli || exit 1
"$TRAVIS_BUILD_DIR"/macdylibbundler/dylibbundler -b -od -x gmic -cd -p "@rpath" > /dev/null
cp -a /usr/local/Cellar/opencv/3.4.3/lib/libopencv_*.dylib libs
echo "install_name_tool -add_rpath \"@loader_path/libs\" gmic"
install_name_tool -add_rpath "@loader_path/libs" gmic
for F in libs/*.dylib; do
	fix_lib "$F"
	#echo "install_name_tool -add_rpath \"@loader_path\" \"$F\""
	#install_name_tool -add_rpath "@loader_path" "$F"
done
cd ..
tar czvf "$TRAVIS_BUILD_DIR"/gmic-cli.tgz gmic-cli
