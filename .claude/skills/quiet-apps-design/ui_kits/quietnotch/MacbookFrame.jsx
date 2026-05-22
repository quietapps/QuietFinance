function MenuBar() {
  return (
    <div className="qn-menubar">
      <div className="left">
        <span className="qn-mb-app">Finder</span>
        <span>File</span><span>Edit</span><span>View</span><span>Go</span><span>Window</span><span>Help</span>
      </div>
      <div className="right">
        <span className="qn-mb-stage-mgr"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><rect x="3" y="5" width="18" height="14" rx="2"/></svg></span>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M9 5l-3 3M15 5l3 3"/></svg>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M2 9a15 15 0 0 1 20 0M5 13a10 10 0 0 1 14 0M8 17a5 5 0 0 1 8 0"/><circle cx="12" cy="20" r="1" fill="currentColor"/></svg>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><circle cx="12" cy="12" r="9"/><path d="M12 12h6M12 12V6"/></svg>
        <span style={{fontVariantNumeric:'tabular-nums', fontSize:11}}>Sat 12/14</span>
      </div>
    </div>
  );
}

function MacbookFrame({ children }) {
  return (
    <div className="qn-stage">
      <div className="qn-bezel">
        <div className="qn-screen">
          <MenuBar/>
          {children}
        </div>
      </div>
    </div>
  );
}
Object.assign(window, { MacbookFrame, MenuBar });
