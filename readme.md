tinyrabbit is a simple objective-c executable that was made to run in background and turn off/on the monitor depending on whether Mouse is connected, since Monitors switch to the active video output by default this helps creating a budget KVM setup that takes advantage of full display specifications since computers won't need a video KVM that supports your full resolution and refresh rate

# Features
- Turn off monitor when Mouse is disconnected<br/>
- Wake monitor when Mouse is connected<br/>
- Set battery shutdown percentage<br/>
- (eqMac) auto-switch audio output (Mac Mini often swiches to built-in speakers) and restore its volume settings<br/>
- Features can be enabled/disabled from a plist file<br/>

Install executable as a launch daemon if you want the binary to be running when you reboot your computer<br/>