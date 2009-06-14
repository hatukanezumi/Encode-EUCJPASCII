print <<'EOF';
#
# eucJP-ascii.ucm
#
<code_set_name>  "eucJP-ascii"
<code_set_alias> "eucjp-ascii"
<code_set_alias> "x-eucjp-open-19970715-ascii"
<mb_cur_min> 1
<mb_cur_max> 3
<subchar> \xA2\xAE
<uconv_class> "MBCS"
#
CHARMAP
EOF

my $dir = $ARGV[0] || 'www.opengroup.or.jp/jvc/cde';
my %ucs = ();
my %rev = ();
my %ext = ();
foreach my $c ((0x00..0x1F, 0x7F, 0x80..0x8D, 0x90..0x9F)) {
    $ucs{sprintf "%04X", $c} = [sprintf "\\x%02X", $c];
    $rev{sprintf "\\x%02X", $c} = [sprintf "%04X", $c];
}
foreach my $map (qw(0201A 0208A 13th 0212A udc ibmext)) {
  open MAP, "$dir/eucJP-$map.txt" || die;
  while (<MAP>) {
    chomp $_;
    my ($euc, $ucs) = split /\s+/;
    $euc =~ s/^0x// || die "$_";
    $ucs =~ s/^0x// || die "$_";
    my @euc = grep { $_ } split /([0-9A-F]{2})/, $euc;
    $euc = "\\x".join("\\x", @euc);
    $ucs{$ucs} ||= [];
    push @{$ucs{$ucs}}, $euc;
    $rev{$euc} ||= [];
    push @{$rev{$euc}}, $ucs;
  }
}

foreach my $ext (qw(0208M 0212M)) {
  open EXT, "$dir/eucJP-$ext.txt" || die;
  while (<EXT>) {
    chomp $_;
    my ($euc, $ucs) = split /\s+/;
    $euc =~ s/^0x// || die "$_";
    $ucs =~ s/^0x// || die "$_";
    my @euc = grep { $_ } split /([0-9A-F]{2})/, $euc;
    $euc = "\\x".join("\\x", @euc);
    next if defined $ucs{$ucs};
    $ext{$ucs} = $euc;
    $ucs{$ucs} = undef;
  }
}

foreach my $u (sort keys %ucs) {
    unless (defined $ucs{$u}) {
	print "<U$u> $ext{$u} |1\n";
	next;
    }
    my @u = @{$ucs{$u}};
    if ($#u == 0) {
	print "<U$u> $u[0] |0\n";
    } else {
	print "<U$u> ".shift(@u)." |0\n";
	foreach my $c (@u) {
	    print "<U$u> $c |3\n";
	}
    }
}
# verify duplicated mapping.
my $dup = 0;
foreach my $e (sort keys %rev) {
    my @e = @{$rev{$e}};
    if ($#e != 0) {
	print STDERR "$e <U".join(">,<U", @e).">\n";
	$dup++;
    }
}
warn "$dup duplicated mapping" if $dup;

print <<'EOF';
END CHARMAP
EOF

