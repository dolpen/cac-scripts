#!/bin/bash

# mod 等は /home/${SERVICE_USER}/Mods に scp で転送することをおすすめします
# （manager でも mod 更新はどのみち手作業だし、クラサバ同期の確実性を考えると一番楽です）

set -e

## Args

# shellcheck disable=SC2016
echo "${SERVICE_PASS:?'run this script with `SERVICE_PASS` env variable'}" >/dev/null
# shellcheck disable=SC2016
echo "${ADMIN_PASS:?'run this script with `ADMIN_PASS` env variable'}" >/dev/null

SERVER_MAP=TheIsland
SERVICE_USER=steam
SERVICE_NAME=ark
SERVICE_TITLE="[po]${SERVER_MAP}"
SERVICE_PORT=7777
QUERY_PORT=27015
ADDITIONAL_ARG=""
# -automanagemods は 現状ちゃんと動いていない
# ConfigのModInstallerセクションに ModID記載してると謎の内部動作で ${modid}.mod ファイルが消えたりするので何も設定書かないのが正解
# ADDITIONAL_ARG="-automanagemods"

SERVICE_HOME=/home/${SERVICE_USER}
STEAMCMD_HOME=${SERVICE_HOME}/steamcmd
APPLICATION_HOME="${SERVICE_HOME}/Steam/steamapps/common/ARK Survival Evolved Dedicated Server"
INNER_STEAM_HOME=${APPLICATION_HOME}/Engine/Binaries/ThirdParty/SteamCMD/Linux

## Utils

# 1:user,2:command
exec_as() {
su "$1" -c "$2"
}
# 2:owner,3:permission,1:path,stdin:content
put_file() {
cat - > "$3"
chown "$1:$1" "$3"
chmod "$2" "$3"
}
# 1:owner,2:permission,3:path
make_dir() {
su "$1" -c "mkdir -p \"$3\""
chown "$1:$1" "$3"
chmod "$2" "$3"
}

# 1:owner, 2:origin_path, 3:symbol_path
make_link() {
ln -fs "$2" "$3"
chown -h "$1:$1" "$3"
}

# 1:owner, 2:permission, 3:origin_path, 4:symbol_path
copy_file() {
cp -f "$3" "$4"
chown "$1:$1" "$4"
chmod "$2" "$4"
}

## Misc.

localectl set-locale LANG=ja_JP.utf8
timedatectl set-timezone Asia/Tokyo

put_file root 755 /tmp/crontab.temp <<EOT
15 6 * * * /sbin/reboot
EOT

crontab -u root /tmp/crontab.temp

## Libs

yum -y install ld-linux.so.2 SDL.x86_64

## Network


firewall-cmd --add-port=${SERVICE_PORT}/udp --zone=public --permanent
firewall-cmd --add-port=${QUERY_PORT}/udp --zone=public --permanent
firewall-cmd --reload

# App User

useradd ${SERVICE_USER}
make_dir ${SERVICE_USER} 755 /home/${SERVICE_USER}/.ssh
put_file ${SERVICE_USER} 644 /home/${SERVICE_USER}/.ssh/authorized_keys <<EOT
ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBM00pdbmU5T0w1FNKhXvRxFOY0Uj/dyvE2s63PlJAXaGwZo/WApia1DCnXB6zpNQB5xreb5jNdRR3fpnJmkrQ3Y= dolpen@dolpen.net
ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAje5AzaJgX02bMD/tuRhyqYwDXsyMg0c1NrxlQWRXGb41hViGsbQltQRGJo8rbVTNZJfMEUBmj0PtrwSp18q+avoSuNDNlDn8MmoLuYIMKIVCZuNvJWz5OQ5bVWA5hUoWq58Gp1/3ZQ3Oj9/owRelCwLXf9aohdhsYthXuEGfhsqAGnA7BSV9I29XF1YWI/xmY/hVVqlIFUBkziu9YWLhU8E35f+UBM8vX2YtjqaeXiQPaGz5RIF7SXsCi3fSj3F/jFKaCHbMtPcK1voqpiRveOm36HayCGmMlniVpvPQ8czREKrrjE7cRoxB87b5S4B+7DcLE9gKnrijoC9k/UKPKw==
EOT


