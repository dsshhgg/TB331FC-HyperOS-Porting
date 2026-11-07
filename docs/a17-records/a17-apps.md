# A17（HyperOS 4 / CP2A.260605.016）装机应用清单

采集时间：2026-10-26 12:1x ｜ 来源：`adb shell pm list packages -f` ｜ 共 **293** 个包

## 分区分布

| 分区 | 数量 | 说明 |
|---|---|---|
| product | 129 | 小米/澎湃自有应用与 overlay（可增删） |
| system_ext | 60 | 系统扩展（Settings、Provision 等） |
| system | 59 | AOSP 核心 |
| apex | 28 | APEX 模块内应用（如 GMS） |
| vendor | 9 | 厂商（勿动） |
| data | 8 | data 分区更新（可直接卸载） |

## 关键结论（实测）

- 默认桌面：`com.miui.home`（/product/priv-app/MiuiHome）
- **没有任何相机应用**（com.android.camera / com.miui.camera / MiuiCamera 全未装）
- **没有图库**（com.miui.gallery / com.android.gallery3d 未装）
- **没有浏览器、没有文件管理器**（com.android.documentsui 未装）
- GMS 存在：`com.google.android.gms`（来自 /apex/com.google.android.gmssystem）
- 没有 Play 商店（com.android.vending 未装）

## 全部包（按分区）

### product（129）

