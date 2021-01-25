# Imapsync sponsoring

You are a great imapsync user or perhaps a future one! I thank you for that, very much.
The paradox to get imapsync stay free and gratis for anyone is that the imapsync author needs to be paid for maintening and improving it.

In case you're using imapsync in a professional context,
then consider buying imapsync and support at https://imapsync.lamiral.info/#buy_all,
you will get also a regular invoice for your company.

If it's too much, then consider a smaller donation:

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=TUENPW59U9LL2) or on regular monthly donation via the new github sponsoring campaign https://github.com/sponsors/gilleslamiral

**Thanks in any case, even no money, I'm ok with that!**

# README
````
NAME

    imapsync - Email IMAP tool for syncing, copying, migrating and archiving
    email mailboxes between two imap servers, one way, and without
    duplicates.

VERSION

    This documentation refers to Imapsync $Revision: 1.977 $

USAGE

     To synchronize the source imap account
       "test1" on server "test1.lamiral.info" with password "secret1"
     to the destination imap account
       "test2" on server "test2.lamiral.info" with password "secret2"
     do:

      imapsync \
       --host1 test1.lamiral.info --user1 test1 --password1 secret1 \
       --host2 test2.lamiral.info --user2 test2 --password2 secret2

DESCRIPTION

    We sometimes need to transfer mailboxes from one imap server to one
    another.

    Imapsync command is a tool allowing incremental and recursive imap
    transfers from one mailbox to another. If you don't understand the
    previous sentence, it's normal, it's pedantic computer oriented jargon.

    All folders are transferred, recursively, meaning the whole folder
    hierarchy is taken, all messages in them, and all messages flags (\Seen
    \Answered \Flagged etc.) are synced too.

    Imapsync reduces the amount of data transferred by not transferring a
    given message if it already resides on the destination side. Messages
    that are on the destination side but not on the source side stay as they
    are (see the --delete2 option to have a strict sync).

    How imapsync knows a message is already on both sides? Same specific
    headers and the transfer is done only once. By default, the
    identification headers are "Message-Id:" and "Received:" lines but this
    choice can be changed with the --useheader option.

    All flags are preserved, unread messages will stay unread, read ones
    will stay read, deleted will stay deleted.

    You can abort the transfer at any time and restart it later, imapsync
    works well with bad connections and interruptions, by design. On a
    terminal hit Ctr-c twice within two seconds in order to abort the
    program. Hit Ctr-c just once makes imapsync reconnect to both imap
    servers.

    A classical scenario is synchronizing a mailbox B from another mailbox A
    where you just want to keep a strict copy of A in B. Strict meaning all
    messages in A will be in B but no more.

    For this, option --delete2 has to be used, it deletes messages in host2
    folder B that are not in host1 folder A. If you also need to destroy
    host2 folders that are not in host1 then use --delete2folders. See also
    --delete2foldersonly and --delete2foldersbutnot to set up exceptions on
    folders to destroy. INBOX will never be destroy, it's a mandatory folder
    in IMAP.

    A different scenario is to delete the messages from the source mailbox
    after a successful transfer, it can be a good feature when migrating
    mailboxes since messages will be only on one side. The source account
    will only have messages that are not on the destination yet, ie,
    messages that arrived after a sync or that failed to be copied.

    In that case, use the --delete1 option. Option --delete1 implies also
    option --expunge1 so all messages marked deleted on host1 will be really
    deleted. In IMAP protocol deleting a message does not really delete it,
    it marks it with the flag \Deleted, allowing an undelete. Expunging a
    folder removes, definitively, all the messages marked as \Deleted in
    this folder.

    You can also decide to remove empty folders once all of their messages
    have been transferred. Add --delete1emptyfolders to obtain this
    behavior.

    Imapsync is not adequate for maintaining two active imap accounts in
    synchronization when the user plays independently on both sides. Use
    offlineimap (written by John Goerzen) or mbsync (written by Michael R.
    Elkins) for a 2 ways synchronization.

