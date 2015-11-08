<<<<<<< HEAD
# Net::Ftp
=======
# Net-Ftp

![Image of CI](https://travis-ci.org/araraloren/Net-Ftp.svg?branch=master)
>>>>>>> master

perl6 Net::Ftp

A simple ftp client module written in perl6.

<<<<<<< HEAD
## USAGE

```Perl6
use Net::Ftp;
use Net::Ftp::Config;

my $ftp = Net::Ftp.new(:host<ftpserver>, :user<user>, :pass<pass>, :passive);

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
 - Net::Ftp::Format 
 	getyear(), gettimet(), not yet implement.
 - Net::Ftp
 	Ftp only implemented passive mode.
=======


>>>>>>> master
