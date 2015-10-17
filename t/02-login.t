
use v6;
use Test;

use Net::Ftp;

plan 3;

my $host = '221.224.163.61';
my $ftp = Net::Ftp.new(:host($host));

ok($ftp.login() == 0, "ftp login failed");

$ftp = Net::Ftp.new(:host('013.3vftp.com'),
					 :user<ftptest138>,
					 :pass('123456'));
				
ok($ftp.login() == 1, "ftp login success");
ok($ftp.quit == 1, "ftp quit");				
