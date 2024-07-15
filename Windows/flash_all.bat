@echo off
title Nothing Phone 2a Fastboot ROM Flasher (t.me/NothingPhone2a)

echo #############################################################################
echo #                Pacman Fastboot ROM Flasher                                #
echo #                   Developed/Tested By                                     #
echo #  HELLBOY017, viralbanda, spike0en, PHATwalrus, arter97, AntoninoScordino  #
echo #         Japanese Translation: Re*Index.(ot_inc)                           #
echo #          [Nothing Phone (2a) Telegram Dev Team]                           #
echo #############################################################################

cd %~dp0

if not exist platform-tools-latest (
    curl -L https://dl.google.com/android/repository/platform-tools-latest-windows.zip -o platform-tools-latest.zip
    Call :UnZipFile "%~dp0platform-tools-latest", "%~dp0platform-tools-latest.zip"
    del /f /q platform-tools-latest.zip
)

set fastboot=.\platform-tools-latest\platform-tools\fastboot.exe
if not exist %fastboot% (
    echo Fastboot を実行できません。中止します。
    pause
    exit
)

set boot_partitions=boot dtbo init_boot vendor_boot
set main_partitions=odm_dlkm product system_dlkm vendor_dlkm
set firmware_partitions=apusys audio_dsp ccu connsys_bt connsys_gnss connsys_wifi dpm gpueb gz lk logo mcf_ota mcupm md1img mvpu_algo pi_img scp spmfw sspm tee vcp
set logical_partitions=odm_dlkm odm vendor_dlkm product vendor system_dlkm system_ext system
set vbmeta_partitions=vbmeta vbmeta_system vbmeta_vendor

echo #############################
echo # FASTBOOT デバイスを確認中 #
echo #############################
%fastboot% devices

%fastboot% getvar current-slot 2>&1 | find /c "current-slot: a" > tmpFile.txt
set /p active_slot= < tmpFile.txt
del /f /q tmpFile.txt
if %active_slot% equ 0 (
    echo ###################################
    echo # アクティブスロットを A に変更中 #
    echo ###################################
    call :SetActiveSlot
)
set curSlot=a

echo ####################
echo #  データの初期化  #
echo ###################
choice /m "データを初期化しますか?"
if %errorlevel% equ 1 (
    echo ｢Did you mean to format this partition?｣という警告は無視してください。
    call :ErasePartition userdata
    call :ErasePartition metadata
)

echo ###############################
echo # BOOT パーティションを FLASH #
echo ##############################
choice /m "両方のスロットにイメージを Flash しますか? 不明な場合は｢N｣と入力してください。"
if %errorlevel% equ 1 (
    set slot=all
) else (
    set slot=a
)

if %slot% equ all (
    for %%i in (%boot_partitions%) do (
        for %%s in (a b) do (
            call :FlashImage %%i_%%s, %%i.img
        )
    ) 
) else (
    for %%i in (%boot_partitions%) do (
        call :FlashImage %%i_%slot%, %%i.img
    )
)

echo ##########################
echo # ファームウェアを FLASH #
echo #########################
if %slot% equ all (
    for %%i in (%firmware_partitions%) do (
        for %%s in (a b) do (
            call :FlashImage %%i_%%s, %%i.img
        )
    ) 
) else (
    for %%i in (%firmware_partitions%) do (
        call :FlashImage %%i_%slot%, %%i.img
    )
)

:: 'preloader_raw.img' must be flashed at a different partition name
if %slot% equ all (
    for %%s in (a b) do (
            call :FlashImage preloader_%%s, preloader_raw.img
        ) 
) else (
    call :FlashImage preloader_%slot%, preloader_raw.img
)