## Service

put_file root 755 /etc/systemd/system/${SERVICE_NAME}.service <<EOT
[Unit]
Description=ARK: Survival Evolved dedicated server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target
[Service]
ExecStartPre=/home/${SERVICE_USER}/steamcmd/steamcmd.sh +login anonymous +app_update 376030 +quit
ExecStart=/home/${SERVICE_USER}/Steam/steamapps/common/ARK\x20Survival\x20Evolved\x20Dedicated\x20Server/ShooterGame/Binaries/Linux/ShooterGameServer ${SERVER_MAP}?listen -server -log ${ADDITIONAL_ARG}
LimitNOFILE=100000
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s INT $MAINPID
User=${SERVICE_USER}
Group=${SERVICE_USER}
TimeoutSec=15min
[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}

## Application & Links
make_dir ${SERVICE_USER} 755 ${STEAMCMD_HOME}
pushd ${STEAMCMD_HOME}
exec_as ${SERVICE_USER} "curl -sqL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar zxvf -"
exec_as ${SERVICE_USER} "chmod a+x steamcmd.sh"
exec_as ${SERVICE_USER} "./steamcmd.sh +login anonymous +app_update 376030 +quit"
popd
make_dir ${SERVICE_USER} 755 "${INNER_STEAM_HOME}"
make_dir ${SERVICE_USER} 755 "${APPLICATION_HOME}/ShooterGame/Saved/Config/LinuxServer"
make_link ${SERVICE_USER} "${APPLICATION_HOME}/" "${SERVICE_HOME}/ark"
make_link ${SERVICE_USER} "${APPLICATION_HOME}/ShooterGame/Content/Mods/" "${SERVICE_HOME}/Mods"
make_link ${SERVICE_USER} "${APPLICATION_HOME}/ShooterGame/Saved/Config/LinuxServer/" "${SERVICE_HOME}/Config"
copy_file ${SERVICE_USER} 755 "${STEAMCMD_HOME}/steamcmd.sh" "${INNER_STEAM_HOME}/steamcmd.sh"
make_link ${SERVICE_USER} "${STEAMCMD_HOME}/linux32/" "${INNER_STEAM_HOME}/linux32"
make_link ${SERVICE_USER} "${STEAMCMD_HOME}/linux64/" "${INNER_STEAM_HOME}/linux64"
make_link ${SERVICE_USER} "${STEAMCMD_HOME}/package/" "${INNER_STEAM_HOME}/package"
make_link ${SERVICE_USER} "${STEAMCMD_HOME}/public/" "${INNER_STEAM_HOME}/public"
make_link ${SERVICE_USER} "${STEAMCMD_HOME}/siteserverui/" "${INNER_STEAM_HOME}/siteserverui"
make_link ${SERVICE_USER} "${SERVICE_HOME}/Steam/steamapps/" "${INNER_STEAM_HOME}/steamapps"

put_file ${SERVICE_USER} 644 ${SERVICE_HOME}/Config/Game.ini  <<EOT
[/Script/ShooterGame.ShooterGameMode]
bPvEDisableFriendlyFire=True
bDisableFriendlyFire=True
CropGrowthSpeedMultiplier=10
bAllowUnlimitedRespecs=True
bFlyerPlatformAllowUnalignedDinoBasing=True
bDisableStructurePlacementCollision=True
ResourceNoReplenishRadiusPlayers=0.5
ResourceNoReplenishRadiusStructures=0.2
MatingSpeedMultiplier=30
EggHatchSpeedMultiplier=50
BabyMatureSpeedMultiplier=50
BabyImprintingStatScaleMultiplier=2
BabyCuddleIntervalMultiplier=0.02
BabyCuddleGracePeriodMultiplier=2
BabyCuddleLoseImprintQualitySpeedMultiplier=0.01
ActiveMods=849985437,895711211,1440414363
EOT

