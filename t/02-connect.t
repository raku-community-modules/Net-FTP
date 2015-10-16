
use v6;
use Test;

use Net::Ftp;

plan 1;

my $host = '221.224.163.61';
my $ftp = Net::Ftp.new(:host($host));

ok($ftp.login() == 1, "ftp login success");
