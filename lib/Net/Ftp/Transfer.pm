
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
	my @infos;

	while (my $buf = self.recv(:bin)) {
		for split($buf, Buf.new(0x0d, 0x0a)) {
			push @infos, format($_.unpack("A*"));
		}
	}

	@infos;
}

method read(Bool :$bin? = False) {
	my @infos;

	while (my $buf = self.recv(:bin)) {
		if $bin {
			@infos.push: $buf;
		} else {
			for split($buf, Buf.new(0x0d, 0x0a)) {
				push @infos, $_.unpack("A*");
			}
		}
	}

	return $bin ?? merge(@infos) !! ~(@infos.join());
}