| 包名 | APK 路径 |
|---|---|
| `android.aosp.overlay` | `/product/overlay/AospFrameworkResOverlay.apk` |
| `android.aosp.overlay.telephony` | `/product/overlay/AospFrameworkTelephonyResOverlay.apk` |
| `android.auto_generated_characteristics_rro` | `/product/overlay/framework-res__tablet__auto_generated_characteristics_rro.apk` |
| `android.miui.overlay` | `/product/overlay/MiuiFrameworkResOverlay.apk` |
| `android.miui.overlay.telephony` | `/product/overlay/MiuiFrameworkTelephonyResOverlay.apk` |
| `android.overlay.common` | `/product/overlay/FrameworksResCommon_Sys.apk` |
| `android.qvaoverlay.common` | `/product/overlay/FrameworksResCommonQva_Sys.apk` |
| `com.android.bluetooth.overlay` | `/product/overlay/AospBluetoothResOverlay.apk` |
| `com.android.carrierconfig.overlay.common` | `/product/overlay/CarrierConfigResCommon_Sys.apk` |
| `com.android.cellbroadcastreceiver.overlay.common` | `/product/overlay/CellBroadcastReceiverResCommon_Sys.apk` |
| `com.android.companiondevicemanager.auto_generated_characteristics_rro` | `/product/overlay/CompanionDeviceManager__tablet__auto_generated_characteristics_rro.apk` |
| `com.android.contacts` | `/product/priv-app/MIUIContactsPad/MIUIContactsPad.apk` |
| `com.android.credentialmanager` | `/product/app/MiuiCredentialManager/MiuiCredentialManager.apk` |
| `com.android.fileexplorer` | `/product/app/MIUIFileExplorer/MIUIFileExplorer.apk` |
| `com.android.imsserviceentitlement` | `/product/priv-app/ImsServiceEntitlement/ImsServiceEntitlement.apk` |
| `com.android.incallui` | `/product/priv-app/InCallUI/InCallUI.apk` |
| `com.android.inputsettings.overlay.miui` | `/product/overlay/MiuiSecurityCoreOverlay.apk` |
| `com.android.internal.display.cutout.emulation.corner` | `/product/overlay/DisplayCutoutEmulationCorner/DisplayCutoutEmulationCornerOverlay.apk` |
| `com.android.internal.display.cutout.emulation.double` | `/product/overlay/DisplayCutoutEmulationDouble/DisplayCutoutEmulationDoubleOverlay.apk` |
| `com.android.internal.display.cutout.emulation.hole` | `/product/overlay/DisplayCutoutEmulationHole/DisplayCutoutEmulationHoleOverlay.apk` |
| `com.android.internal.display.cutout.emulation.tall` | `/product/overlay/DisplayCutoutEmulationTall/DisplayCutoutEmulationTallOverlay.apk` |
| `com.android.internal.display.cutout.emulation.waterfall` | `/product/overlay/DisplayCutoutEmulationWaterfall/DisplayCutoutEmulationWaterfallOverlay.apk` |
| `com.android.internal.systemui.navbar.gestural` | `/product/overlay/NavigationBarModeGestural/NavigationBarModeGesturalOverlay.apk` |
| `com.android.internal.systemui.navbar.threebutton` | `/product/overlay/NavigationBarMode3Button/NavigationBarMode3ButtonOverlay.apk` |
| `com.android.internal.systemui.navbar.transparent` | `/product/overlay/TransparentNavigationBar/TransparentNavigationBarOverlay.apk` |
| `com.android.managedprovisioning.overlay` | `/product/overlay/ManagedProvisioningResOverlay.apk` |
| `com.android.modulemetadata` | `/product/app/ModuleMetadata/ModuleMetadata.apk` |
| `com.android.ncm.overlay.common` | `/product/overlay/NcmTetheringResCommon_Sys.apk` |
| `com.android.networkstack.overlay.miui` | `/product/overlay/NetworkStackOverlay.apk` |
| `com.android.overlay.cngmstelecomm` | `/product/overlay/GmsCnTelecommOverlay.apk` |
| `com.android.overlay.gmscontactprovider` | `/product/overlay/GmsContactProviderOverlay.apk` |
| `com.android.overlay.gmssettingprovider` | `/product/overlay/GmsSettingProviderOverlay.apk` |
| `com.android.overlay.gmssettings` | `/product/overlay/GmsCnSettingsOverlay.apk` |
| `com.android.overlay.systemui` | `/product/overlay/GmsCnSystemUIOverlay.apk` |
| `com.android.phone.auto_generated_characteristics_rro` | `/product/overlay/TeleService__tablet__auto_generated_characteristics_rro.apk` |
| `com.android.phone.overlay.common` | `/product/overlay/TelephonyResCommon_Sys.apk` |
| `com.android.phone.overlay.miui` | `/product/overlay/MiuiTelephonyResOverlay.apk` |
| `com.android.providers.settings.overlay` | `/product/overlay/SettingsProviderCustResOverlay.apk` |
| `com.android.providers.telephony.auto_generated_characteristics_rro` | `/product/overlay/TelephonyProvider__tablet__auto_generated_characteristics_rro.apk` |
| `com.android.providers.telephony.overlay.miui` | `/product/overlay/MiuiTelephonyProviderResOverlay.apk` |
| `com.android.quicksearchbox` | `/product/priv-app/QuickSearchBoxPadMIUI15/QuickSearchBoxPadMIUI15.apk` |
| `com.android.role.notes.enabled` | `/product/overlay/NotesRoleEnabled/NotesRoleEnabledOverlay.apk` |
| `com.android.server.telecom.overlay.common` | `/product/overlay/TelecommResCommon_Sys.apk` |
| `com.android.server.telecom.overlay.miui` | `/product/overlay/MiuiTelecomResOverlay.apk` |
| `com.android.settings.intelligence` | `/product/priv-app/SettingsIntelligence/SettingsIntelligence.apk` |
| `com.android.settings.overlay.common` | `/product/overlay/SettingsResCommon_Sys.apk` |
| `com.android.settings.overlay.miui` | `/product/overlay/MiuiSettingsResOverlay.apk` |
| `com.android.systemui.gesture.line.overlay` | `/product/overlay/GestureLineOverlay.apk` |
| `com.android.systemui.navigation.bar.overlay` | `/product/overlay/ElderlyNavigationBarOverlay.apk` |
| `com.android.systemui.overlay.common` | `/product/overlay/SystemUIResCommon_Sys.apk` |
| `com.android.systemui.overlay.miui` | `/product/overlay/MiuiSystemUIResOverlay.apk` |
| `com.android.theme.font.notoserifsource` | `/product/overlay/FontNotoSerifSource/FontNotoSerifSourceOverlay.apk` |
| `com.android.thememanager` | `/product/app/MIUIThemeManagerPad/MIUIThemeManagerPad.apk` |
| `com.android.thememanager.customthemeconfig.config.overlay` | `/product/overlay/MiuiThemeManagerCnOverlay.apk` |
| `com.android.updater` | `/product/app/Updater/Updater.apk` |
| `com.android.uwb.resources.overlay.common` | `/product/overlay/UwbResCommon_Sys.apk` |
| `com.android.wifi.resources.overlay.common` | `/product/overlay/WifiResCommon_Sys.apk` |
| `com.android.wifi.resources.xiaomi` | `/product/overlay/AospWifiResOverlay.apk` |
| `com.gms.android.ncm.overlay.common` | `/product/overlay/NcmTetheringResCommonGMS_Sys.apk` |
| `com.google.android.cellbroadcastreceiver.overlay.miui` | `/product/overlay/MiuiCellBroadcastReceiverOverlay.apk` |
| `com.google.android.cellbroadcastservice.overlay.miui` | `/product/overlay/MiuiCellBroadcastServiceOverlay.apk` |
| `com.google.android.configupdater` | `/product/priv-app/ConfigUpdater/ConfigUpdater.apk` |
| `com.google.android.overlay.gmsconfig` | `/product/overlay/GmsCnConfigOverlay.apk` |
| `com.google.android.uwb.resources.overlay.common` | `/product/overlay/UwbResCommonMainline_Sys.apk` |
| `com.google.android.webview` | `/product/app/WebViewGoogle64/WebViewGoogle64.apk` |
| `com.google.android.wifi.resources.overlay.common` | `/product/overlay/WifiResCommonMainline_Sys.apk` |
| `com.google.android.wifi.resources.xiaomi` | `/product/overlay/AospWifiResOverlay_mainline.apk` |
| `com.milink.service` | `/product/app/MiLinkOS4Cn/MiLinkOS4Cn.apk` |
| `com.miui.accessibility` | `/product/priv-app/MIUIAccessibility/MIUIAccessibility.apk` |
| `com.miui.cloudservice` | `/product/app/MIUICloudService/MIUICloudService.apk` |
| `com.miui.contentcatcher` | `/product/app/ContentCatcherOS4/ContentCatcherOS4.apk` |
| `com.miui.core` | `/product/app/XmsCore/XmsCore.apk` |
| `com.miui.core.internal.services` | `/product/overlay/MiuiServiceOverlay/MiuiServiceOverlay.apk` |
| `com.miui.greenguard` | `/product/app/MIUIgreenguard/MIUIgreenguard.apk` |
| `com.miui.guardprovider` | `/product/app/MIUIGuardProvider/MIUIGuardProvider.apk` |
| `com.miui.home` | `/product/priv-app/MiuiHome/MiuiHome.apk` |
| `com.miui.mediaviewer` | `/product/app/MediaViewer/MediaViewer.apk` |
| `com.miui.micloudsync` | `/product/app/MIUIMiCloudSync/MIUIMiCloudSync.apk` |
| `com.miui.mishare.connectivity` | `/product/priv-app/MIShare/MIShare.apk` |
| `com.miui.misound` | `/product/app/MiSound/MiSound.apk` |
| `com.miui.miwallpaper` | `/product/app/MiWallpaper/MiWallpaper.apk` |
| `com.miui.miwallpaper.config.overlay` | `/product/overlay/MIWallpaperOverlay.apk` |
| `com.miui.miwallpaper.overlay.customize` | `/product/overlay/MiuiCustomizeLockscreenOverlay.apk` |
| `com.miui.notification` | `/product/app/MIUINotificationCenter/MIUINotificationCenter.apk` |
| `com.miui.packageinstaller` | `/product/priv-app/MIUIPackageInstallerVariants/MIUIPackageInstallerVariants.apk` |
| `com.miui.passwords` | `/product/app/MiuiPasswords/MiuiPasswords.apk` |
| `com.miui.phrase` | `/product/app/MIUIFrequentPhrase/MIUIFrequentPhrase.apk` |
| `com.miui.powerinsight.overlay` | `/product/overlay/MiuiPowerInsightOverlay.apk` |
| `com.miui.screenshot` | `/product/app/MIUIScreenshot/MIUIScreenshot.apk` |
| `com.miui.securityadd` | `/product/app/MIUISecurityAdd/MIUISecurityAdd.apk` |
| `com.miui.securitycenter` | `/product/priv-app/MIUISecurityCenterPad/MIUISecurityCenterPad.apk` |
| `com.miui.securitycore` | `/product/app/SecurityCoreAdd/SecurityCoreAdd.apk` |
| `com.miui.securityinputmethod` | `/product/app/MIUISecurityInputMethod/MIUISecurityInputMethod.apk` |
| `com.miui.settings.rro.common.overlay` | `/product/overlay/SettingsRroCommonOverlay.apk` |
| `com.miui.settings.rro.device.config.overlay` | `/product/overlay/SettingsRroDeviceConfigOverlay.apk` |
| `com.miui.settings.rro.device.systemui.overlay` | `/product/overlay/SettingsRroDeviceSystemUiOverlay.apk` |
| `com.miui.settings.rro.device.type.overlay` | `/product/overlay/SettingsRroDeviceTypeOverlay.apk` |
| `com.miui.system.overlay` | `/product/overlay/MiuiSystemSdkResOverlay.apk` |
| `com.miui.systemAdSolution` | `/product/app/MSA/MSA.apk` |
| `com.miui.systemui.carriers.overlay` | `/product/overlay/MccMncOverlay.apk` |
| `com.miui.systemui.devices.overlay` | `/product/overlay/DevicesOverlay.apk` |
| `com.miui.systemui.overlay.devices.android` | `/product/overlay/DevicesAndroidOverlay.apk` |
| `com.miui.timezone.location.provider` | `/product/priv-app/MiuiLocationTimeZoneProviderService/MiuiLocationTimeZoneProviderService.apk` |
| `com.miui.voiceassistoverlay` | `/product/overlay/VoiceAssistAndroidOverlay/VoiceAssistAndroidOverlay.apk` |
| `com.miui.wallpaper.overlay.customize` | `/product/overlay/MiuiCustomizeWallpaperOverlay.apk` |
| `com.miui.wmsvc` | `/product/app/WMService/WMService.apk` |
| `com.miuix.editor` | `/product/app/MiuixEditor/MiuixEditor.apk` |
| `com.newcall.overlay.miui` | `/product/overlay/MiuiNewCallSdkResOverlay.apk` |
| `com.qti.overlay.framework.nonmodem` | `/product/overlay/FrameworksResNonModem_Sys.apk` |
| `com.qualcomm.uimremoteclient` | `/product/app/uimremoteclient/uimremoteclient.apk` |
| `com.qualcomm.uimremoteserver` | `/product/app/uimremoteserver/uimremoteserver.apk` |
| `com.sohu.inputmethod.sogou.xiaomi` | `/product/app/SogouIME/SogouIME.apk` |
| `com.xiaomi.ab` | `/product/app/system/system.apk` |
| `com.xiaomi.account` | `/product/app/MIUIXiaomiAccount/MIUIXiaomiAccount.apk` |
| `com.xiaomi.aiservice` | `/product/priv-app/AIService/AIService.apk` |
| `com.xiaomi.app.toolbox` | `/product/priv-app/Toolbox/Toolbox.apk` |
| `com.xiaomi.bluetooth.rro.device.config.overlay` | `/product/overlay/MiuiBtRRODeviceConfigOverlay.apk` |
| `com.xiaomi.devauth` | `/product/app/MiDevAuthService/MiDevAuthService.apk` |
| `com.xiaomi.metoknlp` | `/product/priv-app/MetokNLP/MetokNLP.apk` |
| `com.xiaomi.mi_connect_service` | `/product/app/mi_connect_service/mi_connect_service.apk` |
| `com.xiaomi.mis` | `/product/app/MIS/MIS.apk` |
| `com.xiaomi.misettings` | `/product/priv-app/MISettings/MISettings.apk` |
| `com.xiaomi.otrpbroker` | `/product/app/OTrPBroker/OTrPBroker.apk` |
| `com.xiaomi.phone.overlay` | `/product/overlay/MiTelephonyExtResOverlay.apk` |
| `com.xiaomi.trustservice` | `/product/app/MiTrustService/MiTrustService.apk` |
| `com.xiaomi.type` | `/product/app/MiType/MiType.apk` |
| `com.xiaomi.xmsf` | `/product/app/split-XiaomiServiceFrameworkCN/split-XiaomiServiceFrameworkCN-master.apk` |
| `com.xiaomi.xmsfkeeper` | `/product/app/XMSFKeeperCN/XMSFKeeperCN.apk` |
| `miui.systemui.plugin` | `/product/app/MIUISystemUIPlugin/MIUISystemUIPlugin.apk` |

