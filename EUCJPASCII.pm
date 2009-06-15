package Encode::EUCJPASCII;
use strict;
use warnings;
our $VERSION = "0.02";
 
use Encode qw(:fallbacks);
use XSLoader;
XSLoader::load(__PACKAGE__,$VERSION);

Encode::define_alias(qr/\beuc-?jp(-?open)?(-?19970715)?-?ascii$/i
		     => '"eucJP-ascii"');
Encode::define_alias(qr/\b(x-)?iso-?2022-?jp-?ascii$/i
		     => '"x-iso2022jp-ascii"');

my $name = 'x-iso2022jp-ascii';
$Encode::Encoding{$name} = bless { Name => $name } => __PACKAGE__;

use base qw(Encode::Encoding);

# we override this to 1 so PerlIO works
sub needs_lines { 1 }

use Encode::CJKConstants qw(:all);
use Encode::JP::JIS7;

sub decode($$;$) {
    my ( $obj, $str, $chk ) = @_;
    my $residue = '';
    if ($chk) {
        $str =~ s/([^\x00-\x7f].*)$//so and $residue = $1;
    }
    $str =~ s{\e\(J ([^\e]*) (?:\e\(B)?}{
	my $s = $1;
	$s =~ s{([\x5C\x7E]+)}{
	    my $c = $1;
	    $c =~ s/\x5C/\x21\x6F/g;
	    $c =~ s/\x7E/\x21\x31/g;
	    "\e\$B".$c."\e(B";
	}eg;
	($s =~ /^\e/? "\e(B": '').$s;
    }egsx;
    $residue .= Encode::JP::JIS7::jis_euc( \$str );
    $_[1] = $residue if $chk;
    return Encode::decode( 'eucJP-ascii', $str, $chk );
}

sub encode($$;$) {
    my ( $obj, $utf8, $chk ) = @_;

    # empty the input string in the stack so perlio is ok
    $_[1] = '' if $chk;
    my $octet = Encode::encode( 'eucJP-ascii', $utf8, $chk );
    Encode::JP::JIS7::euc_jis( \$octet, 1 );
    return $octet;
}

#
# cat_decode
#
my $re_scan_jis_g = qr{
    \G ( ($RE{JIS_0212}) |  $RE{JIS_0208}  |
	 (\e\(J) |
	 ($RE{ISO_ASC})  | ($RE{JIS_KANA}) | )
      ([^\e]*)
  }x;

sub cat_decode {    # ($obj, $dst, $src, $pos, $trm, $chk)
    my ( $obj, undef, undef, $pos, $trm ) = @_;    # currently ignores $chk
    my ( $rdst, $rsrc, $rpos ) = \@_[ 1, 2, 3 ];
    local ${^ENCODING};
    use bytes;
    my $opos = pos($$rsrc);
    pos($$rsrc) = $pos;
    while ( $$rsrc =~ /$re_scan_jis_g/gc ) {
        my ( $esc, $esc_0212, $esc_0201, $esc_asc, $esc_kana, $chunk ) =
	    ( $1, $2, $3, $4, $5, $6 );

        unless ($chunk) { $esc or last; next; }
	
        if ( $esc && !$esc_asc && !$esc_0201 ) {
            $chunk =~ tr/\x21-\x7e/\xa1-\xfe/;
            if ($esc_kana) {
                $chunk =~ s/([\xa1-\xdf])/\x8e$1/og;
            }
            elsif ($esc_0212) {
                $chunk =~ s/([\xa1-\xfe][\xa1-\xfe])/\x8f$1/og;
            }
            $chunk = Encode::decode( 'eucJP-ascii', $chunk, 0 );
        }
	elsif ( $esc_0201 ) {
	    $chunk =~ s/\x5C/\xA1\xEF/og;
	    $chunk =~ s/\x7E/\xA1\xB1/og;
            $chunk = Encode::decode( 'eucJP-ascii', $chunk, 0 );
	}
        elsif ( ( my $npos = index( $chunk, $trm ) ) >= 0 ) {
            $$rdst .= substr( $chunk, 0, $npos + length($trm) );
            $$rpos += length($esc) + $npos + length($trm);
            pos($$rsrc) = $opos;
            return 1;
        }
        $$rdst .= $chunk;
        $$rpos = pos($$rsrc);
    }
$$rpos = pos($$rsrc);
pos($$rsrc) = $opos;
return '';
}

1;
__END__

=head1 NAME
 
Encode::EUCJPASCII - eucJP-ascii - An eucJP-open mapping
 
=head1 SYNOPSIS

    use Encode::EUCJPASCII;
    use Encode qw/encode decode/;
    $eucjp = encode("eucJP-ascii", $utf8);
    $utf8 = decode("eucJP-ascii", $eucjp);

=head1 DESCRIPTION

This module provides eucJP-ascii, one of eucJP-open mappings,
and its derivative.
Following encodings are supported.

  Canonical    Alias                           Description
  --------------------------------------------------------------
  eucJP-ascii                                  eucJP-ascii
               qr/\beuc-?jp(-?open)?(-?19970715)?-?ascii$/i
  x-iso2022jp-ascii                            7-bit counterpart
               qr/\b(x-)?iso-?2022-?jp-?ascii$/i
  --------------------------------------------------------------

B<Note>: C<x-iso2022jp-ascii> is unofficial encoding name:
It had never been registered by any standards bodies.

=head1 SEE ALSO

L<Encode>, L<Encode::JP>, L<Encode::EUCJPMS>

TOG/JVC CDE/Motif Technical WG (Oct. 1996).
I<Problems and Solutions for Unicode and User/Vendor Defined Characters>.
Revision at Jul. 15 1997.

=head1 AUTHOR

Hatuka*nezumi - IKEDA Soji <hatuka(at)nezumi.nu>

=head1 COPYRIGHT

Copyright (C) 2009 Hatuka*nezumi - IKEDA Soji.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
