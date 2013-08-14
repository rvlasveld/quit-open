-- main.scpt
-- Cocoa-AppleScript Applet
--
-- This app can close and open applications when an other application,
-- the trigger, is launced or terminated. This can be useful when two 
-- applications interfere with eachother or when one is dependend on the
-- other (e.g. with setting an VPN connection).
--
--
-- Roemer Vlasveld (roemer.vlasveld@gmail.com)
--
--
-- Github Gist: https://gist.github.com/5429191
-- Blogpost: http://rvlasveld.github.io/blog/2013/04/21/open-and-close-applications-when-an-other-launches-or-terminates/
--

--
-- SETTINGS
-- Modify the following lists to your needs.
-- To find an application name, use e.g. the command-tab
-- window.
-- 

-- Application to trigger when it is launched
property pTriggerLaunchApplications : {"MATLAB"}
-- Application to trigger when it is terminated
property pTriggerTerminateApplications : {"MATLAB"}

-- Applications to open when the trigger is launched
property pOpenOnLaunchApplications : {} -- {"Cisco AnyConnect Secure Mobility Client"}
-- Applications to close when the trigger is launched
property pCloseOnLaunchApplication : {"Flexiglass"}

-- Applications to open when the trigger is terminated
property pOpenOnTerminateApplications : {"Flexiglass"}
-- Applications to hide when opened
property pHideOnOpenAfterTerminateApplications : {"Flexiglass"}
-- Applications to close when the trigger is terminated
property pCloseOnTerminateApplications : {} -- {"Cisco AnyConnect Secure Mobility Client"}


property pNSWorkspace : class "NSWorkspace"

on run
	-- Register for notifications of launching and terminating applications 
	tell (pNSWorkspace's sharedWorkspace())'s notificationCenter()
		addObserver_selector_name_object_(me, "appQuitNotification:", "NSWorkspaceDidTerminateApplicationNotification", missing value)
		addObserver_selector_name_object_(me, "appLaunchNotification:", "NSWorkspaceDidLaunchApplicationNotification", missing value)
	end tell
end run

-- Handle the notification for a launched application
on appLaunchNotification_(notification)
	set theLauchedApplication to (notification's userInfo's NSWorkspaceApplicationKey's localizedName()) as text
	
	if theLauchedApplication is in pTriggerLaunchApplications then
		-- Open the associated applications
		repeat with applicationToOpen in pOpenOnLaunchApplications
			tell application applicationToOpen to activate
		end repeat
		
		-- Close the associated applications
		repeat with applicationtoClose in pCloseOnLaunchApplication
			tell application applicationtoClose to quit
		end repeat
	end if
	
end appLaunchNotification_

-- Handle the notification for a terminated application
on appQuitNotification_(notification)
	set theLauchedApplication to (notification's userInfo's NSWorkspaceApplicationKey's localizedName()) as text
	
	if theLauchedApplication is in pTriggerTerminateApplications then
		-- Open the associated applications
		repeat with applicationToOpen in pOpenOnTerminateApplications
			tell application applicationToOpen to activate
			
			-- Try for AppleScript support, because we may want the application to hide
			try
				tell application applicationToOpen to count windows
			on error message
				
				-- Enable scripting
				enableAppleScripting(applicationToOpen)
				-- Reopen
				tell application applicationToOpen to quit
				delay 2
				tell application applicationToOpen to activate
			end try
			
			if applicationToOpen is in pHideOnOpenAfterTerminateApplications then
				-- Close all the windows of this application
				tell application applicationToOpen to close every window
			end if
			
		end repeat
		
		-- Close the associated applications
		repeat with applicationtoClose in pCloseOnTerminateApplications
			tell application applicationtoClose to quit
		end repeat
		
	end if
end appQuitNotification_


on enableAppleScripting(theApplication)
	-- Add AppleScript support to an application by overwriting the Info.plist in
	-- the Application bundle.
	-- See http://c-command.com/blog/2009/12/28/capture-from-preview/
	
	try
		set application_path to (path to application theApplication)
		set bundle_identifier to get bundle identifier of (info for the application_path)
		
		
		tell application "Finder"
			
			set the application_to_modify to (application file id bundle_identifier) as alias
			
		end tell
		
		set the app_path to (POSIX path of the application_to_modify)
		set the app_info_path to ((POSIX path of the application_to_modify) & "Contents/Info")
		
		set the plist_filepath to the quoted form of the app_info_path
		
		-- determine which Mac OS X version currently running
		set osver to system version of (system info)
		
		-- Make a backup of the Application bundle and overwrite the plist file
		do shell script "ditto -c -k --sequesterRsrc --keepParent " & app_path & space & app_path & ".quit-open.zip" with administrator privileges
		do shell script "defaults write " & app_info_path & space & "NSAppleScriptEnabled -bool YES" with administrator privileges
		do shell script "chmod a+r" & space & app_info_path & ".plist" with administrator privileges
		
		if osver ³ "10.7" then
			if osver ³ "10.8" then
				-- Assume Xcode is installed
				do shell script "sudo ln -s /Applications/Xcode.app/Contents/Developer/usr/bin/codesign_allocate /usr/bin" with administrator privileges
			end if
			do shell script "codesign -f -s - " & app_path with administrator privileges
		end if
		
		
	on error message number errorNumber
		-- Something went wrong
		if message is not equal to "ln: /usr/bin/codesign_allocate: File exists" then
			display dialog "Problem with enabling AppleScript for " & theApplication & ": " & message & " -- Error number: " & errorNumber
		end if
	end try
end enableAppleScripting