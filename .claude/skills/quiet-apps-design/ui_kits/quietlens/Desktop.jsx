// Simulated desktop with two app windows; one is focused, others get dimmed/blurred when Lens is active.
function Window({ title, x, y, w, h, focused, blur, dim, children }) {
  const style = {
    left: x, top: y, width: w, height: h,
    zIndex: focused ? 30 : 1,
    filter: !focused && blur > 0 ? `blur(${blur}px)` : 'none',
  };
  return (
    <div className={'ql-win' + (focused ? ' focused' : '')} style={style}>
      <div className="ql-win-chrome">
        <span className="tl r"/><span className="tl y"/><span className="tl g"/>
        <span className="ql-win-title">{title}</span>
      </div>
      <div className="ql-win-body">{children}</div>
      {!focused && dim > 0 && <div className="ql-win-dim" style={{ opacity: dim }}/>}
    </div>
  );
}

function Desktop({ active, intensity, mode, grain }) {
  // Per-mode blur ceiling + dim strength. Slider scales 0→1 against these.
  const profile = mode === 'Ambient' ? { blur: 14, dim: 0.25, grain: 0 }
                : mode === 'Deep'    ? { blur: 36, dim: 0.50, grain: 0 }
                : /* Cinema */         { blur: 64, dim: 0.70, grain: 1 };
  const k = active ? intensity / 100 : 0;
  const blur = profile.blur * k;
  const dim  = profile.dim  * k;
  const showGrain = active && grain && profile.grain > 0;

  return (
    <div className="ql-desktop">
      <div className="ql-wallpaper"/>
      {/* Wallpaper-level dim scrim — sits behind windows so the focused one stays bright */}
      <div className="ql-bg-dim" style={{ opacity: dim }}/>

      <Window title="Notes" x={60} y={60} w={360} h={240} focused={false} blur={blur} dim={dim}>
        <div className="ql-notes">
          <div className="ql-notes-row"><b>Quiet Lens</b><span>Today</span></div>
          <div className="ql-notes-row dim"><span>Stand-up agenda</span><span>Tue</span></div>
          <div className="ql-notes-row dim"><span>Reading list</span><span>Mon</span></div>
        </div>
      </Window>

      <Window title="Mail — Inbox" x={140} y={140} w={520} h={300} focused={false} blur={blur} dim={dim}>
        <div className="ql-mail">
          <div className="ql-mail-row"><b>Sam</b><span>Beta build is signed</span></div>
          <div className="ql-mail-row"><b>Anna</b><span>Re: Lens icon</span></div>
          <div className="ql-mail-row"><b>Notion</b><span>Your weekly digest</span></div>
        </div>
      </Window>

      <Window title="Document — quiet-lens-spec.md" x={240} y={220} w={540} h={320} focused={true} blur={0} dim={0}>
        <div className="ql-doc">
          <h3>Quiet Lens — v1.4</h3>
          <p>Dim and blur every window except the one you're working in. Quiet Lens runs in the menu bar and only ever touches what's on screen.</p>
          <p style={{color:'var(--qa-fg-2)'}}>Modes: Ambient (light blur), Deep (frosted), Cinema (deep + grain).</p>
          <p style={{color:'var(--qa-fg-3)', fontSize:13}}>Last saved 22:18 · local-only</p>
        </div>
      </Window>

      {showGrain && <div className="ql-grain"/>}
    </div>
  );
}
Object.assign(window, { Window, Desktop });
