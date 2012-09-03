#$Id: Makefile.PL,v 1.1 2002/10/23 20:45:54 dkernen Exp $
use ExtUtils::MakeMaker;
use Cwd;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'		=> 'Mail::IMAPClient::MessageSet',
    'VERSION_FROM' 	=> '../IMAPClient.pm', # finds $VERSION
);

#History:
#$Log: Makefile.PL,v $
#Revision 1.1  2002/10/23 20:45:54  dkernen
#
#Modified Files: Changes IMAPClient.pm MANIFEST Makefile.PL
#Added Files: Makefile.PL MessageSet.pm
#
#
