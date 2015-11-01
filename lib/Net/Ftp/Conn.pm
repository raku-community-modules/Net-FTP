

unit class Net::Ftp::Conn;

has $.SOCKET = IO::Socket::INET;
has $.host;
has $.port 		= 21;
has $.family	= 2;
has $.encoding	= "utf8";
has $!flag		= False;
has $!conn;

method new (*%args is copy) {
	self.bless(|%args);
}

method connect(:$client = True) {
	$!conn = $client ??
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
	$!flag = True;
	
	return $!conn ~~ $!SOCKET;
}

method close() {
	$!conn.close(); 
}

multi method sendcmd(Str $cmd) {
	$!conn.print: $cmd ~ "\r\n";
	$!flag = True;
}

multi method sendcmd(Str $cmd, Str $para) {
	$!conn.print: $cmd ~ " $para" ~ "\r\n";
	$!flag = True;
}

method can_recv() {
	$!flag;
}

method recv_over() {
	$!flag = False;
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

method host() {
	$!host;
}

method port() {
	$!port;
}

method family() {
	$!family;
}

method encoding() {
	$!encoding;
}

method set_host(Str $host) {
	$!host = $host;
}

method set_port(Str $port) {
	$!port = $port;
}

method set_family(Str $family) {
	$!family = $family;
}

method set_encoding(Str $encoding) {
	$!host = $encoding;
}