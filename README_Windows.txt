# $Id: README_Windows.txt,v 1.18 2019/12/11 18:52:16 gilles Exp gilles $
# 
# This is the README_Windows.txt file for imapsync 
# imapsync : IMAP syncing and migration tool.

=====================
 Imapsync on Windows
=====================

 There is two ways to install and use imapsync on Windows systems: A) or B).

 Standard users should take the A) way, the simplest way.

 Developers, or powerful users that want to build their own imapsync.exe
 or modify it, have to consider the B) way, the complex and powerful way.

---------------
A) Simplest way
---------------

A.0) Preamble for visual users looking for a visual tool.

 Imapsync itself is not a visual tool. The visual tool is Notepad 
 or any text editor. Many pure visual users have succeeded using imapsync
 to transfer their email accounts. Only the ones that tried have succeeded,
 so don't give up before trying once. Another assumption is that visual 
 users can read. So let's go further.

A.1) Get imapsync.

 Get imapsync at https://imapsync.lamiral.info/
 You'll then have access to a zip archive file named imapsync_1.xxx.zip
 where 1.xxx is the imapsync release number.

A.2) Extract the zip file in a folder where you will work with imapsync.

 You can work on the Desktop since the zip file extraction creates
 a unique folder named imapsync_1.xxx (where 1.xxx is the imapsync 
 release number).

A.3) Check the folder

 In the folder extracted imapsync_1.xxx you see 6 files and 2 directories:

 * README_Windows.txt     is the current file you are reading.
 * README.txt             is the imapsync general document.
 * FAQ.d/*                FAQs are a good read when something goes wrong.
 * imapsync_example.bat   is a simple batch file example you will copy and edit.
 * sync_loop_windows.bat  is a batch file example for syncing many accounts.
 * file.txt               is an input file example for syncing many accounts.
 * imapsync.exe           is the imapsync 64bit binary. You don't have to run it directly.
 * imapsync_32bit.exe     is the imapsync 32bit binary. You don't have to run it directly.
 * Cook/                  is the directory to build imapsync.exe from its source, 
                         for the B) way and expert users.

 You can copy or rename the file imapsync_example.bat as you wish,
 as long as its extension remains ".bat", for example mysync.bat

 On Windows systems .bat extension means "I am a batch script". 
 A batch script is a file containing commands, it's a program. 
 Don't be afraid, a program can be simple or at least simple to
 modify. Think it like a cook recipe.

 The batch scripts have to stay in the same directory than 
 imapsync.exe because of the way they call imapsync.exe.
 They use ".\imapsync.exe", so let them be in the same directory.

 Or you can change the path .\ to whatever you want if you understand what
 you are doing (you have to use a pathname from the script point of view).

 For the rest of this documentation I assume you copied
 imapsync_example.bat to a file named imapsync_stuff.bat

 If you don't know how to copy and rename a file then 
 use imapsync_example.bat itself.

A.4) Edit the batch file

 Edit the file imapsync_stuff.bat and change the values with yours.
 In order to edit it you have do a right click on it and select "modify"
 in the list presented in the small window menu.

 Notepad or Notepadd++ are very good editors to modify it.

 Office Word or any powerful text processor are not good for that job.
 Text processors transform files in a special format that
 are wrong to make them stay a good batch file, so don't use them!

 Files FAQ.txt and FAQ.d/* contain many tips and special options sometimes
 needed by specific imap server softwares like Exchange or Gmail.
 Those files are also available online at
 https://imapsync.lamiral.info/FAQ.d/


A.5) Run the batch file

 To run imapsync with your values just double-click on 
 the batch file imapsync_stuff.bat

 There is no need to have administrator privileges to run imapsync.

 The run happens in a DOS window. 

A.6) Look the sync running. 

 You can abort it at any time with a quick double ctrl-c, 
 hit ctrl-c twice within one second.
 A single ctrl-c will reconnect to both imap servers.
 You can also abort the sync by closing the DOS window.

 What you see in this DOS terminal is also put in a logfile located
 in the subdirectory LOG_imapsync/

A.7) Control what happened.

 When the sync is finished you can find the whole log file 
 of the output in the folder named "LOG_imapsync".
 the logfile name is based on the launching date, 
 hour, minute, second, milliseconds plus the user1 and user2 parameters.
 For example a file name can be
 LOG_imapsync\2019_11_29_14_49_36_514_tata_titi.txt

 There is one logfile created at each run.
 The logfile name is printed at the end of the imapsync run.

 When there is a problem, the problem is very often described 
 at the end of the logfile.


A.8) Loop on A.4 through A.7

 * A.4) edit 
 * A.5) run 
 * A.6) look
 * A.7) control

 Loop on the process of editing, running and controlling imapsync
 until you solve all issues and the sync is over.

 Congratulations!


------------
B) Hard way
------------

It is the hard way because it installs all software dependencies.
This is the way for modifying imapsync.exe if needed.

B.1) Install Perl if it isn't already installed.
  Strawberry Perl is a very good candidate
  http://strawberryperl.com/
  I use 5.30.1.1 (released 2019-11-22) but previous and later releases 
  should work as well (Perl 5.18 to 5.26 do).

B.2) Go into the Cook/ directory
B.3) Double-clic build_exe.bat 

It should create a binary imapsync.exe in the current Cook/ directory.

B.4) Move imapsync.exe in the upper directory and follow instructions
     from A.3) to A.8)

