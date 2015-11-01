
use Net::Ftp::Conn;
use Net::Ftp::Config;
use Net::Ftp::Buffer;

unit class Net::Ftp::Transfer;

has $.ascii;
has $!conn;

method new (*%args is copy) {
   self.bless(|%args)!initialize(|%args);
}

method !initialize(*%args) {
	undefine(%args<ascii>);
    $!conn = Net::Ftp::Conn.new(|%args);
    $!ascii ?? 
    	$!conn.connect() !!
    	$!conn.connect(:client<False>);
    self;
}

