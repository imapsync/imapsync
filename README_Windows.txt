# $Id: README_Windows.txt,v 1.4 2014/05/29 23:41:41 gilles Exp gilles $
# 
# README_Windows.txt file for imapsync 
# imapsync : IMAP sync and migrate tool.

WINDOWS
=======

Two ways to install and use imapsync on Windows systems: A) or B).

Standard users should only take the A) way.

Developpers, users that want to build their own imapsync.exe
or modify it, have to consider the B) way.

A) Simplest way
---------------

A.1) Get imapsync.

Buy imapsync at http://imapsync.lamiral.info/
You'll then have access to a zip archive file named imapsync_1.xxx.zip
where 1.xxx is the imapsync release number.

A.2) Extract the zip file in a folder where you'll work with imapsync

You can work on the Desktop since the zip file extraction creates
a uniq folder named imapsync_1.xxx (where 1.xxx is the imapsync 
release number).

A.3) Check the folder

In the folder extracted imapsync_1.xxx you see 6 files:

* README_Windows.txt     is the current file you are reading
* imapsync_example.bat   is a batch file example you will copy and edit
* sync_loop_windows.bat  is a batch file example for syncing many accounts
* FAQ.txt                contains many useful tips, 
                         FAQ is a must read when something goes wrong.
* README.txt             imapsync general documentation.
* imapsync.exe           is the imapsync binary. You don't have to run it directly.

You can copy or rename imapsync_example.bat as you wish as long as 
its extension remains ".bat". On Windows systems .bat extension 
means "I'm a batch script". Same thing for sync_loop_windows.bat.
The batch scripts have to stay with imapsync.exe because
of the way they call it, they use ".\imapsync.exe", so
let them be in the same directory.

For the rest of this documentation I assume you copied
imapsync_example.bat to a file named imapsync_stuff.bat

A.4) Edit the batch file 

Edit imapsync_stuff.bat and change the values with yours.
In order to edit it you have do a right click on it and select "modify"
in the list presented in the small window menu.
Notepad is a good editor to modify it,
Office Word is not good for that job.

File FAQ.txt contains many tips and special options sometimes
needed by specific imap server softwares like Exchange or Gmail.

A.5) Run the batch file

To run imapsync with your values just double-clic on 
the batch file imapsync_example.bat

You do not need to have administrator priviledge to run imapsync.

A.6) Loop on A.5) A.6)

Loop the process of editing and running imapsync until
you solve all issues and all values suit your needs.

A.7) Look the sync running. You can abort it at any time with a ctrl-c. 

A.8) When the sync is finished you can find the whole log of the output 
in the folder named "LOG_imapsync", the logfile name is based
on the launching date and hour and the user2 parameter, one logfile per run.
The logfile name is printed at the end of the imapsync run.
If you do not want logging in a file use option --nolog


B) Hard way. It is the hard way because it installs all software
   dependencies. This is the way for modifying imapsync if needed.

- Get imapsync-x.xx.tgz

- Install Perl if it isn't already installed.
  Strawberry Perl is a very good candidate
  http://strawberryperl.com/

- Use the command CPAN to install modules listed in the PREREQUISITES section.
  There is also a batch file that does this install for you
  It is called install_modules.bat available at
  http://imapsync.lamiral.info/examples/install_modules.bat

c) How to build imapsync.exe?

- Do the hard stuff in B)
- Run build_exe.bat (found in the tarball)

