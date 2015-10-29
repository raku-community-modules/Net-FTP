
unit module Net::Ftp::Buffer;

sub split (Buf $buf is rw, Buf $sep, :$empty = False) {
    my @lines;
    my ($l, $r, $len) = (0, 0, +$buf - +$sep);

    loop (;$r < $len;$r++) {
        for 0 .. ^+$sep {
            if $buf[$r + $_] != $sep[$_] {
                next;
            }
        }
        if ($r - $l) || $empty {
            @lines.push: $buf.subbuf($l, $r - $l);
            $r += +$sep;
            $l = $r;
        }
    }

    if ($r - $l) {
        $buf = $buf.subbuf($l, * - $l);
    }

    return @lines;
}

sub merge (Buf $lb, Buf $rb) {
    my $ret = Buf.new($lb);

    my $len = $lb.elems;

    for 0 .. $rb.elems {
        $ret[$len + $_] = $rb[$_];
    }

    return $ret;
}