OPTIONS

     usage: imapsync [options]

    The standard options are the six values forming the credentials. Three
    values on each side are needed in order to log in into the IMAP servers.
    These six values are a host, a username, and a password, two times.

    Conventions used in the following descriptions of the options:

     str means string
     int means integer
     reg means regular expression
     cmd means command

     --dry               : Makes imapsync doing nothing for real, just print what
                           would be done without --dry.

  OPTIONS/credentials

     --host1        str  : Source or "from" imap server.
     --port1        int  : Port to connect on host1.
                           Optional since default ports are the
                           well known ports imap/143 or imaps/993.
     --user1        str  : User to login on host1.
     --password1    str  : Password for the user1.

     --host2        str  : "destination" imap server.
     --port2        int  : Port to connect on host2. Optional
     --user2        str  : User to login on host2.
     --password2    str  : Password for the user2.

     --showpasswords     : Shows passwords on output instead of "MASKED".
                           Useful to restart a complete run by just reading
                           the command line used in the log,
                           or to debug passwords.
                           It's not a secure practice at all.

     --passfile1    str  : Password file for the user1. It must contain the
                           password on the first line. This option avoids showing
                           the password on the command line like --password1 does.
     --passfile2    str  : Password file for the user2.

    You can also pass the passwords in the environment variables
    IMAPSYNC_PASSWORD1 and IMAPSYNC_PASSWORD2

  OPTIONS/encryption

     --nossl1            : Do not use a SSL connection on host1.
     --ssl1              : Use a SSL connection on host1. On by default if possible.

     --nossl2            : Do not use a SSL connection on host2.
     --ssl2              : Use a SSL connection on host2. On by default if possible.

     --notls1            : Do not use a TLS connection on host1.
     --tls1              : Use a TLS connection on host1. On by default if possible.

     --notls2            : Do not use a TLS connection on host2.
     --tls2              : Use a TLS connection on host2. On by default if possible.

     --debugssl     int  : SSL debug mode from 0 to 4.

     --sslargs1     str  : Pass any ssl parameter for host1 ssl or tls connection. Example:
                           --sslargs1 SSL_verify_mode=1 --sslargs1 SSL_version=SSLv3
                           See all possibilities in the new() method of IO::Socket::SSL
                           http://search.cpan.org/perldoc?IO::Socket::SSL#Description_Of_Methods
     --sslargs2     str  : Pass any ssl parameter for host2 ssl or tls connection.
                           See --sslargs1

     --timeout1     int  : Connection timeout in seconds for host1.
                           Default is 120 and 0 means no timeout at all.
     --timeout2     int  : Connection timeout in seconds for host2.
                           Default is 120 and 0 means no timeout at all.

  OPTIONS/authentication

     --authmech1    str  : Auth mechanism to use with host1:
                           PLAIN, LOGIN, CRAM-MD5 etc. Use UPPERCASE.
     --authmech2    str  : Auth mechanism to use with host2. See --authmech1

     --authuser1    str  : User to auth with on host1 (admin user).
                           Avoid using --authmech1 SOMETHING with --authuser1.
     --authuser2    str  : User to auth with on host2 (admin user).
     --proxyauth1        : Use proxyauth on host1. Requires --authuser1.
                           Required by Sun/iPlanet/Netscape IMAP servers to
                           be able to use an administrative user.
     --proxyauth2        : Use proxyauth on host2. Requires --authuser2.

     --authmd51          : Use MD5 authentication for host1.
     --authmd52          : Use MD5 authentication for host2.
     --domain1      str  : Domain on host1 (NTLM authentication).
     --domain2      str  : Domain on host2 (NTLM authentication).

  OPTIONS/folders

     --folder       str  : Sync this folder.
     --folder       str  : and this one, etc.
     --folderrec    str  : Sync this folder recursively.
     --folderrec    str  : and this one, etc.

     --folderfirst  str  : Sync this folder first. Ex. --folderfirst "INBOX"
     --folderfirst  str  : then this one, etc.
     --folderlast   str  : Sync this folder last. --folderlast "[Gmail]/All Mail"
     --folderlast   str  : then this one, etc.

     --nomixfolders      : Do not merge folders when host1 is case-sensitive
                           while host2 is not (like Exchange). Only the first
                           similar folder is synced (example: with folders
                           "Sent", "SENT" and "sent"
                           on host1 only "Sent" will be synced to host2).

     --skipemptyfolders  : Empty host1 folders are not created on host2.

     --include      reg  : Sync folders matching this regular expression
     --include      reg  : or this one, etc.
                           If both --include --exclude options are used, then
                           include is done before.
     --exclude      reg  : Skips folders matching this regular expression
                           Several folders to avoid:
                            --exclude 'fold1|fold2|f3' skips fold1, fold2 and f3.
     --exclude      reg  : or this one, etc.

     --automap           : guesses folders mapping, for folders well known as
                           "Sent", "Junk", "Drafts", "All", "Archive", "Flagged".

     --f1f2    str1=str2 : Force folder str1 to be synced to str2,
                           --f1f2 overrides --automap and --regextrans2.

     --subfolder2   str  : Syncs the whole host1 folders hierarchy under the
                           host2 folder named str.
                           It does it internally by adding three
                           --regextrans2 options before all others.
                           Add --debug to see what's really going on.

     --subfolder1   str  : Syncs the host1 folders hierarchy which is under folder
                           str to the root hierarchy of host2.
                           It's the couterpart of a sync done by --subfolder2
                           when doing it in the reverse order.
                           Backup/Restore scenario:
                           Use --subfolder2 str for a backup to the folder str
                           on host2. Then use --subfolder1 str for restoring
                           from the folder str, after inverting
                           host1/host2 user1/user2 values.


     --subscribed        : Transfers subscribed folders.
     --subscribe         : Subscribe to the folders transferred on the
                           host2 that are subscribed on host1. On by default.
     --subscribeall      : Subscribe to the folders transferred on the
                           host2 even if they are not subscribed on host1.

     --prefix1      str  : Remove prefix str to all destination folders,
                           usually "INBOX." or "INBOX/" or an empty string "".
                           imapsync guesses the prefix if host1 imap server
                           does not have NAMESPACE capability. So this option
                           should not be used most of the time.
     --prefix2      str  : Add prefix to all host2 folders. See --prefix1

     --sep1         str  : Host1 separator. This option should not be used
                           most of the time.
                           Imapsync gets the separator from the server itself,
                           by using NAMESPACE, or it tries to guess it
                           from the folders listing (it counts
                           characters / . \\ \ in folder names and choose the
                           more frequent, or finally / if nothing is found.
     --sep2         str  : Host2 separator. See --sep1

     --regextrans2  reg  : Apply the whole regex to each destination folders.
     --regextrans2  reg  : and this one. etc.
                           When you play with the --regextrans2 option, first
                           add also the safe options --dry --justfolders
                           Then, when happy, remove --dry for a run, then 
                           remove --justfolders for the next ones.
                           Have in mind that --regextrans2 is applied after
                           the automatic prefix and separator inversion.
                           For examples see:
                           https://imapsync.lamiral.info/FAQ.d/FAQ.Folders_Mapping.txt

  OPTIONS/folders sizes

     --nofoldersizes     : Do not calculate the size of each folder at the
                           beginning of the sync. Default is to calculate them.
     --nofoldersizesatend: Do not calculate the size of each folder at the
                           end of the sync. Default is to calculate them.
     --justfoldersizes   : Exit after having printed the initial folder sizes.

  OPTIONS/tmp

     --tmpdir       str  : Where to store temporary files and subdirectories.
                           Will be created if it doesn't exist.
                           Default is system specific, Unix is /tmp but
                           /tmp is often too small and deleted at reboot.
                           --tmpdir /var/tmp should be better.
     --pidfile      str  : The file where imapsync pid is written,
                           it can be dirname/filename.
                           Default name is imapsync.pid in tmpdir.
     --pidfilelocking    : Abort if pidfile already exists. Useful to avoid
                           concurrent transfers on the same mailbox.

  OPTIONS/log

     --nolog             : Turn off logging on file
     --logfile      str  : Change the default log filename (can be dirname/filename).
     --logdir       str  : Change the default log directory. Default is LOG_imapsync/

    The default logfile name is for example

     LOG_imapsync/2019_12_22_23_57_59_532_user1_user2.txt

    where:

     2019_12_22_23_57_59_532 is nearly the date of the start
     YYYY_MM_DD_HH_MM_SS_mmm 
     year_month_day_hour_minute_seconde_millisecond

    and user1 user2 are the --user1 --user2 values.

  OPTIONS/messages

     --skipmess     reg  : Skips messages matching the regex.
                           Example: 'm/[\x80-ff]/' # to avoid 8bits messages.
                           --skipmess is applied before --regexmess
     --skipmess     reg  : or this one, etc.

     --skipcrossduplicates : Avoid copying messages that are already copied
                             in another folder,  good from Gmail to X when
                             X is not also Gmail.
                             Activated with --gmail1 unless --noskipcrossduplicates

   --skipallmailduplicates : Used when host1 is GMail.  Skips messages in 
                             [Gmail]/All Mail that are also in some other folder.

     --debugcrossduplicates : Prints which messages (UIDs) are skipped with
                              --skipcrossduplicates (and in what other folders
                              they are).  Also prints messages skipped by
                              --skipallmailduplicates.

     --pipemess     cmd  : Apply this cmd command to each message content
                           before the copy.
     --pipemess     cmd  : and this one, etc.
                           With several --pipemess, the output of each cmd
                           command (STDOUT) is given to the input (STDIN)
                           of the next command.
                           For example,
                           --pipemess cmd1 --pipemess cmd2 --pipemess cmd3
                           is like a Unix pipe:
                           "cat message | cmd1 | cmd2 | cmd3"

     --disarmreadreceipts : Disarms read receipts (host2 Exchange issue)

     --regexmess    reg  : Apply the whole regex to each message before transfer.
                           Example: 's/\000/ /g' # to replace null by space.
     --regexmess    reg  : and this one, etc.

  OPTIONS/labels

    Gmail present labels as folders in imap. Imapsync can accelerate the
    sync by syncing X-GM-LABELS, it will avoid to transfer messages when
    they are already on host2.

     --synclabels        : Syncs also Gmail labels when a message is copied to host2.
                           Activated by default with --gmail1 --gmail2 unless
                           --nosynclabels is added.
                       
     --resynclabels      : Resyncs Gmail labels when a message is already on host2.
                           Activated by default with --gmail1 --gmail2 unless
                           --noresynclabels is added.

    For Gmail syncs, see also:
    https://imapsync.lamiral.info/FAQ.d/FAQ.Gmail.txt

  OPTIONS/flags

     If you encounter flag problems see also:
     https://imapsync.lamiral.info/FAQ.d/FAQ.Flags.txt

     --regexflag    reg  : Apply the whole regex to each flags list.
                           Example: 's/"Junk"//g' # to remove "Junk" flag.
     --regexflag    reg  : then this one, etc.

     --resyncflags       : Resync flags for already transferred messages.
                           On by default.
     --noresyncflags     : Do not resync flags for already transferred messages.
                           May be useful when a user has already started to play
                           with its host2 account.

  OPTIONS/deletions

     --delete1           : Deletes messages on host1 server after a successful
                           transfer. Option --delete1 has the following behavior:
                           it marks messages as deleted with the IMAP flag
                           \Deleted, then messages are really deleted with an
                           EXPUNGE IMAP command. If expunging after each message
                           slows down too much the sync then use
                           --noexpungeaftereach to speed up, expunging will then be
                           done only twice per folder, one at the beginning and
                           one at the end of a folder sync.

     --expunge1          : Expunge messages on host1 just before syncing a folder.
                           Expunge is done per folder.
                           Expunge aims is to really delete messages marked deleted.
                           An expunge is also done after each message copied
                           if option --delete1 is set (unless --noexpungeaftereach).

     --noexpunge1        : Do not expunge messages on host1.

     --delete1emptyfolders : Deletes empty folders on host1, INBOX excepted.
                             Useful with --delete1 since what remains on host1
                             is only what failed to be synced.

     --delete2           : Delete messages in host2 that are not in
                           host1 server. Useful for backup or pre-sync.
                           --delete2 implies --uidexpunge2

     --delete2duplicates : Delete messages in host2 that are duplicates.
                           Works only without --useuid since duplicates are
                           detected with an header part of each message.

     --delete2folders    : Delete folders in host2 that are not in host1 server.
                           For safety, first try it like this (it is safe):
                           --delete2folders --dry --justfolders --nofoldersizes
                           and see what folders will be deleted.

     --delete2foldersonly   reg : Delete only folders matching the regex reg.
                                  Example: --delete2foldersonly "/^Junk$|^INBOX.Junk$/"
                                  This option activates --delete2folders

     --delete2foldersbutnot reg : Do not delete folders matching the regex rex.
                                  Example: --delete2foldersbutnot "/Tasks$|Contacts$|Foo$/"
                                  This option activates --delete2folders

     --noexpunge2        : Do not expunge messages on host2.
     --nouidexpunge2     : Do not uidexpunge messages on the host2 account
                           that are not on the host1 account.

  OPTIONS/dates

     If you encounter problems with dates, see also:
     https://imapsync.lamiral.info/FAQ.d/FAQ.Dates.txt

     --syncinternaldates : Sets the internal dates on host2 same as host1.
                           Turned on by default. Internal date is the date
                           a message arrived on a host (Unix mtime).
     --idatefromheader   : Sets the internal dates on host2 same as the
                           ones in "Date:" headers.

  OPTIONS/message selection

     --maxsize      int  : Skip messages larger  (or equal) than  int  bytes
     --minsize      int  : Skip messages smaller (or equal) than  int  bytes
     --maxage       int  : Skip messages older than  int days.
                           final stats (skipped) don't count older messages
                           see also --minage
     --minage       int  : Skip messages newer than  int  days.
                           final stats (skipped) don't count newer messages
                           You can do (+ zone are the messages selected):
                           past|----maxage+++++++++++++++>now
                           past|+++++++++++++++minage---->now
                           past|----maxage+++++minage---->now (intersection)
                           past|++++minage-----maxage++++>now (union)

     --search       str  : Selects only messages returned by this IMAP SEARCH
                           command. Applied on both sides.
                           For a complete set of what can be search see
                           https://imapsync.lamiral.info/FAQ.d/FAQ.Messages_Selection.txt

     --search1      str  : Same as --search but for selecting host1 messages only.
     --search2      str  : Same as --search but for selecting host2 messages only.
                           So --search CRIT equals --search1 CRIT --search2 CRIT

     --maxlinelength int : skip messages with a line length longer than  int  bytes.
                           RFC 2822 says it must be no more than 1000 bytes but
                           real life servers and email clients do more.


     --useheader    str  : Use this header to compare messages on both sides.
                           Ex: Message-ID or Subject or Date.
     --useheader    str    and this one, etc.

     --usecache          : Use cache to speed up next syncs. Not set by default.
     --nousecache        : Do not use cache. Caveat: --useuid --nousecache creates
                           duplicates on multiple runs.
     --useuid            : Use UIDs instead of headers as a criterion to recognize
                           messages. Option --usecache is then implied unless
                           --nousecache is used.

  OPTIONS/miscellaneous

     --syncacls          : Synchronizes acls (Access Control Lists).
                           Acls in IMAP are not standardized, be careful
                           since one acl code on one side may signify something
                           else on the other one.
     --nosyncacls        : Does not synchronize acls. This is the default.

     --addheader         : When a message has no headers to be identified,
                           --addheader adds a "Message-Id" header,
                           like "Message-Id: 12345@imapsync", where 12345
                           is the imap UID of the message on the host1 folder.

  OPTIONS/debugging

     --debug             : Debug mode.
     --debugfolders      : Debug mode for the folders part only.
     --debugcontent      : Debug content of the messages transferred. Huge output.
     --debugflags        : Debug mode for flags.
     --debugimap1        : IMAP debug mode for host1. Very verbose.
     --debugimap2        : IMAP debug mode for host2. Very verbose.
     --debugimap         : IMAP debug mode for host1 and host2. Twice very verbose.
     --debugmemory       : Debug mode showing memory consumption after each copy.

     --errorsmax     int : Exit when int number of errors is reached. Default is 50.

     --tests             : Run local non-regression tests. Exit code 0 means all ok.
     --testslive         : Run a live test with test1.lamiral.info imap server.
                           Useful to check the basics. Needs internet connection.
     --testslive6        : Run a live test with ks2ipv6.lamiral.info imap server.
                           Useful to check the ipv6 connectivity. Needs internet.

  OPTIONS/specific

      --gmail1           : sets --host1 to Gmail and other options. See FAQ.Gmail.txt
      --gmail2           : sets --host2 to Gmail and other options. See FAQ.Gmail.txt

      --office1          : sets --host1 to Office365 and other options. See FAQ.Exchange.txt
      --office2          : sets --host2 to Office365 and other options. See FAQ.Exchange.txt

      --exchange1        : sets options for Exchange. See FAQ.Exchange.txt
      --exchange2        : sets options for Exchange. See FAQ.Exchange.txt

      --domino1          : sets options for Domino. See FAQ.Domino.txt
      --domino2          : sets options for Domino. See FAQ.Domino.txt

  OPTIONS/behavior

     --maxmessagespersecond int : limits the number of messages transferred per second.

     --maxbytespersecond int : limits the average transfer rate per second.
     --maxbytesafter     int : starts --maxbytespersecond limitation only after
                               --maxbytesafter amount of data transferred.

     --maxsleep      int : do not sleep more than int seconds.
                           On by default, 2 seconds max, like --maxsleep 2

     --abort             : terminates a previous call still running.
                           It uses the pidfile to know what process to abort.

     --exitwhenover int  : Stop syncing and exits when int total bytes
                           transferred is reached.

     --version           : Print only software version.
     --noreleasecheck    : Do not check for any new imapsync release.
     --releasecheck      : Check for new imapsync release.
                           it's an http request to
                           http://imapsync.lamiral.info/prj/imapsync/VERSION

     --noid              : Do not send/receive ID command to imap servers.

     --justconnect       : Just connect to both servers and print useful
                           information. Need only --host1 and --host2 options.
                           Obsolete since "imapsync --host1 imaphost" alone
                           implies --justconnect

     --justlogin         : Just login to both host1 and host2 with users
                           credentials, then exit.

     --justfolders       : Do only things about folders (ignore messages).

     --help              : print this help.

     Example: to synchronize imap account "test1" on "test1.lamiral.info"
                         to  imap account "test2" on "test2.lamiral.info"
                         with test1 password "secret1"
                         and  test2 password "secret2"

     imapsync \
        --host1 test1.lamiral.info --user1 test1 --password1 secret1 \
        --host2 test2.lamiral.info --user2 test2 --password2 secret2

SECURITY

    You can use --passfile1 instead of --password1 to give the password
    since it is safer. With --password1 option, on Linux, any user on your
    host can see the password by using the 'ps auxwwww' command. Using a
    variable (like IMAPSYNC_PASSWORD1) is also dangerous because of the 'ps
    auxwwwwe' command. So, saving the password in a well protected file (600
    or rw-------) is the best solution.

    Imapsync activates ssl or tls encryption by default, if possible.

    What detailed behavior is under this "if possible"?

    Imapsync activates ssl if the well known port imaps port (993) is open
    on the imap servers. If the imaps port is closed then it open a normal
    (clear) connection on port 143 but it looks for TLS support in the
    CAPABILITY list of the servers. If TLS is supported then imapsync goes
    to encryption.

    If the automatic ssl and the tls detections fail then imapsync will not
    protect against sniffing activities on the network, especially for
    passwords.

    If you want to force ssl or tls just use --ssl1 --ssl2 or --tls1 --tls2

    See also the document FAQ.Security.txt in the FAQ.d/ directory or at
    https://imapsync.lamiral.info/FAQ.d/FAQ.Security.txt

