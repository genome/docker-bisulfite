#!/usr/bin/perl

use warnings;
use strict;
use IO::File;
use List::MoreUtils qw(first_index);

my %prev;

my $mindepth=2;

#handle gzipped or not vcfs
my $file = $ARGV[0];
if ($file =~ /.gz$/) {
    open(INVCF, "gunzip -c $file |") || die "can’t open pipe to $file";
} else {
    open(INVCF, $file) || die "can’t open $file";
}

while(my $line = <INVCF>){
    next if $line =~ /^#/;
    chomp($line);
    my @F = split("\t",$line);
    next if $F[4] ne "."; #skip SNPs
    next unless $F[7] =~ /CX=CG/; #we only care about CpGs

    #get the CV and BT format field locations
    my @fmt = split(":",$F[8]);
    my $cv_ind = first_index { $_ eq 'CV' } @fmt;
    my $bt_ind = first_index { $_ eq 'BT' } @fmt;

    if ($bt_ind == -1 || $cv_ind == -1){
        print STDERR "WARNING: expected CV and/or BT format fields not found:\n";
        print STDERR $line . "\n";
        next;
    }
    my @vals = split(":",$F[9]);

    #cases
    if(!(defined($prev{"chr"}))){
        #prev is empty, this is a G (just print)
        if($F[3] eq "G"){
            print join("\t", ($F[0], $F[1]-1, $F[1], $vals[$cv_ind], $vals[$bt_ind])) . "\n"  if $vals[$cv_ind] >= $mindepth;
        } elsif($F[3] eq "C"){
            #prev is empty, this is a C (store)
            $prev{"chr"} = $F[0];
            $prev{"pos"} = $F[1];
            $prev{"base"} = $F[3];
            $prev{"CV"} = $vals[$cv_ind];
            $prev{"BT"} = $vals[$bt_ind];
        } else {
            #not a C or G - this should never happen
            die("ERROR: CpG context reported, but ref base isn't a C or G:\n$line\n");
        }
    } else {
        #prev has data, this is a C, print prev, store this
        if($F[3] eq "C"){
            print join("\t", ($prev{"chr"}, $prev{"pos"}-1, $prev{"pos"}, $prev{"CV"}, $prev{"BT"})) . "\n" if $prev{"CV"} >= $mindepth;
            $prev{"chr"} = $F[0];
            $prev{"pos"} = $F[1];
            $prev{"base"} = $F[3];
            $prev{"CV"} = $vals[$cv_ind];
            $prev{"BT"} = $vals[$bt_ind];

        } elsif($F[3] eq "G"){

            #prev has data, this is the adjacent G, (combine, print, blank prev)
            if($F[0] eq $prev{"chr"} && $F[1] == $prev{"pos"}+1){
                my $bt = sprintf("%.2f", (($prev{"CV"}*$prev{"BT"}) + ($vals[$cv_ind]*$vals[$bt_ind]))/($prev{"CV"}+$vals[$cv_ind]));
                print join("\t", ($prev{"chr"}, $prev{"pos"}-1, $prev{"pos"}, $prev{"CV"}+$vals[$cv_ind],$bt)) . "\n" if ($prev{"CV"}+$vals[$cv_ind]) >= $mindepth;
                undef %prev;
            } else {
                #prev has data, this is a non-adjacent G (print prev, print this, blank prev)
                print join("\t", ($prev{"chr"}, $prev{"pos"}-1, $prev{"pos"}, $prev{"CV"}, $prev{"BT"})) . "\n" if $prev{"CV"} >= $mindepth;
                print join("\t", ($F[0], $F[1]-1, $F[1], $vals[$cv_ind], $vals[$bt_ind])) . "\n" if $vals[$cv_ind] >= $mindepth;
                undef %prev;
            }
        } else {
            #not a C or G - this should never happen
            die("ERROR: CpG context reported, but ref base isn't a C or G:\n$line\n");
        }
    }
}

#close out by printing last contents of prev, if they exist
if(defined($prev{"chr"})){
    print join("\t", ($prev{"chr"}, $prev{"pos"}-1, $prev{"pos"}, $prev{"CV"}, $prev{"BT"})) . "\n" if $prev{"CV"} >= $mindepth;
}
close(INVCF);

# Example vcf line
# 0       chr2
# 1       252430
# 2       .
# 3       G
# 4       .
# 5       15
# 6       PASS
# 7       NS=1;CX=CHH;N5=CCCTA
# 8       GT:GL1:GQ:DP:SP:CV:BT
# 9       0/0:-1,-5,-25:15:5:G3R2:2:0.00
