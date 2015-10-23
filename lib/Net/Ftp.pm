use v6;

unit class Net::Ftp;

enum FTP is export (
	:FAIL<0>,
	:OK<1>,
);

enum TYPE is export < A I >;

enum FILE is export < NORMAL DIR LINK SOCKET PIPE CHAR BLOCK >;

has $!SOCKET_CLASS = IO::Socket::INET;

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
		when TYPE::A {
			unless $!ascii {
				self!sendcmd2('TYPE', 'A');
				$!ascii = True;
				unless self!handlecmd() {
					return FTP::FAIL;
				}
			}
		}
		when TYPE::I {
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
		self!pasv_connect(:line-separator("\r\n"));
	} else {
		self!port_connect();
	}
	if $path.defined {
		self!sendcmd2('LIST', ~$path);
	} else {
		self!sendcmd1('LIST');
	}
	my @res = ();
	if self!handlecmd() & self!handlecmd() {
		@res = self!readlist();	
	}
	$!ftpd.close() if $!ftpd;
	return @res;
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
	my @infos;

	while (my $buf = $!ftpd.get()) {
		note $buf if $!debug;
		$buf.chomp;
		if $buf ~~ /^\+/ {
			push @infos, self!eplf(~$buf);
		} else {
			push @infos, self!binls(~$buf);
		}
	}	
	@infos;
}

method !pasv_connect(:$encoding = 'utf-8', :$line-separator = '\n') {
# 227 ok
# 500|501|502|530 error
	self!sendcmd1('PASV');
	self!respone();
	if ($!msg ~~ /(\d+\,\d+\,\d+\,\d+)\,(\d+)\,(\d+)/) {
		$!ftpd = $!SOCKET_CLASS.new(
						:host($0.split(',').join('.')), 
						:port(~$1 * 256 + ~$2),
						:family($!family),
						:encoding($encoding),
						:input-line-separator($line-separator)
					);
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
	$!SOCKET_CLASS.new(:host($h),
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
	
	if ($line ~~ /^(\d ** 3)\s(.*)/) {
		($!res, $!msg) = ($0, $1);
	} elsif ($line ~~ /^(\d ** 3)\-(.*)/) {
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

method !eplf(Str $str is copy) {
	my %info;

	if $str ~~ s/\,\s+(.*)$// {
		%info<name> = ~$0;
	}
	$str ~~ s/^\+//;

	my @col = $str.split(',');

	for @col {
		if /i(.*)/ {
			%info<id> = ~$0;
		} elsif /\// {
			%info<type> = FILE::DIR;
		} elsif /r/ {
			%info<type> = FILE::NORMAL;
		} elsif /s(\d+)/ {
			%info<size> = +$0;
		} elsif /m(\d+)/ {
			%info<time> = +$0;
		}
		# seems like fmode have not use 
		#(elsif /up(\d+)/ {
		#	%info<mode> = ~$0;
		#})
	}
	
	%info;
}

method !gettype($type) {
	given $type {
		when '-' {
			return FILE::NORMAL;
		}
		when 'd' {
			return FILE::DIR;
		}
		when 'l' {
			return FILE::LINK;
		}
		when 's' {
			return FILE::SOCKET;
		}
		when 'p' {
			return FILE::PIPE;
		}
		when 'c' {
			return FILE::CHAR;
		}
		when 'b' {
			return FILE::BLOCK;
		}
	}
}

constant @month = (
	"jan","feb","mar","apr",
	"may","jun","jul","aug",
	"sep","oct","nov","dec"
);

method !getmonth(Str $str) {
	my $strlc = $str.lc;
	
	my $i = 0;
	
	for @month {
		if $strlc eq $_ {
			return $i;
		}
		$i++;
	}
	
	return -1;
}

method !binls(Str $str is copy) {
	my %info;
	
	if $str ~~ /^
			([\-|b|c|d|l|p|s])
			[
				[\-|<.alpha>]+ |
				\s+\[ [\-|<.alpha>]+ \]  
			]\s+/ {
		%info<type> = self!gettype(~$0);
		if $str ~~ /
				$<size> = (\d+)\s+
				$<month> = (<.alpha> ** 3)\s+
				$<day> = (\d+)\s+
				[
					$<year> = (\d ** 4) |
				 	$<hour> = (\d ** 2) \: $<minute> = (\d ** 2)
				]\s+
				$<name> = (.*)$/ {
			%info<name> = $<name>;
			%info<size> = $<size>;
			if $<year>.defined {
				#get time
			} else {
				#get time
			}
		}
	}
	if %info<name>:exists {
		if %info<name> ~~ /(.*)\s+\-\>\s+(.*)/ {
			%info<name> = ~$0;
			%info<link> = ~$1;
		}
	}
	if $str ~~ s:s/^(.*)\.([DIR|.*])\;\S*\s+// {
		if $1 eq DIR {
			%info<type> = FILE::DIR;
			%info<name> = ~$0;
		} else {
			%info<type> = FILE::NORMAL;
			%info<name> = ~$0 ~ '.' ~ $1;
		}
		if $str ~~ /^\S+\s+(\d+)\-(\w ** 3)\-(\d ** 4)\s+(\d+)\:(\d+)/ {
			#$0 day $1 month $2 year $3 hour $4 minute
		}
	} elsif $str ~~ /^(\d+)\-(\d+)\-(\d ** 4)\s+(\d+) \: (\d+)([AM|PM])\s+([\<DIR\> | \d+])\s+(.*)/ {
		#$0 month $1 day $2 year $3 hour $4 minute $5 AM | PM
		%info<name> = ~$7;
		if ~$6 eq '<DIR>' {
			%info<type> = FILE::DIR;
		} else {
			%info<size> = +$6;
			%info<type> = FILE::NORMAL;
		}
	}
	
	%info;
}

#NOT IMPLEMENT
# STRU MODE ALLO [TIMEOUT]
