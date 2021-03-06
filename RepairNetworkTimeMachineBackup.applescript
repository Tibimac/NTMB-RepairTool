##### VARIABLES A CHANGER#####
set myServerUserName to "fab" -- Nom d'utilisateur pour se connecter au serveur/NAS
set myServerPassword to "fab_password" -- Mot de passe de l'utilisateur pour se connecter au serveur/NAS
set myLocalPassword to "fab_password" -- Mot de passe du compte utilisateur admin sur le Mac


##### VARIABLES A NE PAS CHANGER#####
set preferencesFolder to (path to preferences) as string
set fileName to "RepairNetworkTimeMachineBackupPrefences"
set separator to "<RNTMB_Prefs_Separator>"

try #-- Récupération des prefs (chemin où se trouve le fichier sparsebundle de la sauvegarde, nom du serveur et nom du volume)
	set prefFilePath to preferencesFolder & fileName as alias
	open for access prefFilePath
	set contentOfPrefFile to read prefFilePath
	set text item delimiters to {separator}
	set prefsItems to text items of contentOfPrefFile
	set sparseBundleFileStdPath to first item of prefsItems
	set serverName to second item of prefsItems
	set sparseBundleVolumeName to third item of prefsItems
	close access prefFilePath
	set text item delimiters to {""}
on error #-- Sinon demande à l'utilisateur de localiser le fichier et on crée le fichier de pref
	-- Récupération chemin vers fichier sparsebundle
	set sparseBundleFileStdPath to (choose file with prompt "Choisissez le fichier .sparsebundle de votre sauvegarde :" of type ("sparsebundle")) as string
	
	-- Récupération du nom du volume où est stocké le fichier sparsebundle et du nom du serveur où est localisé le volume
	tell application "Finder"
		set sparseBundleVolumeName to name of disk of file sparseBundleFileStdPath
		tell application "System Events"
			set serverName to server of disk sparseBundleVolumeName
		end tell
	end tell
	
	-- Création contenu du fichier
	set contentForPrefFile to sparseBundleFileStdPath & separator & serverName & separator & sparseBundleVolumeName
	
	-- Création fichier prefs, ouverture et enregistrement du contenu
	tell application "Finder" to make new file at alias preferencesFolder with properties {name:fileName, creator type:"????", file type:"pref", locked:false, busy status:false, short version:"", long version:""}
	set prefFilePath to preferencesFolder & fileName as alias
	open for access prefFilePath with write permission
	write contentForPrefFile starting at 0 to prefFilePath
	set eof prefFilePath to (length of contentForPrefFile)
	close access prefFilePath
end try

