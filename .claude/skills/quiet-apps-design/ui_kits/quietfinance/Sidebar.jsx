// Sidebar — grouped navigation, light style.
const ICONS = {
  doc:   <><rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 8h6M9 12h6M9 16h4"/></>,
  pulse: <path d="M3 12h4l3-7 4 14 3-7h4"/>,
  trend: <><path d="M4 18 L10 12 L14 16 L20 8"/><path d="M14 8h6v6"/></>,
  diff:  <><path d="M7 7l-3 3 3 3"/><path d="M4 10h14"/><path d="M17 17l3-3-3-3"/><path d="M6 14h14"/></>,
  list:  <><path d="M9 6h11M9 12h11M9 18h11"/><circle cx="5" cy="6"  r="1"/><circle cx="5" cy="12" r="1"/><circle cx="5" cy="18" r="1"/></>,
  grid:  <><rect x="3" y="3"  width="7" height="7"/><rect x="14" y="3"  width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/></>,
  people:<><circle cx="9" cy="9" r="3"/><path d="M3 19a6 6 0 0 1 12 0"/><circle cx="17" cy="8" r="2.5"/><path d="M15 19a5 5 0 0 1 6 0"/></>,
  globe: <><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a13 13 0 0 1 0 18M12 3a13 13 0 0 0 0 18"/></>,
  layers:<><path d="M12 3 3 8l9 5 9-5-9-5z"/><path d="M3 13l9 5 9-5"/></>,
  rows:  <><rect x="3" y="4" width="18" height="4" rx="1"/><rect x="3" y="10" width="18" height="4" rx="1"/><rect x="3" y="16" width="18" height="4" rx="1"/></>,
  hour:  <><path d="M6 3h12M6 21h12M7 3v3a5 5 0 0 0 5 5 5 5 0 0 1 5 5v3M17 3v3a5 5 0 0 1-5 5 5 5 0 0 0-5 5v3"/></>,
  cal:   <><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 9h18M8 3v4M16 3v4"/></>,
  gear:  <><circle cx="12" cy="12" r="3"/><path d="M12 1v3M12 20v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M1 12h3M20 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/></>,
};

function SideItem({ icon, on, onClick, children }) {
  return (
    <button className={'qf-side-item' + (on ? ' on' : '')} onClick={onClick}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">{ICONS[icon]}</svg>
      <span>{children}</span>
    </button>
  );
}

function Sidebar({ active, setActive }) {
  return (
    <aside className="qf-sidebar">
      <div className="qf-side-section">
        <div className="qf-side-label">Overview</div>
        <SideItem icon="doc"   on={active==='net-worth'}  onClick={() => setActive('net-worth')}>Net Worth</SideItem>
        <SideItem icon="pulse" on={active==='trends'}     onClick={() => setActive('trends')}>Trends</SideItem>
        <SideItem icon="trend" on={active==='historical'} onClick={() => setActive('historical')}>Historical</SideItem>
        <SideItem icon="diff"  on={active==='diff'}       onClick={() => setActive('diff')}>Diff</SideItem>
        <SideItem icon="list"  on={active==='reports'}    onClick={() => setActive('reports')}>Reports</SideItem>
      </div>
      <div className="qf-side-section">
        <div className="qf-side-label">Breakdown</div>
        <SideItem icon="grid"   onClick={() => setActive('alloc')}>By Allocation</SideItem>
        <SideItem icon="people" onClick={() => setActive('person')}>By Person</SideItem>
        <SideItem icon="globe"  onClick={() => setActive('country')}>By Country</SideItem>
        <SideItem icon="layers" onClick={() => setActive('asset')}>By Asset Type</SideItem>
      </div>
      <div className="qf-side-section">
        <div className="qf-side-label">Data</div>
        <SideItem icon="rows" onClick={() => setActive('assets')}>All Assets</SideItem>
        <SideItem icon="hour" onClick={() => setActive('receivables')}>Receivables</SideItem>
      </div>
      <div className="qf-side-section">
        <div className="qf-side-label">Recent</div>
        <SideItem icon="cal" onClick={() => setActive('snapshot')}>May 18, 2026</SideItem>
      </div>
      <div className="qf-side-section" style={{marginTop:'auto'}}>
        <SideItem icon="gear" onClick={() => setActive('settings')}>Settings</SideItem>
      </div>
    </aside>
  );
}

Object.assign(window, { Sidebar });
