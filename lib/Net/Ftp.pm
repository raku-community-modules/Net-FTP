
use Net::Ftp::Conn;
use Net::Ftp::Control;
use Net::Ftp::Transfer;
use Net::Ftp::Config;

unit class Net::Ftp;

has Str $.user;
has Str $.pass;
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

	$!ftpc.cmd_user($!user ?? $!user !! 'anonymous');
	unless self!handlecmd() {
		return FTP::FAIL;
	}

	if $!code == 331 || $!code == 332 {
		$!ftpc.cmd_pass(($!pass || $!user) ?? $!pass !! 'anonymous@');
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

method mkdir(Str $remote-path) {
	$!ftpc.cmd_mkd($remote-path.subst("\n", "\0"));
	if self!handlecmd() {
		if $!code == 257 && ($!msg ~~ /\"(.*)\"/) {
			return ~$0;
		} else {
			return $remote-path;
		}
	}
	return FTP::FAIL;
}

method md(Str $remote-path) {
	self.mkdir($remote-path);
}

method rmdir(Str $remote-path) {
	$!ftpc.cmd_rmd($remote-path.subst("\n", "\0"));
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

method list(Str $remote-path?) {
	my $transfer = self!conn_transfer();
	
	unless $transfer ~~ Net::Ftp::Conn {
		return FTP::FAIL;
	}
	if $remote-path {
		$!ftpc.cmd_list($remote-path);
	} else {
		$!ftpc.cmd_list();
	}
	my @res;
	if self!handlecmd() {
		@res = $transfer.readlist();
		$transfer.close();
		self!handlecmd();
	} else {
		$transfer.close();
	}

	return @res;
}

method ls($remote-path?) {
	if $remote-path {
		self.list($remote-path);
	} else {
		self.list();
	}
}

method dir($remote-path?) {
	if $remote-path {
		self.list($remote-path);
	} else {
		self.list();
	}
}

method stor(Str $remote-path is copy, $data) {
	my $transfer = self!conn_transfer();

	unless $!ascii {
		$remote-path = $remote-path.subst("\n", "\0");
	}
	$!ftpc.cmd_stor($remote-path);
	if self!handlecmd() {
		$transfer.send: $data;
		$transfer.close();
		if self!handlecmd() {
			return FTP::OK;
		}
	} else {
		$transfer.close();
	}

	return FTP::FAIL;
}

method stou($data, Str $remote-path? is copy) {
	my $transfer = self!conn_transfer();

	if (!$!ascii) && $remote-path {
		$remote-path = $remote-path.subst("\n", "\0");
	}
	if $remote-path {
		$!ftpc.cmd_stou($remote-path);
	} else {
		$!ftpc.cmd_stou();	
	}
	if self!handlecmd() {
		if $!code == 250 {
			unless self!handlecmd() {
				$transfer.close();
				return FTP::FAIL;
			}
		}
		if $!msg ~~ /\:\s+$<name> = (.*)$/ {
			$transfer.send: $data;
			$transfer.close();
			if self!handlecmd() {
				return $<name>;
			}
		} else {
			$transfer.close();
		}
	} else {
		$transfer.close();
	}

	return FTP::FAIL;
}

method appe(Str $remote-path is copy, $data) {
	my $transfer = self!conn_transfer();

	unless $!ascii {
		$remote-path = $remote-path.subst("\n", "\0");
	}
	$!ftpc.cmd_appe($remote-path);
	if self!handlecmd() {
		$transfer.send: $data;
		$transfer.close();
		if self!handlecmd() {
			return FTP::OK;
		}
	} else {
		$transfer.close();
	}

	return FTP::FAIL;
}

method append(Str $path,
			Str $remote-path? = "",
			Str :$encoding? = "utf8", 
			Bool :$binary? = False) {
	my $content = read_file($path, $encoding, $binary);

	unless $content {
		return FTP::FAIL;
	}

	return self.appe($remote-path ?? $remote-path !! $path , $content);
}

method put(Str $path,
		Str $remote-path? = "",
		Str :$encoding? = "utf8", 
		Bool :$binary? = False, 
		Bool :$unique? = False) {

	my $content = read_file($path, $encoding, $binary);

	unless $content {
		return FTP::FAIL;
	}

	return $unique ??  
	self.stou($content, $remote-path ?? $remote-path !! $path ) !! 
	self.stor($remote-path ?? $remote-path !! $path , $content);
}

method retr(Str $remote-path is copy, Bool :$binary? = False) {
	unless ($binary ?? self.binary() !! self.ascii()) {
		return FTP::FAIL;
	}
	my $transfer = self!conn_transfer();

	$remote-path = $remote-path.subst("\n", "\0");
	$!ftpc.cmd_retr($remote-path);
	my $ret;

	if self!handlecmd {
		$ret = $binary ??
			$transfer.read(:bin) !!
			$transfer.read();

		self!handlecmd();
	}

	return $ret;
}

method get(Str $remote-path, 
		Str $local? = "",
		Bool :$binary? = False,
		Bool :$appened? = False) {
	my $data = self.retr($remote-path, :binary($binary));

	unless $data {
		return FTP::FAIL;
	}

	write_file($local ?? $local !! $remote-path, 
			$data, $appened);

	return FTP::OK;
}

method rename(Str $old is copy, Str $new is copy) {
	$old = $old.subst("\n", "\0");
	$!ftpc.cmd_rnfr($old);
	unless self!handlecmd {
		return FTP::FAIL;
	}
	$new = $new.subst("\n", "\0");
	$!ftpc.cmd_rnto($new);
	self!handlecmd();
}

method delete(Str $remote-path is copy) {
	$remote-path = $remote-path.subst("\n", "\0");
	$!ftpc.cmd_dele($remote-path);
	self!handlecmd();
}

method !conn_transfer() {
	if $!passive {
		$!ftpc.cmd_pasv();
		unless self!handlecmd() {
			return FTP::FAIL;
		}
		if ($!msg ~~ /
				$<host> = (\d+\,\d+\,\d+\,\d+)\,
				$<p1> = (\d+)\,
				$<p2> = (\d+)/) {
			my $transfer = Net::Ftp::Transfer.new(
				:host($<host>.split(',').join('.')),
				:port($<p1> * 256 + $<p2>),
				:passive($!passive),
				:ascii($!ascii),
				:family($!family),
				:encoding($!encoding));
			unless $transfer ~~ Net::Ftp::Conn {
				fail("Can not connect to @$<host>:$<port>");
			}
			$transfer;
		}
	} else {

	}
}

sub read_file(Str $path, Str $encoding, Bool $bin) {
	my $fp = IO::Path.new($path);

	unless $fp ~~ :e {
		return FTP::FAIL;
	}

	my $fh = $fp.open(:r, :bin($bin));

	my $content = $bin ?? 
			$fh.slurp-rest(:bin) !!
			 $fh.slurp-rest(:enc($encoding));

	$fh.close();

	return $content;
}

multi sub write_file(Str $path, Buf $data, Bool $append) {
	my $fh = $append ?? 
		$path.IO.open(:a) !! $path.IO.open(:w);

	$fh.write($data);
			
	$fh.close();
}

multi sub write_file(Str $path, Str $data, Bool $append) {
	my $fh = $append ?? 
		$path.IO.open(:a) !! $path.IO.open(:w);

	$fh.print($data);
			
	$fh.close();
}

=begin pod

=head1 NAME

Net::Ftp - A simple ftp client

=head1 SYNOPSIS

	use Net::Ftp;

	my $ftp = Net::Ftp.new(:user<ftpt>, :pass<123456>, :host<192.168.0.101>, :debug, :passive);

	$ftp.login();
	$ftp.list();
	$ftp.quit();

=head1 DESCRIPTION

Net::Ftp is a ftp client class in perl6.

=head1 METHOD

=head2 new([OPTIONS]);

	This is a constructor for Net::Ftp.

	CODE:
		my $ftp = Net::Ftp.new(:host<192.168.0.1>);

	OPTIONS are passed in hash. If OPTIONS followed by a square brackets , '*' means optionals, 

	other means has a default value.

	These OPTIONS are :

=item3 host

	Ftp host we want connect to, it's required. Sample as '192.168.0.1';

=item3 port[21]

	Ftp server port number.

=item3 family[2]

	The ip domain we use. Defaults to 2 for IPv4, and can be set to 3 for IPv6.

=item3 encoding[utf8]

	Specifies the encoding we use.

=item3 user[*]

	You may be need a ftp username to login. If user is not given or a empty string, ftp will login as anonymous.

=item3 pass[*]

	Ftp user's password. If password is not given or a empty string, and the user is anonymous, anonymous@ will be 
	the password of user. 

=item3 passive[False]

	Default ftp is active mode, set to True use ftp passive mode.

=item3 debug[False]

	If debug is set, print debug infomation. Generally it is [+code, msg we receive from ftp server]. 

=item3 SOCKET[IO::Socket::INET]

	Socket class we use.

=head2 code( --> Int);

	Get the last respone code from server.

	CODE:
		say $ftp.code();

=head2 msg( --> Str);

	Get the last respone msg from server. 

	CODE:
		say $ftp.msg();

=head2 login([ACCOUNT], --> enum);

	Login to remote ftp server. Some ftp server may be ask for a account.
	
	CODE:
		$ftp.login();

	RETURN VALUE:
		FTP::OK	- When success;
		FTP::FAIL - When failed.

=head2 quit( --> enum);

	Disconnect from ftp server.

	CODE:
		$ftp.quit();

	RETURN VALUE:
		FTP::OK	- When success;
		FTP::FAIL - When failed.

=head2 cwd(Str $dir, --> enum);

	Change current directory to $dir.

	CODE:
		$ftp.cwd("/somedir");

	RETURN VALUE:
		FTP::OK	- When success;
		FTP::FAIL - When failed.

=end pod



