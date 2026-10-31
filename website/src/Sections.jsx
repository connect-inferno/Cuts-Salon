import { useRef } from 'react';
import {
  ArrowRight, ArrowUpRight, Check, Phone, Mail, Plus, ShieldCheck, Lock, Database, FileLock2, Smartphone,
  UserRound, Cake, History, HandCoins, TabletSmartphone, Monitor, ReceiptText, Hash, Users, Wallet, MapPin, BadgeIndianRupee, PackageSearch, Receipt,
  ChartNoAxesCombined, QrCode, Building2, Target, Sparkles,
} from 'lucide-react';
import { TOUR, FEATURES, GALLERY, FAQ } from './content';
import WhatsAppIcon from './WhatsAppIcon';
import { whatsappLink, PHONE_DISPLAY, WHATSAPP_NUMBER, SUPPORT_EMAIL, DEVELOPER_NAME, DEVELOPER_URL } from './config';

const Icons = {
  ReceiptText, Hash, Users, Wallet, MapPin, BadgeIndianRupee, PackageSearch, Receipt, ChartNoAxesCombined, HandCoins, QrCode,
  WhatsApp: WhatsAppIcon, Building2, Target, Smartphone, Sparkles,
};

export function DeveloperCredit({ className }) {
  return DEVELOPER_URL ? (
    <a className={className} href={DEVELOPER_URL} target="_blank" rel="noopener">
      {DEVELOPER_NAME}
    </a>
  ) : (
    <b className={className}>{DEVELOPER_NAME}</b>
  );
}

export function Hero() {
  return (
    <section className="hero" id="top" aria-label="Introduction">
      <div className="wrap">
        <div className="hero-copy">
          <span className="eyebrow hero-in" style={{ color: 'var(--champagne)' }}>
            Salon management app
          </span>
          <h1 className="hero-title" style={{ marginTop: 18 }}>
            The <span className="serif">calm</span> way to run a busy salon.
          </h1>
          <p className="lede hero-in">
            <span className="long">
              GST billing with numbered invoices, client history and dues, staff attendance and payroll, stock and automatic WhatsApp
              reminders. One app for the owner, one for the team.
            </span>
            <span className="short">Billing, clients, staff, payroll and WhatsApp reminders, in one app.</span>
          </p>
          <div className="hero-ctas hero-in">
            <a className="btn btn-primary" href={whatsappLink()} target="_blank" rel="noopener">
              <WhatsAppIcon size={18} /> Get a demo
            </a>
            <a className="btn btn-ghost" href="#tour" data-scroll="tour">
              See the app <ArrowRight size={18} />
            </a>
          </div>
          <div className="hero-meta hero-in">
            <span><ShieldCheck size={16} /> Own database for every salon</span>
            <span><Smartphone size={16} /> Android, iOS + web</span>
            <span><WhatsAppIcon size={16} /> WhatsApp receipts</span>
          </div>
        </div>
      </div>
      <div className="scroll-hint" aria-hidden="true">
        Scroll <i />
      </div>
    </section>
  );
}

const MARQUEE = ['GST billing', 'Numbered invoices', 'Client dues', 'Birthday wishes', 'Attendance with location', 'Commission', 'Low-stock alerts', 'Expenses', 'Reports', 'Branches', 'Payment QR', 'Google review QR', 'WhatsApp reminders'];

export function Marquee() {
  const items = [...MARQUEE, ...MARQUEE];
  return (
    <div className="marquee" aria-hidden="true">
      <div className="marquee-track">
        {items.map((m, i) => (
          <span key={i}>{m}</span>
        ))}
      </div>
    </div>
  );
}

