#!/bin/bash
# Enter the snapshot view path
printf "Please enter the Snapshot View Path\n"
read CCSnpPath
# go the to the snapshot view path
cd $CCSnpPath

#Update the snapshot view and capture the stdout and stderror both
#UpdateCmdOP will hold the stdout and Error.txt will hold the stderror
UpdateCmdOP="$(cleartool update -f 2> Error.txt)"
#Get the Error.txt data to a variable
UpdateCmdErr="$( cat Error.txt )"
#remove the Error.txt
rm Error.txt
#Setting  Internal Field Separator to \n for new line
IFS=$'\n'
declare -a MovedFileArray
declare -a RenameFileArray
declare -a NewFileArray
declare -a DeletedFileArray
declare -a UpdatedFileArray
# folder separator
strFldSep="/"
#echo "Error Data is :"`cat Error.txt`
#If UpdateCmdOP is not empty, then process
if [ -n "$UpdateCmdOP" ]
then
	#echo "UpdateCmdOP is "$UpdateCmdOP
	#process the UpdateCmdOP value and fetch the update log file name
	Var=($(echo "${UpdateCmdOP}" | grep "Log has been written to"))
	# If still the Var is empty, then process UpdateCmdErr to fetch the update log file name
	if [ -z "$Var" ]
	then
		Var=($(echo "${UpdateCmdErr}" | grep "Log has been written to"))
	fi
	#if Var is not empty, then process
	if [ -n "$Var" ]
	then
		#echo "Var is "$Var
		#Fetch the update log file name from the double inverted comma
		FileName=`echo $Var| awk -F \" '{print $2}'`
		#echo "The update log file name is : "$FileName
		#Regular expression to fetch the new files
		RegexNew="New:[[:space:]]+([[:print:]]+)[[:space:]]/main/[[:print:]]+"
		#Regular expression to fetch the Unloaded files
		RegexUnloaded="UnloadDeleted:[[:space:]]+([[:print:]]+)"
		#Regular expression to fetch the Updated files
		RegexUpdate="Updated:[[:space:]]+([[:print:]]+)[[:space:]]/main/[[:print:]]+[[:space:]]/main/[[:print:]]+"
		
		# Two arrays have been delcared
		declare -a NewEleArray
		declare -a UnloadedArray
		# Three variables have been declared for indexing number
		var1=0
		var2=0
		var3=0
		# For loop, to traverse through the update log file data
		for f in $( cat "$FileName" );
		do
			#below code will match with RegexNew expression and save the file name to NewEleArray
			if [[ $f =~ $RegexNew ]]; then
				name="${BASH_REMATCH[1]}"
				NewEleArray[var1]=$name
				echo "New File: "$name
				((var1++))
			#below code will match with RegexUnloaded expression and save the file name to UnloadedArray
			elif [[ $f =~ $RegexUnloaded ]]; then
				name="${BASH_REMATCH[1]}"
				UnloadedArray[var2]=$name
				echo "Unloaded File:"$name
				((var2++))
			#below code will match with RegexUnloaded expression and save the file name to UnloadedArray
			elif [[ $f =~ $RegexUpdate ]]; then
				name="${BASH_REMATCH[1]}"
				UpdatedFileArray[var3]=$name
				echo "Updated File:"$name
				((var3++))
			fi
		done
		# Please enter the path till /view/lg535701_test_wau2_15fw41.2
		printf "\nPlease enter the dynamic view Path\n"
		read CCDynPath
		declare -a INODEUnloadedArray
		#if UnloadedArray is not empty, then process
		if [[ $UnloadedArray ]]; then
			echo "In UnloadedArray Processing"
			#Traverse trhough all the UnloadedArray data
			for i in "${UnloadedArray[@]}"
			do
				#Separate the folder name
				Folder="${i%"$strFldSep"*}"
				#Separate the file name
				File="${i##*"$strFldSep"}"
				
				echo "Folder is"$Folder
				echo "File is"$File
				
				if [[ $File == *"."* ]]
				then
					echo "In Unloaded File processing"
					DynViewPath="$CCDynPath/$Folder"
					
					#echo "DynViewPath is"$DynViewPath
					#Execute the command to check the version number of the folder, Error has been stored for debug process
					CmdOP="$(cleartool ls -s -d "${DynViewPath}" 2> Error.txt)"
					CmdErr="$( cat Error.txt )"
					rm Error.txt
					
					echo "CmdOP is"$CmdOP
					echo "CmdErr is"$CmdErr
					#if the CmdOP is not empty, then process
					if [ -n "$CmdOP" ]
					then
						#Fetch the folder name
						FileName="${CmdOP%"$strFldSep"*}"
						#Fetch the Version number
						FileVersion="${CmdOP##*"$strFldSep"}"
						((FileVersion--))
						#Processing for inode number fetch
						until [ $FileVersion -lt 1 ]; do
							INODEFilePath="$FileName/$FileVersion/$File@@/main/0"
							OutPut="$(ls -i "${INODEFilePath}")"
							Number=${OutPut% *}
							echo $OutPut
							#Check the Number variable value is numeric
							if [ "$(echo $Number | grep "^[[:digit:]]*$")" ]
							then
								INODEUnloadedArray[Number]=$i
								#echo "break"
								#break
								FileVersion=0
								echo $Number
							fi
							FileVersion=$(( FileVersion-1 ))
						done
					fi
				fi
			done
		else
			echo "No Unloaded files"
		fi
		
		declare -a INODENewEleArray
		if [[ $NewEleArray ]]; then
			echo "In NewEleArray Processing"
			for i in "${NewEleArray[@]}"
			do
				Folder="${i%"$strFldSep"*}"
				File="${i##*"$strFldSep"}"
				
				#echo "Folder is"$Folder
				#echo "File is"$File
				
				if [[ $File == *"."* ]]
				then
					DynViewPath="$CCDynPath/$Folder"
					
					#echo "DynViewPath is"$DynViewPath
					
					CmdOP="$(cleartool ls -s -d "${DynViewPath}" 2> Error.txt)"
					CmdErr="$( cat Error.txt )"
					rm Error.txt
					
					#echo "CmdOP is"$CmdOP
					#echo "CmdErr is"$CmdErr
					
					if [ -n "$CmdOP" ]
					then
						INODEFilePath="$CmdOP/$File@@/main/0"
						OutPut="$(ls -i "${INODEFilePath}")"
						Number=${OutPut% *}
						echo $Number
						if [ "$(echo $Number | grep "^[[:digit:]]*$")" ]
						then
							INODENewEleArray[Number]=$i
						fi
					fi
				fi
			done
		else
			echo "No new files"
		fi
		#Array processing for the move and rename file identification
		declare -a DoNotProcessArray
		for i in "${!INODEUnloadedArray[@]}"
		do
			#echo "In for loop"
			if [ -n "${INODENewEleArray[$i]}" ]
			then
				DoNotProcessArray[i]="Do Not Process"
				#echo "In for loop in if cond"
				NewEle="${INODENewEleArray[$i]}"
				UnloEle="${INODEUnloadedArray[$i]}"
				#Fecth the file name
				NewEleFileName="${NewEle##*"$strFldSep"}"
				UnloEleFileName="${UnloEle##*"$strFldSep"}"
				
				if [ "$NewEleFileName" == "$UnloEleFileName" ]; then
					echo "Moved file: "$UnloEle" is moved to "$NewEle
					MovedFileArray+=("$UnloEle:$NewEle")
				else
					echo "Renamed file: "$UnloEle" is renamed to "$NewEle
					RenameFileArray+=("$UnloEle:$NewEle")
				fi
			fi
		done
		#Processing Deleted files Only
		for i in "${!INODEUnloadedArray[@]}"
		do
			if [ -z "${DoNotProcessArray[$i]}" ]
			then
				#echo "Deleted File is ""${INODEUnloadedArray[$i]}"
				DeletedFileArray+=("${INODEUnloadedArray[$i]}")
			fi
		done
		#Processing Newly added files only
		for i in "${!INODENewEleArray[@]}"
		do
			if [ -z "${DoNotProcessArray[$i]}" ]
			then
				echo "Newly added File is ""${INODENewEleArray[$i]}"
				NewFileArray+=("${INODENewEleArray[$i]}")
			fi
		done
	else
		echo "No update log file found."
	fi