EXIT STATUS

    Imapsync will exit with a 0 status (return code) if everything went
    good. Otherwise, it exits with a non-zero status. That's classical Unix
    behavior. Here is the list of the exit code values (an integer between 0
    and 255). The names reflect their meaning:

         EX_OK          => 0  ; #/* successful termination */
         EX_USAGE       => 64 ; #/* command line usage error */
         EX_NOINPUT     => 66 ; #/* cannot open input */
         EX_UNAVAILABLE => 69 ; #/* service unavailable */
         EX_SOFTWARE    => 70 ; #/* internal software error */
         EXIT_CATCH_ALL              =>   1 ; # Any other error
         EXIT_BY_SIGNAL              =>   6 ; # Should be 128+n where n is the sig_num
         EXIT_PID_FILE_ERROR         =>   8 ;
         EXIT_CONNECTION_FAILURE     =>  10 ;
         EXIT_TLS_FAILURE            =>  12 ;
         EXIT_AUTHENTICATION_FAILURE =>  16 ;
         EXIT_SUBFOLDER1_NO_EXISTS   =>  21 ;
         EXIT_WITH_ERRORS            => 111 ;
         EXIT_WITH_ERRORS_MAX        => 112 ;
         EXIT_TESTS_FAILED           => 254 ; # Like Test::More API