echo ###################
echo # VBMETA を FLASH #
echo ###################
choice /m "Android Verified Boot を無効化しますか? 不明な場合は｢N｣を入力してください。｢Y｣を入力した場合、Bootloader のロックができなくなります。"
if %errorlevel% equ 1 (
    if %slot% equ all (
        for %%i in (%vbmeta_partitions%) do (
            for %%s in (a b) do (
                call :FlashImage "%%i_%%s --disable-verity --disable-verification", %%i.img
            )
        ) 
    ) else (
        for %%i in (%vbmeta_partitions%) do (
            call :FlashImage "%%i_%slot% --disable-verity --disable-verification", %%i.img
        )
    )
) else (
    set avb_enabled=1
    if %slot% equ all (
        for %%i in (%vbmeta_partitions%) do (
            for %%s in (a b) do (
                call :FlashImage "%%i_%%s", %%i.img
            )
        ) 
    ) else (
        for %%i in (%vbmeta_partitions%) do (
            call :FlashImage "%%i_%slot%", %%i.img
        )
    )
)

echo ##########################
echo #   FASTBOOTD で再起動   #
echo ##########################
%fastboot% reboot fastboot
if %errorlevel% neq 0 (
    echo fastboot の再起動中にエラーが発生しました。中止します。
    pause
    exit
)

echo ################################
echo #  論理パーティションに FLASH  #
echo ###############################
echo 論理パーティションにイメージを Flash しますか?
echo 独自の論理パーティションで配布をするカスタム ROM をインストールする場合は｢N｣を入力してください。
choice /m "不明な場合は｢Y｣と入力してください。"
if %errorlevel% equ 1 (
    if not exist super.img (
        if exist super_empty.img (
            call :WipeSuperPartition
        ) else (
            call :ResizeLogicalPartition
        )
        for %%i in (%logical_partitions%) do (
            call :FlashImage %%i_%curSlot%, %%i.img
        )
    ) else (
        call :FlashImage super, super.img
    )
)

echo #########################
echo #  BOOTLOADER のロック  #
echo ########################
if %avb_enabled% equ 1 (
    choice /m "Bootloader をロックしますか?不明な場合は｢N｣を入力してください。"
    if %errorlevel% equ 1 (
        %fastboot% reboot bootloader
        if %errorlevel% neq 0 (
            echo Bootloader の再起動中にエラーが発生しました。中止します。
            pause
            exit
        ) else (
            %fastboot% flashing lock
        )
    )
)

echo ##########
echo # 再起動 #
echo #########
choice /m "システムを再起動しますか?不明な場合は｢Y｣を入力してください。"
if %errorlevel% equ 1 (
    %fastboot% reboot
)

echo ########
echo # 完了 #
echo ########
echo Stock ファームウェアが復元されました。
echo Android Verified Boot を無効化していない場合は、オプションで Bootloader をロックすることができます。

pause
exit

:UnZipFile
if not exist "%~dp0platform-tools-latest" (
    powershell -command "Expand-Archive -Path '%~dp0platform-tools-latest.zip' -DestinationPath '%~dp0platform-tools-latest' -Force"
)
exit /b

:ErasePartition
%fastboot% erase %~1
if %errorlevel% neq 0 (
    call :Choice "Erasing %~1 partition failed"
)
exit /b

:SetActiveSlot
%fastboot% --set-active=a
if %errorlevel% neq 0 (
    echo Error occured while switching to slot A. Aborting
    pause
    exit
)
exit /b

:WipeSuperPartition
%fastboot% wipe-super super_empty.img
if %errorlevel% neq 0 (
    echo Wiping super partition failed. Fallback to deleting and creating logical partitions
    call :ResizeLogicalPartition
)
exit /b

:ResizeLogicalPartition
for %%i in (%logical_partitions%) do (
    for %%s in (a b) do (
        call :DeleteLogicalPartition %%i_%%s-cow
        call :DeleteLogicalPartition %%i_%%s
    )
    call :CreateLogicalPartition %%i_%curSlot%, 1
)
exit /b

:DeleteLogicalPartition
%fastboot% delete-logical-partition %~1
if %errorlevel% neq 0 (
    call :Choice "Deleting %~1 partition failed"
)
exit /b

:CreateLogicalPartition
%fastboot% create-logical-partition %~1 %~2
if %errorlevel% neq 0 (
    call :Choice "Creating %~1 partition failed"
)
exit /b

:FlashImage
%fastboot% flash %~1 %~2
if %errorlevel% neq 0 (
    call :Choice "Flashing %~2 failed"
)
exit /b

:Choice
choice /m "%~1 continue? If unsure say N"
if %errorlevel% equ 2 (
    exit
)
exit /b
