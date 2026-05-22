// Quiet Notch — Dynamic-Island-style panel hanging from the MacBook notch.
// Home view: Now Playing | Calendar | Webcam preview.

const ICONS = {
  home:  <path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-7h-6v7H4a1 1 0 0 1-1-1v-9.5z"/>,
  inbox: <><path d="M3 7h18v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7z"/><path d="M3 13h5l1 2h6l1-2h5"/></>,
  prev:  <path d="M6 5v14h2V5H6zm12 0L10 12l8 7V5z"/>,
  pause: <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"/>,
  next:  <path d="M16 5v14h2V5h-2zM6 5v14l8-7L6 5z"/>,
  music: <path d="M9 18V6l11-2v12M9 16a3 3 0 1 1-3-3 3 3 0 0 1 3 3zm11-2a3 3 0 1 1-3-3 3 3 0 0 1 3 3z"/>,
  gear:  <><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9c.3.6.9 1 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></>,
};

function NotchPanel({ tab, setTab }) {
  return (
    <div className="qn-panel">
      <div className="qn-statusbar">
        <div className="qn-tabs">
          <button className={'qn-tab' + (tab === 'home' ? ' on' : '')} onClick={() => setTab('home')} aria-label="Home">
            <svg viewBox="0 0 24 24" fill="currentColor">{ICONS.home}</svg>
          </button>
          <button className={'qn-tab' + (tab === 'inbox' ? ' on' : '')} onClick={() => setTab('inbox')} aria-label="Inbox">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6">{ICONS.inbox}</svg>
          </button>
        </div>

        <div className="qn-notch-cutout"/>

        <div className="qn-status">
          <button className="qn-icon-btn" aria-label="Settings">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">{ICONS.gear}</svg>
          </button>
          <span className="qn-batt-pct">84%</span>
          <span className="qn-batt">
            <span className="qn-batt-fill" style={{width:'82%'}}/>
            <svg className="qn-batt-bolt" viewBox="0 0 12 12"><path d="M7 1L3 7h2.5L4.5 11l4-6H6z"/></svg>
          </span>
        </div>
      </div>

      <div className="qn-content">
        <NowPlaying/>
        <Calendar/>
        <Webcam/>
      </div>
    </div>
  );
}

function NowPlaying() {
  return (
    <div className="qn-np">
      <div className="qn-album">
        <div className="qn-album-art"/>
        <span className="qn-album-badge" aria-label="Music">
          <svg viewBox="0 0 24 24">{ICONS.music}</svg>
        </span>
      </div>
      <div className="qn-np-body">
        <div className="qn-np-title">Show &amp; Tell</div>
        <div className="qn-np-artist">Melanie Martinez</div>
        <div className="qn-np-bar"><span style={{width:'48%'}}/></div>
        <div className="qn-np-times qn-mono"><span>1:43</span><span>3:35</span></div>
        <div className="qn-np-controls">
          <button aria-label="Previous"><svg viewBox="0 0 24 24" fill="currentColor">{ICONS.prev}</svg></button>
          <button aria-label="Pause" className="big"><svg viewBox="0 0 24 24" fill="currentColor">{ICONS.pause}</svg></button>
          <button aria-label="Next"><svg viewBox="0 0 24 24" fill="currentColor">{ICONS.next}</svg></button>
        </div>
      </div>
    </div>
  );
}

function Calendar() {
  return (
    <div className="qn-cal">
      <div className="qn-cal-head">
        <div className="qn-cal-month">Dec</div>
        <div className="qn-cal-days">
          <div className="qn-cal-day"><div className="qn-cal-dn">Thu</div><div className="qn-cal-dd">12</div></div>
          <div className="qn-cal-day today"><div className="qn-cal-dn">Fri</div><div className="qn-cal-dd">13</div></div>
        </div>
      </div>
      <div className="qn-cal-msg">
        <div className="qn-cal-msg-title">No events today</div>
        <div className="qn-cal-msg-sub">Enjoy your free time!</div>
      </div>
    </div>
  );
}

function Webcam() {
  return (
    <div className="qn-cam">
      <span className="qn-cam-rec">LIVE</span>
    </div>
  );
}

Object.assign(window, { NotchPanel, NowPlaying, Calendar, Webcam });