### system_ext（60）

| 包名 | APK 路径 |
|---|---|
| `com.android.avatarpicker` | `/system_ext/priv-app/AvatarPicker/AvatarPicker.apk` |
| `com.android.carrierconfig` | `/system_ext/priv-app/CarrierConfig/CarrierConfig.apk` |
| `com.android.cellbroadcastreceiver` | `/system_ext/priv-app/CellBroadcastAppPlatform/CellBroadcastAppPlatform.apk` |
| `com.android.emergency` | `/system_ext/priv-app/EmergencyInfo/EmergencyInfo.apk` |
| `com.android.intentresolver` | `/system_ext/priv-app/MiIntentResolver/MiIntentResolver.apk` |
| `com.android.printspooler` | `/system_ext/app/MiuiPrintSpooler/MiuiPrintSpooler.apk` |
| `com.android.provision` | `/system_ext/priv-app/Provision/Provision.apk` |
| `com.android.settings` | `/system_ext/priv-app/Settings/Settings.apk` |
| `com.android.storagemanager` | `/system_ext/priv-app/StorageManager/StorageManager.apk` |
| `com.android.systemui` | `/system_ext/priv-app/MiuiSystemUI/MiuiSystemUI.apk` |
| `com.android.systemui.accessibility.accessibilitymenu` | `/system_ext/app/AccessibilityMenu/AccessibilityMenu.apk` |
| `com.android.vpndialogs` | `/system_ext/priv-app/MiuiVpnDialogs/MiuiVpnDialogs.apk` |
| `com.android.wallpapercropper` | `/system_ext/priv-app/WallpaperCropper/WallpaperCropper.apk` |
| `com.android.wifi.dialog` | `/system_ext/priv-app/MiuiWifiDialog/MiuiWifiDialog.apk` |
| `com.android.wm.shell` | `/system_ext/app/MiuiWMShellResources-install/MiuiWMShellResources-install.apk` |
| `com.lbe.security.miui` | `/system_ext/priv-app/AuthManager/AuthManager.apk` |
| `com.miui.audiomonitor` | `/system_ext/app/MiuiAudioMonitor/MiuiAudioMonitor.apk` |
| `com.miui.autoui.ext` | `/system_ext/app/AutoUIExtension/AutoUIExtension.apk` |
| `com.miui.misightservice` | `/system_ext/app/MiSightService/MiSightService.apk` |
| `com.miui.powerinsight` | `/system_ext/priv-app/PowerInsight/PowerInsight.apk` |
| `com.miui.powerkeeper` | `/system_ext/app/PowerKeeper/PowerKeeper.apk` |
| `com.miui.rom` | `/system_ext/framework/framework-ext-res/framework-ext-res.apk` |
| `com.miui.server.litert` | `/system_ext/priv-app/MiLiteRTServiceStub/MiLiteRTServiceStub.apk` |
| `com.miui.system` | `/system_ext/app/miuisystem/miuisystem.apk` |
| `com.miui.vsimcore` | `/system_ext/app/VsimCore/VsimCore.apk` |
| `com.qti.dcf` | `/system_ext/priv-app/dcf/dcf.apk` |
| `com.qti.ltebc` | `/system_ext/priv-app/QAS_DVC_MSP/QAS_DVC_MSP.apk` |
| `com.qti.phone` | `/system_ext/priv-app/QtiTelephony/QtiTelephony.apk` |
| `com.qti.qualcomm.deviceinfo` | `/system_ext/app/DeviceInfo/DeviceInfo.apk` |
| `com.qti.service.colorservice` | `/system_ext/app/colorservice/colorservice.apk` |
| `com.qualcomm.atfwd` | `/system_ext/app/atfwd/atfwd.apk` |
| `com.qualcomm.location` | `/system_ext/priv-app/com.qualcomm.location/com.qualcomm.location.apk` |
| `com.qualcomm.qcrilmsgtunnel` | `/system_ext/priv-app/qcrilmsgtunnel/qcrilmsgtunnel.apk` |
| `com.qualcomm.qti.ims` | `/system_ext/app/imssettings/imssettings.apk` |
| `com.qualcomm.qti.poweroffalarm` | `/system_ext/app/PowerOffAlarm/PowerOffAlarm.apk` |
| `com.qualcomm.qti.powersavemode` | `/system_ext/app/PowerSaveMode/PowerSaveMode.apk` |
| `com.qualcomm.qti.qcolor` | `/system_ext/app/QColor/QColor.apk` |
| `com.qualcomm.qti.server.qtiwifi` | `/system_ext/priv-app/QtiWifiService/QtiWifiService.apk` |
| `com.qualcomm.qti.server.wigig.tethering.rro` | `/system_ext/app/WigigTetheringRRO/WigigTetheringRRO.apk` |
| `com.qualcomm.qti.services.systemhelper` | `/system_ext/priv-app/com.qualcomm.qti.services.systemhelper/com.qualcomm.qti.services.systemhelper.apk` |
| `com.qualcomm.qti.uceShimService` | `/system_ext/app/uceShimService/uceShimService.apk` |
| `com.qualcomm.qti.workloadclassifier` | `/system_ext/app/workloadclassifier/workloadclassifier.apk` |
| `com.qualcomm.qti.xrcb` | `/system_ext/priv-app/xrcbservice/xrcbservice.apk` |
| `com.qualcomm.qti.xrvd.service` | `/system_ext/priv-app/xrvdservice/xrvdservice.apk` |
| `com.qualcomm.qti.xrwifi` | `/system_ext/priv-app/xrwifiservice/xrwifiservice.apk` |
| `com.qualcomm.wfd.service` | `/system_ext/priv-app/WfdService/WfdService.apk` |
| `com.xiaomi.apn` | `/system_ext/priv-app/CarrierStudioApn/CarrierStudioApn.apk` |
| `com.xiaomi.bluetooth` | `/system_ext/app/BluetoothExtension/BluetoothExtension.apk` |
| `com.xiaomi.cameramind` | `/system_ext/app/CameraMind/CameraMind.apk` |
| `com.xiaomi.carrierconfig` | `/system_ext/priv-app/CarrierStudioCarrierConfig/CarrierStudioCarrierConfig.apk` |
| `com.xiaomi.digitalkey` | `/system_ext/app/digitalkey/digitalkey.apk` |
| `com.xiaomi.ecc` | `/system_ext/priv-app/CarrierStudioEcc/CarrierStudioEcc.apk` |
| `com.xiaomi.micloud.sdk` | `/system_ext/priv-app/RtMiCloudSDK/RtMiCloudSDK.apk` |
| `com.xiaomi.mtb` | `/system_ext/app/ModemTestBox/ModemTestBox.apk` |
| `com.xiaomi.phone` | `/system_ext/priv-app/HyperPhone/HyperPhone.apk` |
| `com.xiaomi.touchservice` | `/system_ext/priv-app/TouchService/TouchService.apk` |
| `org.codeaurora.ims` | `/system_ext/priv-app/ims/ims.apk` |
| `vendor.qti.bluetooth.xpan` | `/system_ext/priv-app/Xpan/Xpan.apk` |
| `vendor.qti.data.ntnsatapp` | `/system_ext/app/NtnSatApp/NtnSatApp.apk` |
| `vendor.qti.imsdatachannel` | `/system_ext/app/ImsDataChannelService/ImsDataChannelService.apk` |

