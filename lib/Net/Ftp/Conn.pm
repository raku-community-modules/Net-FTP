

unit class Net::Ftp::Conn;

has $.SOCKET = IO::Socket::INET;
has $.host;
has $.port 		= 21;
has $.family	= 2;
has $.encoding	= "utf8";
has $.pasv		= False;
has $!conn;

method new (*%args) {
	if !%args<pasv> {
		%args<host> = %args<host> ?? 
			%args<host> !! 
			"localhost";
	} else {
		unless %args<host> {
			fail("Host can not be empty!");
		}
	}
	self.bless(|%args);
}

method connect() {
	$!conn = $!pasv ??
		$!SOCKET.new(
			:host($!host),
			:port($!port),
			:family($!family),
			:encoding($!encoding)) !!
		$!SOCKET.new(
			:listen,
			:host($!host),
			:port($!port),
			:family($!family),
			:encoding($!encoding));
	
	return $!conn ~~ $!SOCKET;
}

method close() {
	$!conn.close(); 
}

multi method sendcmd(Str $cmd) {
	$!conn.print: $cmd ~ "\r\n";
}

multi method sendcmd(Str $cmd, Str $para) {
	$!conn.print: $cmd ~ " $para" ~ "\r\n";
}

multi method recv(:$bin?) {
    $bin ?? $!conn.recv(:bin) !! $!conn.recv();
}

multi method send(Str $str) {
	$!conn.print: $str;
}

multi method send(Buf $buf) {
	$!conn.write: $buf;	
}
