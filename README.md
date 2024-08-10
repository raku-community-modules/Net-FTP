# Net::FTP

Net::FTP

A simple ftp client module written in Raku.

## Usage

```raku
use Net::FTP;
use Net::FTP::Config;

my $ftp = Net::FTP.new(:host<ftpserver>, :user<user>, :pass<pass>, :passive);

if $ftp.login() {
	mkdir('./ftpfile/');
	$ftp.cwd('/');
	for $ftp.ls() -> %info {
		next if (%info<name> eq '.' || %info<name> eq '..');
		if %info<type> == FILE::NORMAL {
			if $ftp.get(~%info<name>, "./ftpfile/", :binary) {
				say "GET %info<name> OK";
			}
		}
	}
	$ftp.quit();
}
```

## Installation

 install with zef

 zef install Net::FTP

## WARNING
 - Net::FTP::Format - getyear(), gettimet(), not yet implement.
 - Net::FTP - FTP only implemented passive mode.

## TODO
 - not available on new rakudo version
 - FTP need bind a local port

## Problem
Cause Raku can not bind a local port to a socket, it's not easy to implement a ftp client according to the standard.
If anyone know more about this, please contact me with email: blackcatoverwall@gmail.com