### system（59）

| 包名 | APK 路径 |
|---|---|
| `android` | `/system/framework/framework-res.apk` |
| `android.ext.shared` | `/system/app/ExtShared/ExtShared.apk` |
| `com.android.apps.tag` | `/system/priv-app/Tag/Tag.apk` |
| `com.android.appsearch.aiseal.config` | `/system/app/AppSearchAiSealConfig/AppSearchAiSealConfig.apk` |
| `com.android.backupconfirm` | `/system/priv-app/BackupRestoreConfirmation/BackupRestoreConfirmation.apk` |
| `com.android.bips` | `/system/priv-app/BuiltInPrintService/BuiltInPrintService.apk` |
| `com.android.bluetoothmidiservice` | `/system/app/BluetoothMidiService/BluetoothMidiService.apk` |
| `com.android.calllogbackup` | `/system/priv-app/CallLogBackup/CallLogBackup.apk` |
| `com.android.cameraextensions` | `/system/app/CameraExtensionsProxy/CameraExtensionsProxy.apk` |
| `com.android.captiveportallogin` | `/system/app/CaptivePortalLogin/CaptivePortalLogin.apk` |
| `com.android.carrierdefaultapp` | `/system/app/CarrierDefaultApp/CarrierDefaultApp.apk` |
| `com.android.cellbroadcastservice` | `/system/priv-app/CellBroadcastServiceModulePlatform/CellBroadcastServiceModulePlatform.apk` |
| `com.android.certinstaller` | `/system/app/CertInstaller/CertInstaller.apk` |
| `com.android.companiondevicemanager` | `/system/app/CompanionDeviceManager/CompanionDeviceManager.apk` |
| `com.android.contactspicker` | `/system/priv-app/ContactsPicker/ContactsPicker.apk` |
| `com.android.DeviceAsWebcam` | `/system/priv-app/DeviceAsWebcam/DeviceAsWebcam.apk` |
| `com.android.devicediagnostics` | `/system/priv-app/DeviceDiagnostics/DeviceDiagnostics.apk` |
| `com.android.dreams.basic` | `/system/app/BasicDreams/BasicDreams.apk` |
| `com.android.dynsystem` | `/system/priv-app/DynamicSystemInstallationService/DynamicSystemInstallationService.apk` |
| `com.android.egg` | `/system/app/EasterEgg/EasterEgg.apk` |
| `com.android.externalstorage` | `/system/priv-app/ExternalStorageProvider/ExternalStorageProvider.apk` |
| `com.android.eyedropper` | `/system/priv-app/EyeDropper/EyeDropper.apk` |
| `com.android.htmlviewer` | `/system/priv-app/HTMLViewer/HTMLViewer.apk` |
| `com.android.inputdevices` | `/system/priv-app/InputDevices/InputDevices.apk` |
| `com.android.keychain` | `/system/app/KeyChain/KeyChain.apk` |
| `com.android.localtransport` | `/system/priv-app/LocalTransport/LocalTransport.apk` |
| `com.android.location.fused` | `/system/priv-app/FusedLocation/FusedLocation.apk` |
| `com.android.managedprovisioning` | `/system/priv-app/ManagedProvisioning/ManagedProvisioning.apk` |
| `com.android.mms.service` | `/system/priv-app/MmsService/MmsService.apk` |
| `com.android.mtp` | `/system/priv-app/MtpService/MtpService.apk` |
| `com.android.musicfx` | `/system/priv-app/MusicFX/MusicFX.apk` |
| `com.android.networkstack` | `/system/priv-app/NetworkStack/NetworkStack.apk` |
| `com.android.ons` | `/system/priv-app/ONS/ONS.apk` |
| `com.android.pacprocessor` | `/system/app/PacProcessor/PacProcessor.apk` |
| `com.android.phone` | `/system/priv-app/TeleService/TeleService.apk` |
| `com.android.printservice.recommendation` | `/system/app/PrintRecommendationService/PrintRecommendationService.apk` |
| `com.android.providers.blockednumber` | `/system/priv-app/BlockedNumberProvider/BlockedNumberProvider.apk` |
| `com.android.providers.calendar` | `/system/priv-app/CalendarProvider/CalendarProvider.apk` |
| `com.android.providers.contactkeys` | `/system/priv-app/E2eeContactKeysProvider/E2eeContactKeysProvider.apk` |
| `com.android.providers.contacts` | `/system/priv-app/ContactsProvider/ContactsProvider.apk` |
| `com.android.providers.downloads` | `/system/priv-app/DownloadProvider/DownloadProvider.apk` |
| `com.android.providers.partnerbookmarks` | `/system/priv-app/PartnerBookmarksProvider/PartnerBookmarksProvider.apk` |
| `com.android.providers.settings` | `/system/priv-app/SettingsProvider/SettingsProvider.apk` |
| `com.android.providers.telephony` | `/system/priv-app/TelephonyProvider/TelephonyProvider.apk` |
| `com.android.providers.userdictionary` | `/system/priv-app/UserDictionaryProvider/UserDictionaryProvider.apk` |
| `com.android.proxyhandler` | `/system/priv-app/ProxyHandler/ProxyHandler.apk` |
| `com.android.se` | `/system/app/SecureElement/SecureElement.apk` |
| `com.android.server.telecom` | `/system/priv-app/Telecom/Telecom.apk` |
| `com.android.server.telecomui` | `/system/priv-app/TelecomUi/TelecomUi.apk` |
| `com.android.sharedstoragebackup` | `/system/priv-app/SharedStorageBackup/SharedStorageBackup.apk` |
| `com.android.shell` | `/system/priv-app/Shell/Shell.apk` |
| `com.android.simappdialog` | `/system/app/SimAppDialog/SimAppDialog.apk` |
| `com.android.soundpicker` | `/system/priv-app/SoundPicker/SoundPicker.apk` |
| `com.android.stk` | `/system/app/Stk/Stk.apk` |
| `com.android.traceur` | `/system/app/Traceur/Traceur.apk` |
| `com.android.wallpaper.livepicker` | `/system/priv-app/LiveWallpapersPicker/LiveWallpapersPicker.apk` |
| `com.android.wallpaperbackup` | `/system/app/WallpaperBackup/WallpaperBackup.apk` |
| `com.google.android.documentsui` | `/system/priv-app/DocumentsUIGoogleMiuiCn/DocumentsUIGoogleMiuiCn.apk` |
| `com.wapi.wapicertmanage` | `/system/app/WapiCertManage/WapiCertManage.apk` |

