// Menu bar surface + Lens status item. Click the lens to toggle the panel.
function MenuBar({ open, onToggle, active }) {
  return (
    <div className="ql-menubar">
      <div className="ql-mb-left">
        <span className="ql-mb-apple"></span>
        <span className="ql-mb-app">QuietLens</span>
        <span>File</span><span>Edit</span><span>View</span><span>Window</span><span>Help</span>
      </div>
      <div className="ql-mb-right">
        <span style={{fontFamily:'var(--qa-font-mono)'}}>{new Date().toLocaleTimeString([], {hour:'2-digit', minute:'2-digit'})}</span>
        <button className={'ql-mb-status' + (active ? ' on' : '') + (open ? ' open' : '')} onClick={onToggle} aria-label="Quiet Lens">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>
          </svg>
        </button>
      </div>
    </div>
  );
}
Object.assign(window, { MenuBar });
