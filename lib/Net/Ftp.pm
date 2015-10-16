use v6;

unit class Net::Ftp;

my enum FTP (
	:OK<1>,
);

has $!ftpc;
has $!ftpd;
has	$.family = 2; #3 -> IPV6

has Str $.host = "";
has Int $.port = 21;
has Str $.user = "";
has Str $.pass = "";

has Bool $.pasv = True; 


method new (*%args is copy) {
	self.bless(|%args);
}

method login() {
	self!connect();
	self!welcome();
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
	my ($res, $msg) = self!respone();
	
	self!dispatch($res, $msg);
}

method !dispatch($res, $msg) {
	given $res {
		when 120 {
			fail("Ftp service not ready. msg: $msg");
		}
		when 220 {
			return FTP::OK;
		}
		when 412 {
			fail("Service not available. msg: $msg");
		}
	}
}

method !respone() {
	my $line = $!ftpc.get();
	
	if ($line ~~ /(\d+)\s(.*)/) {
		return ($0, $1);
	}
	if ($line ~~ /(\d+)\-(.*)/) {
		my ($msg, $res);
		
		$res = $0;
		$msg = $1;
		loop {
			$line = $!ftpc.get();
			
			if ($line ~~ /$res\s(.*)/) {
				return ($res, $msg ~ $1);
			} else {
				$msg = $msg ~ $1;
			}
		}
	}
	return (0, "");
}

method fail(Str $err_msg) {
	fail($err_msg);
}

method exit(Str $err_msg) {
	say $err_msg;
	exit;
}

