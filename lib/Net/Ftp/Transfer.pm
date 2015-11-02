
use Net::Ftp::Conn;
use Net::Ftp::Config;
use Net::Ftp::Buffer;
use Net::Ftp::Format;

unit class Net::Ftp::Transfer is Net::Ftp::Conn;

has $.ascii;

#	%args 
#	host port passive ascii family encoding
method new (*%args is copy) {
	%args<listen> = %args<passive>;
	nextsame(|%args);
}

method readlist() {
	unless self.can_recv() {
        fail("You need send a command!");
    }
	my @infos;
	
	while (my $buf = self.recv(:bin)) {
		for split($buf, Buf.new(0x0d, 0x0a)) {
			push @infos, format($_.unpack("A*"));
		}
	}

	@infos;
}