else
	echo "Error while running the updating the snapshot view."
fi

echo "Please enter the Perforce workspace folder path"
read P4VPath

printf "\nPerforming Perforce operations\n"
cd $P4VPath
read -p "Enter UserName: " UserName
export P4USER="$UserName"
printf "Please enter the Perforce password to login\n"
p4 login
printf "Please enter the Perforce workspace client name\n"
read P4VClient
P4CLIENT="$P4VClient" ; export P4CLIENT
printf "Showing the Perforce workspace settings"
p4 set
#printf "Syncing the Perforce workspace"
#p4 sync

#Dispalying the Moved files
Var=0
strDem=":"
for i in "${!MovedFileArray[@]}"
do
	Var=1
	#echo "Moved file is ""${MovedFileArray[$i]}"
	Value="${MovedFileArray[$i]}"
	UnloEleFileName="${Value%"$strDem"*}"
	NewEleFileName="${Value##*"$strDem"}"
	WithOutVobUnloEle="${UnloEleFileName#*/}"
	WithOutVobNewEle="${NewEleFileName#*/}"
	cd $P4VPath
	p4 edit "$WithOutVobUnloEle"
	p4 move "$WithOutVobUnloEle" "$WithOutVobNewEle"
	SourcePath="$CCSnpPath/$NewEleFileName"
	#WithOutVob="${Value#*/}"
	DestinPath="$P4VPath/$WithOutVobNewEle"
	DestinFolder="${DestinPath%"$strFldSep"*}"
	if [ ! -d "$DestinFolder" ]; then
		mkdir -p "$DestinFolder"
	fi
	cp -f "$SourcePath" "$DestinPath"
