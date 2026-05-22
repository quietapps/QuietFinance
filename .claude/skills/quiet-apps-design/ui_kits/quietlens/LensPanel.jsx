// Dropdown panel — the heart of the app's controls.
function LensPanel({ active, setActive, mode, setMode, intensity, setIntensity, autoPause, setAutoPause, grain, setGrain }) {
  return (
    <div className="ql-panel" role="dialog" aria-label="Quiet Lens">
      <div className="ql-panel-head">
        <div className="ql-panel-title">Quiet Lens</div>
        <button className={'ql-toggle' + (active ? '' : ' off')} onClick={() => setActive(!active)} aria-label="Toggle">
          <span/>
        </button>
      </div>
      <div className="ql-panel-sub">{active ? 'Dimming unfocused windows' : 'Off'}</div>

      <div className="ql-section">
        <div className="ql-section-label">Mode</div>
        <div className="ql-seg">
          {['Ambient','Deep','Cinema'].map(m => (
            <button key={m} className={mode === m ? 'on' : ''} onClick={() => setMode(m)}>{m}</button>
          ))}
        </div>
      </div>

      <div className="ql-section">
        <div className="ql-row"><span>Intensity</span><span className="ql-mono">{intensity}%</span></div>
        <input type="range" min={0} max={100} value={intensity} onChange={e => setIntensity(+e.target.value)} className="ql-slider"/>
      </div>

      <div className="ql-section">
        <div className="ql-row"><span>Auto-pause on call</span>
          <button className={'ql-toggle sm' + (autoPause ? '' : ' off')} onClick={() => setAutoPause(!autoPause)}><span/></button>
        </div>
        <div className="ql-row"><span>Film grain</span>
          <button className={'ql-toggle sm' + (grain ? '' : ' off')} onClick={() => setGrain(!grain)}><span/></button>
        </div>
      </div>

      <div className="ql-foot">
        <div className="ql-kbd"><kbd>⌘</kbd><kbd>⇧</kbd><kbd>L</kbd></div>
        <span className="ql-foot-label">toggle Lens</span>
        <button className="ql-foot-btn">Preferences…</button>
      </div>
    </div>
  );
}
Object.assign(window, { LensPanel });
