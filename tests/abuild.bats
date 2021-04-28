setup() {
	export ABUILD="$PWD/../abuild"
	export ABUILD_SHAREDIR="$PWD/.."
	export ABUILD_CONF=/dev/null
	tmpdir="$BATS_TMPDIR"/abuild
	export REPODEST="$tmpdir"/packages
	mkdir -p $tmpdir
	export CLEANUP="srcdir bldroot pkgdir deps"
}

teardown() {
	rm -rf "$tmpdir"
}

@test "abuild: help text" {
	$ABUILD -h
}

@test "abuild: version string" {
	$ABUILD -V
}

@test "abuild: build simple package without deps" {
	cd testrepo/pkg1
	$ABUILD
}

@test "abuild: build failure" {
	cd testrepo/buildfail
	run ERROR_CLEANUP="$CLEANUP" $ABUILD all
	[ $status -ne 0 ]
}

@test "abuild: test check for invalid file names" {
	cd testrepo/invalid-filename
	run ERROR_CLEANUP="$CLEANUP" $ABUILD all
	echo "$output"
	[ $status -ne 0 ]
}

@test "abuild: test check for /usr/lib64" {
	cd testrepo/lib64test
	run $ABUILD all
	[ $status -ne 0 ]
}

@test "abuild: test options=lib64" {
	cd testrepo/lib64test
	options=lib64 $ABUILD
	$ABUILD cleanpkg
}

@test "abuild: test -dbg subpackage" {
	cd testrepo/dbgpkg
	$ABUILD
}

@test "abuild: test SETFATTR in -dbg subpackage" {
	cd testrepo/dbgpkg
	ERROR_CLEANUP="$CLEANUP" SETFATTR=true $ABUILD
}

@test "abuild: test SETFATTR failure in -dbg subpackage" {
	cd testrepo/dbgpkg
	run ERROR_CLEANUP="$CLEANUP" SETFATTR=false $ABUILD
	[ $status -ne 0 ]
}

@test "abuild: verify that packages are reproducible built" {
	cd testrepo/pkg1
	arch=$($ABUILD -A)
	pkgs=$($ABUILD listpkg)

	$ABUILD
	checksums=$(cd "$REPODEST"/testrepo/$arch && md5sum $pkgs)
	echo "$checksums"

	$ABUILD cleanpkg all
	checksums2=$(cd "$REPODEST"/testrepo/$arch && md5sum $pkgs)
	echo "$checksums2"

	[ "$checksums" = "$checksums2" ]
}

@test "abuild: test checksum generation" {
	mkdir -p "$tmpdir"/foo
	cat >> "$tmpdir"/foo/APKBUILD <<-EOF
		pkgname="foo"
		pkgver="1.0"
		source="test.txt"
	EOF
	echo "foo" > "$tmpdir"/foo/test.txt
	cd "$tmpdir"/foo
	$ABUILD checksum
	. ./APKBUILD && echo "$sha512sums" > sums
	cat sums
	sha512sum -c sums
}

@test "abuild: test duplicates in checksum generation" {
	mkdir -p "$tmpdir"/foo "$tmpdir"/foo/dir1 "$tmpdir"/foo/dir2
	cat >> "$tmpdir"/foo/APKBUILD <<-EOF
		pkgname="foo"
		pkgver="1.0"
		source="dir1/testfile dir2/testfile"
	EOF
	echo "first" > "$tmpdir"/foo/dir1/testfile
	echo "second" > "$tmpdir"/foo/dir2/testfile
	cd "$tmpdir"/foo
	run $ABUILD checksum
	[ $status -ne 0 ]
}

