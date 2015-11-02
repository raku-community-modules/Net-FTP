
use Net::Ftp::Conn;
use Net::Ftp::Control;
use Net::Ftp::Transfer;
use Net::Ftp::Config;

unit class Net::Ftp;

has $.user;
has $.pass;
has $.passive 	= False;
has $.ascii 	= False;
has $.family    = 2;
has $.encoding  = "utf8";
has $!ftpc;
has $!code;
has $!msg;

method new (*%args is copy) {
	unless %args<family> {
		%args<family> = 2;
	}
	unless %args<encoding> {
		%args<encoding> = "utf8";
	}
	self.bless(|%args)!initialize(|%args);
}

method !initialize(*%args) {
	$!ftpc = Net::Ftp::Control.new(|%args);
	self;
}

method !handlecmd() {
	($!code, $!msg) = $!ftpc.get();
	$!ftpc.dispatch($!code);
}

method code() {
	$!code;
}

method msg() {
	$!msg;
}

method login(:$account?) {
	$!ftpc.cmd_conn();
	unless self!handlecmd() {
		return FTP::FAIL;
	}

	$!ftpc.cmd_user($!user);
	unless self!handlecmd() {
		return FTP::FAIL;
	}

	if $!code == 331 || $!code == 332 {
		$!ftpc.cmd_pass($!pass);
		unless self!handlecmd() {
			return FTP::FAIL;
		}

		if $!code == 332 {
			$account ?? fail("Login need account.") !!
			$!ftpc.cmd_acct($account);
			unless self!handlecmd() {
				return FTP::FAIL;
			}
		}
	}

	return FTP::OK;
}

method quit() {
	$!ftpc.cmd_quit();
	unless self!handlecmd() {
		return FTP::FAIL;
	}
	$!ftpc.cmd_close();
	return FTP::OK;
}

method cwd(Str $path) {
	$!ftpc.cmd_cwd($path);
	self!handlecmd();
}

method cdup() {
	$!ftpc.cmd_cdup();
	self!handlecmd();
}

method smnt(Str $drive) {
	$!ftpc.cmd_smnt($drive);
	self!handlecmd();
}

method rein() {
	$!ftpc.cmd_rein();
	self!handlecmd();
}

method pwd() {
	$!ftpc.cmd_pwd();
	if self!handlecmd() {
		if ($!msg ~~ /\"(.*)\"/) {
			return ~$0;
		}	
	}
	return FTP::FAIL;
}

method passive(Bool $passive?) {
	if $passive {
		$!passive = $passive;
	}
	return $!passive;
}

method type(MODE $t) {
	given $t {
		when MODE::ASCII {
			unless $!ascii {
				$!ftpc.cmd_type('A');
				$!ascii = True;
				unless self!handlecmd() {
					return FTP::FAIL;
				}
			}
		}
		when MODE::BINARY {
			if $!ascii {
				$!ftpc.cmd_type('I');
				$!ascii = False;
				unless self!handlecmd() {
					return FTP::FAIL;
				}
			}
		}
	}
	
	return FTP::OK;
}

method ascii() {
	self.type(MODE::ASCII);
}

method binary() {
	self.type(MODE::BINARY);
}

method rest(Int $pos) {
	$!ftpc.cmd_rest($pos);
	self!handlecmd();
}

method list(Str $path?) {
	my $transfer = self!conn_transfer();
	
	if $path {
		$!ftpc.cmd_list($path);
	} else {
		$!ftpc.cmd_list();
	}
	my @res;
	if self!handlecmd() {
		@res = $transfer.readlist();
		say @res;
		$transfer.close();
	}

	return @res;
}

method !conn_transfer() {
	if $!passive {
		$!ftpc.cmd_pasv();
		unless self!handlecmd() {
			return FTP::FAIL;
		}
	} else {

	}
	if ($!msg ~~ /
			$<host> = (\d+\,\d+\,\d+\,\d+)\,
			$<p1> = (\d+)\,
			$<p2> = (\d+)/) {
		Net::Ftp::Transfer.new(
			:host($<host>.split(',').join('.')),
			:port($<p1> * 256 + $<p2>),
			:passive($!passive),
			:ascii($!ascii),
			:family($!family),
			:encoding($!encoding));
	}

}