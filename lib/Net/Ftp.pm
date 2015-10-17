use v6;

unit class Net::Ftp;

my enum FTP (
	:FAIL<0>,
	:OK<1>,
);

has $!ftpc;
has $!ftpd;
has $!res;
has $!msg;
has	$.family = 2; #3 -> IPV6

has Str $.host = "";
has Int $.port = 21;
has Str $.user = "";
has Str $.pass = "";

has Bool $.pasv = False; 


method new (*%args is copy) {
	self.bless(|%args);
}

method login(:$account = "") {
	self!connect();
	self!welcome();
	self!authenticate($account);
}

method quit() {
# 221 ok
# 500 error
	self!sendcmd1('QUIT');
	self!respone();
	self!dispatch();
# close socket
	$!ftpc.close() if $!ftpc;
	$!ftpd.close() if $!ftpd;
	
	return FTP::OK;
}

method pasv() {
	$!pasv = False;
}

method result() {
	$!res;
}

method message() {
	$!msg;
}

method !connect() {
	$!ftpc = IO::Socket::INET.new(
							:host($!host),
							:port($!port), 
							:family($!family),
						);
	return FTP::OK;
}


method !welcome() {
# 220 ok
# 120|421 error
	self!respone();
	self!dispatch();
}

method !authenticate($account) {
# 230 ok
# 331 332 pass
# 530 500|501|421 error
	self!sendcmd2('USER', $!user);
	self!respone();
	unless self!dispatch() == FTP::OK {
		return FTP::FAIL;
	}

	if ($!res == 331 | $!res == 332) {
# 230 ok
# 202 no need pass, we send a pass
# 332 account
# 530 500|501|503|421 error
		self!sendcmd2('PASS', $!pass);
		self!respone();
		unless self!dispatch() == FTP::OK {
			return FTP::FAIL;
		}
		
		if ($!res == 332) {
# 230 ok
# 202 permission was already granted
# 530 500|501|503|421 error
			self!sendcmd2('ACCT', $account);
			self!respone();
			unless self!dispatch() == FTP::OK {
				return FTP::FAIL;
			}
		}
	}
	
	return FTP::OK;
}



method !respone() {
	my $line = $!ftpc.get();
	
	if ($line ~~ /(\d+)\s(.*)/) {
		($!res, $!msg) = ($0, $1);
	} elsif ($line ~~ /(\d+)\-(.*)/) {
		my ($res, $msg) = ($0, $1);
		
		loop {
			$line = $!ftpc.get();
			
			if ($line ~~ /$res\s(.*)/) {
				($!res, $!msg) = ($res, $msg ~ $1);
				last;
			} else {
				$msg = $msg ~ $line;
			}
		}
	} else {
		($!res, $!msg) = (-1, "Unknow respone!");
	}
}

method !dispatch() {
	given $!res {
		when 220 {
			return FTP::OK;
		}
		when 230 | 332 | 331 | 202 {
			return FTP::OK;
		}
		when 221 {
			return FTP::OK;
		}
		when 120 | 421 {
			return FTP::FAIL;
		}
		
		when 530 | 500 | 501 | 503 | 421 {
			return FTP::FAIL;
		}
	}
}


##private multi method not support..
method !sendcmd2($cmd, $para) {;
	$!ftpc.print: $cmd ~ ' ' ~ $para ~ "\r\n";
}

method !sendcmd1($cmd) {
	$!ftpc.print: $cmd ~ "\r\n";
}

method !exit(Str $err_msg) {
	say $err_msg;
	exit;
}