LICENSE AND COPYRIGHT

    Imapsync is free, open, public but not always gratis software cover by
    the NOLIMIT Public License, now called NLPL. See the LICENSE file
    included in the distribution or just read this simple sentence as it IS
    the licence text:

     "No limits to do anything with this work and this license."

    In case it is not long enough, I repeat:

     "No limits to do anything with this work and this license."

    Look at https://imapsync.lamiral.info/LICENSE

AUTHOR

    Gilles LAMIRAL <gilles@lamiral.info>

    Good feedback is always welcome. Bad feedback is very often welcome.

    Gilles LAMIRAL earns his living by writing, installing, configuring and
    teaching free, open and often gratis software. Imapsync used to be
    "always gratis" but now it is only "often gratis" because imapsync is
    sold by its author, a good way to maintain and support free open public
    software over decades.

BUGS AND LIMITATIONS

    See https://imapsync.lamiral.info/FAQ.d/FAQ.Reporting_Bugs.txt

IMAP SERVERS supported

    See https://imapsync.lamiral.info/S/imapservers.shtml

HUGE MIGRATION

    If you have many mailboxes to migrate think about a little shell
    program. Write a file called file.txt (for example) containing users and
    passwords. The separator used in this example is ';'

    The file.txt file contains:

    user001_1;password001_1;user001_2;password001_2
    user002_1;password002_1;user002_2;password002_2
    user003_1;password003_1;user003_2;password003_2
    user004_1;password004_1;user004_2;password004_2
    user005_1;password005_1;user005_2;password005_2 ...

    On Unix the shell program can be:

     { while IFS=';' read  u1 p1 u2 p2; do
            imapsync --host1 imap.side1.org --user1 "$u1" --password1 "$p1" \
                     --host2 imap.side2.org --user2 "$u2" --password2 "$p2" ...
     done ; } < file.txt

    On Windows the batch program can be:

      FOR /F "tokens=1,2,3,4 delims=; eol=#" %%G IN (file.txt) DO imapsync ^
      --host1 imap.side1.org --user1 %%G --password1 %%H ^
      --host2 imap.side2.org --user2 %%I --password2 %%J ...

    The ... have to be replaced by nothing or any imapsync option. Welcome
    in shell or batch programming !

    You will find already written scripts at
    https://imapsync.lamiral.info/examples/

