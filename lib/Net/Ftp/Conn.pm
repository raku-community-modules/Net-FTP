

unit class Net::Ftp::Conn;

has $.SOCKET;
has $.host;
has $.port;
has $!flag		= False;
has $!conn;

#	%args
#	host port family encoding client
method new (*%args is copy) {
	unless %args<port> {
		%args<port> = 21;
	}
	unless %args<SOCKET> {
		%args<SOCKET> = IO::Socket::INET;
	}
	dd %args;
	self.bless(|%args)!connect(|%args);
}

method !connect(*%args) {
	$!conn = $!SOCKET.new(|%args);
	$!flag = True;
	fail("Connect failed!") unless $!conn ~~ $!SOCKET;
	self;
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

method recv (:$bin?) {
    $bin ?? $!conn.recv(:bin) !! $!conn.recv();
}

multi method send(Str $str) {
	$!conn.print: $str;
}

multi method send(Buf $buf) {
	$!conn.write: $buf;	
}

method close() {
	$!conn.close(); 
}

method host() {
	$!host;
}

method port() {
	$!port;
}