export function Tour({ reduced }) {
  if (reduced) {
    return (
      <section className="panel dark-panel dark round-top" id="tour" aria-label="App tour">
        <div className="wrap tour-static">
          {TOUR.map((s, i) => (
            <div className="row" key={s.screen}>
              <div>
                <div className="tour-step-static">
                  <span className="serif" style={{ fontSize: 22 }}>0{i + 1}</span>
                  <h3 style={{ fontSize: 34, marginTop: 8 }}>{s.title}</h3>
                  <p>{s.text}</p>
                </div>
              </div>
              <figure className="shot" style={{ width: 'auto', margin: 0 }}>
                <div className="frame">
                  <img src={`/screens/${s.screen}.jpg`} alt={`Stylux ${s.title} screen`} loading="lazy" />
                </div>
              </figure>
            </div>
          ))}
        </div>
      </section>
    );
  }
  return (
    <section className="tour dark" id="tour" aria-label="App tour">
      <div className="wrap tour-inner">
        <div className="tour-head">
          <span className="eyebrow">A tour of the owner app</span>
        </div>
        <div className="tour-steps">
          {TOUR.map((s, i) => (
            <article className="tour-step" key={s.screen} aria-label={s.title}>
              <span className="num">0{i + 1} / 0{TOUR.length}</span>
              <h3>{s.title}</h3>
              <p>{s.text}</p>
              <ul>
                {s.points.map((p) => (
                  <li key={p}>
                    <Check size={16} /> {p}
                  </li>
                ))}
              </ul>
            </article>
          ))}
        </div>
        <div className="tour-progress" aria-hidden="true">
          {TOUR.map((s) => (
            <i key={s.screen}>
              <b />
            </i>
          ))}
        </div>
      </div>
    </section>
  );
}

function TiltCard({ className, children }) {
  const ref = useRef();
  const onMove = (e) => {
    if (e.pointerType !== 'mouse') return;
    const el = ref.current;
    const r = el.getBoundingClientRect();
    const x = (e.clientX - r.left) / r.width - 0.5;
    const y = (e.clientY - r.top) / r.height - 0.5;
    el.style.transform = `perspective(900px) rotateX(${(-y * 6).toFixed(2)}deg) rotateY(${(x * 6).toFixed(2)}deg) translateY(-3px)`;
  };
  const onLeave = () => {
    ref.current.style.transform = '';
  };
  return (
    <div ref={ref} className={className} onPointerMove={onMove} onPointerLeave={onLeave}>
      {children}
    </div>
  );
}

export function Features() {
  return (
    <section className="panel round-top" id="features" data-nav="light" aria-labelledby="features-title">
      <div className="wrap">
        <div className="section-head">
          <span className="eyebrow">Everything in one place</span>
          <h2 id="features-title" className="split">
            Everything your salon runs on, <span className="serif">nothing it doesn't.</span>
          </h2>
          <p className="lede">
            Billing, clients, team, stock and money, built for how salons in India actually work: GST, UPI, pay-later clients and staff on
            commission.
          </p>
        </div>
        <div className="features">
          {FEATURES.map((f) => {
            const Icon = Icons[f.icon] ?? Icons.Sparkles;
            return (
              <TiltCard className="feature reveal-card" key={f.title}>
                <span className="tag">{f.tag}</span>
                <div className="tile">
                  <Icon size={21} />
                </div>
                <h3>{f.title}</h3>
                <p>{f.text}</p>
              </TiltCard>
            );
          })}
        </div>
      </div>
    </section>
  );
}

