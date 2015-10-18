
use v6;
use Test;

use Net::Ftp;

plan 7;

##013.3vftp.com is a ftp service
##mirrors.sohu.com is a anonymous ftp service 

my $ftp = Net::Ftp.new(:host('mirrors.sohu.com'));

ok($ftp.login() == 1, "anonymous ftp login success");
isnt($ftp.pwd(), '', "get current directory.");
ok($ftp.cwd('fedora') == 1, "change current directory to fedora");
isnt($ftp.pwd(), '', "get current directory.");
ok($ftp.cdup() == 1, "change current directory to fedora");
isnt($ftp.pwd(), '', "get current directory.");
ok($ftp.quit == 1, "anonymous ftp quit");
			
