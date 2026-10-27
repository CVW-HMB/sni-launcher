//go:build windows

package main

import (
	"net"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"github.com/lxn/walk"
	. "github.com/lxn/walk/declarative"
	"github.com/lxn/win"
	"golang.org/x/sys/windows"
)

const detached = 0x00000008 | 0x00000200 // DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP

var (
	user32                  = windows.NewLazySystemDLL("user32.dll")
	procSetForegroundWindow = user32.NewProc("SetForegroundWindow")

	dir        string
	mw         *walk.MainWindow
	status     *walk.Label
	sniButton  *walk.PushButton
	snfmButton *walk.PushButton
	busy       bool
)

func main() {
	exe, err := os.Executable()
	if err != nil {
		walk.MsgBox(nil, "SNI Launcher", err.Error(), walk.MsgBoxIconError)
		return
	}
	dir = filepath.Dir(exe)

	err = MainWindow{
		AssignTo: &mw,
		Title:    "SNI Launcher",
		Size:     Size{Width: 300, Height: 170},
		Layout:   VBox{Margins: Margins{Left: 20, Top: 20, Right: 20, Bottom: 20}, Spacing: 12},
		Children: []Widget{
			Label{AssignTo: &status, TextAlignment: AlignCenter},
			PushButton{AssignTo: &sniButton, Text: "Start SNI", OnClicked: sniClicked},
			PushButton{AssignTo: &snfmButton, Text: "Open File Manager", OnClicked: snfmClicked},
		},
	}.Create()
	if err != nil {
		walk.MsgBox(nil, "SNI Launcher", err.Error(), walk.MsgBoxIconError)
		return
	}

	// Fixed size: drop the sizing border and the maximize box
	style := win.GetWindowLong(mw.Handle(), win.GWL_STYLE)
	win.SetWindowLong(mw.Handle(), win.GWL_STYLE, style&^win.WS_THICKFRAME&^win.WS_MAXIMIZEBOX)
	mw.SetSize(walk.Size{Width: 300, Height: 170})

	refresh()
	go func() {
		for range time.Tick(1500 * time.Millisecond) {
			mw.Synchronize(refresh)
		}
	}()

	mw.Run()
}

func sniClicked() {
	message := "Restarting SNI…"
	if len(pidsOf("sni.exe")) == 0 {
		message = "Starting SNI…"
	}
	work(message, func() {
		stopSNI()
		startSNI()
	})
}

func snfmClicked() {
	work("Starting SNI…", func() {
		if len(pidsOf("sni.exe")) == 0 {
			startSNI()
		}
		if pids := pidsOf("manage_files.exe"); len(pids) > 0 {
			bringToFront(pids)
		} else {
			start("manage_files.exe")
		}
	})
}

func refresh() {
	if busy {
		return
	}
	if len(pidsOf("sni.exe")) == 0 {
		status.SetText("SNI is not running")
		sniButton.SetText("Start SNI")
	} else {
		if sniListening() {
			status.SetText("SNI is running")
		} else {
			status.SetText("SNI is starting…")
		}
		sniButton.SetText("Restart SNI")
	}
}

func work(message string, body func()) {
	busy = true
	status.SetText(message)
	sniButton.SetEnabled(false)
	snfmButton.SetEnabled(false)
	go func() {
		body()
		mw.Synchronize(func() {
			busy = false
			sniButton.SetEnabled(true)
			snfmButton.SetEnabled(true)
			refresh()
		})
	}()
}

func startSNI() {
	start("sni.exe")
	waitUntil(10*time.Second, sniListening)
}

// Stops every SNI, including ones not started from here, since they would all fight over the same ports
func stopSNI() {
	for _, pid := range pidsOf("sni.exe") {
		h, err := windows.OpenProcess(windows.PROCESS_TERMINATE|windows.SYNCHRONIZE, false, pid)
		if err != nil {
			continue
		}
		if windows.TerminateProcess(h, 1) == nil {
			windows.WaitForSingleObject(h, 5000)
		}
		windows.CloseHandle(h)
	}
	waitUntil(2*time.Second, func() bool { return len(pidsOf("sni.exe")) == 0 })
}

func start(name string) {
	cmd := newCommand(name)
	if cmd.Start() == nil {
		cmd.Process.Release()
	}
}

func pidsOf(name string) []uint32 {
	snap, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return nil
	}
	defer windows.CloseHandle(snap)
	var pids []uint32
	var entry windows.ProcessEntry32
	entry.Size = uint32(unsafe.Sizeof(entry))
	for err = windows.Process32First(snap, &entry); err == nil; err = windows.Process32Next(snap, &entry) {
		if strings.EqualFold(windows.UTF16ToString(entry.ExeFile[:]), name) {
			pids = append(pids, entry.ProcessID)
		}
	}
	return pids
}

func sniListening() bool {
	conn, err := net.DialTimeout("tcp", "127.0.0.1:8191", 500*time.Millisecond)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

func bringToFront(pids []uint32) {
	callback := syscall.NewCallback(func(hwnd windows.HWND, _ uintptr) uintptr {
		var pid uint32
		windows.GetWindowThreadProcessId(hwnd, &pid)
		for _, p := range pids {
			if p == pid && win.IsWindowVisible(win.HWND(hwnd)) {
				win.ShowWindow(win.HWND(hwnd), win.SW_RESTORE)
				procSetForegroundWindow.Call(uintptr(hwnd))
			}
		}
		return 1
	})
	windows.EnumWindows(callback, nil)
}

func waitUntil(timeout time.Duration, done func() bool) {
	end := time.Now().Add(timeout)
	for time.Now().Before(end) && !done() {
		time.Sleep(200 * time.Millisecond)
	}
}
