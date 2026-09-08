#Requires AutoHotkey v2.0
#SingleInstance Off
#Include drivers\DrawerControl.ahk

if (A_Args.Length < 1)
    ExitApp(2)

ExitApp(DrawerExit(Integer(A_Args[1])) ? 0 : 1)
