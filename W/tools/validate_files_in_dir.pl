#!/usr/bin/perl

use strict;
use warnings;
use WebService::Validator::HTML::W3C;

=head1 DESCRIPTION

This script takes a directory as an argument and then submits every file
in that directory to the W3C validator. It will print out a line for each
file stating if it is valid or otherwise. For the invalid files it will
also print out the errors returned by the validator.

=cut

my $v = WebService::Validator::HTML::W3C->new(
    # you should probably install a local validator if you 
    # are indenting to run this against a lot of files and
    # then uncomment this line and change the uri
    # validator_uri =>  'http://localhost/w3c-validator/check',
    detailed        =>  1
) or die "failed to init validator object";

my $dir = shift;

for my $file ( glob( "$dir/*.html" ) ) {
    if ( $v->validate_file( $file ) ) {
        if ( $v->is_valid ) {
            print "$file: valid\n";
        } else {
            print "$file: invalid\n";
            for my $err ( @{ $v->errors } ) {
                printf("  line: %s, col: %s\n  error: %s\n\n", 
                    $err->line, $err->col, $err->msg);
            }
        }
    } else {
        die "failed to validate $file: " . $v->validator_error . "\n";
    }
    print "\n" . '-' x 60 . "\n";
    # sleep between files so as not to hammer the validator
    sleep 1;
}
