
use v6;
use Test;

use Net::Ftp;

plan 4;

##mirrors.sohu.com is a anonymous ftp service 

my $ftp = Net::Ftp.new(:host('013.3vftp.com'),
					 :user<ftptest138>,
					 :pass('123456'));

$ftp.login();
ok($ftp.pasv() == 1, "set pasv mode");
isnt($ftp.ls(), (), "list file success");
$ftp.quit();


$ftp = Net::Ftp.new(:host('mirrors.sohu.com'));

$ftp.login();
ok($ftp.pasv() == 1, "set pasv mode");
isnt($ftp.ls(), (), "list file success");
$ftp.quit();
			
