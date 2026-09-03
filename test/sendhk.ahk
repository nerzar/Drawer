#Requires AutoHotkey v2.0
#SingleInstance Off
SetKeyDelay(20, 20)
SendLevel(1)
Send(A_Args[1])
Sleep(400)
ExitApp()
