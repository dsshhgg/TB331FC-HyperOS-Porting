# TB331FC-HyperOS-Porting

鑱旀兂灏忔柊骞虫澘 2024锛圱B331FC锛夌Щ妞?Xiaomi HyperOS 4.0 椤圭洰銆?
## 璁惧淇℃伅
- 璁惧锛歀enovo Xiaoxin Pad 2024 (TB331FC)
- 骞冲彴锛歈ualcomm SM6225-AD (Snapdragon 685)
- 鍐呮牳锛欸KI 5.15.123-android13锛圞MI: android13-5.15锛?- 搴曞寘锛歓UI 16.0.544 瀹樻柟鍥轰欢

## 绉绘婧?- 婧愭満鍨嬶細Xiaomi Pad 6 Pro (yupei)
- ROM锛欻yperOS 4.0 / Android 17
- 鍖呭悕锛歽upei-ota_full-OS4.0.5.0.XPZCNXM-user-17.0-4fe489f542

## 绉绘绛栫暐
**纭欢闈?ZUI锛屼笂灞傞潬 HyperOS**
- 淇濈暀 ZUI锛歜oot / dtbo / vendor / odm / firmware
- 绉绘 HyperOS锛歴ystem / system_ext / product / mi_ext

## 褰撳墠杩涘害
- [x] ZUI 搴曞寘瑙ｅ寘 + 缁撴瀯鍒嗘瀽 鈫?`docs/zui_structure.md`
- [x] HyperOS 鍖呰В鍖?+ 缁撴瀯鍒嗘瀽 鈫?`docs/hyperos_structure.md`
- [x] 鍙鎬ц瘎浼版姤鍛?鈫?`docs/feasibility_report.md`锛堢粨璁猴細**涓嶅彲琛?*瀹屾暣绉绘锛?- [x] vendor 宸紓娓呭崟 鈫?`docs/vendor_diff.md`
- [ ] 棣栨璇曞埛
- [ ] 寮€鏈鸿皟璇?
## 鏍稿績缁撹锛?026-09-29锛?**瀹屾暣绉绘 yupei HyperOS 4 鍒?TB331FC 涓嶅彲琛屻€?*
- GKI KMI锛歚android13-5.15` vs `android15-6.6`锛堝惁鍐筹級
- SoC锛歋M6225 vs 鏂颁竴浠ｉ珮閫氾紙鍚﹀喅锛?- Android锛?4/13 鈫?17锛堣法 3 浠ｏ級
- 绌洪棿锛氱郴缁熶晶 ~9.3 GiB > system_a 5.79 GiB
- 鏇夸唬锛欸SI / 闄嶇骇婧愬寘 / 鏃㈡湁 TB331FC 涓撳寘

## 鐜渚濊禆
- OrangeFox Recovery锛圱B331FC 涓撳睘锛夛細瑙?[TB331FC-TWRP](https://github.com/dsshhgg/TB331FC-TWRP) fox-12.1 鍒嗘敮
- payload_dumper
- erofs-utils / simg2img
- magiskboot

## 鍒嗘敮绛栫暐
- `main`锛氱ǔ瀹氱増绉绘鎴愭灉銆佹寮忓彂甯?- `dev`锛氭棩甯稿紑鍙戯紙涓昏寮€鍙戝垎鏀級
- `exp-xxx`锛氬疄楠屾€ф敼鍔?
## 鍏嶈矗澹版槑
鏈」鐩粎渚涘涔犱氦娴侊紝鍒锋満椋庨櫓鑷礋锛岃鍔″繀澶囦唤鍘熷巶鍏ㄩ儴鍒嗗尯銆?