### apex（28）

| 包名 | APK 路径 |
|---|---|
| `android.ext.services` | `/apex/com.android.extservices/priv-app/ExtServices-sminus@CP2A.260605.016/ExtServices-sminus.apk` |
| `com.android.adservices.api` | `/apex/com.android.adservices/priv-app/AdServicesApk@CP2A.260605.016/AdServicesApk.apk` |
| `com.android.appsearch.apk` | `/apex/com.android.appsearch/priv-app/com.android.appsearch.apk@CP2A.260605.016/com.android.appsearch.apk.apk` |
| `com.android.bluetooth` | `/apex/com.android.bt/app/Bluetooth@CP2A.260605.016/Bluetooth.apk` |
| `com.android.compos.payload` | `/apex/com.android.compos/app/CompOSPayloadApp@CP2A.260605.016/CompOSPayloadApp.apk` |
| `com.android.connectivity.resources` | `/apex/com.android.tethering/priv-app/ServiceConnectivityResources@CP2A.260605.016/ServiceConnectivityResources.apk` |
| `com.android.cts.ctsshim` | `/apex/com.android.apex.cts.shim/app/CtsShim@MAIN/CtsShim.apk` |
| `com.android.cts.priv.ctsshim` | `/apex/com.android.apex.cts.shim/priv-app/CtsShimPriv@MAIN/CtsShimPriv.apk` |
| `com.android.devicelockcontroller` | `/apex/com.android.devicelock/priv-app/DeviceLockController@CP2A.260605.016/DeviceLockController.apk` |
| `com.android.federatedcompute.services` | `/apex/com.android.ondevicepersonalization/app/FederatedCompute@CP2A.260605.016/FederatedCompute.apk` |
| `com.android.health.connect.backuprestore` | `/apex/com.android.healthfitness/app/HealthConnectBackupRestore@CP2A.260605.016/HealthConnectBackupRestore.apk` |
| `com.android.healthconnect.controller` | `/apex/com.android.healthfitness/priv-app/HealthConnectController@CP2A.260605.016/HealthConnectController.apk` |
| `com.android.hotspot2.osulogin` | `/apex/com.android.wifi/app/OsuLogin@CP2A.260605.016/OsuLogin.apk` |
| `com.android.microdroid.empty_payload` | `/apex/com.android.virt/app/EmptyPayloadApp@CP2A.260605.016/EmptyPayloadApp.apk` |
| `com.android.networkstack.tethering` | `/apex/com.android.tethering/priv-app/TetheringNext@CP2A.260605.016/TetheringNext.apk` |
| `com.android.ondevicepersonalization.services` | `/apex/com.android.ondevicepersonalization/priv-app/OnDevicePersonalization@CP2A.260605.016/OnDevicePersonalization.apk` |
| `com.android.permissioncontroller` | `/apex/com.android.permission/priv-app/PermissionController@CP2A.260605.016/PermissionController.apk` |
| `com.android.photopicker` | `/apex/com.android.mediaprovider/priv-app/Photopicker@CP2A.260605.016/Photopicker.apk` |
| `com.android.providers.media.module` | `/apex/com.android.mediaprovider/priv-app/MediaProvider@CP2A.260605.016/MediaProvider.apk` |
| `com.android.rkpdapp` | `/apex/com.android.rkpd/priv-app/rkpdapp@CP2A.260605.016/rkpdapp.apk` |
| `com.android.safetycenter.resources` | `/apex/com.android.permission/priv-app/SafetyCenterResources@CP2A.260605.016/SafetyCenterResources.apk` |
| `com.android.sdksandbox` | `/apex/com.android.adservices/app/SdkSandbox@CP2A.260605.016/SdkSandbox.apk` |
| `com.android.uwb.resources` | `/apex/com.android.uwb/priv-app/ServiceUwbResources@CP2A.260605.016/ServiceUwbResources.apk` |
| `com.android.virtualization.terminal` | `/apex/com.android.virt/priv-app/VmTerminalApp@CP2A.260605.016/VmTerminalApp.apk` |
| `com.android.virtualmachine.res` | `/apex/com.android.virt/app/android.system.virtualmachine.res@CP2A.260605.016/android.system.virtualmachine.res.apk` |
| `com.android.webapp.service` | `/apex/com.android.webapp/priv-app/WebAppService@CP2A.260605.016/WebAppService.apk` |
| `com.android.wifi.resources` | `/apex/com.android.wifi/priv-app/ServiceWifiResources@CP2A.260605.016/ServiceWifiResources.apk` |
| `com.google.android.gms` | `/apex/com.google.android.gmssystem/priv-app/PrebuiltGmsCoreVic@361800000/PrebuiltGmsCoreVic.apk` |