INSTALL

     Imapsync works under any Unix with Perl.

     Imapsync works under most Windows (2000, XP, Vista, Seven, Eight, Ten
     and all Server releases 2000, 2003, 2008 and R2, 2012 and R2, 2016)
     as a standalone binary software called imapsync.exe,
     usually launched from a batch file in order to avoid always typing
     the options. There is also a 64bit binary called imapsync_64bit.exe
 
     Imapsync works under OS X as a standalone binary
     software called imapsync_bin_Darwin

     Purchase latest imapsync at
     https://imapsync.lamiral.info/

     You'll receive a link to a compressed tarball called imapsync-x.xx.tgz
     where x.xx is the version number. Untar the tarball where
     you want (on Unix):

      tar xzvf  imapsync-x.xx.tgz

     Go into the directory imapsync-x.xx and read the INSTALL file.
     As mentioned at https://imapsync.lamiral.info/#install
     the INSTALL file can also be found at
     https://imapsync.lamiral.info/INSTALL.d/INSTALL.ANY.txt
     It is now split in several files for each system
     https://imapsync.lamiral.info/INSTALL.d/

CONFIGURATION

    There is no specific configuration file for imapsync, everything is
    specified by the command line parameters and the default behavior.

HACKING

    Feel free to hack imapsync as the NOLIMIT license permits it.

