# $Id: README_Windows.txt,v 1.9 2017/09/11 02:57:38 gilles Exp gilles $
# 
# This is the README_Windows.txt file for imapsync 
# imapsync : IMAP sync and migrate tool.

WINDOWS
=======

There is two ways to install and use imapsync on Windows systems: A) or B).

Standard users should only take the A) way.

Developers, or powerful users that want to build their own imapsync.exe
or modify it, have to consider the B) way.

A) Simplest way
---------------

A.1) Get imapsync.

Get imapsync at https://imapsync.lamiral.info/dist/
You'll then have access to a zip archive file named imapsync_1.xxx.zip
where 1.xxx is the imapsync release number.

A.2) Extract the zip file in a folder where you'll work with imapsync

You can work on the Desktop since the zip file extraction creates
a unique folder named imapsync_1.xxx (where 1.xxx is the imapsync 
release number).

A.3) Check the folder

In the folder extracted imapsync_1.xxx you see 6 files and 2 directories:

* README_Windows.txt     is the current file you are reading
* README.txt             is the imapsync general document.
* FAQ.d/*                FAQs are a must read when something goes wrong.
* imapsync_example.bat   is a batch file example you will copy and edit
* sync_loop_windows.bat  is a batch file example for syncing many accounts
* file.txt               is an input file example for syncing many accounts
* imapsync.exe           is the imapsync binary. You don't have to run it directly.
* Cook/                  is the directory to build imapsync.exe from its source.

You can copy or rename imapsync_example.bat as you wish as long as 
its extension remains ".bat". On Windows systems .bat extension 
means "I'm a batch script". Same thing for sync_loop_windows.bat.
The batch scripts have to stay with imapsync.exe because
of the way they call it, they use ".\imapsync.exe", so
let them be in the same directory (or change the path .\
to whatever you want if you understand what you're doing).

For the rest of this documentation I assume you copied
imapsync_example.bat to a file named imapsync_stuff.bat

A.4) Edit the batch file 

Edit imapsync_stuff.bat and change the values with yours.
In order to edit it you have do a right click on it and select "modify"
in the list presented in the small window menu.
Notepad or Notepadd++ are good editors to modify it.
Office Word is not good for that job, don't use it!

Files FAQ.txt and FAQ.d/* contain many tips and special options sometimes
needed by specific imap server softwares like Exchange or Gmail.


A.5) Run the batch file

To run imapsync with your values just double-clic on 
the batch file imapsync_stuff.bat

You do not need to have administrator privilege to run imapsync.

A.6) Loop on A.5) A.6)

Loop the process of editing and running imapsync until
you solve all issues and all values suit your needs.

A.7) Look the sync running. You can abort it at any time with a 
     quick double ctrl-c, hit ctrl-c twice within one second.
     (a single ctrl-c will reconnect to both imap servers)

A.8) When the sync is finished you can find the whole log of the output 
in the folder named "LOG_imapsync", the logfile name is based
on the launching date, hour, minute, second, miliseconds and the 
user2 parameter. There is one logfile per run.
The logfile name is printed at the end of the imapsync run.
If you do not want logging to a file then use option --nolog


B) Hard way. It is the hard way because it installs all software
   dependencies. This is the way for modifying imapsync.exe if needed.

B.1) Install Perl if it isn't already installed.
  Strawberry Perl is a very good candidate
  http://strawberryperl.com/
  I use 5.26.0.1 (31 may 2017) but previous and later releases 
  should work (5.18 and 5.20 do) as well.

B.2) Go into the Cook/ directory
B.3) Double-clic build_exe.bat 

It should create a binary imapsync.exe in the current Cook/ directory.

B.4) Move imapsync.exe in the upper directory and follow instructions
     from A.3) to A.8)

