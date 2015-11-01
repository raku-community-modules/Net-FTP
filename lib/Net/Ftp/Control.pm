
use Net::Ftp::Buffer;
use Net::Ftp::Config;
use Net::Ftp::Conn;

unit class Net::Ftp::Control;

has $.debug;
has $!conn;
has @!lines;
has Buf $!buff;

method new (*%args is copy) {
    self.bless(|%args)!initialize(|%args);
}

method !initialize(*%args) {
    undefine(%args<debug>);
    $!conn = Net::Ftp::Conn.new(|%args);
    self;
}

method cmd_conn() {
    note '+connect' if $!debug;
    $!conn.connect();
}

method cmd_user(Str $user) {
    $!conn.sendcmd('USER', $user);
}

method cmd_pass(Str $pass) {
    $!conn.sendcmd('PASS', $pass);
}

method cmd_acct(Str $account) {
    $!conn.sendcmd('ACCT', $account);
}

method cmd_cwd(Str $path) {
    $!conn.sendcmd('CWD', $path);
}

method cmd_cdup() {
    $!conn.sendcmd('CDUP');
}

method cmd_smnt(Str $drive) {
    $!conn.sendcmd('SMNT', $drive);
}

method cmd_rein() {
    $!conn.sendcmd('REIN');
}

method cmd_quit() {
    $!conn.sendcmd('QUIT');
}

method cmd_pwd() {
    $!conn.sendcmd('PWD');
}

method cmd_port(Str $info) {
    $!conn.sendcmd('PORT', $info);
}

method cmd_pasv() {
    $!conn.sendcmd('PASV');
}

method cmd_type(Str $type) {
    $!conn.sendcmd('TYPE', $type);
}

method cmd_rest(Str $pos) {
    $!conn.sendcmd('REST', $pos);
}

method cmd_rest(Int $pos) {
    $!conn.sendcmd('REST', ~$pos);
}

multi method cmd_list(Str $path) {
    $!conn.sendcmd('LIST', $path);
}

multi method cmd_list() {
    $!conn.sendcmd('LIST');
}

method cmd_stor(Str $path) {
    $!conn.sendcmd('STOR', $path);
}

method cmd_close() {
    $!conn.close();
}

method get() {
    unless $!conn.can_recv() {
        fail("You need send a command!");
    }
    my ($code, $msg, $line);

    loop (;;) {
        if +@!lines {
            $line = @!lines.shift;

            if $line ~~ /^(\d ** 3)\s(.*)/ {
                ($code, $msg) = ($0, $1); last;
            } elsif $line ~~ /^$code\s(.*)/ {
                $msg = $msg ~ $0; last;
            } elsif $line ~~ /^(\d ** 3)\-(.*)/ {
                ($code, $msg) = ($0, $1);
            } elsif $line ~~ /\s+(.*)/ {
                $msg = $msg ~ $0;
            } else {
                ($code, $msg) = (-1, $line);
            }
        } else {
            $!buff = $!buff ??
                    merge($!buff, $!conn.recv(:bin)) !!
                    $!conn.recv(:bin);

            for split($!buff, Buf.new(0x0d, 0x0a)) {
                $line = $_.unpack("A*");
                note '+' ~ $line if $!debug;
                @!lines.push: $line;
            }

            $!conn.recv_over();
        }
    }

    return (~$code, ~$msg);
}

method dispatch($code) {
    unless $code ~~ Int || $code ~~ Str {
        return FTP::FAIL;
    }
    given $code {
        when -1 {
            return FTP::FAIL;
        }
        when 220 |
             230 | 332 | 331 | 202 |
             221 |
             250 | 200 |
             257 |
             227 |
             350 |
             150 | 125 | 226 {
            return FTP::OK;
        }
        # 120 is not a error
        # 421 service closing ftpc
        when 120 | 421 |
             530 | 500 | 501 | 503 | 421 |
             502 | 550 |
             504 |
             425 | 426 | 451 | 450 |
             551 | 552 | 553 | 532 | 452 {
            return FTP::FAIL;
        }
    }
}

# vim: ft=perl6