set volumeToMount to "afp://" & serverName & "._afpovertcp._tcp.local/" & sparseBundleVolumeName
set plistFilePath to (sparseBundleFileStdPath & "com.apple.TimeMachine.MachineID.plist")
-- Suppression des : mis à la fin du chemin (sinon erreur dans l'execution des commandes shell)
set text item delimiters to {".sparsebundle:"}
set sparseBundleFileStdPathTextItems to text items of sparseBundleFileStdPath
set text item delimiters to {".sparsebundle"}
set sparseBundleFileStdPath to sparseBundleFileStdPathTextItems as text
set text item delimiters to {""}
set sparseBundleFilePosixPath to quoted form of POSIX path of sparseBundleFileStdPath





#===== Montage du volume réseau =====#
try
	mount volume volumeToMount as user name myServerUserName with password myServerPassword
on error
	display dialog "Impossible de se connecter au volume AFP " & sparseBundleVolumeName & " sur le serveur " & serverName & "."
end try





#-- Vérification du "VerificationState" dans le fichier plist de la sauvegarde
tell application "System Events"
	tell property list file plistFilePath
		tell contents
			set currentVerificationState to value of property list item "VerificationState"
		end tell
	end tell
end tell





#-- VerificationState à 2 = problème -> réparation
if currentVerificationState is 2 then
	##### COMMANDES #####
	# 1
	set chflagsResult to do shell script "sudo chflags -R nouchg " & sparseBundleFilePosixPath password myLocalPassword with administrator privileges
	
	if chflagsResult is equal to 0 or chflagsResult is equal to "" then
		#2 -- Le volume va être monté pour que son nom soit renvoyé et qu'il puisse être récupéré
		set hdiutilAttachResult to do shell script "sudo hdiutil attach -noverify -noautofsck " & sparseBundleFilePosixPath password myLocalPassword with administrator privileges
		
		#-- Découpage par ligne
		set text item delimiters to {"
	"}
		set diskPartitionsLines to text items of hdiutilAttachResult
		
		#-- Détection et récupération de la ligne correspondant à la partition Apple_HFS
		repeat with i from 1 to (count of diskPartitionsLines)
			set currentLine to text item i of diskPartitionsLines
			if "Apple_HFS" is in currentLine then
				set diskAppleHFSLine to currentLine
			end if
		end repeat
		
		#-- Découpage de la ligne par tabulation
		set text item delimiters to {"	"}
		set diskAppleHFSLineItems to text items of diskAppleHFSLine
		
		-- Découpage de la première partie (le chemin) par espace
		set text item delimiters to {" "}
		set diskAppleHFSLinePathItems to text items of (first text item of diskAppleHFSLineItems)
		
		-- Découpage de la dernière partie (le nom) par slash
		set text item delimiters to {"/"}
		set diskAppleHFSLineNameItems to text items of (last text item of diskAppleHFSLineItems)
		set text item delimiters to {""}
		
		#log diskAppleHFSLinePathItems (***DEBUG***)
		#log diskAppleHFSLineNameItems (***DEBUG***)
		
		#-- Récupération chemin partition et nom du volume
		set diskAppleHFSPartitionPath to first item of diskAppleHFSLinePathItems
		set diskAppleHFSPartitionName to last item of diskAppleHFSLineNameItems
		
		(*
	-- OU (plus "sur" mais plus "long")
	#-- Boucle pour récupérer le chemin de la partition en Apple_HFS
	repeat with i from 1 to (count of diskAppleHFSLinePathItems)
		set currentValue to text item i of diskAppleHFSLinePathItems
		if currentValue is not "" then
			set diskAppleHFSPartitionPath to currentValue -- Valeur non vide = chemin de la partition -> on le récupère.
			exit repeat
		end if
	end repeat
	
	#-- Boucle pour récupérer le nom du volume
	repeat with i from 1 to (count of diskAppleHFSLineNameItems)
		set currentValue to text item i of diskAppleHFSLineNameItems
		if currentValue is not "" and "Volumes" is not in currentValue then -- Valeur non vide et non "Volumes" = nom du volume -> on le récupère
			set diskAppleHFSPartitionName to currentValue
			exit repeat
		end if
	end repeat
	-- FIN OU
	*)
		
		#log diskAppleHFSPartitionPath (***DEBUG***)
		#log diskAppleHFSPartitionName (***DEBUG***)
		
		#3 -- Le nom du volume ayant été récupéré -> démontage du volume sans détacher l'image disque
		do shell script "diskutil unmount " & quoted form of POSIX path of ("/Volumes/" & diskAppleHFSPartitionName)
		
		#-- Avant de continuer, petite vérification pour s'assurer que le chemin vers la partition est bon (s'il commence bien par /dev/disk ca devrait)
		if "/dev/disk" is in diskAppleHFSPartitionPath then
			#4 -- Réparation du volume et de son système de fichiers
			set fsckHfsResult to do shell script "sudo fsck_hfs -drfy " & diskAppleHFSPartitionPath password myLocalPassword with administrator privileges
			set fsckHfsIsSucceed to false
			#set fsckHfsIsSucceed to true (***DEBUG***)
			
			if "The volume " & diskAppleHFSPartitionName & " repaired successfully" is in fsckHfsResult then
				set fsckHfsIsSucceed to true
			else
				if "The volume " & diskAppleHFSPartitionName & " could not be repaired" is in fsckHfsResult then
					#-- On retente l'opération avec espoir, en cas de nouvelle erreur, le script en restera là
					set fsckHfsResult to do shell script "sudo fsck_hfs -drfy " & diskAppleHFSPartitionPath password myLocalPassword with administrator privileges
					if "The volume " & diskAppleHFSPartitionName & " repaired successfully" is in fsckHfsResult then
						set fsckHfsIsSucceed to true
					else
						set fsckHfsIsSucceed to false
					end if
				else
					if "Invalid node structure" is in fsckHfsResult or "Invalid B-tree node size" is in fsckHfsResult or ("RebuildBTree -record" is in fsckHfsResult and "is not recoverable" is in fsckHfsResult) then
						#-- Tentative de réparation avec une option de commande différente
						set fsckHfsResult to do shell script "sudo fsck_hfs -p " & diskAppleHFSPartitionPath password myLocalPassword with administrator privileges
						#-- Puis on retente la commande précédente
						set fsckHfsResult to do shell script "sudo fsck_hfs -drfy " & diskAppleHFSPartitionPath password myLocalPassword with administrator privileges
						if "The volume " & diskAppleHFSPartitionName & " repaired successfully" is in fsckHfsResult then
							set fsckHfsIsSucceed to true
						else
							set fsckHfsIsSucceed to false
						end if
					end if
				end if
			end if
			
			#-- Si la réparation a réussie -> détachement et modification fichier plist
			if fsckHfsIsSucceed is true then
				#5 -- Détachement de la partition
				do shell script "hdiutil detach " & diskAppleHFSPartitionPath
				
				#6 -- Modification du VerificationState du fichier plist de la sauvegarde
				tell application "System Events"
					tell property list file plistFilePath
						tell contents
							set value of property list item "VerificationState" to 0
						end tell
					end tell
				end tell
				
				#7 -- Ejection du volume du serveur
				tell application "Finder" to eject disk sparseBundleVolumeName
				
				tell application "System Events"
					display dialog "La réparation a réussie 😃. La prochaine sauvegarde Time Machine devrait s'executer normalement."
				end tell
			else
				tell application "System Events"
					display dialog "La réparation a malheureusement échouée et ce malgré plusieurs tentatives."
				end tell
			end if
		end if
	end if
else
	tell application "System Events"
		display dialog "La sauvegarde Time Machine n'a aucun soucis pour le moment. Keep cool 😉"
	end tell
end if