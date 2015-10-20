use v6;

unit class Net::Ftp;

enum FTP is export (
	:FAIL<0>,
	:OK<1>,
);

enum TYPE is export < Ascii Image >;

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
has Bool $.ascii = True;

method new (*%args is copy) {
	self.bless(|%args);
}

method login(:$account = "") {
	$!ftpc = self!connect($!host, $!port, $!family);
	unless $!ftpc {
		return FTP::OK;
	}
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
	$!ftpc.close() if $!ftpc.defined;
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

# cause of perl6's getsockname not implement, you need
# pass a port to method
method port(Int $port?) {
# server does not connect to us immediately
	return FTP::FAIL if $!pasv;
	$!pasv = False;
    if ($port.defined) {
		#OS::gethost not implement now ..
    } else {
    	return FTP::FAIL;
    }
}

method pasv() {
	$!pasv = True; 
}

method type(TYPE $t) {
	given $t {
		when TYPE::Ascii {
			unless $!ascii {
				self!sendcmd2('TYPE', 'A');
				$!ascii = True;
				unless self!handlecmd() {
					return FTP::FAIL;
				}
			}
		}
		when TYPE::Image {
			if $!ascii {
				self!sendcmd2('TYPE', 'I');
				$!ascii = False;
				unless self!handlecmd() {
					return FTP::FAIL;
				}
			}
		}
	}
	
	return FTP::OK;
}

method rest($pos) {
	self!sendcmd2('REST', ~$pos);
	unless self!handlecmd() {
		return FTP::FAIL;
	}
	return FTP::OK;
}

method list($path?) {
	if $!pasv {
		self!pasv_connect();
	} else {
		self!port_connect();
	}
	if $path.defined {
		self!sendcmd2('LIST', ~$path);
	} else {
		self!sendcmd1('LIST');
	}
	if self!handlecmd() & self!handlecmd() {
		self!readlist();
		$!ftpd.close() if $!ftpd;
		return FTP::OK;
	} else {
		$!ftpd.close() if $!ftpd;
		return FTP::FAIL;
	}
}

method ls($path?) {
	if $path.defined {
		self.list($path);
	} else {
		self.list();
	}
}

method dir($path?) {
	if $path.defined {
		self.list($path);
	} else {
		self.list();
	}
}

method res() {
	$!res;
}

method msg() {
	~$!msg;
}

method !readlist() {
	while (my $buf = $!ftpd.get()) {
		say $buf;
		#go on
	}
}

method !pasv_connect() {
# 227 ok
# 500|501|502|530 error
	self!sendcmd1('PASV');
	self!respone();
	if ($!msg ~~ /(\d+\,\d+\,\d+\,\d+)\,(\d+)\,(\d+)/) {
		$!ftpd = self!connect($0.split(',').join('.'), 
							~$1 * 256 + ~$2, $!family);
		unless $!ftpd {
			return FTP::FAIL;
		}
		return FTP::OK;
	}
	return FTP::FAIL;
}

method !port_connect() {
	#
}

method !connect($h, $p, $f) {
	IO::Socket::INET.new(:host($h),
						 :port($p), 
						 :family($f));
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
	
	if ($line ~~ /^(\d+)\s(.*)/) {
		($!res, $!msg) = ($0, $1);
	} elsif ($line ~~ /^(\d+)\-(.*)/) {
		my ($res, $msg) = ($0, $1);
		
		loop {
			$line = $!ftpc.get();
			
			if ($line ~~ /^$res\s(.*)/) {
				($!res, $!msg) = ($res, $msg ~ $0);
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
			 257 |
			 227 |
			 350 |
			 150 | 125 | 226 {
			return FTP::OK;
		}
		# 120 is not a error
		# 421 service closing ftpc
		when 120 | 421 |
			 530 | 500 | 501 | 503 | 421 |
			 502 | 550 |
			 504 |
			 425 | 426 | 451 | 450 {
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

#NOT IMPLEMENT
# STRU MODE ALLO [TIMEOUT]
