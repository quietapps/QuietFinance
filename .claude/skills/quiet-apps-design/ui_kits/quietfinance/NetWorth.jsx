// The hero net-worth display + KPI strip + goal section.

function HeroChart({ data }) {
  const w = 100, h = 100;
  const min = Math.min(...data), max = Math.max(...data);
  const span = Math.max(1, max - min);
  const pts = data.map((v, i) => [(i / (data.length - 1)) * w, h - ((v - min) / span) * (h - 4) - 2]);
  const d = pts.map((p, i) => (i === 0 ? 'M' : 'L') + p[0].toFixed(1) + ',' + p[1].toFixed(1)).join(' ');
  return (
    <div className="qf-hero-chart">
      <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none">
        <path d={d} stroke="#1E88E5" strokeWidth=".7" fill="none" strokeLinecap="round"/>
        <path d={d + ` L${w},${h} L0,${h} Z`} fill="url(#qfgrad)" opacity=".22"/>
        <defs>
          <linearGradient id="qfgrad" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor="#1E88E5"/>
            <stop offset="1" stopColor="#1E88E5" stopOpacity="0"/>
          </linearGradient>
        </defs>
        {/* dashed baseline */}
        <line x1="0" x2={w} y1={h-1} y2={h-1} stroke="#1E88E5" strokeOpacity=".4" strokeDasharray="1.5 2" strokeWidth=".4"/>
      </svg>
    </div>
  );
}

function NetWorthHero({ compare, setCompare }) {
  const data = [171, 173.5, 174, 176, 175, 178, 180, 181, 183.5, 184.5, 187, 889.5, 891.5];
  return (
    <section className="qf-hero">
      <div className="qf-hero-head">
        <div className="qf-eyebrow">NET WORTH <span className="sep">·</span> May 18, 2026</div>
        <div className="qf-seg">
          <button className={compare === 'prev' ? 'on' : ''} onClick={() => setCompare('prev')}>vs Previous</button>
          <button className={compare === 'year' ? 'on' : ''} onClick={() => setCompare('year')}>vs Year ago</button>
        </div>
      </div>
      <div className="qf-hero-row">
        <div className="qf-hero-num"><span className="ccy">$</span>891,568</div>
        <div className="qf-hero-delta">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M7 17L17 7"/><path d="M9 7h8v8"/></svg>
          <span>+$20.0K</span><span className="pct">+2.3% QoQ</span>
        </div>
      </div>
      <HeroChart data={data}/>
      <div className="qf-hero-foot">
        Across 39 accounts in 2 countries, held by Komal &amp; Parth. Last updated May 18, 2026 · exchange rate ₹96.35 / $1.
      </div>
    </section>
  );
}

function AIBanner() {
  return (
    <div className="qf-ai">
      <span className="qf-ai-spark">✦</span>
      <span>Net worth grew $20.0K (2.3%) since the previous snapshot. Lifted by 2 PT Kraken Crypto and 2 PT BofA Personal. Dragged by 2 PT RH Demat Balance and 4 KD BofA. Goal cleared by $691.6K.</span>
    </div>
  );
}

function KPICards() {
  const cards = [
    { eye:'LIQUID',     num:'$506.2K', cap:'Cash + deposits',   ch:'+0.5%', dn:false },
    { eye:'INVESTED',   num:'$321.6K', cap:'Equity + crypto',   ch:'+4.8%', dn:false },
    { eye:'RETIREMENT', num:'$91.0K',  cap:'401k · IRA · NPS · HSA', ch:'+2.2%', dn:false },
    { eye:'DEBT',       num:'$27.2K',  cap:'Loans · credit',    ch:'−2.6%', dn:true,  red:true },
  ];
  return (
    <div className="qf-kpis">
      {cards.map(c => (
        <div className="qf-kpi" key={c.eye}>
          <div className="qf-kpi-eye">{c.eye}</div>
          <div className={'qf-kpi-num' + (c.red ? ' debt' : '')}>{c.num}</div>
          <div className="qf-kpi-cap">{c.cap} <b className={c.dn ? 'dn' : ''}>{c.ch} QoQ</b></div>
        </div>
      ))}
    </div>
  );
}

function GoalCard() {
  return (
    <div className="qf-goal">
      <div className="qf-goal-head">
        <div className="qf-goal-title">Goal</div>
        <div className="qf-goal-cleared">Cleared</div>
      </div>
      <div className="qf-goal-row">
        <div className="qf-goal-num">$891.6K <small>/ $200.0K</small></div>
        <div className="qf-goal-pct">100.0%</div>
      </div>
      <div className="qf-goal-bar"><span style={{width:'100%'}}/></div>
      <div className="qf-goal-meta">
        <div><span className="lbl">Trend ETA</span><b>—</b><span className="sub">$51.9K/mo</span></div>
        <div><span className="lbl">Target date</span><b>Dec 2027</b><span className="sub">Trend not enough data</span></div>
      </div>
    </div>
  );
}

Object.assign(window, { NetWorthHero, AIBanner, KPICards, GoalCard });