### vendor（9）

| 包名 | APK 路径 |
|---|---|
| `android.overlay.target` | `/vendor/overlay/FrameworksResTarget_Vendor.apk` |
| `com.android.wifi.resources.overlay.target` | `/vendor/overlay/WifiResTarget_Vendor.apk` |
| `com.qualcomm.qti.cne` | `/vendor/app/CneApp/CneApp.apk` |
| `com.qualcomm.qti.qms.service.connectionsecurity` | `/vendor/app/ConnectionSecurityService/ConnectionSecurityService.apk` |
| `com.qualcomm.qti.qms.service.trustzoneaccess` | `/vendor/app/TrustZoneAccessService/TrustZoneAccessService.apk` |
| `com.qualcomm.timeservice` | `/vendor/app/TimeService/TimeService.apk` |
| `vendor.qti.data.txpwradmin` | `/vendor/app/TxPwrAdmin/TxPwrAdmin.apk` |
| `vendor.qti.hardware.cacert.server` | `/vendor/app/CACertService/CACertService.apk` |
| `vendor.qti.iwlan` | `/vendor/app/IWlanService/IWlanService.apk` |

### data（8）

| 包名 | APK 路径 |
|---|---|
| `com.android.calendar` | `/data/app/MIUICalendar/base.apk` |
| `com.android.deskclock` | `/data/app/MIUIDeskClock/base.apk` |
| `com.android.providers.downloads.ui` | `/data/app/DownloadProviderUiPad/base.apk` |
| `com.android.soundrecorder` | `/data/app/MIUISoundRecorderTargetSdk30/base.apk` |
| `com.miui.calculator` | `/data/app/MIUICalculator/base.apk` |
| `com.miui.miservice` | `/data/app/MIService/base.apk` |
| `com.miui.notes` | `/data/app/MIUINotes/base.apk` |
| `com.miui.screenrecorder` | `/data/app/MIUIScreenRecorder/base.apk` |

