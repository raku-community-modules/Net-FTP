# Net::FTP

[![Build Status](https://travis-ci.org/araraloren/Net-FTP.svg?branch=master)](https://travis-ci.org/araraloren/Net-FTP)

perl6 Net::FTP

A simple ftp client module written in perl6.

## USAGE

```Perl6
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

## WARNING
 - Net::FTP::Format 
 	getyear(), gettimet(), not yet implement.
 - Net::FTP
 	FTP only implemented passive mode.




