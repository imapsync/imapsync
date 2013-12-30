create_folder {
	my( $imap2, $h2_fold, $h1_fold ) = @_ ;
        my(@parts, $parent);

	print "Creating folder [$h2_fold] on host2\n";
        if ( ( 'INBOX' eq uc( $h2_fold) )
         and ( $imap2->exists( $h2_fold ) ) ) {
                print "Folder [$h2_fold] already exists\n" ;
                return( 1 ) ;
        }

        @parts = split($h2_sep, $h2_fold );
        pop( @parts );
        $parent = join($h2_sep, @parts );
        $parent =~ s/^\s+|\s+$//g ;
        if(($parent ne "") and !$imap2->exists( $parent )) {
        	create_folder( $imap2 , $parent , $h1_fold);
        }

	if ( ! $dry ){
		if ( ! $imap2->create( $h2_fold ) ) {
			print( "Couldn't create folder [$h2_fold] from [$h1_fold]: ",
			$imap2->LastError(  ), "\n" );
			$nb_errors++;
                        # success if folder exists ("already exists" error)
                        return( 1 ) if $imap2->exists( $h2_fold ) ;
                        # failure since create failed
			return( 0 );
		}else{
			#create succeeded
			return( 1 );
		}
	}else{
		# dry mode, no folder so many imap will fail, assuming failure
		return( 0 );
	}
}

