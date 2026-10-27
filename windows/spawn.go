//go:build windows

package main

import (
	"os/exec"
	"path/filepath"
	"syscall"
)

func newCommand(name string) *exec.Cmd {
	cmd := exec.Command(filepath.Join(dir, name))
	cmd.Dir = dir
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: detached}
	return cmd
}