SIMILAR SOFTWARE

      See also https://imapsync.lamiral.info/S/external.shtml
      for a better up to date list.

    Last updated and verified on Sun Dec 8, 2019.

     imapsync: https://github.com/imapsync/imapsync (this is an imapsync copy, sometimes delayed, with --noreleasecheck by default since release 1.592, 2014/05/22)
     imap_tools: https://web.archive.org/web/20161228145952/http://www.athensfbc.com/imap_tools/. The imap_tools code is now at https://github.com/andrewnimmo/rick-sanders-imap-tools
     imaputils: https://github.com/mtsatsenko/imaputils (very old imap_tools fork)
     Doveadm-Sync: https://wiki2.dovecot.org/Tools/Doveadm/Sync ( Dovecot sync tool )
     davmail: http://davmail.sourceforge.net/
     offlineimap: http://offlineimap.org/
     mbsync: http://isync.sourceforge.net/
     mailsync: http://mailsync.sourceforge.net/
     mailutil: https://www.washington.edu/imap/ part of the UW IMAP toolkit. (well, seems abandoned now)
     imaprepl: https://bl0rg.net/software/ http://freecode.com/projects/imap-repl/
     imapcopy (Pascal): http://www.ardiehl.de/imapcopy/
     imapcopy (Java): https://code.google.com/archive/p/imapcopy/
     imapsize: http://www.broobles.com/imapsize/
     migrationtool: http://sourceforge.net/projects/migrationtool/
     imapmigrate: http://sourceforge.net/projects/cyrus-utils/
     larch: https://github.com/rgrove/larch (derived from wonko_imapsync, good at Gmail)
     wonko_imapsync: http://wonko.com/article/554 (superseded by larch)
     pop2imap: http://www.linux-france.org/prj/pop2imap/ (I wrote that too)
     exchange-away: http://exchange-away.sourceforge.net/
     SyncBackPro: http://www.2brightsparks.com/syncback/sbpro.html
     ImapSyncClient: https://github.com/ridaamirini/ImapSyncClient
     MailStore: https://www.mailstore.com/en/products/mailstore-home/
     mnIMAPSync: https://github.com/manusa/mnIMAPSync
     imap-upload: http://imap-upload.sourceforge.net/ (A tool for uploading a local mbox file to IMAP4 server)
     imapbackup: https://github.com/rcarmo/imapbackup (A Python script for incremental backups of IMAP mailboxes)
     BitRecover email-backup 99 USD, 299 USD https://www.bitrecover.com/email-backup/.
     ImportExportTools: https://addons.thunderbird.net/en-us/thunderbird/addon/importexporttools/ ImportExportTools for Mozilla Thunderbird by Paolo Kaosmos. ImportExportTools does not do IMAP.

HISTORY

    I initially wrote imapsync in July 2001 because an enterprise, called
    BaSystemes, paid me to install a new imap server without losing huge old
    mailboxes located in a far away remote imap server, accessible by an
    often broken low-bandwidth ISDN link.

    I had to verify every mailbox was well transferred, all folders, all
    messages, without wasting bandwidth or creating duplicates upon resyncs.
    The imapsync design was made with the beautiful rsync command in mind.

    Imapsync started its life as a patch of the copy_folder.pl script. The
    script copy_folder.pl comes from the Mail-IMAPClient-2.1.3 perl module
    tarball source (more precisely in the examples/ directory of the
    Mail-IMAPClient tarball).

    So many happened since then that I wonder if it remains any lines of the
    original copy_folder.pl in imapsync source code.

