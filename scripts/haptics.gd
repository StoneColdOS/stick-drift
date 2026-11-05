extends RefCounted
## Little buzzes for gear changes.
##   Android / Thor APK: real vibration.
##   Web on Android: navigator.vibrate.
##   Web on iPhone: Safari has no vibration API. iOS 18+ gives a haptic tick when a "switch"
##   checkbox is toggled by a real touch, so the page queues one and fires it on the next finger
##   lift (see html/head_include in export_presets.cfg). That means it lands when you let go of
##   the shifter, not mid-throw.


static func buzz(ms := 25) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.sdHaptic && window.sdHaptic.request(%d)" % ms, true)
	elif OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