put_file ${SERVICE_USER} 644 ${SERVICE_HOME}/Config/GameUserSettings.ini <<EOT
[ServerSettings]
ShowMapPlayerLocation=True
allowThirdPersonPlayer=True
ServerCrosshair=True
ServerPassword=${SERVICE_PASS}
ServerAdminPassword=${ADMIN_PASS}
RCONPort=27020
TheMaxStructuresInRange=10500.000000
OxygenSwimSpeedStatMultiplier=1.000000
StructurePreventResourceRadiusMultiplier=1.000000
TribeNameChangeCooldown=15.000000
PlatformSaddleBuildAreaBoundsMultiplier=1.000000
StructurePickupTimeAfterPlacement=120.000000
StructurePickupHoldDuration=0.500000
AllowIntegratedSPlusStructures=True
AllowHideDamageSourceFromLogs=True
PlayerCharacterWaterDrainMultiplier=0.500000
PlayerCharacterFoodDrainMultiplier=0.500000
ResourcesRespawnPeriodMultiplier=0.300000
RaidDinoCharacterFoodDrainMultiplier=1.000000
PvEDinoDecayPeriodMultiplier=1.000000
KickIdlePlayersPeriod=3600.000000
PerPlatformMaxStructuresMultiplier=1.000000
AutoSavePeriodMinutes=15.000000
ListenServerTetherDistanceMultiplier=1.000000
MaxTamedDinos=5000.000000
ItemStackSizeMultiplier=1.000000
RCONServerGameLogBuffer=600.000000
AllowHitMarkers=True
serverPVE=True
DifficultyOffset=5.0
OverrideOfficialDifficulty=5.0
bUseCorpseLocator=True
ShowFloatingDamageText=True
DisableWeatherFog=True
alwaysNotifyPlayerJoined=True
alwaysNotifyPlayerLeft=True
AllowRaidDinoFeeding=True
AllowFlyerCarryPvE=True
NightTimeSpeedScale=10.0
TamingSpeedMultiplier=50.0
XPMultiplier=2.5
HarvestAmountMultiplier=5.0
ActiveMods=849985437,895711211,1440414363