done

if [ "$Var" == 0 ]; then
	echo "No file has been moved."
fi

#Dispalying the Renamed files
Var=0
for i in "${!RenameFileArray[@]}"
do
	Var=1
	#echo "Renamed file is ""${RenameFileArray[$i]}"
	Value="${RenameFileArray[$i]}"
	UnloEleFileName="${Value%"$strDem"*}"
	NewEleFileName="${Value##*"$strDem"}"
	WithOutVobUnloEle="${UnloEleFileName#*/}"
	WithOutVobNewEle="${NewEleFileName#*/}"
	cd $P4VPath
	p4 edit "$WithOutVobUnloEle"
	p4 move "$WithOutVobUnloEle" "$WithOutVobNewEle"
	SourcePath="$CCSnpPath/$NewEleFileName"
	#WithOutVob="${Value#*/}"
	DestinPath="$P4VPath/$WithOutVobNewEle"
	cp -f "$SourcePath" "$DestinPath"
done

if [ "$Var" == 0 ]; then
	echo "No file has been renamed."
fi

#Dispalying the Deleted files
Var=0
for i in "${!DeletedFileArray[@]}"
do
	Var=1
	#echo "Deleted file is ""${DeletedFileArray[$i]}"
	Value="${DeletedFileArray[$i]}"
	WithOutVob="${Value#*/}"
	DestinPath="$P4VPath/$WithOutVob"
	FolderName="${DestinPath%"$strFldSep"*}"
	FileName="${DestinPath##*"$strFldSep"}"
	cd $FolderName
	p4 delete "$FileName"
done

if [ "$Var" == 0 ]; then
	echo "No file has been deleted."
fi

#Dispalying the Newly added files
Var=0
for i in "${!NewFileArray[@]}"
do
	Var=1
	#echo "Newly added file is ""${NewFileArray[$i]}"
	Value="${NewFileArray[$i]}"
	echo "Copying the newly added file from CC snapshot view to P4V workspace"
	SourcePath="$CCSnpPath/$Value"
	WithOutVob="${Value#*/}"
	DestinPath="$P4VPath/$WithOutVob"
	DestinFolder="${DestinPath%"$strFldSep"*}"
	if [ ! -d "$DestinFolder" ]; then
		mkdir -p "$DestinFolder"
	fi
	cp -f "$SourcePath" "$DestinPath"
	FolderName="${DestinPath%"$strFldSep"*}"
	FileName="${DestinPath##*"$strFldSep"}"
	cd $FolderName
	#pwd
	p4 add "$FileName"
done

if [ "$Var" == 0 ]; then
	echo "No file has been newly added."
fi

#Dispalying the Updated files
Var=0
for i in "${!UpdatedFileArray[@]}"
do
	Var=1
	#echo "Updated file is ""${UpdatedFileArray[$i]}"
	Value="${UpdatedFileArray[$i]}"
	echo "Copying the updated file from CC snapshot view to P4V workspace"
	SourcePath="$CCSnpPath/$Value"
	WithOutVob="${Value#*/}"
	DestinPath="$P4VPath/$WithOutVob"
	FolderName="${DestinPath%"$strFldSep"*}"
	FileName="${DestinPath##*"$strFldSep"}"
	cd $FolderName
	#pwd
	p4 edit "$FileName"
	cp -f "$SourcePath" "$DestinPath"
done

if [ "$Var" == 0 ]; then
	echo "No file has been updated."
fi
#Submit command
cd $P4VPath
p4 submit -d all
