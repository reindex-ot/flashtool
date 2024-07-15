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
    echo Fastboot �����s�ł��܂���B���~���܂��B
    pause
    exit
)

set boot_partitions=boot dtbo init_boot vendor_boot
set main_partitions=odm_dlkm product system_dlkm vendor_dlkm
set firmware_partitions=apusys audio_dsp ccu connsys_bt connsys_gnss connsys_wifi dpm gpueb gz lk logo mcf_ota mcupm md1img mvpu_algo pi_img scp spmfw sspm tee vcp
set logical_partitions=odm_dlkm odm vendor_dlkm product vendor system_dlkm system_ext system
set vbmeta_partitions=vbmeta vbmeta_system vbmeta_vendor

echo #############################
echo # FASTBOOT �f�o�C�X���m�F�� #
echo #############################
%fastboot% devices

%fastboot% getvar current-slot 2>&1 | find /c "current-slot: a" > tmpFile.txt
set /p active_slot= < tmpFile.txt
del /f /q tmpFile.txt
if %active_slot% equ 0 (
    echo ###################################
    echo # �A�N�e�B�u�X���b�g�� A �ɕύX�� #
    echo ###################################
    call :SetActiveSlot
)
set curSlot=a

echo ####################
echo #  �f�[�^�̏�����  #
echo ###################
choice /m "�f�[�^�����������܂���?"
if %errorlevel% equ 1 (
    echo �Did you mean to format this partition?��Ƃ����x���͖������Ă��������B
    call :ErasePartition userdata
    call :ErasePartition metadata
)

echo ###############################
echo # BOOT �p�[�e�B�V������ FLASH #
echo ##############################
choice /m "�����̃X���b�g�ɃC���[�W�� Flash ���܂���? �s���ȏꍇ�͢N��Ɠ��͂��Ă��������B"
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
echo # �t�@�[���E�F�A�� FLASH #
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
echo # VBMETA �� FLASH #
echo ###################
choice /m "Android Verified Boot �𖳌������܂���? �s���ȏꍇ�͢N�����͂��Ă��������B�Y�����͂����ꍇ�ABootloader �̃��b�N���ł��Ȃ��Ȃ�܂��B"
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
echo #   FASTBOOTD �ōċN��   #
echo ##########################
%fastboot% reboot fastboot
if %errorlevel% neq 0 (
    echo fastboot �̍ċN�����ɃG���[���������܂����B���~���܂��B
    pause
    exit
)

echo ################################
echo #  �_���p�[�e�B�V������ FLASH  #
echo ###############################
echo �_���p�[�e�B�V�����ɃC���[�W�� Flash ���܂���?
echo �Ǝ��̘_���p�[�e�B�V�����Ŕz�z������J�X�^�� ROM ���C���X�g�[������ꍇ�͢N�����͂��Ă��������B
choice /m "�s���ȏꍇ�͢Y��Ɠ��͂��Ă��������B"
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
echo #  BOOTLOADER �̃��b�N  #
echo ########################
if %avb_enabled% equ 1 (
    choice /m "Bootloader �����b�N���܂���?�s���ȏꍇ�͢N�����͂��Ă��������B"
    if %errorlevel% equ 1 (
        %fastboot% reboot bootloader
        if %errorlevel% neq 0 (
            echo Bootloader �̍ċN�����ɃG���[���������܂����B���~���܂��B
            pause
            exit
        ) else (
            %fastboot% flashing lock
        )
    )
)

echo ##########
echo # �ċN�� #
echo #########
choice /m "�V�X�e�����ċN�����܂���?�s���ȏꍇ�͢Y�����͂��Ă��������B"
if %errorlevel% equ 1 (
    %fastboot% reboot
)

echo ########
echo # ���� #
echo ########
echo Stock �t�@�[���E�F�A����������܂����B
echo Android Verified Boot �𖳌������Ă��Ȃ��ꍇ�́A�I�v�V������ Bootloader �����b�N���邱�Ƃ��ł��܂��B

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
