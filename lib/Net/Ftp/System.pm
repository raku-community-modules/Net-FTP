
use NativeCall;

unit module Net::Ftp::System;

sub time () returns int is native('libc.so.6') is export { * }

sub findLibrary(Str $libkeyword) {

}