[/Script/ShooterGame.ShooterGameUserSettings]
MasterAudioVolume=1.000000
MusicAudioVolume=1.000000
SFXAudioVolume=1.000000
VoiceAudioVolume=1.000000
UIScaling=1.000000
UIQuickbarScaling=0.650000
CameraShakeScale=0.650000
bFirstPersonRiding=False
bThirdPersonPlayer=False
bShowStatusNotificationMessages=True
TrueSkyQuality=0.000000
FOVMultiplier=1.000000
GroundClutterDensity=0.000000
bFilmGrain=False
bMotionBlur=False
bUseDistanceFieldAmbientOcclusion=False
bUseSSAO=False
bShowChatBox=True
bCameraViewBob=True
bInvertLookY=False
bFloatingNames=True
bChatBubbles=True
bHideServerInfo=False
bJoinNotifications=False
bCraftablesShowAllItems=False
bLocalInventoryItemsShowAllItems=False
bLocalInventoryCraftingShowAllItems=True
bRemoteInventoryItemsShowAllItems=False
bRemoteInventoryCraftingShowAllItems=False
bRemoteInventoryShowEngrams=True
LookLeftRightSensitivity=1.000000
LookUpDownSensitivity=1.000000
GraphicsQuality=1
ActiveLingeringWorldTiles=1
ClientNetQuality=3
LastServerSearchType=0
LastServerSort=2
LastPVESearchType=-1
LastDLCTypeSearchType=-1
LastServerSortAsc=True
LastAutoFavorite=True
LastServerSearchHideFull=False
LastServerSearchProtected=False
HideItemTextOverlay=True
bQuickToggleItemNames=True
bDistanceFieldShadowing=False
LODScalar=0.780000
bToggleToTalk=False
HighQualityMaterials=True
HighQualitySurfaces=True
bTemperatureF=False
bDisableTorporEffect=False
bChatShowSteamName=False
bChatShowTribeName=True
bReverseTribeLogOrder=False
EmoteKeyBind1=0
EmoteKeyBind2=0
bNoBloodEffects=False
bLowQualityVFX=False
bSpectatorManualFloatingNames=False
bSuppressAdminIcon=False
bUseSimpleDistanceMovement=False
bDisableMeleeCameraSwingAnims=False
bHighQualityAnisotropicFiltering=False
bUseLowQualityLevelStreaming=True
bPreventInventoryOpeningSounds=False
bPreventItemCraftingSounds=False
bPreventHitMarkers=False
bPreventCrosshair=False
bPreventColorizedItemNames=False
bHighQualityLODs=False
bExtraLevelStreamingDistance=False
bEnableColorGrading=True
DOFSettingInterpTime=0.000000
bDisableBloom=False
bDisableLightShafts=False
LastJoinedSessionPerCategory=" "
LastJoinedSessionPerCategory=" "
LastJoinedSessionPerCategory=" "
LastJoinedSessionPerCategory=" "
LastJoinedSessionPerCategory=" "
LastJoinedSessionPerCategory=" "
LastJoinedSessionPerCategory=" "
LastJoinedSessionPerCategory=" "
LastJoinedSessionPerCategory=" "
bDisableMenuTransitions=False
bEnableInventoryItemTooltips=True
bRemoteInventoryShowCraftables=False
bNoTooltipDelay=False
LocalItemSortType=0
LocalCraftingSortType=0
RemoteItemSortType=0
RemoteCraftingSortType=0
VersionMetaTag=1
ShowExplorerNoteSubtitles=False
DisableMenuMusic=False
DisableDefaultCharacterItems=False
bHideFloatingPlayerNames=False
bHideGamepadItemSelectionModifier=False
bToggleExtendedHUDInfo=False
PlayActionWheelClickSound=True
MaxAscensionLevel=0
bHostSessionHasBeenOpened=False
bForceTPVCameraOffset=False
bDisableTPVCameraInterpolation=False
bFPVClimbingGear=False
bFPVGlidingGear=False
Gamma1=2.200000
Gamma2=3.000000
AmbientSoundVolume=1.000000
bAllowAnimationStaggering=True
bUseOldThirdPersonCameraTrace=False
bUseOldThirdPersonCameraOffset=False
bLowQualityAnimations=True
bUseVSync=False
MacroCtrl0=
MacroCtrl1=
MacroCtrl2=
MacroCtrl3=
MacroCtrl4=
MacroCtrl5=
MacroCtrl6=
MacroCtrl7=
MacroCtrl8=
MacroCtrl9=
ResolutionSizeX=1280
ResolutionSizeY=720
LastUserConfirmedResolutionSizeX=1280
LastUserConfirmedResolutionSizeY=720
WindowPosX=-1
WindowPosY=-1
bUseDesktopResolutionForFullscreen=False
FullscreenMode=2
LastConfirmedFullscreenMode=2
Version=5

[ScalabilityGroups]
sg.ResolutionQuality=100
sg.ViewDistanceQuality=3
sg.AntiAliasingQuality=3
sg.ShadowQuality=3
sg.PostProcessQuality=3
sg.TextureQuality=3
sg.EffectsQuality=3
sg.TrueSkyQuality=3
sg.GroundClutterQuality=3
sg.IBLQuality=1
sg.HeightFieldShadowQuality=3
sg.GroundClutterRadius=10000

[SessionSettings]
SessionName=${SERVICE_TITLE}

[/Script/Engine.GameSession]
MaxPlayers=16
EOT
