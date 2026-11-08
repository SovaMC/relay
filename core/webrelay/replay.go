package webrelay

import (
	"context"
	"errors"
	"net"
	"regexp"
	"strings"

	"github.com/hashimthearab/rust-mcbe/core/control"
)

var (
	replayTicket  = regexp.MustCompile(`^[a-z][a-z0-9]{15}$`)
	errReplayOnly = errors.New("webrelay: relay serves replays only")
)

func (relay *Relay) replays() bool {
	return relay.cfg.Target != ""
}

func (relay *Relay) selectTarget(ctx context.Context, kind, value string) (string, error) {
	if !relay.replays() {
		return selectTarget(ctx, kind, value)
	}
	if _, ok := replayName(kind, value); !ok {
		return "", control.ErrInvalidTarget
	}
	return relay.cfg.Target, nil
}

func (relay *Relay) targetName(kind, value string) string {
	if !relay.replays() {
		return ""
	}
	name, _ := replayName(kind, value)
	return name
}

func replayName(kind, value string) (string, bool) {
	if kind != control.TargetRakNet {
		return "", false
	}
	host, _, err := net.SplitHostPort(strings.TrimSpace(value))
	if err != nil || !replayTicket.MatchString(host) {
		return "", false
	}
	return host, true
}
