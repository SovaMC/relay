const moves = [["KeyW", 0, -1], ["KeyS", 0, 1], ["KeyA", -1, 0], ["KeyD", 1, 0]];

/** Creates one overlay control owned by the touch session. */
function control(doc, className, text = "") {
  const node = doc.createElement("div");
  node.className = className;
  node.textContent = text;
  return node;
}

/** Follows one captured pointer on a node until it lifts or is cancelled. */
function track(node, start, move, end) {
  let active = null;
  node.addEventListener("pointerdown", (event) => {
    if (event.pointerType === "mouse" || active !== null) return;
    event.preventDefault();
    active = event.pointerId;
    node.setPointerCapture(event.pointerId);
    start(event);
  });
  node.addEventListener("pointermove", (event) => { if (event.pointerId === active) move(event); });
  for (const name of ["pointerup", "pointercancel", "lostpointercapture"]) {
    node.addEventListener(name, (event) => {
      if (event.pointerId !== active) return;
      active = null;
      end(event);
    });
  }
}

/** Drives the spectator camera on touch screens: a stick moves, dragging the canvas looks, buttons fly. */
export function touchEdges(canvas, input, audio, view = window, doc = document) {
  if (!view.matchMedia("(pointer: coarse)").matches) return;
  const held = new Set();
  const press = (code, down) => {
    if (held.has(code) === down) return;
    if (down) held.add(code); else held.delete(code);
    input.key(code, down);
  };
  const wake = () => {
    input.focus(true);
    audio.resume().catch(() => {});
  };

  const pad = control(doc, "touch-pad");
  const knob = control(doc, "touch-knob");
  pad.append(knob);
  const steer = (event) => {
    const box = pad.getBoundingClientRect();
    const radius = box.width / 2;
    let x = (event.clientX - box.left - radius) / radius;
    let y = (event.clientY - box.top - radius) / radius;
    const length = Math.hypot(x, y);
    if (length > 1) { x /= length; y /= length; }
    knob.style.transform = `translate(${x * radius * 0.6}px, ${y * radius * 0.6}px)`;
    for (const [code, dx, dy] of moves) press(code, x * dx + y * dy > 0.35);
  };
  track(pad, (event) => { wake(); steer(event); }, steer, () => {
    knob.style.transform = "";
    for (const [code] of moves) press(code, false);
  });

  let last = null;
  track(canvas, (event) => { wake(); last = [event.clientX, event.clientY]; }, (event) => {
    input.motion((event.clientX - last[0]) * 1.5, (event.clientY - last[1]) * 1.5);
    last = [event.clientX, event.clientY];
  }, () => { last = null; });

  const buttons = [["touch-button touch-up", "▲", "Space"], ["touch-button touch-down", "▼", "ShiftLeft"]];
  for (const [className, text, code] of buttons) {
    const button = control(doc, className, text);
    track(button, () => { wake(); press(code, true); }, () => {}, () => press(code, false));
    doc.body.append(button);
  }
  doc.body.append(pad);
  view.addEventListener("blur", () => held.clear());
}