export function WhatsApp() {
  return (
    <section className="panel dark-panel dark" id="whatsapp" aria-labelledby="wa-title">
      <div className="wrap wa-grid">
        <div>
          <span className="eyebrow">Automatic WhatsApp</span>
          <h2 id="wa-title" className="split" style={{ marginTop: 14 }}>
            Clients hear from you <span className="serif">at the right moment.</span>
          </h2>
          <p className="lede">
            From your salon's own WhatsApp Business number, only to clients who said yes. Switch it on once and Stylux does the rest.
          </p>
          <div className="wa-list">
            {[
              { icon: Icons.ReceiptText, t: 'Bill receipt', d: 'Right after the bill is made: services, total, paid and balance due.' },
              { icon: Cake, t: 'Birthday wishes', d: 'At 10:00 AM on their birthday, with a nudge to come in.' },
              { icon: History, t: 'Come-back reminder', d: '21 days after their last visit, inviting them to book again.' },
            ].map(({ icon: I, t, d }) => (
              <div className="wa-item reveal-up" key={t}>
                <div className="tile">
                  <I size={19} />
                </div>
                <div>
                  <h3>{t}</h3>
                  <p>{d}</p>
                </div>
              </div>
            ))}
          </div>
          <p className="wa-note">Each client has an "OK to send WhatsApp messages" box, and the owner has one switch for the whole salon.</p>
        </div>
        <div className="chat" aria-label="Example WhatsApp messages">
          <div className="chat-screen">
            <div className="chat-top">
              <div className="av">YS</div>
              <div>
                <b>Your Salon</b>
                <small>Business account</small>
              </div>
            </div>
            <div className="chat-body">
              <span className="chat-day">Today</span>
              <div className="bubble">
                <span className="kind">Bill receipt</span>
                <pre>{`Hi Priya, thank you for visiting Your Salon!

Bill no: INV-0042
Services: Haircut, Hair Spa
Total: ₹1,200
Paid: ₹1,200
Balance due: ₹0

We look forward to seeing you again.`}</pre>
                <time>4:12 PM</time>
              </div>
              <div className="bubble">
                <span className="kind">Birthday wish</span>
                <pre>{`Happy Birthday, Riya! 🎂
Everyone at Your Salon wishes you a wonderful year ahead.`}</pre>
                <time>10:00 AM</time>
              </div>
              <div className="bubble">
                <span className="kind">Come-back reminder</span>
                <pre>{`Hi Arjun, it has been a few weeks since your last visit. Time for a refresh?`}</pre>
                <time>10:00 AM</time>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

const BANDS = [
  { cls: 'green', label: 'Gentle nudge', days: '30-44 days', people: [['Meera S.', '34 days ago', '#eaf1fe', '#2456c4'], ['Kabir J.', '41 days ago', '#f1edfe', '#5b3fd0']] },
  { cls: 'amber', label: 'Worth a call', days: '45-59 days', people: [['Ananya R.', '48 days ago', '#fef3e7', '#b35c10'], ['Rohit P.', '57 days ago', '#e8f4f8', '#1f6f8b']] },
  { cls: 'red', label: 'Win them back', days: '60+ days', people: [['Sana K.', '72 days ago', '#fdeded', '#c03035'], ['Vikram D.', '90 days ago', '#eef2f7', '#1e3a5f']] },
];

export function FollowUp() {
  return (
    <section className="panel white" id="clients" data-nav="light" aria-labelledby="fu-title">
      <div className="wrap">
        <div className="section-head">
          <span className="eyebrow">Client follow-up</span>
          <h2 id="fu-title" className="split">
            Spot who's drifting away, <span className="serif">before they're gone.</span>
          </h2>
          <p className="lede">
            Reports sort your clients by when they last came in. Each one has a Call button and a ready-written WhatsApp message.
          </p>
        </div>
        <div className="followup">
          {BANDS.map((b) => (
            <div className={`band ${b.cls} reveal-card`} key={b.cls}>
              <header>
                <b>
                  <span className="dot" />
                  {b.label}
                </b>
                <small>{b.days}</small>
              </header>
              <div className="who">
                {b.people.map(([n, d, bg, fg]) => (
                  <div className="person" key={n}>
                    <span className="av" style={{ background: bg, color: fg }}>
                      {n.split(' ').map((w) => w[0]).join('')}
                    </span>
                    <div>
                      <b>{n}</b>
                      <small>Last visit {d}</small>
                    </div>
                    <span className="acts" aria-hidden="true">
                      <span><Phone size={14} /></span>
                      <span><WhatsAppIcon size={14} /></span>
                    </span>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
        <div className="followup-foot">
          <div className="mini reveal-card">
            <div className="tile"><Cake size={19} /></div>
            <div>
              <h3>Birthdays this week</h3>
              <p>A list of who to wish, with the WhatsApp wish sent for you if it's switched on.</p>
            </div>
          </div>
          <div className="mini reveal-card">
            <div className="tile"><HandCoins size={19} /></div>
            <div>
              <h3>Dues, by client</h3>
              <p>What every pay-later client still owes, and a one-tap way to clear it.</p>
            </div>
          </div>
          <div className="mini reveal-card">
            <div className="tile"><UserRound size={19} /></div>
            <div>
              <h3>Full visit history</h3>
              <p>Every visit, every bill and the total they've spent, on one client page.</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export function Gallery() {
  return (
    <section className="gallery dark" id="screens" aria-labelledby="gallery-title">
      <div className="gallery-pin">
        <div className="wrap">
          <div className="section-head" style={{ marginBottom: 40 }}>
            <span className="eyebrow">Real screens</span>
            <h2 id="gallery-title" className="split" style={{ marginTop: 14 }}>
              The actual app, <span className="serif">not a mock-up.</span>
            </h2>
            <p className="lede">Taken from a demo salon in Stylux today. Swipe or scroll through.</p>
          </div>
        </div>
        <div className="gallery-track">
          {GALLERY.map((g) => (
            <figure className="shot" key={g.src}>
              <div className="frame">
                <img src={`/screens/${g.src}.jpg`} alt={`Stylux ${g.title} screen: ${g.sub}`} loading="lazy" width="540" height="873" />
              </div>
              <figcaption>
                {g.title}
                <small>{g.sub}</small>
              </figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  );
}

export function Security() {
  return (
    <section className="panel" id="security" data-nav="light" aria-labelledby="sec-title">
      <div className="wrap sec-grid">
        <div>
          <span className="eyebrow">Security</span>
          <h2 id="sec-title" className="split" style={{ marginTop: 14 }}>
            Your salon's data <span className="serif">stays your salon's.</span>
          </h2>
          <div className="sec-list">
            {[
              { i: Database, t: 'Its own isolated database', d: "Every salon runs on its own separate database and sign-in. Nothing is shared with another salon." },
              { i: Lock, t: 'Money actions are owner-only', d: 'Bills, payments, stock, payroll and targets can only be changed by the owner. The database itself enforces it, not just the app.' },
              { i: UserRound, t: 'Staff see only their own pay', d: "Salary, commission and attendance are visible to the owner and that one person. Never to coworkers." },
              { i: FileLock2, t: "Bills can't be rewritten", d: 'Once a bill is made it is never edited, and removed services are archived, so old bills stay exactly as they were.' },
            ].map(({ i: I, t, d }) => (
              <div className="sec-item reveal-up" key={t}>
                <div className="tile"><I size={19} /></div>
                <div>
                  <h3>{t}</h3>
                  <p>{d}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
        <div className="vaults" aria-hidden="true">
          {['Salon A', 'Salon B', 'Salon C', 'Salon D', 'Salon E', 'Salon F'].map((s, i) => (
            <div className="vault" key={s}>
              <div className="lock"><Lock size={19} /></div>
              <b>{s}</b>
              <small>{i === 0 ? 'Your salon' : 'Separate database'}</small>
              <div className="db"><i /><i /><i /></div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export function Platforms() {
  return (
    <section className="panel white" id="platforms" data-nav="light" aria-labelledby="plat-title">
      <div className="wrap">
        <div className="section-head center">
          <span className="eyebrow">Works everywhere</span>
          <h2 id="plat-title" className="split" style={{ marginTop: 14 }}>
            On the counter, <span className="serif">or in your pocket.</span>
          </h2>
        </div>
        <div className="plat">
          <div className="plat-card reveal-card">
            <div className="tile"><Smartphone size={22} /></div>
            <h3>Android app</h3>
            <p>Install Stylux on the counter phone or tablet. Same account, same data as on iPhone and the web.</p>
            <div className="chips"><span>Owner and staff</span><span>Opens WhatsApp & calls directly</span></div>
          </div>
          <div className="plat-card light reveal-card">
            <div className="tile"><TabletSmartphone size={22} /></div>
            <h3>iPhone and iPad</h3>
            <p>Open Stylux in Safari and tap Share, then Add to Home Screen. It gets its own icon, opens full screen and stays signed in.</p>
            <div className="chips"><span>No App Store needed</span><span>Owner and staff</span><span>Always the latest version</span></div>
          </div>
          <div className="plat-card light reveal-card">
            <div className="tile"><Monitor size={22} /></div>
            <h3>Web, on any computer</h3>
            <p>The front-desk PC or your laptop at home: open it in Chrome, Edge or Safari. Same account, same data everywhere.</p>
            <div className="chips"><span>Nothing to install</span><span>Big-screen reports</span><span>Export bills as CSV</span></div>
          </div>
        </div>
      </div>
    </section>
  );
}

export function GetStarted() {
  return (
    <section className="panel" id="pricing" data-nav="light" aria-labelledby="start-title">
      <div className="wrap">
        <div className="section-head">
          <span className="eyebrow">Get started</span>
          <h2 id="start-title" className="split" style={{ marginTop: 14 }}>
            Up and running <span className="serif">without the fuss.</span>
          </h2>
        </div>
        <div className="steps">
          {[
            ['Say hello on WhatsApp', 'Tell us about your salon: how many branches, how many staff, and how you bill today.'],
            ['We set up your salon', 'Your own database, your services and prices, your team and branches, ready to go.'],
            ['Start billing', 'Sign in as the owner, give your staff their logins, and make your first bill.'],
          ].map(([t, d], i) => (
            <div className="step reveal-card" key={t}>
              <span className="n">0{i + 1}</span>
              <h3>{t}</h3>
              <p>{d}</p>
            </div>
          ))}
        </div>
        <div className="pricing reveal-card">
          <div>
            <h3>Plans that fit your salon</h3>
            <p>Pricing depends on how many branches and staff you have. Message us and we'll send a quote.</p>
            <div className="ctas">
              <a className="btn btn-wa" href={whatsappLink("Hi! I'd like a quote for Stylux for my salon.")} target="_blank" rel="noopener">
                <WhatsAppIcon size={18} /> Ask for a quote
              </a>
              <a className="btn btn-ghost" href={`tel:+${WHATSAPP_NUMBER}`}>
                <Phone size={18} /> Call us
              </a>
            </div>
          </div>
          <ul>
            {['Your own isolated database', 'Owner and staff accounts', 'Android, iOS and web', 'Help setting up services, staff and WhatsApp'].map((p) => (
              <li key={p}><Check size={16} /> {p}</li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}

export function Faq() {
  return (
    <section className="panel white" id="faq" data-nav="light" aria-labelledby="faq-title">
      <div className="wrap">
        <div className="section-head center">
          <span className="eyebrow">FAQ</span>
          <h2 id="faq-title" className="split" style={{ marginTop: 14 }}>
            Questions, <span className="serif">answered.</span>
          </h2>
        </div>
        <div className="faq">
          {FAQ.map((f) => (
            <details key={f.q}>
              <summary>
                {f.q}
                <span className="pm"><Plus size={16} /></span>
              </summary>
              <div className="answer"><p>{f.a}</p></div>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}

export function Contact() {
  return (
    <section className="contact dark" id="contact" aria-labelledby="contact-title">
      <div className="wrap contact-grid">
        <div>
          <span className="eyebrow">Contact</span>
          <h2 id="contact-title" className="split" style={{ marginTop: 14 }}>
            Let's set up <span className="serif">your salon.</span>
          </h2>
          <p className="lede">
            WhatsApp is the quickest way to reach us: ask for a demo, a quote, or anything about how Stylux works.
          </p>
          <p className="credit">
            Stylux is designed and developed by <DeveloperCredit />. Have an idea for your salon software? We'd love to hear it.
          </p>
        </div>
        <div className="contact-cards">
          <a className="c-card wa reveal-up" href={whatsappLink()} target="_blank" rel="noopener">
            <span className="tile"><WhatsAppIcon size={22} /></span>
            <span>
              <b>WhatsApp us</b>
              <small>{PHONE_DISPLAY} · for more info</small>
            </span>
            <ArrowUpRight className="go" size={20} />
          </a>
          <a className="c-card reveal-up" href={`tel:+${WHATSAPP_NUMBER}`}>
            <span className="tile"><Phone size={22} /></span>
            <span>
              <b>Call</b>
              <small>{PHONE_DISPLAY}</small>
            </span>
            <ArrowUpRight className="go" size={20} />
          </a>
          <a className="c-card reveal-up" href={`mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent('Stylux enquiry')}`}>
            <span className="tile"><Mail size={22} /></span>
            <span>
              <b>Email</b>
              <small>{SUPPORT_EMAIL}</small>
            </span>
            <ArrowUpRight className="go" size={20} />
          </a>
        </div>
      </div>
    </section>
  );
}

export function Footer() {
  return (
    <footer className="footer">
      <div className="wrap">
        <div className="footer-inner">
          <a className="brand" href="#top" data-scroll="top" style={{ color: '#fff' }}>
            <img src="/brand/stylux-192.png" alt="" width="32" height="32" /> STYLUX
          </a>
          <nav className="links" aria-label="Footer">
            <a href="#/privacy">Privacy policy</a>
            <a href="#/disclaimer">Disclaimer</a>
            <a href="#faq" data-scroll="faq">FAQ</a>
            <a href="#contact" data-scroll="contact">Contact</a>
          </nav>
          <span className="made">
            Developed by <DeveloperCredit />
          </span>
        </div>
        <div className="big-word" aria-hidden="true">STYLUX</div>
        <p style={{ textAlign: 'center', marginTop: 20, fontSize: 13 }}>© {new Date().getFullYear()} Stylux. All rights reserved.</p>
      </div>
    </footer>
  );
}
