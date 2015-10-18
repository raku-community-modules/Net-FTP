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

has Bool $.debug = False;
has Bool $.pasv = False; 


method new (*%args is copy) {
	self.bless(|%args);
}

method login(:$account = "") {
	self!connect();
	if self!welcome() {
		self!authenticate($account);
	} else {
		FTP::FAIL;
	}
}

method cwd(Str $path) {
# 250 200 ok
# 500|501|502|530|550 error
	self!sendcmd2('CWD', $path);
	self!handlecmd();
}

method cdup() {
# 200 250 ok
# 500|501|502|530|550 error
	self!sendcmd1('CDUP');
	self!handlecmd();
}

method smnt(Str $drive) {
# 202 250 ok
# 500|501|502|530|550 error
	self!sendcmd2('SMNT', $drive);
	self!handlecmd();
}

method rein() {
#should use quit instead
# 220 ok
# 120 wait
# 500|502 error
	self!sendcmd1('REIN');
	self!handlecmd();
}

method quit() {
# 221 ok
# 500 error
	self!sendcmd1('QUIT');
	unless self!handlecmd() {
	#should return ?
		return FTP::FAIL;
	}
# close socket
	$!ftpc.close() if $!ftpc;
	$!ftpd.close() if $!ftpd;
	
	return FTP::OK;
}

method pwd() {
# 257 ok
# 550|501|502|550 error
	self!sendcmd1('PWD');
	unless self!handlecmd() {
		return '';
	}
	if $!msg ~~ /\"(.*)\"/ {
		return ~$0;
	}
	return '';
}

method pasv() {
	$!pasv = False;
}

method res() {
	$!res;
}

method msg() {
	~$!msg;
}

method !connect() {
	$!ftpc = IO::Socket::INET.new(
							:host($!host),
							:port($!port), 
							:family($!family),
						);
}


method !welcome() {
# 220 ok
# 120 wait - just return fail
	self!respone();
	self!dispatch();
}

method !authenticate($account) {
# 230 ok
# 331 332 pass
# 530 500|501 error
	self!sendcmd2('USER', #if user empty, use 'anonymous'. 
				$!user ?? $!user !! 'anonymous');
	unless self!handlecmd() {
		return FTP::FAIL;
	}
	
	# | need bracket
	if (($!res == 331) | ($!res == 332)) {
# 230 ok
# 202 no need pass, we send a pass
# 332 account
# 530 500|501|503 error
		self!sendcmd2('PASS', #if user pass both empty, use 'anonymous@' 
					($!pass | $!user) ?? $!pass !! 'anonymous@');
		unless self!handlecmd() {
			return FTP::FAIL;
		}
		
		if ($!res == 332) {
# 230 ok
# 202 permission was already granted
# 530 500|501|503 error
			self!sendcmd2('ACCT', $account);
			unless self!handlecmd() {
				return FTP::FAIL;
			}
		}
	}
	
	return FTP::OK;
}

method !handlecmd() {
	self!respone();
	self!dispatch();
}

method !respone() {
	my $line = $!ftpc.get();
	
	note ~$line if $!debug;
	
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
		($!res, $!msg) = (-1, 'Unknow respone!');
	}
}

method !dispatch() {
	given $!res {
		when 220 |
			 230 | 332 | 331 | 202 |
			 221 |
			 250 | 200 |
			 257 {
			return FTP::OK;
		}
		# 120 is not a error
		# 421 service closing ftpc
		when 120 | 421 |
			 530 | 500 | 501 | 503 | 421 |
			 502 | 550 {
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

