# $Id: README_Windows.txt,v 1.26 2022/01/14 11:54:28 gilles Exp gilles $
# 
# This is the README_Windows.txt file for imapsync 
# imapsync: IMAP syncing and migration tool.

=====================
 Imapsync on Windows
=====================

 There are two ways to install and use imapsync on Windows systems: A) or B).

 Standard users should take the A) way, the simplest way.

 Developers, or power users that want to build their own imapsync.exe
 or modify it, have to consider the B) way, the complex and powerful way.


---------------
A) Simplest way
---------------

A.0) Preamble for visual users looking for a visual tool.

 First, the visual thing I am talking about here is not the online
 visual interface I call /X that you might have seen and used at the
 URL https://imapsync.lamiral.info/X/ 

 This /X visual interface is not yet available on Windows as a service
 that you can install and use in your system.  I plan to make a visual
 tool available on Windows but, for now, I encountered technical
 issues.

 So what visual thing am I talking about?
 
 Imapsync itself is not a visual tool. The visual tool is Notepad or
 any text editor. Many pure visual users have succeeded in using
 imapsync to transfer their email accounts. As you can guess, only the
 ones that tried have succeeded, so don't give up before trying at
 least once. Another assumption is that visual users can read.
 
 Let's go for some reading!

A.1) Get imapsync.

 Get imapsync at https://imapsync.lamiral.info/
 You'll then have access to a zip archive file named imapsync_2.178.zip
 where 2.178 is the imapsync release number.

A.2) Extract the zip file in a folder where you will work with imapsync.

 You can work on the Desktop since the zip file extraction creates
 a unique folder named imapsync_2.178/
 
 Do not unzip the archive in what is called a "system" directory since
 you may encounter permission issues.

Two points to have in mind:
* You don't need to be an Administrator to unzip the zip archive.
* You don't need to be an Administrator to run imapsync.

In short, any user on your system can use imapsync.

A.3) Check the folder

 In the folder extracted and called imapsync_2.178, you see 7 files
 and 2 directories.  Those files and directories may be presented in a
 different order than the following, the order is not important
 anyway. There are only two important files to get your mailbox
 transfer job started in a few minutes, the first two files of the
 following list:

 * README_Windows.txt     is the current file you are reading.
 * imapsync_example.bat   is a simple batch file example that you will copy and edit.

 * README.txt             is the imapsync general document.
 * FAQ.d/*                FAQs are a good read when something goes wrong.
 * sync_loop_windows.bat  is a batch file example for syncing many accounts.
 * file.txt               is an input file example for syncing many accounts.
 * imapsync.exe           is the imapsync 64bit binary. You don't have to run it directly.
 * imapsync_32bit.exe     is the imapsync 32bit binary. You don't have to run it directly.
 * Cook/                  is the directory to build imapsync.exe from its source, 
                          for the B) way and expert users.

 You can copy or rename the file imapsync_example.bat as you wish,
 as long as its extension remains ".bat", for example, mysync.bat

 On Windows systems, a file name ending with a .bat extension means
 "I'm a batch script".  A batch script is a file containing commands,
 it's a program.  Don't be afraid, a program can be very simple to
 modify and I hope imapsync_example.bat is one of them.

 The batch scripts have to stay in the same directory as imapsync.exe
 because of the way they call imapsync.exe.  They use the string
 ".\imapsync.exe", so let them be in the same directory.

 You can change the path .\ to whatever you want if you understand
 what you are doing (you have to use a pathname from the script point
 of view).

 For the rest of this documentation, I assume you copied
 imapsync_example.bat to a file named mysync.bat

 If you don't know how to copy and rename a file then use
 imapsync_example.bat itself, it's ok. The original file is still in
 the zip file in case you want to restart from scratch.

A.4) Edit the batch file

 This section describes how to edit the file mysync.bat and change 
 it by replacing example values with your values.
 
 To edit mysync.bat, you have to right-click on it and select "modify"
 in the list presented in the small window menu.

 Notepad or Notepadd++ are very good editor candidates to modify the
 script.  Notepad is already installed on any Windows system,
 Notepadd++ is not usually installed but if you have it, then use it.

 Office Word or any powerful text processor is NOT good for that job.
 Text processors transform files in a special format that is wrong to
 make them stay a good batch file, so don't use them!

 The documents FAQ.txt and FAQ.d/* contain many tips. They describe
 some special options that are sometimes needed by specific imap
 software servers like Exchange, Office365, or Gmail.

 Those documents are also available online at
 https://imapsync.lamiral.info/FAQ.d/
 You don't have to look into them unless you encounter problems.

A.5) Run the batch file

 To run imapsync with your values just double-click on the batch file
 mysync.bat

 There is no need to have administrator privileges to run imapsync.

 The run happens in a DOS window; usually, this window is black.

 If imapsync.exe returns immediately with the ERRORLEVEL -1, it may be
 because you have a Group Policy in place to prevent the execution of
 programs in the %TEMP% directory. Temporarily remove this restriction
 and imapsync will work as expected. Thanks to Walter H. for this
 input!

 Technically speaking, imapsync.exe is an embedded Perl script with
 also the Perl interpreter and many Perl modules, all glued together
 in an archive auto-extracted at run time. So it needs write-access to
 the temporary directory. The temporary directory name depends on the
 user but its value is in the variable %TEMP%. You can have the value
 by running the command ECHO %TEMP% in a DOS window. You can have a
 DOS window by launching the command cmd.exe

A.6) Look at the sync running. 

 You can abort the sync at any time with a quick double ctrl-c, hit
 ctrl-c twice within one second.
 
 A single ctrl-c will reconnect to both imap servers.
 
 You can also simply abort the sync by closing the DOS window, using
 the cross situated at the up-right corner.

 What you see in this DOS terminal is also put in a logfile located
 in the subdirectory LOG_imapsync/

A.7) Control what happened.

 When the sync is finished you can find the whole log file of the
 output in the folder named "LOG_imapsync/".
 
 The logfile name is based on the launching date, hour, minute,
 second, milliseconds, plus the user1 and user2 parameters. 

 For example, a file name can be
 LOG_imapsync\2019_11_29_14_49_36_514_tata_titi.txt

 There is one log file created for each run.  The log file name is
 printed both at the beginning and the end of the imapsync run.

 IMPORTANT: When there is a problem, the problem is very often
 described at the end of the log file. It means you don't have to read
 all this bloody ununderstandable verbose logfile, just read the end
 first.


A.8) Loop on A.4 through A.7

 * A.4) edit the batch file
 * A.5) run the batch file
 * A.6) look at the run and the log file
 * A.7) control what happened.

 Loop on the process of editing, running and controlling imapsync
 until you solve all issues and the sync is over.

A good sign that the sync went very well is when the nearly last lines are like:

" The sync looks good, all 123456 identified messages in host1 are on host2.
" There is no unidentified message
" Detected 0 errors

Congratulations!


------------
B) Hard way
------------

It is the hard way because it installs all software dependencies.
This is the way for modifying imapsync.exe if needed.

B.1) Install Perl if it isn't already installed.
  Strawberry Perl is a very good candidate
  http://strawberryperl.com/
  I use 5.32.1.1 (released 2021-01-24) but previous and later releases 
  should work as well (Perl 5.18 to 5.30 do).

B.2) Go into the Cook/ directory
B.3) Double-click build_exe.bat 

It should create a binary imapsync.exe in the current Cook/ directory.

B.4) Move imapsync.exe in the upper directory and follow instructions
     from A.3) to A.8)
